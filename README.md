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

## Resource Provisioning (Best Practice: Modular Scripts and Sourcing Variables)

Use modular `.sh` files for each step, sourcing a common `source.sh` file for variables. This approach ensures consistency, repeatability, and easy maintenance.

### 1. Create a `0-source.sh` file for shared variables - modify variable contents as needed

```sh name=0-source.sh
# 0-source.sh
export RG_NAME="az-204-eventgrid-lab-rg"
export LOCATION="westus"
export STORAGE_NAME="eventgridlabstorage2025071408"
export QUEUE_NAME="eventgridqueue"
export TOPIC_NAME="topic-eventgrid-demo"

echo $RG_NAME
echo $LOCATION
echo $STORAGE_NAME
echo $QUEUE_NAME
echo $TOPIC_NAME

```

### 2. Create a script to provision resources (`1-setup-az-eventgrid.sh`) and run it.

```sh name=setup-eventgrid.sh
#!/bin/bash
source ./0-source.sh

az group create --name $RG_NAME --location $LOCATION

az storage account create --name $STORAGE_NAME --resource-group $RG_NAME --location $LOCATION --sku Standard_LRS

az storage queue create --name $QUEUE_NAME --account-name $STORAGE_NAME
```

### 3. Application Setup

#### Create script to Scaffold a new Azure Function (.NET) with HTTP Trigger (2-setup-dotnet-http-trigger.sh) and run it.

```sh name=init-function.sh
#!/bin/bash
func init EventGridFunctionProj --worker-runtime dotnet --target-framework net8.0
cd EventGridFunctionProj
func new --name EventPublisherFunction --template "HTTP trigger"
```
_Note: At this point you can build and run locally._

#### Create script to Add packages for Event Grid publishing (3-add-libs-eventgrid-publishing) and run it.

```sh name=add-packages.sh
dotnet add package Azure.Messaging.EventGrid
dotnet add package Azure.Storage.Queues
```

#### Implement Function logic (.NET) to POST incoming payloads to Azure Storage Queue

Create `EventPublisherFunction.cs` in your Azure Function project:

```csharp
using System.IO;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.WebJobs;
using Microsoft.Azure.WebJobs.Extensions.Http;
using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Logging;
using Azure.Storage.Queues;

public static class EventPublisherFunction
{
    [FunctionName("EventPublisherFunction")]
    public static async Task<IActionResult> Run(
        [HttpTrigger(AuthorizationLevel.Function, "post", Route = null)] HttpRequest req,
        ILogger log)
    {
        // optional logging
        log.LogInformation("C# HTTP trigger function processing a request.");

        string requestBody = await new StreamReader(req.Body).ReadToEndAsync();

        // Get connection string and queue name from environment variables
        string queueConnectionString = Environment.GetEnvironmentVariable("AzureWebJobsStorage");
        string queueName = Environment.GetEnvironmentVariable("QueueName"); // set this in local.settings.json

       // optional logging
        log.LogInformation($"queueName:{queueName}.");

        var queueClient = new QueueClient(queueConnectionString, queueName);
        await queueClient.CreateIfNotExistsAsync();

        // Enqueue message
        await queueClient.SendMessageAsync(requestBody);

        return new OkObjectResult($"Message sent to queue: {queueName}");
    }
}
```

Set up `local.settings.json` with your storage connection string and queue name:

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "<your_storage_connection_string>",
    "QueueName": "eventgridqueue"
  }
}
```

---

This function receives POST requests, reads the payload, and enqueues it to the Azure Storage Queue. Configure your resource provisioning and Event Grid subscription as described above to complete the workflow.

---

### 4. Configure Event Grid Topic & Subscription (before deploying Function)

#### Create Event Grid topic and subscribe Storage Queue

```sh name=setup-eventgrid-topic.sh
#!/bin/bash
source ./0-source.sh

az eventgrid topic create --name $TOPIC_NAME --resource-group $RG_NAME --location $LOCATION

az eventgrid event-subscription create \
  --resource-group $RG_NAME \
  --topic-name $TOPIC_NAME \
  --name "demoSubscription" \
  --endpoint-type storagequeue \
  --endpoint "/subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RG_NAME/providers/Microsoft.Storage/storageAccounts/$STORAGE_NAME/queueServices/default/queues/$QUEUE_NAME"
```

---

### 5. Deploy Function to Azure

```sh name=5-az-deploy-function.sh
#!/bin/bash
source ./0-source.sh

cd EventGridFunctionProj

az functionapp create --resource-group $RG_NAME --consumption-plan-location $LOCATION --runtime dotnet --functions-version 4 --name "EventGridFunctionProj" --storage-account $STORAGE_NAME

func azure functionapp publish EventGridFunctionProj
```

---

### 6. Event Grid Exercise (Test Locally and in Cloud)

**Note:** These tests can be performed twice:
- First, after the subscription step above, using the local endpoint.
- Again, after the deployment step above, using the cloud endpoint.

#### Send a POST Request to the Azure Function

```sh
curl -X POST <function-endpoint-url> -H "Content-Type: application/json" -d '{"data":"sample"}'
```

#### Function publishes event to Event Grid.

#### Event Grid delivers event to the Storage Queue.

#### Check the Storage Queue

```sh
az storage message peek --queue-name $QUEUE_NAME --account-name $STORAGE_NAME
```

---

**Summary:**  
- Use modular `.sh` scripts for each step.
- Use a common `source.sh` for variables.
- Always `source` `source.sh` in each script for consistent variable access.
- This pattern applies for both multi-line and one-liner scripts if variables or config are needed.---

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
