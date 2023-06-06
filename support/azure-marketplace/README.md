# Welcome to DevOps Shield - Azure Marketplace - Post Installation Script
> The following PowerShell script will complete the DevOps Shield application installation. It will register an application with Microsoft identity platform and update the DevOps Shield application settings required to complete the installation and configuration. Run the script below and your are minutes from completing a full DevOps security assessment.  

----
## Prerequisites

- You have already installed DevOps Shield managed application from the Azure Marketplace.
- Sample Installation:
![image](https://user-images.githubusercontent.com/112144174/230929336-1e49f495-5e17-47fa-8313-9eba0717ec5d.png)

## Usage

- Open a PowerShell terminal, then copy and run the following command:
```
Invoke-WebRequest "https://raw.githubusercontent.com/devopsshield/devops-shield/main/support/azure-marketplace/DevOpsShield-Marketplace-Post-Install-Script.ps1" -OutFile "DevOpsShield-Marketplace-Post-Install-Script.ps1"; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; .\DevOpsShield-Marketplace-Post-Install-Script.ps1
```

### Steps:
1. You will be asked to login using your Azure account that is allowed to register an application.
2. You will be asked the information you have provided during the DevOps Shield installation (see image above for your reference).
3. We will register an application with the Microsoft identity platform.
4. We will update the DevOps Shield application settings.
5. DevOps Shield is ready to use.

## Contact Us
- https://www.devopsshield.com/contact
- Feel free to contact us for assistance with the installation and configuration of the product at no cost.

----
Thank you for choosing DevOps Shield!

----