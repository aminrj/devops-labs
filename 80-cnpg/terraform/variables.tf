variable "resource_group_name" { default = "secrets-rg" }
variable "location"            { default = "westeurope" }

variable "key_vault_name"      { default = "mysecretskv" }

# Storage must be unique → change if it already exists
variable "storage_account_name" {
  default = "linkdingsa1234"
}

variable "container_name" { default = "linkding-db" }

variable "app_name"       { default = "eso-app" }

variable "db_username"    { default = "lduser" }

variable "target_cluster_server" {
  description = "Kubernetes API server URL used by Argo CD"
  default     = "https://kubernetes.default.svc"
}
