# MIT License

# Copyright (c) 2022 DevOps Shield

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

Function New-DevOpsShieldAppRegistrationPostCreate {
    [CmdletBinding()]
    Param( 
        [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "Subscription name or id")]
        [String]$Subscription,   
         
        [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "Resource Group containing the DevOps Shield App created in the Azure Marketplace")]
        [String]$ResourceGroupName,

        [PARAMETER(Mandatory = $True, Position = 2, HelpMessage = "Managed App Name")]
        [String]$AppName,
        
        [PARAMETER(Mandatory = $False, Position = 3, HelpMessage = "user object id to become devops shield owner - if not provided - signed-in user will be used")]
        [String]$DevOpsShieldOwnerObjectId,

        [PARAMETER(Mandatory = $False, Position = 4, HelpMessage = "Is App Registration Multi Tenant?")]
        [bool]$IsMultiTenant = $False,

        [PARAMETER(Mandatory = $false, Position = 5, HelpMessage = "use sql azure ad")]
        [bool]$UseSqlAzureAd = $false
    )
    
    az account clear #to be safe
    az login
    az account set -s "$Subscription"
    Write-Host Using the following subscription
    az account show

    $existingPackageJson = az managedapp show -g $ResourceGroupName -n $AppName
    Write-Host $existingPackageJson
    $existingPackage = $existingPackageJson | ConvertFrom-Json

    if ($existingPackage) {
        $managedResourceGroupName = $existingPackage.outputs.mainResourceGroupName.value
        $uniqueString = $existingPackage.outputs.uniqueStringGenerated.value
        $CustomerPrefix = $existingPackage.parameters.uniqueSuffix.value
        $Location = $existingPackage.location
        $tenantId = $existingPackage.parameters.tenant.value
        $appVersion = $existingPackage.plan.version
        $sqlServerName = $existingPackage.outputs.sqlServerName.value
        $keyVaultName = $existingPackage.outputs.keyVaultName.value
        if ($sqlServerName) {

        }
        else {
            Write-Warning "need to calculate sql server name"
            $sqlServerName = "sql-devopsshield${CustomerPrefix}${uniqueString}"
    
        }
        $sqlDatabaseName = $existingPackage.outputs.sqlDatabaseName.value
        if ($sqlDatabaseName) {

        }
        else {
            Write-Warning "need to calculate sql database name"
            $sqlDatabaseName = "sqldb-devopsshield"
        }
        Write-Host found the app in mrg $managedResourceGroupName with customer prefix $CustomerPrefix and unique string $uniqueString
        Write-Host app version is $appVersion
    }
    else {
        Write-Host please ensure there is a DevOps Shield Managed app $AppName in resource group $ResourceGroupName
    }

    Import-Module .\createAppRegistration.psm1  -Force
    $retValueHashTableFromAppReg = New-DevOpsShieldAppRegistration -ResourceGroupName $managedResourceGroupName `
        -AppName $AppName `
        -CustomerPrefix $CustomerPrefix -Location $Location `
        -UniqueStringKnown $uniqueString -TenantIdKnown $tenantId `
        -DevOpsShieldOwnerObjectId $DevOpsShieldOwnerObjectId `
        -IsMultiTenant $IsMultiTenant

    Write-Host configuring app settings...
        
    Write-Host "AzureAd__ClientId", $retValueHashTableFromAppReg.AppRegistrationId    
    Write-Host "AzureAd__Domain", $retValueHashTableFromAppReg.AzureAdDomain
    Write-Host "AzureAd__Instance", $retValueHashTableFromAppReg.AzureAdInstance    
    Write-Host "AzureAd__TenantId", $retValueHashTableFromAppReg.TenantId

    $webAppName = "app-devopsshield${CustomerPrefix}${UniqueString}"
    
    $value1 = $retValueHashTableFromAppReg.AppRegistrationId    
    $value2 = $retValueHashTableFromAppReg.ClientSecret    
    $value3 = $retValueHashTableFromAppReg.AzureAdDomain    
    $value4 = $retValueHashTableFromAppReg.AzureAdInstance    
    $value5 = $retValueHashTableFromAppReg.TenantId 
    
    $useKeyVaultRefForSensitiveStrings = $True #should always be true
    
    az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__ClientId=$value1 --output none
    if ($useKeyVaultRefForSensitiveStrings) {
        $value2AsKeyRef = "@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/AZURE-AD-CLIENT-SECRET-FOR-OBO)"
        az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__ClientCredentials__2__ClientSecret="`"$value2AsKeyRef`""
        # also need to push secret to kv
        if ($DevOpsShieldOwnerObjectId) {
            $ObjectIdForSignedInUser = $DevOpsShieldOwnerObjectId  
        }
        else {
            $ObjectIdForSignedInUser = $retValueHashTableFromAppReg.ObjectIdForSignedInUser 
        }
        
        Write-Host "injecting secret AZURE-AD-CLIENT-SECRET-FOR-OBO into key vault through user $ObjectIdForSignedInUser"
        az keyvault set-policy -n $keyVaultName --secret-permissions get list set --object-id $ObjectIdForSignedInUser
        az keyvault secret set --name "AZURE-AD-CLIENT-SECRET-FOR-OBO" --vault-name $keyVaultName --value "${value2}" --output none;
        az keyvault delete-policy -n $keyVaultName -g $managedResourceGroupName --object-id $ObjectIdForSignedInUser
    }
    else {        
        az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__ClientCredentials__2__ClientSecret=$value2 --output none
    }
    az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__Domain=$value3 --output none
    az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__Instance=$value4 --output none
    az webapp config appsettings set -g $managedResourceGroupName -n $webAppName --settings AzureAd__TenantId=$value5 --output none
    
    if ($UseSqlAzureAd) {
        Write-Host touching sql by activating azure ad and config app setting
        $msiobjectid = az webapp identity show --resource-group $managedResourceGroupName --name $webAppName --query principalId --output tsv
        Write-Host msi object id is $msiobjectid
        az sql server ad-admin create --display-name $webAppName --object-id $msiObjectId --resource-group $managedResourceGroupName --server $sqlServerName
        Write-Host also change conn String
        $newConnString = "Server=tcp:$sqlServerName.database.windows.net;Authentication=Active Directory Default; Database=$sqlDatabaseName;"
        az webapp config connection-string set -g $managedResourceGroupName -n $webAppName -t sqlazure --settings ComplianceConnection=$newConnString # --output none
    }
    else {
        Write-Host removing azure ad and going back to key vault ref
        az sql server ad-admin delete --resource-group $managedResourceGroupName --server $sqlServerName
        Write-Host also change conn String        
        $newConnString = "@Microsoft.KeyVault(SecretUri=https://${keyVaultName}.vault.azure.net/secrets/DevOpsShieldComplianceConnection)"
        #tricky: need to escape out double quotes in windows
        az webapp config connection-string set -g $managedResourceGroupName -n $webAppName -t sqlazure --settings ComplianceConnection="`"$newConnString`""
    }

    Write-Host "Finally we give new service principal access to key vault..."
    az keyvault set-policy -n $keyVaultName --secret-permissions get list --spn $retValueHashTableFromAppReg.AppRegistrationId

    Write-Warning "Please review settings above and ensure no secrets are visible - if so it is preferable to use key vault references."
    Write-Host "You can use this script to rotate app registration secret if required"

    Write-Host Restart web application
    az webapp restart --name $webAppName --resource-group $managedResourceGroupName

    $websiteUrl = az webapp show --name $webAppName --resource-group $managedResourceGroupName --query defaultHostName
    $websiteUrl = $websiteUrl.Replace('"', '')

    Write-Host Check it out here - may need to wait a minute: "https://$websiteUrl"
}