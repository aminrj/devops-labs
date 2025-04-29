terraform {
  required_version = ">= 1.5.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.9.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.22.0"
    }
  }
}

variable "kubeconfig" {
  description = "Path to your kubeconfig file"
  type        = string
  default     = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig
  }
}

# CloudNativePG operator
resource "helm_release" "cnpg" {
  name             = "cloudnative-pg"
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.20.1"  # matches CNPG 1.22.x
  namespace        = "cnpg-system"
  create_namespace = true

  set {
    name  = "monitoring.enabled"
    value = true
  }
}

# External‑Secrets operator
resource "helm_release" "external_secrets" {
  name             = "external-secrets"
  repository       = "https://charts.external-secrets.io"
  chart            = "external-secrets"
  version          = "0.9.16"
  namespace        = "external-secrets"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = true
  }
}

# (Optional) Argo CD
resource "helm_release" "argo_cd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  # Reduce footprint for a lab / homelab
  set {
    name  = "configs.params.server.insecure"
    value = true
  }
}
