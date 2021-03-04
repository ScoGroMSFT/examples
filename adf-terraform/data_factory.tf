resource "azurerm_data_factory" "datafactory" {
  name                = "scogro-adf-tf-test"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_data_factory_linked_service_azure_blob_storage" "csvlinkedservice" {
  name                = "csvlinkedservice"
  resource_group_name = azurerm_resource_group.rg.name
  data_factory_name   = azurerm_data_factory.datafactory.name
  connection_string   = azurerm_storage_account.storageaccount.primary_connection_string
}

resource "azurerm_data_factory_dataset_delimited_text" "csvdataset" {
  name                = "csvdataset"
  resource_group_name = azurerm_resource_group.rg.name
  data_factory_name   = azurerm_data_factory.datafactory.name
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.csvlinkedservice.name

  azure_blob_storage_location {
    container = azurerm_storage_blob.csvblob.storage_container_name
    path     = "/"
    filename = azurerm_storage_blob.csvblob.name
  }

  column_delimiter    = ","
  row_delimiter       = "NEW"
  encoding            = "UTF-8"
  quote_character     = "\""
  escape_character    = "f"
  first_row_as_header = true
  null_value          = "NULL"
}

# The row delimiter is required in the azurerm_data_factory_dataset_delimited_text field. However,
# it doesn't get created properly there is no way to specify auto-detect (empty value) so remove the
# setting using the control plan rest API
# External programs must return a single key/value pair so return the id of the resource.
data "external" "csvrowsetfix" {
 program = ["bash", "-c", "az rest --method get --uri ${azurerm_data_factory.datafactory.id}/datasets/${azurerm_data_factory_dataset_delimited_text.csvdataset.name}?api-version=2018-06-01 | jq 'del(.properties.typeProperties.rowDelimiter)' | xargs -0 az rest --method put --uri ${azurerm_data_factory.datafactory.id}/datasets/${azurerm_data_factory_dataset_delimited_text.csvdataset.name}?api-version=2018-06-01 --body | jq '{id: .id}'"]
}

# There is no parquet formatted dataset in the provider currently. Using blob and then revising it to 
# add the parquet format allows us to set up a parquet data sink
# This works for using a Copy Data activity. However, it doesn't create a full-featured
# Parquet dataset in ADF that allows you to see/select the compression type, etc... in the Portal UX
data "external" "parquetfix" {
 program = ["bash", "-c", "az rest --method get --uri ${azurerm_data_factory.datafactory.id}/datasets/${azurerm_data_factory_dataset_azure_blob.parquetdataset.name}?api-version=2018-06-01 | jq '.properties.typeProperties +=  {format: {type: \"ParquetFormat\"}}' | xargs -0 az rest --method put --uri ${azurerm_data_factory.datafactory.id}/datasets/${azurerm_data_factory_dataset_azure_blob.parquetdataset.name}?api-version=2018-06-01 --body | jq '{id: .id}'"]
}

# This converts the datasource to a full parquet data source but subsequent TF apply commands will choke, as it 
# is unable to parse the response from the resource manager as a azurerm_data_factory_dataset_azure_blob resource type. 
# data "external" "parquetfullfix" {
# program = ["bash", "-c", "az rest --method get --uri ${azurerm_data_factory.scogroadf.id}/datasets/${azurerm_data_factory_dataset_azure_blob.parquetdata.name}?api-version=2018-06-01 | jq '.properties.type= \"Parquet\" | del(.properties.typeProperties.folderPath) | .properties.typeProperties +=  {format: {type: \"ParquetFormat\"}} | .properties.typeProperties +=  {location: {type: \"AzureBlobStorageLocation\", folderPath: \"/\", container: \"/\"}} | .type = \"RelationalTable\"' | xargs -0 az rest --method put --uri ${azurerm_data_factory.scogroadf.id}/datasets/${azurerm_data_factory_dataset_azure_blob.parquetdata.name}?api-version=2018-06-01 --body | jq '{id: .id}'"]
# }

resource "azurerm_data_factory_linked_service_azure_blob_storage" "parquetlinkedservice" {
  name                = "parquetlinkedservice"
  resource_group_name = azurerm_resource_group.rg.name
  data_factory_name   = azurerm_data_factory.datafactory.name
  connection_string   = azurerm_storage_account.storageaccount.primary_connection_string
}

resource "azurerm_data_factory_dataset_azure_blob" "parquetdataset" {
  name                = "parquetdata"
  resource_group_name = azurerm_resource_group.rg.name
  data_factory_name   = azurerm_data_factory.datafactory.name
  linked_service_name = azurerm_data_factory_linked_service_azure_blob_storage.parquetlinkedservice.name

  path     = azurerm_storage_container.parquetcontainer.name
}

resource "azurerm_data_factory_pipeline" "pipeline" {
  name                = "Csv-to-Parquet pipeline"
  resource_group_name = azurerm_resource_group.rg.name
  data_factory_name   = azurerm_data_factory.datafactory.name

  activities_json = <<JSON
 [
    {
        "name": "Copy CSV Data to Parquet",
        "type": "Copy",
        "dependsOn": [],
        "policy": {
            "timeout": "7.00:00:00",
            "retry": 0,
            "retryIntervalInSeconds": 30,
            "secureOutput": false,
            "secureInput": false
        },
        "userProperties": [],
        "typeProperties": {
            "source": {
                "type": "DelimitedTextSource",
                "storeSettings": {
                    "type": "AzureBlobStorageReadSettings",
                    "recursive": true,
                    "enablePartitionDiscovery": false
                },
                "formatSettings": {
                    "type": "DelimitedTextReadSettings"
                }
            },
            "sink": {
                "type": "BlobSink"
            },
            "enableStaging": false
        },
        "inputs": [
            {
                "referenceName": "${azurerm_data_factory_dataset_delimited_text.csvdataset.name}",
                "type": "DatasetReference"
            }
        ],
        "outputs": [
            {
                "referenceName": "${azurerm_data_factory_dataset_azure_blob.parquetdataset.name}",
                "type": "DatasetReference"
            }
        ]
    }
]
  JSON
}

