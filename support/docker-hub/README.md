# Quick Start

- Maintained by:
  - [DevOps Shield](https://www.devopsshield.com)
- Where to get help:  
  - [Resource Center](https://www.devopsshield.com/resources)
  - [Contact Us](https://www.devopsshield.com/contact)
- Report any issues:
  - [GitHub Issues](https://github.com/devopsshield/devops-shield/issues)

## Who we are

> DevOps Shield - Your Business. We Protect It. Our mission is to empower and protect every organization with innovative cybersecurity for DevOps.

- Improve your DevOps security governance.
- Reduce exposure to possible DevOps cyberattacks.
- Solve rising security and DevOps misconfiguration concerns.
- Generate DevOps security assessment reports.

DevOps Shield fills the gap between the DevSecOps and Cloud security governance solutions by hardening your DevOps platform configuration and remediating non-compliant resources.

![logo](https://www.devopsshield.com/images/logo.png)

## How to use this image

Here you'll find the Docker image for the Community Edition of DevOps Shield.

1. To run it in detached mode on host port 8080

```PowerShell

docker run -d -p 8080:8080 devopsshield/devopsshield

```

2. Then browse to <http://localhost:8080> in PowerShell:

```PowerShell

start http://localhost:8080

```

or in Linux (e.g. WSL 2 - see [Install Google Chrome for Linux](https://learn.microsoft.com/en-us/windows/wsl/tutorials/gui-apps#install-google-chrome-for-linux) and install xdg utilities (sudo apt install xdg-utils))

```Bash

xdg-open http://localhost:8080

```

3. Log in with username **devopsshield** and password **devopsshield**. You will then be prompted to change your password.

## Detailed Instructions using Docker Desktop GUI

### Installation Prerequisites

- Docker Desktop for [Windows](https://docs.docker.com/desktop/install/windows-install/), [Linux](https://docs.docker.com/desktop/install/linux-install/), or [Mac](https://docs.docker.com/desktop/install/mac-install/)

### Install Steps

1. Open Docker Desktop, click on Images, then Search Images to Run
![Docker Hub Click on Search Images to Run](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/01-docker-hub-search-images-to-run.png)
1. Search for image "devopsshield/devopsshield" and click pull
![Find image for devopsshield](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/02-pull-devopsshield-container.png)
1. Click on run
![click on run](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/03-click-on-run.png)
1. Choose host port (e.g. 8080) in optional settings then click on run
![add host port](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/04-add-host-port-in-optional-settings-then-click-on-run.png)
1. Now browse to the app at <http://localhost:8080> or simply click on the hyperlink below
![browse localhost on port 8080](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/05-click-on-browse-port-8080-on-localhost.png)
1. Login to the app by clicking login button on top right
![click on login button](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/06-click-on-login-button.png)
1. Log in with username **devopsshield** and password **devopsshield**. You will then be prompted to change your password.
![enter default password](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/07-enter-password-then-login.png)
1. Change default password
![change password](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/08-change-password.png)

### Configuration Prerequisites

1. Obtain a Full Scoped Personal Access Token (PAT) for the Azure DevOps Organization to assess (see [Use personal access tokens](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate))
![get full pat token](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/04-generate-full-pat-token-for-azure-devops-organization-to-assess.png)
1. Don't for get to copy the PAT to the clipboard!
![copy PAT token](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/04-click-on-copy-icon-to-copy-to-clipboard.png)
1. Obtain the Microsoft Entra ID (aka Azure Active Directory Tenant ID) associated to the Azure DevOps Organization you chose to assess (see [Connect your organization to Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/connect-organization-to-azure-ad))
![get microsoft entra id](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/03-microsoft-entra-id-for-azure-devops-organization.png)

### Config Steps

1. In the app, click on setup configuration
![setup configuration](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/01-click-on-setup-configuration.png)
1. Now click on Quick Setup - Get Started
![quick setup - get started](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/02-click-on-quick-setup-get-started.png)
1. Fill out the values obtained above with your Tenant ID, your Azure Devops organization to assess as well as your Full PAT. Then click on Start Setup Now!
![fill out with your values](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/05-fill-out-with-your-values.png)
1. You should quickly see the setup configuration done as below:
![config done](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/06-config-done.png)
1. Go to Automation Tasks and wait for the scan to complete
![automation tasks](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/07-go-to-automation-tasks.png)
1. Depending on how large your Azure DevOps organization is, it may take minutes to finish. In our case, it took about 5 minutes to complete.
![wait for tasks to finish](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/08-assessment-scan-completed.png)

## Detailed Instructions using Azure (Web App for Containers)

Coming Soon!

## DevOps Assessments

Once an assessment has been done, you can view a full history of all assessments done by clicking on DevOps Assessments
![click on DevOps Assessments](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/01-click-on-devops-assessments.png)
Clicking on any individual assessment, we see:
![sample assessment details](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/02-sample-assessment-details.png)
Clicking on View & Export Reports:
![view and export reports](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/03-view-and-export.png)
Scroll Down to see the full report including: DevOps Security Overview, DevOps Governance and Compliance, DevOps Inventory
![devops governance and compliance](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/04-devops-governace-and-compliance.png)
![devops inventory](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/05-devops-inventory.png)
Please note that the Community Edition is limited to seeing up to 10 Azure DevOps Resources in these Assessment Reports
![limit of up to 10 resources in community edition](https://github.com/devopsshield/devops-shield/raw/main/media/images/assessments/06-devops-inventory-limited-in-community-edition.png)

You can currently export to JSON or CSV the following reports:

- Security Governance

- Resource Inventory

- Security Permissions

## Video Walkthrough

Click here for video instructions.

## DevOps Shield in the Azure Marketplace

Alternatively, you can try it for FREE in the [Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/cad4devopsinc1662079207461.devops-shield?src=website&mktcmpid=header).

## License

**DevOps Shield Community Edition** is licensed under the [DevOps Shield proprietary license](https://www.devopsshield.com/termsofuse). Copyright (c) CAD4DevOps Inc. (DevOps Shield). All rights reserved.
