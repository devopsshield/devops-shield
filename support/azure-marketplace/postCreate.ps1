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

Param( 

    [PARAMETER(Mandatory = $True, Position = 0, HelpMessage = "The Managed Resource Group Name that contains the DevOps Shield App created in the Azure Marketplace")]    
    [String]$ResourceGroup,
    
    [PARAMETER(Mandatory = $True, Position = 1, HelpMessage = "Managed App Name")]
    [String]$AppName,
    
    [PARAMETER(Mandatory = $False, Position = 2, HelpMessage = "user object id to become devops shield owner - if not provided - signed-in user will be used")]
    [String]$DevOpsShieldOwnerObjectId,

    [PARAMETER(Mandatory = $False, Position = 3, HelpMessage = "Is App Registration Multi Tenant?")]
    [bool]$IsMultiTenant = $False
)
    
#sample call
# .\postCreate.ps1 -ResourceGroup "rg-managedapps" -AppName "devopsshieldcxdev009"

Import-Module .\postCreate.psm1  -Force
New-DevOpsShieldAppRegistrationPostCreate -ResourceGroup $ResourceGroup -AppName $AppName -DevOpsShieldOwnerObjectId $DevOpsShieldOwnerObjectId -IsMultiTenant $IsMultiTenant