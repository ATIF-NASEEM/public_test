#!/bin/bash

# Variables (Terraform will output these or you can hardcode)
VAULT_NAME="<your-key-vault-name>"
SECRET_NAME="TestSecret"

echo "Logging into Azure using Managed Identity..."
az login --identity

echo "Fetching secret: $SECRET_NAME from $VAULT_NAME..."
SECRET_VALUE=$(az keyvault secret show --name $SECRET_NAME --vault-name $VAULT_NAME --query value -o tsv)

if [ "$SECRET_VALUE" == "ConnectivitySuccessful!" ]; then
    echo "SUCCESS: Connection confirmed. Secret value: $SECRET_VALUE"
else
    echo "ERROR: Could not retrieve secret."
fi