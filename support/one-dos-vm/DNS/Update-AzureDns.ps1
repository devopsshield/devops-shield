# MIT License

# Copyright (c) 2025 DevOps Shield

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


param (
    [string]$ZoneName = "devopsabcs.com",
    [string]$customerSuffix = "mcx-002",
    [string[]]$RecordSetNames = @("defectdojo-$customerSuffix", "sonarqube-$customerSuffix", "devopsshield-$customerSuffix", "dependencytrack-fe-$customerSuffix", "dependencytrack-api-$customerSuffix"),
    [string]$ResourceGroupName = "devopsabcs-dns-rg",
    [string]$CName = "bigwin2025.devopsabcs.com", # "onedosdev003.canadacentral.cloudapp.azure.com", #bigwin2025.devopsabcs.com
    [string]$SubscriptionNameOrId = "Production"
)

# # sample usage
# .\Update-AzureDns.ps1 -customerSuffix "cx-003" `
#     -CName bigwin2025.devopsabcs.com

Write-Output "Output parameters:"
Write-Output "ZoneName: $ZoneName"
Write-Output "customerSuffix: $customerSuffix"
Write-Output "RecordSetNames: $RecordSetNames"
Write-Output "ResourceGroupName: $ResourceGroupName"
Write-Output "CName: $CName"
Write-Output "SubscriptionNameOrId: $SubscriptionNameOrId"


# Function to check if Azure CLI is installed
function Test-AzureCLI {
    if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
        Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    }
}

# Function to check if Azure CLI is logged in
function Test-AzureLogin {
    $azLoginStatus = az account show --query "user.name" -o tsv 2>$null
    if (-not $azLoginStatus) {
        Write-Error "Azure CLI is not logged in. Please log in using 'az login'."
        exit 1
    }
}

# Function to set the Azure subscription
function Set-AzureSubscription {
    Write-Host "Setting subscription to $SubscriptionNameOrId..." -ForegroundColor Green
    az account set --subscription $SubscriptionNameOrId
}

# Function to update DNS records
function Update-DnsRecords {
    foreach ($recordSetName in $RecordSetNames) {
        Write-Host "Updating DNS for record set $recordSetName in resource group $ResourceGroupName..." -ForegroundColor Green
        az network dns record-set cname set-record `
            --resource-group $ResourceGroupName `
            --subscription $SubscriptionNameOrId `
            --zone-name $ZoneName `
            --record-set-name $recordSetName `
            --ttl 3600 `
            --cname "$CName" `
            --if-none-match
    }
}

# Function to get all record sets
function Get-AllRecordSets {
    Write-Host "Listing all record sets in resource group $ResourceGroupName..." -ForegroundColor Green
    az network dns record-set list `
        --resource-group $ResourceGroupName `
        --zone-name $ZoneName `
        --query "[].{Name:name, Type:type, TTL:ttl}" -o table
}

# Main script execution
Test-AzureCLI
Test-AzureLogin
Set-AzureSubscription
Update-DnsRecords
Get-AllRecordSets