# Post Install Script to create App Registration for DevOps Shield

## Usage

### Prerequisite

You have already installed DevOps Shield from the Azure Marketplace

Sample Installation:
![image](https://user-images.githubusercontent.com/112144174/230929336-1e49f495-5e17-47fa-8313-9eba0717ec5d.png)

### Automatic Method

Open a PowerShell terminal and run the following commands from within a new or existing directory:
```
$installUri = "https://raw.githubusercontent.com/devopsshield/devops-shield/$Branch/support/azure-marketplace/Install-DevOpsShield-Tools.ps1"
Invoke-WebRequest $installUri -OutFile "Install-DevOpsShield-Tools.ps1"
.\Install-DevOpsShield-Tools.ps1
```

### Manual Method

Download entire contents of this folder onto your device which contains these required files:
- createAppRegistration.psm1
- getUniqueString.bicep
- getUniqueString.psm1
- manifest.template.json
- postCreate.ps1
- postCreate.psm1

Go into the downloaded folder then execute the following script:
```
.\postCreate.ps1 -Subscription "<YOUR-AZURE-SUBSCRIPTION>" -ResourceGroup "<YOUR-RESOURCE-GROUP-NAME-THAT-CONTAINS-THE-MANAGED-APP>" -AppName "<THE-MANAGED-APP-NAME>"

# for example
# .\postCreate.ps1 -Subscription "IT Test" -ResourceGroup "rg-managedapps" -AppName "devopsshieldtest"  
```
