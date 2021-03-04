provider "azurerm" {
    features {}
}
 
resource "azurerm_resource_group" "rg" {
  name     = "scogro-adf-tf-example-rg"
  location = "westus2"
}
 