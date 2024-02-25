# Table of Contents

- [Quick Start](#quick-start)
  - [Who we are](#who-we-are)
  - [How to use this image](#how-to-use-this-image)
  - [Video Walkthrough](#video-walkthrough)
  - [DevOps Shield in the Azure Marketplace](#devops-shield-in-the-azure-marketplace)
  - [DevOps Shield in the Azure DevOps Marketplace](#devops-shield-in-the-azure-devops-marketplace)
  - [License](#license)
- [Detailed Instructions using Docker Desktop GUI](#detailed-instructions-using-docker-desktop-gui)
  - [Installation Prerequisites](#installation-prerequisites)
  - [Install Steps](#install-steps)
  - [First Login for DevOps Shield](#first-login-for-devops-shield)
  - [Configuration Prerequisites](#configuration-prerequisites)
  - [Config Steps](#config-steps)
- [Detailed Instructions using Azure (Web App for Containers)](#detailed-instructions-using-azure-web-app-for-containers)
  - [Azure Install Script](#azure-install-script) 
- [Detailed Instructions using AWS (Amazon Lightsail)](#detailed-instructions-using-aws-amazon-lightsail)
- [Detailed Instructions using GCP (Cloud Run)](#detailed-instructions-using-gcp-cloud-run)
- [DevOps Assessments](#devops-assessments)

<h1 id="quick-start">Quick Start</h1>

- Maintained by:
  - [DevOps Shield](https://www.devopsshield.com)
- Where to get help:  
  - [Resource Center](https://www.devopsshield.com/resources)
  - [Contact Us](https://www.devopsshield.com/contact)
- Report any issues:
  - [GitHub Issues](https://github.com/devopsshield/devops-shield/issues)
- Videos:
  - [Installation Guide](https://youtu.be/N00IR_WImN8)
- Docker Hub:
  - [DevOps Shield Community Edition](https://hub.docker.com/r/devopsshield/devopsshield)
- Live Demo:
  - [demo.devopsshield.com](https://demo.devopsshield.com)
- DevOps Shield Security Scanner Pipeline Task:
  - [Azure DevOps Marketplace](https://marketplace.visualstudio.com/items?itemName=DevOpsShield.DevOpsShield-SecurityScanner)

<h2 id="who-we-are">Who we are</h2>

DevOps Shield - Your Business. We Protect It. Our mission is to empower and protect every organization with innovative cybersecurity for DevOps.

- Improve your DevOps security governance.
- Reduce exposure to possible DevOps cyberattacks.
- Solve rising security and DevOps misconfiguration concerns.
- Generate DevOps security assessment reports.

DevOps Shield fills the gap between the DevSecOps and Cloud security governance solutions by hardening your DevOps platform configuration and remediating non-compliant resources.

![logo](https://www.devopsshield.com/images/logo.png)

<h2 id="how-to-use-this-image">How to use this image</h2>

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

<h2 id="video-walkthrough">Video Walkthrough</h2>

Click [here](https://youtu.be/N00IR_WImN8) for video instructions.

<h2 id="devops-shield-in-the-azure-marketplace">DevOps Shield in the Azure Marketplace</h2>

Alternatively, you can try it for FREE in the [Azure Marketplace](https://azuremarketplace.microsoft.com/en-us/marketplace/apps/cad4devopsinc1662079207461.devops-shield?src=website&mktcmpid=header).

<h2 id="devops-shield-in-the-azure-devops-marketplace">DevOps Shield in the Azure DevOps Marketplace</h2>

You can also run the DevOps Shield CLI in a pipeline using the [DevOps Shield Security Scanner build task](https://marketplace.visualstudio.com/items?itemName=DevOpsShield.DevOpsShield-SecurityScanner).

<h2 id="license">License</h2>

**DevOps Shield Community Edition** is licensed under the [DevOps Shield proprietary license](https://www.devopsshield.com/termsofuse). Copyright (c) CAD4DevOps Inc. (DevOps Shield). All rights reserved.

---

<h1 id="detailed-instructions-using-docker-desktop-gui">Detailed Instructions using Docker Desktop GUI</h1>

<h2 id="installation-prerequisites">Installation Prerequisites</h2>

- Docker Desktop for [Windows](https://docs.docker.com/desktop/install/windows-install/), [Linux](https://docs.docker.com/desktop/install/linux-install/), or [Mac](https://docs.docker.com/desktop/install/mac-install/)

<h2 id="install-steps">Install Steps</h2>

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

<h2 id="first-login-for-devops-shield">First Login for DevOps Shield</h2>

1. Login to the app by clicking login button on top right
![click on login button](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/06-click-on-login-button.png)
1. Log in with username **devopsshield** and password **devopsshield**. You will then be prompted to change your password.
![enter default password](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/07-enter-password-then-login.png)
1. Change default password
![change password](https://github.com/devopsshield/devops-shield/raw/main/media/images/install/08-change-password.png)

<h2 id="configuration-prerequisites">Configuration Prerequisites</h2>

1. Obtain a Full Scoped Personal Access Token (PAT) for the Azure DevOps Organization to assess (see [Use personal access tokens](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/use-personal-access-tokens-to-authenticate))
![get full pat token](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/04-generate-full-pat-token-for-azure-devops-organization-to-assess.png)
1. Don't for get to copy the PAT to the clipboard!
![copy PAT token](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/04-click-on-copy-icon-to-copy-to-clipboard.png)
1. Obtain the Microsoft Entra ID (aka Azure Active Directory Tenant ID) associated to the Azure DevOps Organization you chose to assess (see [Connect your organization to Microsoft Entra ID](https://learn.microsoft.com/en-us/azure/devops/organizations/accounts/connect-organization-to-azure-ad))
![get microsoft entra id](https://github.com/devopsshield/devops-shield/raw/main/media/images/config/03-microsoft-entra-id-for-azure-devops-organization.png)

<h2 id="config-steps">Config Steps</h2>

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

<h1 id="detailed-instructions-using-azure-web-app-for-containers">Detailed Instructions using Azure (Web App for Containers)</h1>

1. Login to the [Azure Portal](https://portal.azure.com) and click on Create a Resource
![Create a resource in azure portal](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/Login-to-Azure-click-create-a-resource.png)
2. Search for **Web App for Containers** and click on the tile
![Choose Web App for Containers](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/Search-for-web-app-for-containers.png)
3. Click on Create
![click on create](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/Click-on-create.png)
4. Enter instance details such as:

- Subscription
- Resource Group
- Web App Name
- Region

![enter instance details](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/select-instance-details.png)

Ensure you pick a **Linux** Plan as well as set Publish to **Docker Container**.

5. Select the Docker Tab (or click Next 3 times) and enter the following information:

![docker settings](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/docker-tab.png)

Ensure you enter **devopsshield/devopsshield** for the Image and tag.

6. Click on Review and Create then on Create.

![click on create](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/review-and-create.png)

7. Once deployment is done, click on Go to resource

![click on go to resource](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/click-on-go-to-resource.png)

8. Now click on configuration to add an app setting mapping the website port to 8080 (see [Default ASP.NET Core port changed from 80 to 8080](https://learn.microsoft.com/en-us/dotnet/core/compatibility/containers/8.0/aspnet-port))

![click on configuration](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/click-on-configuration.png)

9. Add the setting ```WEBSITES_PORT``` with value ```8080``` then click OK

![add the setting](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/add-websites-port-8080.png)

10. Click on Save to restart webapp

![save to restart](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/click-on-save-to-restart-app.png)

11. Browse to the app by clicking on default domain in Overview Page

![click on default domain in overview](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/click-on-default-domain.png)

12. Follow the post install steps

![follow post install steps](https://github.com/devopsshield/devops-shield/raw/main/media/images/azure/install/post-install-steps.png)

<h2 id="azure-install-script">Azure Install Script</h2>

- Open a PowerShell terminal, then copy and run the following command:
```
Invoke-WebRequest "https://raw.githubusercontent.com/devopsshield/devops-shield/main/support/docker-hub/scripts/Azure/DevOpsShield-DockerHub-Azure-Install-Script.ps1" -OutFile "DevOpsShield-DockerHub-Azure-Install-Script.ps1"; Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass; .\DevOpsShield-DockerHub-Azure-Install-Script.ps1
```

<h1 id="detailed-instructions-using-aws-amazon-lightsail">Detailed Instructions using AWS (Amazon Lightsail)</h1>

1. Sign in to the [Lightsail console](https://lightsail.aws.amazon.com/). On the Lightsail home page, choose the Containers tab and click on Create container service.
![click on containers in overview](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/Login-to-Amazon-Lightsail-and-click-on-containers.png)
1. In the Create a container service page, choose Change AWS Region, then choose an AWS Region for your container service. Choose a capacity for your container service.
![choose region and capacity](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/Select-AWS-Region-and-choose-container-service-capacity.png)
1. Click on Setup Deployment and Specify a custom deployment. Enter the following information:

- Container name: Container names must contain only alphanumeric characters and hyphens. A hyphen (-) can separate words but cannot be at the start or end of the name.
- Image: **devopsshield/devopsshield**
- Open Ports: **8080 (HTTP)**
- Public Endpoint: select the container name above

![enter deployment information](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/setup-first-deployment.png)

4. Identify your service and create it!
The name of your container service must be unique within each AWS Region in your Lightsail account. It must also be lower-case, and DNS-compliant.

![identify service](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/identify-service-and-create-it.png)

5. Wait for the deployment to complete (may take a few minutes...)

![wait for deployment to complete](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/wait-for-deployment-to-complete.png)

6. Once your deployment is done, browse your new instance!

![deployment is done](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/browse-your-new-instance.png)

7. Click on public domain link above and start your first DevOps assessment!

![login-and-configure](https://github.com/devopsshield/devops-shield/raw/main/media/images/aws/install/login-to-configure-as-above.png)

<h1 id="detailed-instructions-using-gcp-cloud-run">Detailed Instructions using GCP (Cloud Run)</h1>

1. Login to Google Cloud Platform [Cloud Run](https://console.cloud.google.com/run)

![create service in GCP cloud run](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/create-service-in-gcp-cloud-run.png)

2. Click on Create Service and fill in the service details:

- Container Image URL: **devopsshield/devopsshield**
- Service Name: e.g. devopsshield-gcp-demo-1
- Region

![fill in service details](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/service-details-1.png)

3. Add Authorization info, port information as well as (optionally) some health checks

![add auth and port info](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/service-details-2.png)

4. You may need to **increase Memory Limit**!

![increase memory limit if container crashes](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/increase-memory-limit-if-needed.png)

You can always check your resource usage in the metrics

![check resource usage](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/verify-resource-metrics-usage.png)

5. Now click on create

![click on create](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/now-click-on-create.png)

6. Wait for deployment to finish, then click on URL

![wait for deployment then navigate to URL](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/wait-for-deployment-then-click-on-url.png)

7. Browse the DevOps Shield Site then do your first login!

![do the first login](https://github.com/devopsshield/devops-shield/raw/main/media/images/gcp/install/do-the-first-login.png)

<h1 id="devops-assessments">DevOps Assessments</h1>

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
