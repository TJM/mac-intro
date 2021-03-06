output "region" {
  value = var.region
}

output "suffix" {
  value = module.gitlab-gke.suffix
}
output "gitlab_address" {
  value       = module.gitlab-gke.gitlab_address
  description = "IP address where you can connect to your GitLab instance"
}

output "chart_name" {
  value = module.gitlab-gke.chart_name
}
output "gitlab_url" {
  value       = module.gitlab-gke.gitlab_url
  description = "URL where you can access your GitLab instance"
}

output "cluster_name" {
  value       = module.gitlab-gke.cluster_name
  description = "Name of the GKE cluster that GitLab is deployed in."
}

output "cluster_location" {
  value       = module.gitlab-gke.location
  description = "Location of the GKE cluster that GitLab is deployed in."
}

output "cluster_ca_certificate" {
  value       = module.gitlab-gke.cluster_ca_certificate
  description = "CA Certificate for the GKE cluster that GitLab is deployed in."
}

output "host" {
  value       = module.gitlab-gke.host
  description = "Host for the GKE cluster that GitLab is deployed in."
}

output "token" {
  value       = module.gitlab-gke.token
  description = "Token for the GKE cluster that GitLab is deployed in."
}

output "root_password_instructions" {
  value = module.gitlab-gke.root_password_instructions
}

output "location" {
  value = module.gitlab-gke.location
}