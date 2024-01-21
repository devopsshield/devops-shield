# MIT License

# Copyright (c) 2024 DevOps Shield

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

Write-Host 
"---------------------------------------------------------------------------------------------------------------
Welcome to DevOps Shield - Docker Hub - Azure Installation Script!

-> Prerequisites: 
- An Azure account with an active subscription (https://azure.microsoft.com/en-in/free/).
- Azure CLI (https://docs.microsoft.com/en-us/cli/azure/install-azure-cli).

Steps:
  1. You will be asked to login using your Azure account where you have contributor permissions.
  2. You will be asked information needed for the installation of DevOps Shield as a Web App for Containers.
  3. We will create the resource group you specified if it doesn't already exist.
  4. We will deploy the DevOps Shield application in the specified resource group.
  5. DevOps Shield is ready to use!

Contact us: 
- https://www.devopsshield.com/contact
- Feel free to contact us for assistance with the installation and configuration of the product at no cost.

Report issues:
- https://github.com/devopsshield/devops-shield/issues

Docker Hub:
- https://hub.docker.com/r/devopsshield/devopsshield
---------------------------------------------------------------------------------------------------------------"

$WarningPreference = "SilentlyContinue"

# STEP 1
Write-Host 'Step 1: Login to your Azure account using az login ...'

az account clear

$login = az login --only-show-errors

if (!$login) {
    Write-Error 'Error logging in and validating your credentials.'
    return;
}

# STEP 2
Write-Host 
"---------------------------------------------------------------------------------------------------------------
Step 2: Please provide the following information about where you would like to install DevOps Shield container 
        application from Docker Hub:
---------------------------------------------------------------------------------------------------------------"

$Subscription = Read-Host -Prompt '1. Enter your Azure Subscription ID or Name'
$ResourceGroupName = Read-Host -Prompt '2. Enter your Azure Resource Group (this will be created if it does not exist)'
$location = Read-Host -Prompt '3. Enter the Azure Region where you would like to install DevOps Shield (e.g. eastus)'
Write-Host '---------------------------------------------------------------------------------------------------------------'

# check if az cli is installed
if (!(Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "az cli is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit
}

Write-Host "Setting subscription to $subscription"
az account set -s "$Subscription" 

Write-Host "Validating location $location"
# validate location
$locations = az account list-locations --query "[].name" -o tsv
if ($locations -notcontains $location) {
    Write-Host "Invalid location $location. Valid locations are: $locations"
    exit
}

# STEP 3
Write-Host
"---------------------------------------------------------------------------------------------------------------
Step 3: Creating resource group $ResourceGroupName in location $location if it does not exist...
---------------------------------------------------------------------------------------------------------------"

# check if resource group exists
$resourceGroupExists = az group exists -n $ResourceGroupName
if ($resourceGroupExists -eq "false") {
    Write-Host "Resource Group $ResourceGroupName does not exist. Creating it..."
    az group create -n $ResourceGroupName -l $location
}
else {
    Write-Host "Resource Group $resourceGroupName already exists."
}

# STEP 4
Write-Host
"---------------------------------------------------------------------------------------------------------------
Step 4: Deploying DevOps Shield application in resource group $ResourceGroupName...
---------------------------------------------------------------------------------------------------------------"

$bicepTemplateContent = "param appServicePlanName string = 'asp-devopsshield-`${uniqueString(resourceGroup().id)}'
param webAppName string = 'app-devopsshield-`${uniqueString(resourceGroup().id)}'
param dockerRegistryUserName string = 'devopsshield'
param location string = resourceGroup().location

var imageName = 'devopsshield'
var imageTag = 'latest'

resource appServicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: appServicePlanName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: location
  tags: {}
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
      linuxFxVersion: 'DOCKER|`${dockerRegistryUserName}/`${imageName}:`${imageTag}'
    }
    serverFarmId: appServicePlan.id
  }
}

output webAppUrl string = webApp.properties.defaultHostName"

Write-Host "Creating main.bicep file..."
Set-Content -Path main.bicep -Value $bicepTemplateContent

$deploymentJson = az deployment group create -f main.bicep -g $ResourceGroupName -n "devopsshield-deploy"

$deployment = $deploymentJson | ConvertFrom-Json

$defaultHostName = $deployment.properties.outputs.webAppUrl.value

$webAppUrl = "https://$defaultHostName"

Write-Host "Web App URL: $webAppUrl"

# STEP 5
Write-Host
"---------------------------------------------------------------------------------------------------------------
Step 5: DevOps Shield is ready to use!
---------------------------------------------------------------------------------------------------------------"

# open web app in browser
# check if browser is installed
if (!(Get-Command start -ErrorAction SilentlyContinue)) {
    Write-Host "Browser is not installed. Please install it."
    exit
} 
# open web app in browser
Write-Host "Opening web app in browser..."
Start-Process $webAppUrl
