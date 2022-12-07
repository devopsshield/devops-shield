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

Function Get-UniqueString {
    [CmdletBinding()]
    Param(        
        [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "The Resource Group Name for which you want the unique string")]    
        [String]$ResourceGroupName,

        [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "Azure Region to use to deploy temp resource group")]
        [String]$Location, #= 'canadacentral',
    
        [PARAMETER(Mandatory = $False, Position = 2, HelpMessage = "Temp Resource Group Name To Create - if not specified a random one will be created")]
        [String]$TempResourceGroup
    )
    
    $deploymentName = "getUniqueStringValue"
    if ($TempResourceGroup) {
        Write-Host temp resource group provided
        az deployment sub create --location $Location --name $deploymentName --template-file getUniqueString.bicep  --parameters resourceGroupName=$ResourceGroupName location=$Location tempResourceGroupName=$TempResourceGroup
    }
    else {
        Write-Host temp res group not provided so will be generated for you
        az deployment sub create --location $Location --name $deploymentName --template-file getUniqueString.bicep  --parameters resourceGroupName=$ResourceGroupName location=$Location
    }
    $uniqueString = az deployment sub show -n $deploymentName --query properties.outputs.uniqueStringValue.value
    $tenantId = az deployment sub show -n $deploymentName --query properties.outputs.tenantId.value
    $tenantId = $tenantId.Replace('"', '') #remove surrounding double quotes
    $tempResourceGroupNameGenerated = az deployment sub show -n $deploymentName --query properties.outputs.tempResourceGroupNameGenerated.value
    $tempResourceGroupIdGenerated = az deployment sub show -n $deploymentName --query properties.outputs.tempResourceGroupIdGenerated.value

    Write-Host unique string          : $uniqueString
    Write-Host tenant id              : $tenantId
    Write-Host temp rg generated id   : $tempResourceGroupIdGenerated
    Write-Host temp rg generated name : $tempResourceGroupNameGenerated
    
    $hashTable = @{ UniqueString = $uniqueString; TenantId = $tenantId; TempResourceGroupIdGenerated = $tempResourceGroupIdGenerated; TempResourceGroupNameGenerated = $tempResourceGroupNameGenerated; }
    return $hashTable
}