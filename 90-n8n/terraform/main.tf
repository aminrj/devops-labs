############################################################
# Providers
############################################################
terraform {
  required_version = ">= 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm",
      version = "~> 3.99"
    }
    azuread = {
      source  = "hashicorp/azuread",
      version = "~> 2.50"
    }
    random = {
      source  = "hashicorp/random",
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time",
      version = "~> 0.10"
    }
    kubectl = {
      source  = "gavinbunney/kubectl",
      version = ">= 1.14.0"
    }
  }
}

provider "helm" {
  kubernetes {
    config_path = pathexpand("~/.kube/config")
  }
}

provider "kubernetes" {
  config_path = pathexpand("~/.kube/config")
}

provider "kubectl" {
  config_path = pathexpand("~/.kube/config")
}


provider "azurerm" {
  features {}
}

provider "azuread" {}

############################################################
# Caller’s tenant / subscription info
############################################################
data "azurerm_client_config" "current" {}

############################################################
# 1.  Resource Group
############################################################
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
}

############################################################
# 2.  Key Vault
############################################################
resource "azurerm_key_vault" "this" {
  name                        = var.key_vault_name
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  enable_rbac_authorization   = true
}

############################################################
# 3.  Storage account → container → SAS token
############################################################
resource "azurerm_storage_account" "backup" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "db" {
  name                  = var.container_name
  storage_account_name  = azurerm_storage_account.backup.name
  container_access_type = "private"
}

resource "time_static" "sas_start" {}


data "azurerm_storage_account_sas" "sas" {
  connection_string = azurerm_storage_account.backup.primary_connection_string
  signed_version    = "2022-11-02"

  https_only = true
  start      = time_static.sas_start.rfc3339
  expiry     = timeadd(time_static.sas_start.rfc3339, "8760h") # 1 year

  resource_types {
    service   = true
    container = true
    object    = true
  }

  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }

  permissions {
    read    = true
    write   = true
    delete  = true
    list    = true
    add     = true
    create  = true
    update  = false
    process = false
    tag     = false
    filter  = false
  }
}

############################################################
# 4.  Azure AD app / Service-Principal for ESO
############################################################
resource "azuread_application" "eso" {
  display_name = var.app_name
}

resource "azuread_service_principal" "eso" {
  client_id = azuread_application.eso.client_id
}

resource "azuread_service_principal_password" "eso" {
  service_principal_id = azuread_service_principal.eso.id
  end_date_relative    = "8760h"
}

############################################################
# 5.  Role assignments (ESO + Terraform runner)
############################################################
resource "azurerm_role_assignment" "eso_kv_reader" {
  principal_id         = azuread_service_principal.eso.id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.this.id
}

resource "azurerm_role_assignment" "secrets_officer" {
  principal_id         = data.azurerm_client_config.current.object_id
  role_definition_name = "Key Vault Secrets Officer"
  scope                = azurerm_key_vault.this.id
}

############################################################
# 6.  Seed Key Vault secrets (SAS + backup path + DB creds)
############################################################
resource "azurerm_key_vault_secret" "sas_token" {
  name         = "${var.container_name}-blob-sas"
  value        = data.azurerm_storage_account_sas.sas.sas
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "container_name" {
  name         = "${var.container_name}-container-name"
  value        = var.container_name
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [azurerm_role_assignment.secrets_officer]
}

resource "azurerm_key_vault_secret" "destination_path" {
  name         = "${var.container_name}-destination-path"
  value        = "https://${var.storage_account_name}.blob.core.windows.net/${var.container_name}"
  key_vault_id = azurerm_key_vault.this.id
}

# resource "random_password" "db_pwd" {
#   length  = 32
#   special = true
# }
#
# resource "azurerm_key_vault_secret" "db_user" {
#   name         = "n8n-db-username"
#   value        = var.db_username
#   key_vault_id = azurerm_key_vault.this.id
# }
#
# resource "azurerm_key_vault_secret" "db_password" {
#   name         = "n8n-db-password"
#   value        = random_password.db_pwd.result
#   key_vault_id = azurerm_key_vault.this.id
# }

# n8n DB credentials
resource "random_password" "n8n_db_pwd" {
  length  = 32
  special = true
}

resource "azurerm_key_vault_secret" "n8n_db_user" {
  name         = "n8n-db-username"
  value        = "n8n"
  key_vault_id = azurerm_key_vault.this.id
}

resource "azurerm_key_vault_secret" "n8n_db_password" {
  name         = "n8n-db-password"
  value        = random_password.n8n_db_pwd.result
  key_vault_id = azurerm_key_vault.this.id
}

resource "random_password" "n8n_encryption_key" {
  length  = 64
  special = true
}

resource "azurerm_key_vault_secret" "n8n_encryption_key" {
  name         = "n8n-encryption-key"
  value        = random_password.n8n_encryption_key.result
  key_vault_id = azurerm_key_vault.this.id
}

# Install ArgoCD with Helm
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = "argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  version    = "5.46.0"

  create_namespace = true
}

resource "kubectl_manifest" "argocd_self_managed" {
  depends_on = [helm_release.argocd]

  yaml_body = templatefile("${path.module}/argocd-config.yaml", {
    TARGET_SERVER = var.target_cluster_server
  })
}

resource "helm_release" "external_secrets" {
    name             = "external-secrets"
    namespace        = "external-secrets"
    repository       = "https://charts.external-secrets.io"
    chart            = "external-secrets"
    version          = "0.9.13"
    create_namespace = true

    set {
        name  = "installCRDs"
        value = true
      }
}

resource "helm_release" "cnpg_operator" {
  name             = "cloudnative-pg"
  # namespace        = var.namespace
  namespace        = "cnpg" #TODO change this
  repository       = "https://cloudnative-pg.github.io/charts"
  chart            = "cloudnative-pg"
  version          = "0.23.2"
  create_namespace = true
  wait             = true

}
