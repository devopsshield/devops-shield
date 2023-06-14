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

Write-Host 
"---------------------------------------------------------------------------------------------------------------
Welcome to DevOps Shield - Azure Marketplace - Post Installation Script!

-> Prerequisites: You have already installed DevOps Shield managed application from the Azure Marketplace.

Steps:
  1. You will be asked to login using your Azure account that is allowed to register an application.
  2. You will be asked the information you have provided during the DevOps Shield installation.
  3. We will register an application with the Microsoft identity platform.
  4. We will update the DevOps Shield application settings.
  5. DevOps Shield is ready to use.

Contact us: 
- https://www.devopsshield.com/contact
- Feel free to contact us for assistance with the installation and configuration of the product at no cost.
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
Step 2: Please provide the following information about your DevOps Shield managed application installation from Azure Marketplace:
---------------------------------------------------------------------------------------------------------------"

$Subscription = Read-Host -Prompt '1. Enter your Azure Subscription ID or Name'
$ResourceGroupName = Read-Host -Prompt '2. Enter your Azure Resource Group (of your DevOps Shield managed application)'
$AppName = Read-Host -Prompt '3. Enter your DevOps Shield managed application name'
[ValidateSet('Y', 'N')]$MultiTenantYN = Read-Host -Prompt '4. Are you using DevOps Shield for Multitenant Azure DevOps (choose N for a Single tenant)? (Y/N)'
Write-Host '---------------------------------------------------------------------------------------------------------------'

$IsMultiTenant = $MultiTenantYN -eq "Y"

az account set -s "$Subscription" 

#Write-Host ''
#Write-Host 'Using the following Azure subscription: '
#clearaz account show

# STEP 3
Write-Host 
"---------------------------------------------------------------------------------------------------------------
Step 3: Register an application with the Microsoft identity platform for the followings:
- Subscription:                             $($Subscription)
- Resource Group:                           $($ResourceGroupName)
- DevOps Shield managed application name:   $($AppName)
- Multitenant:                              $($IsMultiTenant)
---------------------------------------------------------------------------------------------------------------"

[ValidateSet('Y', 'N')]$ContinueYN = Read-Host -Prompt 'Please confirm the information above is correct and we can continue? (Y/N)'

if ($ContinueYN -eq "N") {
    Write-Warning 'Please try again with the right information. Thank you!'
    return;
}

Write-Host ''
Write-Host 'Preparing for the DevOps Shield post install configuration...'
Write-Host ''
Write-Host '--> Getting the information of your DevOps Shield managed application'
$existingPackageJson = az managedapp show -g $ResourceGroupName -n $AppName
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
    if (!$sqlServerName) {
        $sqlServerName = "sql-devopsshield-${CustomerPrefix}${uniqueString}"
    }

    $sqlDatabaseName = $existingPackage.outputs.sqlDatabaseName.value
    if (!$sqlDatabaseName) {
        $sqlDatabaseName = "sqldb-devopsshield"
    }
    
    Write-Host --> Found DevOps Shield application with version $appVersion in managed resource group $managedResourceGroupName
}
else {
    Write-Error --> Please ensure there is a DevOps Shield managed application $AppName in your resource group $ResourceGroupName
    return;
}

$CustomerPrefix = $CustomerPrefix.Replace('"', '') #remove surrounding double quotes
$appHomepage = "https://app-devopsshield-${CustomerPrefix}${uniqueString}.azurewebsites.net" 
$appReplyUrl1 = "https://app-devopsshield-${CustomerPrefix}${uniqueString}.azurewebsites.net/signin-oidc"  
$appReplyUrl2 = "https://app-devopsshield-${CustomerPrefix}${uniqueString}.azurewebsites.net/signin-oidc-webapp"  
$appReplyUrl3 = "https://app-devopsshield-${CustomerPrefix}${uniqueString}.azurewebsites.net/oidc-consent" 

# Delete exisiting app registrations by the same name (if they exist)
$currentAppRegs = az ad app list --display-name $AppName
$currentAppRegsObject = $currentAppRegs | ConvertFrom-Json
$currentAppRegsObject | ForEach-Object -Process {
    if ($_.displayName -eq $AppName) {
        Write-Host --> Deleting the previous DevOps Shield application registration with name $_.DisplayName and id $_.appId
        az ad app delete --id $_.appId  --output none
    }
}

$manifestJsonContent = 
'{
    "appRoles": [
        {
            "allowedMemberTypes": [
                "User",
                "Application"
            ],
            "id": "__DEVOPSSHIELD_MEMBER_ROLE_ID__",
            "description": "Can access and view your DevOps Shield application.",
            "displayName": "DevOps Shield Member",
            "isEnabled": true,
            "origin": "Application",
            "value": "DevOpsShield.Member"
        },
        {
            "allowedMemberTypes": [
                "User",
                "Application"
            ],
            "id": "__DEVOPSSHIELD_OWNER_ROLE_ID__",
            "description": " Can access and manage the DevOps Shield application.",
            "displayName": "DevOps Shield Owner",
            "isEnabled": true,
            "origin": "Application",
            "value": "DevOpsShield.Owner"
        }
    ]
}'

$memberAppRoleId = [guid]::NewGuid()
$ownerAppRoleId = [guid]::NewGuid()
$manifestJsonContent = $manifestJsonContent.Replace("__DEVOPSSHIELD_MEMBER_ROLE_ID__", $memberAppRoleId)
$manifestJsonContent = $manifestJsonContent.Replace("__DEVOPSSHIELD_OWNER_ROLE_ID__", $ownerAppRoleId)

Set-Content -Path .\manifest.json -Value $manifestJsonContent

Write-Host '--> Registering the application with the Microsoft identity platform'

$app = az ad app create --display-name $AppName --enable-access-token-issuance $false --enable-id-token-issuance $true --web-home-page-url $appHomepage --web-redirect-uris $appReplyUrl1 $appReplyUrl2 $appReplyUrl3 --app-roles manifest.json | ConvertFrom-Json

Remove-Item .\manifest.json

# There is no CLI support for some properties, so we have to patch manually via az rest
$appPatchUri = "https://graph.microsoft.com/v1.0/applications/{0}" -f $app.id
$appPatchBody = '{\"web\":{\"logoutUrl\":\"https://app-devopsshield-SUFFIXTOREPLACE.azurewebsites.net/signout-oidc\"}}'
$appPatchBody = $appPatchBody.Replace('SUFFIXTOREPLACE', "${CustomerPrefix}${uniqueString}")
az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $appPatchBody  --output none
$appPatchBody = '{\"info\":{\"supportUrl\": \"https://www.devopsshield.com/contact\",\"privacyStatementUrl\": \"https://www.devopsshield.com/product-privacypolicy\", \"termsOfServiceUrl\": \"https://www.devopsshield.com/product-termsandconditions\", \"marketingUrl\": \"https://www.devopsshield.com/solution\", \"logoUrl\": \"https://www.devopsshield.com/images/logo-icon.png\"}}'
az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $appPatchBody  --output none

if ($IsMultiTenant) {
    $MyData = '{\"signInAudience\": \"AzureADMultipleOrgs\"}'
}
else {
    $MyData = '{\"signInAudience\": \"AzureADMyOrg\"}'
}
az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $MyData  --output none

Write-Host --> App Registration $app.appId created for DevOps Shield application: $appHomepage

Write-Host '--> Configuring the registered application'

# DOS LOGO
Try {
    Write-Host '--> Updating the application logo.'

    Invoke-WebRequest -Uri "https://www.devopsshield.com/images/logo-icon.png" -OutFile "DevOpsShield-Logo.png"
    
    $logoToken = (az account get-access-token --resource "https://graph.windows.net") | ConvertFrom-Json
    $bearerToken = $logoToken.accessToken

    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Authorization", "Bearer ${bearerToken}")
    $headers.Add("Content-Type", "image/png")

    $appPutMainLogoUri = "https://graph.windows.net/${tenantId}/applications/$($app.id)/mainLogo?api-version=1.6"

    Invoke-RestMethod $appPutMainLogoUri -Method 'PUT' -Headers $headers -Infile '.\DevOpsShield-Logo.png' 
}
Catch {
    Write-Host '--> An error occurred while setting the application logo.'
}
Finally {
    Remove-Item '.\DevOpsShield-Logo.png'
}

Write-Host '--> Creating the service principal for the registered application and add the API permissions.'
#Run the following commands to create a new service principal for the Azure AD application.
#Provide Application (client) Id
$appId = $app.appId

$appPostUri = "https://graph.microsoft.com/v1.0/servicePrincipals"
$appPatchBody = '{\"appId\": \"APPIDTOREPLACE\", \"appRoleAssignmentRequired\": true, \"tags\": [\"HideApp\"]}'
$appPatchBody = $appPatchBody.Replace('APPIDTOREPLACE', $appId)
$enterpriseApp = az rest --method POST --uri $appPostUri --headers 'Content-Type=application/json' --body $appPatchBody | ConvertFrom-Json

$appGetUri = "https://graph.microsoft.com/v1.0/applications/${app.appId}"
az rest --method GET --uri $appGetUri --headers 'Content-Type=application/json'  --output none
$enterpriseAppId = $enterpriseApp.id
$enterpriseAppGetUri = "https://graph.microsoft.com/v1.0/servicePrincipals/${enterpriseAppId}"
az rest --method GET --uri $enterpriseAppGetUri --headers 'Content-Type=application/json'  --output none

$tenantGetUri = "https://graph.microsoft.com/v1.0/domains?`$select=id,isDefault"
$tenants = az rest --method GET --uri $tenantGetUri --headers 'Content-Type=application/json' | ConvertFrom-Json #| Where-Object { $_.isDefault -eq $True }
$allTenants = $tenants.value
$defaultTenant = $allTenants | Where-Object { $_.isDefault -eq $True }

# Add Microsoft Graph delegated permission User.Read (Sign in and read user profile).
# user.read, openid and profile
$p1 = az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope --output none --only-show-errors
$p2 = az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions 14dad69e-099b-42c9-810b-d002981feec1=Scope --output none --only-show-errors
$p3 = az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions 37f7f235-527c-4136-accd-4a02d197296e=Scope --output none --only-show-errors
# User impersonation for Azure DevOps
$p4 = az ad app permission add --id $appId --api 499b84ac-1321-427f-aa17-267ca6975798 --api-permissions ee69721e-6c3a-468f-a9ec-302d16a4c599=Scope --output none --only-show-errors

# Add a client secret
# Add client secret with expiration. The default is 2 years.
$clientSecretName = "clientSecretToSupportOBO"
$clientSecretDuration = 2
$clientSecret = az ad app credential reset --id $appId --append --display-name $clientSecretName --years $clientSecretDuration --query password --output tsv --only-show-errors

# Add signed-in user as DevOpsShield.Owner role
$oidForCurrentUser = az ad signed-in-user show --query id  
$oidForCurrentUser = $oidForCurrentUser.Replace('"', '') # remove surrounding quotes   
$appPostBody = '{\"principalId\": \"OIDCURUSERTOREPLACE\", \"resourceId\": \"ENTAPPIDTOREPLACE\",\"appRoleId\": \"OWNERAPPROLEIDTOREPLACE\"}'
$appPostBody = $appPostBody.Replace('OIDCURUSERTOREPLACE', $oidForCurrentUser)
$appPostBody = $appPostBody.Replace('ENTAPPIDTOREPLACE', $enterpriseAppId)
$appPostBody = $appPostBody.Replace('OWNERAPPROLEIDTOREPLACE', $ownerAppRoleId)

Write-Host '--> Adding current signed in user as DevOpsShield.Owner application role.'
az rest -m POST -u "https://graph.microsoft.com/v1.0/users/${oidForCurrentUser}/appRoleAssignments" -b $appPostBody  --output none

# STEP 4
Write-Host 
"---------------------------------------------------------------------------------------------------------------
Step 4: Update DevOps Shield application settings and have it ready to use.
- AzureAd__Domain:      $($defaultTenant.id)
- AzureAd__TenantId:    $($tenantId)
- AzureAd__ClientId:    $($app.appId)
- Key Vault & App Settings
---------------------------------------------------------------------------------------------------------------"

$webAppName = "app-devopsshield-${CustomerPrefix}${UniqueString}"
    
$value1 = $app.appId    
$value2 = $clientSecret    
$value3 = $defaultTenant.id    
#$value4 = "https://login.microsoftonline.com/"    
$value5 = $tenantId

$azureAdClientSecretKeyVaultSecretName = 'AzureAd-ClientCredentials-ClientSecret'
$azureAdClientIdKeyVaultSecretName = 'AzureAd-ClientId'
$azureAdTenantIdKeyVaultSecretName = 'AzureAd-TenantId'
$azureAdDomainKeyVaultSecretName = 'AzureAd-Domain'
#$azureAdInstanceKeyVaultSecretName = 'AzureAd-Instance'

$ObjectIdForSignedInUser = $oidForCurrentUser 
    
# Injecting secrets into key vault through user $ObjectIdForSignedInUser
az keyvault set-policy -n $keyVaultName --secret-permissions get list set --object-id $ObjectIdForSignedInUser  --output none
az keyvault secret set --name $azureAdClientIdKeyVaultSecretName --vault-name $keyVaultName --value "${value1}" --output none;
az keyvault secret set --name $azureAdClientSecretKeyVaultSecretName --vault-name $keyVaultName --value "${value2}" --output none;
az keyvault secret set --name $azureAdDomainKeyVaultSecretName --vault-name $keyVaultName --value "${value3}" --output none;
#az keyvault secret set --name $azureAdInstanceKeyVaultSecretName --vault-name $keyVaultName --value "${value4}" --output none;
az keyvault secret set --name $azureAdTenantIdKeyVaultSecretName --vault-name $keyVaultName --value "${value5}" --output none;
az keyvault delete-policy -n $keyVaultName -g $managedResourceGroupName --object-id $ObjectIdForSignedInUser  --output none

# Finally we give new service principal access to key vault...
az keyvault set-policy -n $keyVaultName --secret-permissions get list --spn $app.appId --output none

Write-Host '--> Final Step: Restarting the DevOps Shield application...'
az webapp restart --name $webAppName --resource-group $managedResourceGroupName --output none

$websiteUrl = az webapp show --name $webAppName --resource-group $managedResourceGroupName --query defaultHostName
$websiteUrl = $websiteUrl.Replace('"', '')

Write-Host '--> Waiting for the application to be ready...'
Start-Sleep -Seconds 15
$homepage = Invoke-WebRequest -Uri "https://$($websiteUrl)"
Start-Sleep -Seconds 55
$homepage = Invoke-WebRequest -Uri "https://$($websiteUrl)"

# FINAL STEP
Write-Host 
"---------------------------------------------------------------------------------------------------------------
DevOps Shield post installation completed:
- Subscription:                             $($Subscription)
- Resource Group:                           $($ResourceGroupName)
- DevOps Shield managed application name:   $($AppName)
- Multitenant:                              $($IsMultiTenant)
- Application ClientId:                     $($app.appId)

Click here to start using your DevOps Shield application:

https://$($websiteUrl)

Thank you for choosing DevOps Shield!

https://www.devopsshield.com
Email: contact@devopsshield.com

Feel free to contact us for assistance with the installation and configuration of the product at no cost.
---------------------------------------------------------------------------------------------------------------"

# LOGOUT
Write-Host 'Logging out from your Azure account using az logout / az account clear ...'
Write-Host ''

az logout --only-show-errors
az account clear