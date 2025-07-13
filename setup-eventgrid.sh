RG_NAME="az-2024-eventgrid-lab-rg"
LOCATION="westus"
STORAGE_NAME="eventgridlabstorage$RANDOM"
QUEUE_NAME="eventgridqueue"

# Create resource group
az group create --name $RG_NAME --location $LOCATION

# Create storage account to act as an endpoint
az storage account create --name $STORAGE_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS

# Create storage queue
az storage queue create --name $QUEUE_NAME --account-name $STORAGE_NAME