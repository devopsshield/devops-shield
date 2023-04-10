# Post Install Script to create App Registration for DevOps Shield

## Usage

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
# .\postCreate.ps1 -Subscription "IT Test" -ResourceGroup "rg-managedapps" -AppName "devopsshieldcxdev009"  
```