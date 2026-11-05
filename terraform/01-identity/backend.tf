terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true

    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sthybridlab2629100752"
    container_name       = "tfstate"
    key                  = "hybrid-identity.tfstate"
  }
}
