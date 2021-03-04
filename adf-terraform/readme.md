# Simple CSV -> Parquet Pipeline in ADF

## CSV Dataset

Following the samples for creating a CSV-delimited test dataset [here](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/data_factory_dataset_delimited_text), I ended up with a dataset whose row_delimiter was set the the literal text "NEW". I was unable to figure out how to actually tell this to use the default (auto-detect \n, \r, or \r\n) so I used a REST call to the RM endpoint to modify the underlying ARM template, removing the rowDelimiter line which worked to use the default. (The property is shown below as an illustration of the incorrect outcome. This property is required.)

```json
{
    "name": "csvdata",
    "properties": {
        "linkedServiceName": {
            "referenceName": "scogroadfcsv",
            "type": "LinkedServiceReference"
        },
        "annotations": [],
        "type": "DelimitedText",
        "typeProperties": {
            "location": {
                "type": "AzureBlobStorageLocation",
                "fileName": "adfblobdata.csv",
                "folderPath": "/",
                "container": "csvdata"
            },
            "columnDelimiter": ",",
            "rowDelimiter": "NEW",
            "compressionCodec": "",
            "compressionLevel": "",
            "encodingName": "UTF-8",
            "escapeChar": "f",
            "firstRowAsHeader": true,
            "nullValue": "NULL",
            "quoteChar": "\""
        },
        "schema": []
    },
    "type": "Microsoft.DataFactory/factories/datasets"
}
```

## Parquet Dataset

So at this point, the TF provider for ADF does not support parquet datasets directly. You can create them via the UI but not via TF.

I found a workaround that allowed me to create a vanilla blob resource and modify the underlying ARM template using REST calls to tell ADF to treat the blob resource as a parquet-formatted sink. This is done by adding the format object under typeProperties. The rest of the structure is what's created by TF.

```json
{
    "name": "parquetdata",
    "properties": {
        "linkedServiceName": {
            "referenceName": "scogroadfparquet",
            "type": "LinkedServiceReference"
        },
        "annotations": [],
        "type": "AzureBlob",
        "typeProperties": {
            "format": {
                "type": "ParquetFormat"
            },
            "fileName": "",
            "folderPath": "parquetdata"
        }
    },
    "type": "Microsoft.DataFactory/factories/datasets"
}
```

I created a full Parquet dataset via the UI and then programmatically changed the resource template via the RM REST API, which created the correct resource type in ADF but caused Terraform to error out on subsequent executions, as the resource could no longer be interpreted as an Azure blob.