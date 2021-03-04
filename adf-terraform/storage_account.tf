
resource "azurerm_storage_account" "storageaccount" {
  name                     = "adftftest"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Source Container that holds csv data
resource "azurerm_storage_container" "csvcontainer" {
  name                  = "csvdata"
  storage_account_name  = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}

# Source blob that contains csv data
resource "azurerm_storage_blob" "csvblob" {
  name                   = "adfblobdata.csv"
  storage_account_name   = azurerm_storage_account.storageaccount.name
  storage_container_name = azurerm_storage_container.csvcontainer.name
  type                   = "Block"
  source                 = "${path.root}/testdata/adftestdata.csv"
}

# Target container to receive Parquet formatted data
resource "azurerm_storage_container" "parquetcontainer" {
  name                  = "parquetdata"
  storage_account_name  = azurerm_storage_account.storageaccount.name
  container_access_type = "private"
}
