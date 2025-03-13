param (
    [Parameter(Mandatory = $false)]
    [string]$resourceGroupName = "rg-onedos-dev-003",

    [Parameter(Mandatory = $false)]
    [string]$vmName = "onedosdev003",

    [Parameter(Mandatory = $false)]
    [string]$subscriptionNameOrId = "QA",

    [Parameter(Mandatory = $false)]
    [string]$nsgName = "onedosdev003-nsg",

    [Parameter(Mandatory = $false)]
    [bool]$enableHttp = $false
)

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
    Write-Host "Setting subscription to $subscriptionNameOrId..." -ForegroundColor Green
    az account set --subscription $subscriptionNameOrId
}

# Function to open a port on the VM
function Open-Port {
    param (
        [Parameter(Mandatory = $true)]
        [string]$port,

        [Parameter(Mandatory = $true)]
        [string]$priority
    )

    Write-Output "Opening port $port for VM $vmName in resource group $resourceGroupName..."
    az vm open-port --resource-group $resourceGroupName `
        --name $vmName `
        --port $port `
        --priority $priority
}

# Function to list all inbound security rules
function Get-InboundSecurityRules {
    Write-Host "Listing all inbound security rules for NSG $nsgName in resource group $resourceGroupName..." -ForegroundColor Green
    az network nsg rule list --resource-group $resourceGroupName `
        --nsg-name $nsgName --query "[?direction=='Inbound']" -o table
}

# Function to remove a port rule from the NSG
function Remove-PortRule {
    param (
        [Parameter(Mandatory = $true)]
        [string]$ruleName
    )

    Write-Output "Removing inbound security rule $ruleName from NSG $nsgName in resource group $resourceGroupName..."
    az network nsg rule delete --resource-group $resourceGroupName `
        --nsg-name $nsgName `
        --name $ruleName
}

# Main script execution
Test-AzureCLI
Test-AzureLogin
Set-AzureSubscription

# Open ports 80 and 443
Open-Port -port 80 -priority 100
Open-Port -port 443 -priority 101

# Open or close additional HTTP ports based on $enableHttp
if ($enableHttp) {
    Write-Host "Opening additional HTTP ports..." -ForegroundColor Green
    Open-Port -port 8080 -priority 102
    Open-Port -port 8081 -priority 103
    Open-Port -port 8082 -priority 104
    Open-Port -port 8083 -priority 105
    Open-Port -port 9001 -priority 106
}
else {
    Write-Host "Closing additional HTTP ports..." -ForegroundColor Green
    $ruleNames = @("open-port-8080", "open-port-8081", "open-port-8082", "open-port-8083", "open-port-9001")
    foreach ($ruleName in $ruleNames) {
        Remove-PortRule -ruleName $ruleName
    }
}

# List all inbound security rules
Get-InboundSecurityRules