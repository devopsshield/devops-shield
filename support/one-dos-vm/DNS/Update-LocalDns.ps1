param (
    [Parameter(Mandatory = $false)]
    [string]$ZoneName = "devopsabcs.com",

    [string]$customerSuffix = "cx-003",

    [Parameter(Mandatory = $false)]
    [string[]]$CnameRecordNames = @("defectdojo-$customerSuffix", "sonarqube-$customerSuffix", "devopsshield-$customerSuffix", "dependencytrack-fe-$customerSuffix", "dependencytrack-api-$customerSuffix"),

    [Parameter(Mandatory = $false)]
    [string]$DnsServer = "dc2devops.devopsabcs.com",

    [Parameter(Mandatory = $false)]
    [string]$CnameRecordTarget = "onedosdev003.canadacentral.cloudapp.azure.com" #onedosvmcx003.devopsabcs.com
)

# # sample usage
# .\Update-LocalDns.ps1 -customerSuffix "cx-003" `
#     -CnameRecordTarget "onedosvmcx003.devopsabcs.com"

# Verify if DnsServer PowerShell module is installed
function Test-DnsServerModule {
    if (-not (Get-Module -ListAvailable -Name DnsServer)) {
        Write-Error "DnsServer module is not installed. Please install it from the PowerShell Gallery."
        exit 1
    }
}

# Function to update CNAME records
function Update-CnameRecords {
    param (
        [Parameter(Mandatory = $true)]
        [string[]]$CnameRecordNames,

        [Parameter(Mandatory = $true)]
        [string]$ZoneName,

        [Parameter(Mandatory = $true)]
        [string]$DnsServer,

        [Parameter(Mandatory = $true)]
        [string]$CnameRecordTarget
    )

    foreach ($cnameRecord in $CnameRecordNames) {
        try {
            # Remove the existing CNAME record
            Write-Host "Removing existing CNAME record for $cnameRecord..." -ForegroundColor Green
            Write-Host "COMMAND: Remove-DnsServerResourceRecord -Name $cnameRecord -ZoneName $ZoneName -ComputerName $DnsServer -RRType CNAME -Force" -ForegroundColor Green
            Remove-DnsServerResourceRecord -Name $cnameRecord `
                -ZoneName $ZoneName `
                -ComputerName $DnsServer `
                -RRType CNAME -Force                      
        }
        catch {
            Write-Error "Failed to update CNAME record for ${cnameRecord}: $_"
        }
        try {
            # Add the new CNAME record
            Write-Host "Adding new CNAME record for $cnameRecord..." -ForegroundColor Green
            Write-Host "COMMAND: Add-DnsServerResourceRecordCName -Name $cnameRecord -ZoneName $ZoneName -ComputerName $DnsServer -Target $CnameRecordTarget" -ForegroundColor Green
            Add-DnsServerResourceRecordCName -Name $cnameRecord `
                -ZoneName $ZoneName `
                -ComputerName $DnsServer `
                -HostNameAlias $CnameRecordTarget

            Write-Host "CNAME record for $cnameRecord updated successfully." -ForegroundColor Green
        }
        catch {
            Write-Error "Failed to add CNAME record for ${cnameRecord}: $_"
        }
    }
}

# Main script execution
Test-DnsServerModule
Update-CnameRecords -CnameRecordNames $CnameRecordNames `
    -ZoneName $ZoneName `
    -DnsServer $DnsServer `
    -CnameRecordTarget $CnameRecordTarget
