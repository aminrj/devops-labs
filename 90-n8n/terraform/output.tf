output "client_id" {
  value = azuread_application.eso.client_id
}

output "client_secret" {
  value       = azuread_service_principal_password.eso.value
  sensitive   = true
}

output "vault_uri" {
  value = azurerm_key_vault.this.vault_uri
}

output "backup_destination" {
  value     = azurerm_key_vault_secret.destination_path.value
  sensitive = true
}

output "sas_token_name" {
  value = azurerm_key_vault_secret.sas_token.name
}
