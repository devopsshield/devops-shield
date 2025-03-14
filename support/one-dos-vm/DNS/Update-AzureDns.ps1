param (
    [string]$ZoneName = "devopsabcs.com",
    [string]$customerSuffix = "cx-003",
    [string[]]$RecordSetNames = @("defectdojo-$customerSuffix", "sonarqube-$customerSuffix", "devopsshield-$customerSuffix", "dependencytrack-fe-$customerSuffix", "dependencytrack-api-$customerSuffix"),
    [string]$ResourceGroupName = "devopsabcs-dns-rg",
    [string]$CName = "onedosdev003.canadacentral.cloudapp.azure.com", #bigwin2025.devopsabcs.com
    [string]$SubscriptionNameOrId = "Production"
)

# # sample usage
# .\Update-AzureDns.ps1 -customerSuffix "cx-003" `
#     -CName bigwin2025.devopsabcs.com

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
