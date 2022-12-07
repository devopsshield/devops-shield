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

Function New-DevOpsShieldAppRegistration {
    [CmdletBinding()]
    Param( 

        [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "The Managed Resource Group Name")]        
        [String]$ResourceGroupName,
    
        [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "Customer provided Unique Suffix")]
        [ValidateLength(3, 8)]
        [String]$CustomerPrefix,

        [PARAMETER(Mandatory = $False, Position = 2, HelpMessage = "Azure Region")]
        [String]$Location,

        [PARAMETER(Mandatory = $False, Position = 3, HelpMessage = "user object id to become devops shield owner")]
        [String]$DevOpsShieldOwnerObjectId,

        [PARAMETER(Mandatory = $False, Position = 4, HelpMessage = "Is App Registration Multi Tenant?")]
        [bool]$IsMultiTenant = $False,

        [PARAMETER(Mandatory = $False, Position = 5, HelpMessage = "unique string if you know it")]
        [string]$UniqueStringKnown,

        [PARAMETER(Mandatory = $False, Position = 6, HelpMessage = "tenant id if you know it")]
        [string]$TenantIdKnown
    
    )

    #sample call .\createAppRegistration.ps1 -ResourceGroupName mrg-devops-shield-preview-20221023235620 -CustomerPrefix cxdev013 -Location "canadacentral"   

    if ($UniqueStringKnown && $TenantIdKnown) {
        Write-Host let us save time since you provided the unique string and tenant
        $uniqueString = $UniqueStringKnown
        $tenantId = $TenantIdKnown
    }
    else {
        Import-Module .\getUniqueString.psm1  -Force
        $retValueHashTable = Get-UniqueString -ResourceGroupName $ResourceGroupName -Location $Location
        Write-Host "Unique String generated for rg $ResourceGroupName is $($retValueHashTable.UniqueString). You may NOW delete temporary RG $($retValueHashTable.TempResourceGroupNameGenerated) in tenant $($retValueHashTable.TenantId)."
        $uniqueString = $retValueHashTable.UniqueString
        $tenantId = $retValueHashTable.TenantId
    }

    $appName = "devopsshield${CustomerPrefix}"
    $appHomepage = "https://app-devopsshield${CustomerPrefix}${uniqueString}.azurewebsites.net" 
    $appReplyUrl1 = "https://app-devopsshield${CustomerPrefix}${uniqueString}.azurewebsites.net/signin-oidc"  
    $appReplyUrl2 = "https://app-devopsshield${CustomerPrefix}${uniqueString}.azurewebsites.net/signin-oidc-webapp"  
    $appReplyUrl3 = "https://app-devopsshield${CustomerPrefix}${uniqueString}.azurewebsites.net/oidc-consent"
    
    Write-Host app home page is $appHomepage
    
    Write-Host "delete exisiting app registrations by the same name (if they exist)"
    $currentAppRegs = az ad app list --display-name $appName
    $currentAppRegsObject = $currentAppRegs | ConvertFrom-Json
    $currentAppRegsObject | ForEach-Object -Process {        
        if ($_.displayName -eq $appName) {
            Write-Host found previous devopsshield app reg  $_.DisplayName with appId $_.appId
            Write-Host so will delete it
            az ad app delete --id $_.appId
        }
    }

    Write-Host "Web App Creating..."

    $manifestJsonContent = Get-Content .\manifest.template.json
    $memberAppRoleId = [guid]::NewGuid()
    $ownerAppRoleId = [guid]::NewGuid()
    $manifestJsonContent = $manifestJsonContent.Replace("__DEVOPSSHIELD_MEMBER_ROLE_ID__", $memberAppRoleId)
    $manifestJsonContent = $manifestJsonContent.Replace("__DEVOPSSHIELD_OWNER_ROLE_ID__", $ownerAppRoleId)

    Write-Host $manifestJsonContent
    Set-Content -Path .\manifest.json -Value $manifestJsonContent

    $app = az ad app create --display-name $appName --enable-access-token-issuance $false --enable-id-token-issuance $true --web-home-page-url $appHomepage --web-redirect-uris $appReplyUrl1 $appReplyUrl2 $appReplyUrl3 --app-roles manifest.json | ConvertFrom-Json
    Write-Host Web App $app.appId Created.

    #cleanup
    Remove-Item .\manifest.json

    Write-Host "Web App Updating..."
    # there is no CLI support for some properties, so we have to patch manually via az rest
    $appPatchUri = "https://graph.microsoft.com/v1.0/applications/{0}" -f $app.id    
    $appPatchBody = '{\"web\":{\"logoutUrl\":\"https://app-devopsshieldSUFFIXTOREPLACE.azurewebsites.net/signout-oidc\"}}'
    $appPatchBody = $appPatchBody.Replace('SUFFIXTOREPLACE', "${CustomerPrefix}${uniqueString}")
    az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $appPatchBody    
    $appPatchBody = '{\"info\":{\"supportUrl\": \"https://www.devopsshield.com/support\",\"privacyStatementUrl\": \"https://www.devopsshield.com/privacy\", \"termsOfServiceUrl\": \"https://www.devopsshield.com/termsOfService\", \"marketingUrl\": \"https://www.devopsshield.com/marketing\", \"logoUrl\": \"https://www.devopsshield.com/logo\"}}'
    Write-Host $appPatchBody
    az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $appPatchBody
    
    if ($IsMultiTenant) {
        Write-Host Multitenant installation chosen
        $MyData = '{\"signInAudience\": \"AzureADMultipleOrgs\"}'
    }
    else {
        Write-Host Single tenant installation chosen
        $MyData = '{\"signInAudience\": \"AzureADMyOrg\"}'
    }
    az rest --method PATCH --uri $appPatchUri --headers 'Content-Type=application/json' --body $MyData
    Write-Host "Web App Updated."

    #Run the following commands to create a new service principal for the Azure AD application.

    #Provide Application (client) Id
    $appId = $app.appId    

    $appPostUri = "https://graph.microsoft.com/v1.0/servicePrincipals"
    $appPatchBody = '{\"appId\": \"APPIDTOREPLACE\"}'
    $appPatchBody = $appPatchBody.Replace('APPIDTOREPLACE', $appId)
    $enterpriseApp = az rest --method POST --uri $appPostUri --headers 'Content-Type=application/json' --body $appPatchBody | ConvertFrom-Json

    $appGetUri = "https://graph.microsoft.com/v1.0/applications/${app.appId}"
    az rest --method GET --uri $appGetUri --headers 'Content-Type=application/json'
    $enterpriseAppId = $enterpriseApp.id
    $enterpriseAppGetUri = "https://graph.microsoft.com/v1.0/servicePrincipals/${enterpriseAppId}"
    az rest --method GET --uri $enterpriseAppGetUri --headers 'Content-Type=application/json'

    $tenantGetUri = "https://graph.microsoft.com/v1.0/domains?`$select=id,isDefault"
    $tenants = az rest --method GET --uri $tenantGetUri --headers 'Content-Type=application/json' | ConvertFrom-Json #| Where-Object { $_.isDefault -eq $True }
    $allTenants = $tenants.value
    $defaultTenant = $allTenants | Where-Object { $_.isDefault -eq $True }
    Write-Host $defaultTenant

    #Add Microsoft Graph delegated permission User.Read (Sign in and read user profile).
    # also added openid and profile
    az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions e1fe6dd8-ba31-4d61-89e7-88639da4683d=Scope
    az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions 14dad69e-099b-42c9-810b-d002981feec1=Scope
    az ad app permission add --id $appId --api 00000003-0000-0000-c000-000000000000 --api-permissions 37f7f235-527c-4136-accd-4a02d197296e=Scope
    # to make change effective
    #az ad app permission grant --id $appId --api 00000003-0000-0000-c000-000000000000 --scope e1fe6dd8-ba31-4d61-89e7-88639da4683d
    #az ad app permission grant --id $appId --api 00000003-0000-0000-c000-000000000000 --scope 14dad69e-099b-42c9-810b-d002981feec1
    #az ad app permission grant --id $appId --api 00000003-0000-0000-c000-000000000000 --scope 37f7f235-527c-4136-accd-4a02d197296e
    # user impersonation ADO
    az ad app permission add --id $appId --api 499b84ac-1321-427f-aa17-267ca6975798 --api-permissions ee69721e-6c3a-468f-a9ec-302d16a4c599=Scope
    #az ad app permission grant --id $appId --api 499b84ac-1321-427f-aa17-267ca6975798 --scope ee69721e-6c3a-468f-a9ec-302d16a4c599

    # add a client secret
    ###Add client secret with expiration. The default is 2 years.
    $clientSecretName = "clientSecretToSupportOBO"
    $clientSecretDuration = 2
    $clientSecret = az ad app credential reset --id $appId --append --display-name $clientSecretName --years $clientSecretDuration --query password --output tsv
    
    #add provided user object (or signed-in user) as DevOpsShield.Owner 
    if ($DevOpsShieldOwnerObjectId) {
        Write-Host user object id supplied is $DevOpsShieldOwnerObjectId
        $oidForCurrentUser = $DevOpsShieldOwnerObjectId
        az ad user show --id $DevOpsShieldOwnerObjectId
    }
    else {
        Write-Host current user signed in is   
        az ad signed-in-user show
        $oidForCurrentUser = az ad signed-in-user show --query id
    }
    
    $oidForCurrentUser = $oidForCurrentUser.Replace('"', '') # remove surrounding quotes   
    $appPostBody = '{\"principalId\": \"OIDCURUSERTOREPLACE\", \"resourceId\": \"ENTAPPIDTOREPLACE\",\"appRoleId\": \"OWNERAPPROLEIDTOREPLACE\"}'
    $appPostBody = $appPostBody.Replace('OIDCURUSERTOREPLACE', $oidForCurrentUser)
    $appPostBody = $appPostBody.Replace('ENTAPPIDTOREPLACE', $enterpriseAppId)
    $appPostBody = $appPostBody.Replace('OWNERAPPROLEIDTOREPLACE', $ownerAppRoleId)
    Write-Host $appPostBody
    Write-Host adding current signed in user as DevOpsShield Owner
    az rest -m POST -u "https://graph.microsoft.com/v1.0/users/${oidForCurrentUser}/appRoleAssignments" -b $appPostBody

    Write-Host Fill this up in Marketplace
    Write-Host Key Vault Settings
    Write-Host Object Id for UPN with Get, List, and Set secrets $oidForCurrentUser
    Write-Host Application Registration Settings
    Write-Host app registration id $app.appId
    Write-Host tenant id $tenantId
    Write-Host enterprise app object id $enterpriseApp.id
    Write-Host azure ad instance "https://login.microsoftonline.com/"
    Write-Host azure ad domain $defaultTenant.id

    $hashTable = @{ AppRegistrationId = $app.appId; TenantId = $tenantId; EnterpriseAppObjectId = $enterpriseApp.id; AzureAdInstance = "https://login.microsoftonline.com/"; AzureAdDomain = $defaultTenant.id; ClientSecret = $clientSecret; ObjectIdForSignedInUser = $oidForCurrentUser; UniqueString = $uniqueString; }
    return $hashTable
}

