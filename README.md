# Azure-Event-Grid-Minimal-Lab
# Azure Event Grid Minimal Lab (Enterprise Best Practices)

This repository demonstrates how to set up and exercise Azure Event Grid using practices consistent with enterprise best practices. All infrastructure provisioning and configuration steps use the Azure CLI for repeatability and automation. Application code is kept minimal, but structured as if for production. This guide can be followed to repeat the setup or adapt it for your own organization.

---

## Product Description

This project delivers a minimal enterprise-grade event-driven system using Azure services:

- **Azure Function (.NET):** An HTTP-triggered function that receives POST requests.
- **Event Grid:** Used by the Function to publish events/messages.
- **Azure Storage Queue:** Subscribes to the Event Grid topic and receives the events, acting as a durable backend for further processing.

**Operational Flow:**
1. External systems or users POST content to the Azure Function endpoint.
2. The Azure Function publishes an event to Event Grid.
3. Event Grid delivers the event to the configured Azure Storage Queue.
4. Downstream systems/processes can consume messages from the queue.

This pattern is highly adaptable for real-world enterprise workloads, ensuring scalability, durability, and maintainability.

---

## Testing Method

Follow this sequence to validate the system:

1. **Provision the Azure Storage Queue**
    - Create a storage account and queue using Azure CLI.

2. **Deploy the Azure Function**
    - Build and publish the .NET Azure Function to Azure.

3. **POST to the Function Endpoint**
    - Use `curl`, Postman, or similar tools to send data to the Function’s HTTP endpoint.

4. **Verify Message Delivery**
    - Check the Azure Storage Queue using Azure CLI, Azure Storage Explorer, or code to confirm the message exists.

---

## Table of Contents

- [Product Description](#product-description)
- [Testing Method](#testing-method)
- [Project Overview](#project-overview)
- [Technology Stack](#technology-stack)
- [Pre-requisites](#pre-requisites)
- [Azure CLI Setup](#azure-cli-setup)
- [Resource Provisioning](#resource-provisioning)
- [Application Setup](#application-setup)
- [Event Grid Exercise](#event-grid-exercise)
- [Enterprise Practices](#enterprise-practices)
- [Local Development (IDE)](#local-development-ide)
- [Cleanup](#cleanup)
- [References](#references)

---

## Project Overview

This project provisions Azure resources and exercises Event Grid with a minimal, repeatable workflow. It is suitable as a template for enterprise event-driven architectures and can be expanded for real-world products.

---

## Technology Stack

- **Infrastructure as Code:** Azure CLI scripts (can be migrated to Bicep/Terraform)
- **Application:** .NET 8 (C#) for publisher/subscriber (replaceable with Java/Python/Node)
- **Event Grid Topic:** Custom topic
- **Authentication:** Azure AD (Service Principal recommended for automation)
- **Local Development:** Visual Studio Code (cross-platform), with recommended extensions

---

## Pre-requisites

- Azure subscription (with permissions to create resources)
- Azure CLI installed ([Install guide](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli))
- .NET 8 SDK ([Download](https://dotnet.microsoft.com/en-us/download/dotnet/8.0))
- Visual Studio Code ([Download](https://code.visualstudio.com/)) or preferred IDE
- jq (for scripting convenience, optional)

---

## Azure CLI Setup

1. **Login**
   ```sh
   az login
   ```

2. **Set Default Subscription**
   ```sh
   az account set --subscription "<your-subscription-id>"
   ```

3. **(Optional) Create Service Principal**
   For CI/CD or automation:
   ```sh
   az ad sp create-for-rbac --name "<your-app-name>" --role contributor
   ```

---

## Resource Provisioning

Use the CLI for resource creation. Replace variables as appropriate.

```sh
RG_NAME="eventgrid-demo-rg"
LOCATION="eastus"
STORAGE_NAME="eventgriddemostorage$RANDOM"
QUEUE_NAME="eventgridqueue"

# Create resource group
az group create --name $RG_NAME --location $LOCATION

# Create storage account to act as an endpoint
az storage account create --name $STORAGE_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS

# Create storage queue
az storage queue create --name $QUEUE_NAME --account-name $STORAGE_NAME
```

---

## Application Setup

1. **Create Azure Function (.NET) with HTTP Trigger**
   - Scaffold a new HTTP-triggered Azure Function:
     ```sh
     func init EventGridFunctionProj --worker-runtime dotnet
     cd EventGridFunctionProj
     func new --name EventPublisherFunction --template "HTTP trigger"
     ```
   - Add packages for Event Grid publishing:
     ```sh
     dotnet add package Azure.Messaging.EventGrid
     ```

   - Implement Function logic to POST incoming payloads as events to Event Grid (see `EventPublisherFunction.cs`).

2. **Deploy Function to Azure**
   - Create a Function App:
     ```sh
     az functionapp create --resource-group $RG_NAME --consumption-plan-location $LOCATION --runtime dotnet --functions-version 4 --name <your-func-name> --storage-account $STORAGE_NAME
     ```
   - Deploy code:
     ```sh
     func azure functionapp publish <your-func-name>
     ```

3. **Configure Event Grid Topic & Subscription**
   - Create a custom Event Grid topic:
     ```sh
     TOPIC_NAME="eventgrid-demo-topic"
     az eventgrid topic create --name $TOPIC_NAME --resource-group $RG_NAME --location $LOCATION
     ```
   - Subscribe the Storage Queue to the topic:
     ```sh
     az eventgrid event-subscription create \
       --resource-group $RG_NAME \
       --topic-name $TOPIC_NAME \
       --name "demoSubscription" \
       --endpoint-type storagequeue \
       --endpoint "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME/queueServices/default/queues/$QUEUE_NAME"
     ```

---

## Event Grid Exercise

1. **Send a POST Request to the Azure Function**
   ```sh
   curl -X POST <function-endpoint-url> -H "Content-Type: application/json" -d '{"data":"sample"}'
   ```

2. **Function publishes event to Event Grid.**

3. **Event Grid delivers event to the Storage Queue.**

4. **Check the Storage Queue**
   - Use Azure CLI or Storage Explorer to confirm message delivery:
     ```sh
     az storage message peek --queue-name $QUEUE_NAME --account-name $STORAGE_NAME
     ```

---

## Enterprise Practices

- **Automation:** All steps scripted with Azure CLI; can be converted to CI/CD or IaC templates.
- **Security:** Use Azure AD Service Principal for automation and RBAC for resource control.
- **Naming Conventions:** Use consistent, discoverable resource names.
- **Separation of Concerns:** Separate publisher, topic, and subscriber logic.
- **Monitoring:** Enable diagnostics on Event Grid topic and endpoints.

---

## Local Development (IDE)

1. **Open Solution in VS Code**
   ```sh
   code .
   ```

2. **Recommended Extensions**
   - C# (OmniSharp)
   - Azure Tools
   - Azure CLI Tools

3. **Debug/Run**
   - Use built-in VS Code terminal for CLI commands.
   - Use VS Code debugger for .NET app.

---

## Cleanup

To remove all resources:
```sh
az group delete --name $RG_NAME --yes
```

---

## References

- [Azure Event Grid Documentation](https://docs.microsoft.com/en-us/azure/event-grid/)
- [Azure CLI Reference](https://docs.microsoft.com/en-us/cli/azure/eventgrid)
- [Enterprise Patterns for Event Grid](https://learn.microsoft.com/en-us/azure/architecture/guide/architecture-styles/event-driven)
- [.NET Event Grid SDK](https://learn.microsoft.com/en-us/dotnet/api/overview/azure/eventgrid)

---

## Next Steps

- Expand publisher/subscriber code for real scenarios
- Integrate with CI/CD pipeline
- Implement more secure authentication flows
