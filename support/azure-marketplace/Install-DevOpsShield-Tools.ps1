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
    [Parameter()]
    [string]
    $Branch = "main"
)
#This script will download a list of files from GitHub to the folder it is running from

#GitHub base URL used for downloads. Base URL can't end with a /
$baseURL = "https://raw.githubusercontent.com/devopsshield/devops-shield/$Branch/support/azure-marketplace"

$workFolder = (Get-Location).Path
$fileListName = "fileList.txt"
Write-Host "Work Folder: $workFolder"
Invoke-WebRequest $baseURL/$fileListName -OutFile $workFolder/$fileListName

Write-Host "Downloading from: $baseURL"
Write-Host "Fetching these files:"
Get-Content $workFolder/$fileListName | `
    ForEach-Object { Write-Host "   $_" }

Get-Content $workFolder/$fileListName | `
    ForEach-Object { Invoke-WebRequest $baseURL/$_ -OutFile $workFolder/$(Split-Path $_ -Leaf) }

Write-Host "Congratulations! You can now run the following script:"
Write-Host ".\postCreate.ps1 -Subscription `"<YOUR-AZURE-SUBSCRIPTION>`" -ResourceGroup `"<YOUR-RESOURCE-GROUP-NAME-THAT-CONTAINS-THE-MANAGED-APP>`" -AppName `"<THE-MANAGED-APP-NAME>`""
Write-Host
Write-Host "For example:"
Write-Host ".\postCreate.ps1 -Subscription `"IT Test`" -ResourceGroup `"rg-managedapps`" -AppName `"devopsshieldtest`""