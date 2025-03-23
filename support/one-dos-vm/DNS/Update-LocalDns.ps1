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
    [Parameter(Mandatory = $false)]
    [string]$ZoneName = "devopsabcs.com",

    [string]$customerSuffix = "cx-002",

    [Parameter(Mandatory = $false)]
    [string[]]$CnameRecordNames = @("defectdojo-$customerSuffix", "sonarqube-$customerSuffix", "devopsshield-$customerSuffix", "dependencytrack-fe-$customerSuffix", "dependencytrack-api-$customerSuffix"),

    [Parameter(Mandatory = $false)]
    [string]$DnsServer = "dc2devops.devopsabcs.com",

    [Parameter(Mandatory = $false)]
    [string]$CnameRecordTarget = "onedosmngsvc002.devopsabcs.com" #"onedosdev003.canadacentral.cloudapp.azure.com" #onedosvmcx003.devopsabcs.com #
)

# # sample usage
# .\Update-LocalDns.ps1 -customerSuffix "cx-002" `
#     -CnameRecordTarget "onedosmngsvc002.devopsabcs.com"

Write-Output "Output parameters:"
Write-Output "ZoneName: $ZoneName"
Write-Output "customerSuffix: $customerSuffix"
Write-Output "CnameRecordNames: $CnameRecordNames"
Write-Output "DnsServer: $DnsServer"
Write-Output "CnameRecordTarget: $CnameRecordTarget"


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