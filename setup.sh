#! /bin/bash

# gcp project
export PROJECT="$(gcloud config get-value project)"
echo "Your current configured gcloud project is $PROJECT"
echo ""

# sets git specific variables
export URL="$(git config --get remote.origin.url)"
export EMAIL="$(git config --get user.email)"

# if a git email isnt configured for the user, it will exit and refer them to do so
if [[ -z $EMAIL ]]
then
    echo "This installation takes place in a few parts..."
    echo ""
    echo "Before executing run the following: "
    echo "
    git config --global user.email \"EMAIL\"
    git config --global user.name \"USERNAME\"
    "
    sleep 2
    exit 0
fi
echo "Git email $EMAIL"
echo ""
TOKEN=$(cat token)
if [[ -z $TOKEN ]]
then
    # prompts for github personal access token
    read -p "Enter a github personal access token: " TOKEN
fi

# checks if terraform state file exists, if it does - sets the cluster_name to the output in the state file
if [[ ! -f './terraform.tfstate' ]]
then
    read -p "Enter a cluster name: " NAME
fi
if [[ -f './terraform.tfstate' ]]
then
    export NAME="$(cat terraform.tfstate|jq -r '.outputs.cluster_name.value')"
    echo "Your existing cluster is called $NAME"
fi

# creates gcp project to use for example
echo ""
helm repo add gitlab https://charts.gitlab.io
helm repo update
terraform init
sleep 5
terraform apply -var "certmanager_email=${EMAIL}" -var "cluster_name=${NAME}" -var "project_id=${PROJECT}" -auto-approve
sleep 5

# sets regex for parsing git specifics to configure flux values.yaml
basename=$(basename $URL)
re="^(https|git)(:\/\/|@)([^\/:]+)[\/:]([^\/:]+)\/(.+).git$"
if [[ $URL =~ $re ]]; then    
    USERNAME=${BASH_REMATCH[4]}
    REPO=${BASH_REMATCH[5]}
fi
echo ""
echo "Git is configured for $USERNAME on the $REPO repository."
echo ""

# gets k8s cluster name and generates credentials
export REGION=$(cat terraform.tfstate|jq -r '.outputs.location.value')

gcloud container clusters get-credentials $NAME --zone $REGION --project $PROJECT -q

# sets current gcp user as cluster admin 
kubectl create clusterrolebinding cluster-admin-binding \
--clusterrole cluster-admin \
--user $(gcloud config get-value account)

# creates the flux namespace (if it doesnt exist)
ns=$(kubectl get ns|grep flux)
helm repo add stable https://kubernetes-charts.storage.googleapis.com/
helm repo add fluxcd https://charts.fluxcd.io
if [[ -z $ns ]]
then
    kubectl create namespace flux
fi

# creates the ssh key used for a deploy key on the repo and then creates a related k8s secret
s=$(kubectl get secrets -n flux|grep flux-ssh)
if [[ -z $s ]]
then
    ssh-keygen -t rsa -N '' -f ./id_rsa -C flux-ssh <<< y
    kubectl create secret generic flux-ssh --from-file=identity=./id_rsa -n flux

    ## adds the deploy key created above to the github repo
    curl -s \
    -X POST \
    -H "Authorization: token ${TOKEN}" \
    "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/repos/${USERNAME}/${REPO}/keys" \
    -d "{\"key\":\"$(cat ./id_rsa.pub)\"}"
fi

# installs helm-operator to manage helmreleases
helm upgrade --install helm-operator --version 1.0.2 \
fluxcd/helm-operator \
 -f ./flux/helmOperator.yaml \
 -n flux

# installs flux
sed "s/USERNAME/$USERNAME/g; s/EMAIL/$EMAIL/g; s/REPO/$REPO/g" ./templates/flux.yaml.tpl > "./flux/flux.yaml" 
helm upgrade --install flux \
fluxcd/flux --version 1.3.0 \
-f "./flux/flux.yaml" \
-n flux


# cleanup
if [[ -f id_rsa ]]
then
    rm id_rsa*
fi

echo ""
export GITLAB_URL=$(cat terraform.tfstate|jq -r '.outputs.gitlab_url.value')
export CHART_NAME=$(cat terraform.tfstate|jq -r '.outputs.chart_name.value')
export GITLAB_PASS=$(kubectl get secret $CHART_NAME-gitlab-initial-root-password -o go-template='{{ .data.password }}' | base64 -d && echo)
echo "The Gitlab Address is $GITLAB_URL"
echo "The Gitlab Root Password is $GITLAB_PASS"
