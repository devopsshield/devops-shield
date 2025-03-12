Set-StrictMode -Version Latest

# Menu driven script to update the DevOps Shield One VM
# It is recommended to run this script as a root user
# The script will prompt for confirmation before proceeding with each update
# The script will log all actions to a log file
# The script will check for updates and install them if available
# The script will check for the latest version of each application and update it if necessary

# log file path depends on the OS
# For Windows, the log file is stored in C:\DevOpsShieldOneVM_UpdateLog.txt
# For Linux, the log file is stored in /var/log/DevOpsShieldOneVM_UpdateLog.txt
# The script will create the log file if it does not exist
# The script will append to the log file if it already exists

if ($env:OS -eq "Windows_NT") {
  # Windows OS
  Write-Output "Running on Windows OS"
  Write-Output "Setting log file path to C:\DevOpsShieldOneVM_UpdateLog.txt"
  $logFile = "C:\DevOpsShieldOneVM_UpdateLog.txt"
}
else {
  # Linux OS
  Write-Output "Running on Linux OS"
  Write-Output "Setting log file path to /var/log/DevOpsShieldOneVM_UpdateLog.txt"
  $logFile = "/var/log/DevOpsShieldOneVM_UpdateLog.txt"
  $rootFolder = "/home/ubuntu"
}

# ensure script is run with sudo privileges
if ($PSVersionTable.Platform -eq "Unix") {
  if ($(whoami) -ne "root") {
    Write-Output "Script is not running with sudo privileges."
    Write-Output "Please run the script with sudo."
    Write-Output "run with: sudo pwsh Update-DevOpsShieldOneVm.ps1"
    Write-Output "Exiting script."
    exit 1
  }
}

# Requires PowerShell Module Resolve-DnsNameCrossPlatform
# Check if the module is installed

Write-Output "Checking if Resolve-DnsNameCrossPlatform module is installed..."
$moduleName = "Resolve-DnsNameCrossPlatform"
$moduleFound = Get-InstalledModule -Name $moduleName
# verify if the module is installed
if ($moduleFound) {
  Write-Output "Module $moduleName is installed."
  Write-Output "Module version: $($moduleFound.Version)"
  Write-Output "Module Found:"
  Write-Output $moduleFound
}
else {
  Write-Output "Module $moduleName is not installed."
  Write-Output "Installing module $moduleName..."
  Install-Module -Name $moduleName -Force -Scope CurrentUser
  Write-Output "Module $moduleName installed."
}

function Write-ActionLog {
  param (
    [string]$message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logMessage = "$timestamp - $message"
  Add-Content -Path $logFile -Value $logMessage
}

function Update-Hostname {
  Write-Output "Updating hostname..."
  Write-ActionLog "Updating hostname"
  try {
    Write-Output "Changing hostname..."
    Write-ActionLog "Changing hostname"
    Write-Output "Current hostname: $(hostname)"
    Write-Output "Current hostname pretty: $(hostnamectl --pretty)"
    $newHostname = Read-Host "Enter new hostname"
    $newHostnamePretty = Read-Host "Enter new pretty hostname"
    if ($newHostname -eq "") {
      Write-Output "Hostname cannot be empty. Please enter a valid hostname."
      continue
    }
    if ($newHostnamePretty -eq "") {
      Write-Output "Pretty hostname cannot be empty. Please enter a valid pretty hostname."
      continue
    }
    if ($env:OS -eq "Windows_NT") {
      Write-Output "Changing hostname to $newHostname..."
      Write-ActionLog "Changing hostname to $newHostname"
      # Windows command to change hostname
      Rename-Computer -NewName $newHostname -Force
    }
    else {
      Write-Output "Changing hostname to $newHostname..."
      Write-ActionLog "Changing hostname to $newHostname"
      # Linux command to change hostname
      sudo hostnamectl set-hostname $newHostname
      hostnamectl
      sudo hostnamectl set-hostname $newHostnamePretty --pretty
      hostnamectl
    }
    Write-Output "Hostname changed to $newHostname."
    
    Write-Output "Hostname update completed."
    Write-ActionLog "Hostname update completed"
  }
  catch {
    Write-Output "Error updating hostname: $_"
    Write-ActionLog "Error updating hostname: $_"
  }
}

function Update-OperatingSystem {
  Write-Output "Updating Operating System..."
  Write-ActionLog "Updating Operating System"
  try {
    if ($env:OS -eq "Windows_NT") {
      # Windows OS update commands
      Write-Output "Running Windows update commands..."
      # Example: Install-WindowsUpdate -AcceptAll -AutoReboot
    }
    else {
      # Linux OS update commands
      Write-Output "Running Linux update commands..."
      sudo apt-get update && sudo apt-get upgrade -y
      sudo apt-get autoremove -y
    }
    Write-Output "Operating System update completed."
    Write-ActionLog "Operating System update completed"
  }
  catch {
    Write-Output "Error updating Operating System: $_"
    Write-ActionLog "Error updating Operating System: $_"
  }
}

function Update-DevOpsShieldApp {
  param (
    [string]$containerName = "devopsshield",
    [string]$devopsShieldImage = "devopsshield/devopsshield:latest",
    [string]$sqlServerContainerName = "mssql",
    [string]$sqlServerImage = "mcr.microsoft.com/mssql/server:2022-latest",
    [string]$sqlServerUserName = "sa",
    [string]$MSSQL_SA_PASSWORD = "D3v0psSh!eld",
    [string]$sqlLiteDatabaseName = "DevOpsShield.db",
    [string]$sqlServerDatabaseName = "sqldb-devopsshield",
    [string]$Volume = "/data",
    [string]$Port = "8083",
    [string]$SqlPort = "1433",
    [string]$externalNetwork = "false",
    [string]$dosOvrIncQty = "20",
    [string]$RUN_MODE = "Continuous",
    [string]$IdentityProvider = "Local",
    [string]$Marketplace = "SelfHosted",
    [string]$LOG_ANALYTICS_WORKSPACE_ID = "",
    [string]$LOG_ANALYTICS_WORKSPACE_KEY = "",
    [string]$APPLICATIONINSIGHTS_CONNECTIONSTRING = "",
    [string]$KEY_VAULT_NAME = "",
    [string]$YOUR_DOMAIN = "<YOUR-DOMAIN-HERE>.onmicrosoft.com",
    [string]$YOUR_TENANT_ID = "<YOUR-TENANT-ID-HERE>",
    [string]$YOUR_CLIENT_ID = "<YOUR-CLIENT-ID-HERE>",
    [string]$YOUR_CLIENT_SECRET = "<YOUR-CLIENT-SECRET-HERE>",
    [string]$READ_ONLY_MODE = "False",
    [string]$dockerComposeFileName = "docker-compose.yaml",
    [string]$DatabaseProvider = "SQLite",
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "8080",
    [string]$LETSENCRYPT_HOST = ""
  )
  Write-Output "Updating DevOps Shield Application..."
  Write-ActionLog "Updating DevOps Shield Application"
  try {
    Set-Location  "${rootFolder}/devops-shield"
    Write-Output "Pulling latest images..."
    sudo docker pull $devopsShieldImage
    Write-Output "Stopping containers..."
    sudo docker compose down   

    @"
services:
  ${containerName}:
    image: $devopsShieldImage
    restart: always
    environment:
      ${environmentPrefix}VIRTUAL_HOST: $VIRTUAL_HOST
      ${environmentPrefix}VIRTUAL_PORT: $VIRTUAL_PORT
      ${environmentPrefix}LETSENCRYPT_HOST: $LETSENCRYPT_HOST
      dosOvrIncQty: $dosOvrIncQty
      DOSPlan__RunMode: "$RUN_MODE"
      DOSPlan__DatabaseProvider: "SQLite"
      DOSPlan__IdentityProvider: "$IdentityProvider"
      DOSPlan__Marketplace: "$Marketplace"
      ConnectionStrings__SQLiteComplianceConnection: "Data Source=${Volume}/${sqlLiteDatabaseName}"
      LAWSId: "$LOG_ANALYTICS_WORKSPACE_ID"
      LAWSSharedKey: "$LOG_ANALYTICS_WORKSPACE_KEY"
      ReadOnlyMode: "$READ_ONLY_MODE"
      ApplicationInsights__ConnectionString: "$APPLICATIONINSIGHTS_CONNECTIONSTRING"
      KeyVaultName: "$KEY_VAULT_NAME"
      AzureAd__Domain: "$YOUR_DOMAIN"
      AzureAd__TenantId: "$YOUR_TENANT_ID"
      AzureAd__ClientId: "$YOUR_CLIENT_ID"
      AzureAd__ClientSecret: "$YOUR_CLIENT_SECRET"
      AzureAd__ClientCredentials__2__ClientSecret: "$YOUR_CLIENT_SECRET"
    ${portPrefix}ports:
    ${portPrefix}  - "${Port}:8080"
    volumes:
      - dos_data_sqlite:${Volume}

volumes:
  dos_data_sqlite:

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.SQLite.yaml" -Encoding utf8

    @"
services:
  ${containerName}:
    image: $devopsShieldImage
    restart: always
    environment:
      ${environmentPrefix}VIRTUAL_HOST: $VIRTUAL_HOST
      ${environmentPrefix}VIRTUAL_PORT: $VIRTUAL_PORT
      ${environmentPrefix}LETSENCRYPT_HOST: $LETSENCRYPT_HOST
      dosOvrIncQty: $dosOvrIncQty
      DOSPlan__RunMode: "$RUN_MODE"
      DOSPlan__DatabaseProvider: "SqlServer"
      DOSPlan__IdentityProvider: "$IdentityProvider"
      DOSPlan__Marketplace: "$Marketplace"
      ConnectionStrings__ComplianceConnection: "Server=${sqlServerContainerName},1433;Initial Catalog=${sqlServerDatabaseName};Persist Security Info=False;User Id=${sqlServerUserName};Password=${MSSQL_SA_PASSWORD};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=True;Connection Timeout=30;"
      LAWSId: "$LOG_ANALYTICS_WORKSPACE_ID"
      LAWSSharedKey: "$LOG_ANALYTICS_WORKSPACE_KEY"
      ReadOnlyMode: "$READ_ONLY_MODE"
      ApplicationInsights__ConnectionString: "$APPLICATIONINSIGHTS_CONNECTIONSTRING"
      KeyVaultName: "$KEY_VAULT_NAME"
      AzureAd__Domain: "$YOUR_DOMAIN"
      AzureAd__TenantId: "$YOUR_TENANT_ID"
      AzureAd__ClientId: "$YOUR_CLIENT_ID"
      AzureAd__ClientSecret: "$YOUR_CLIENT_SECRET"
      AzureAd__ClientCredentials__2__ClientSecret: "$YOUR_CLIENT_SECRET"
    ${portPrefix}ports:
    ${portPrefix}  - "${Port}:8080"
    depends_on:
      - ${sqlServerContainerName}

  ${sqlServerContainerName}:
    image: $sqlServerImage
    restart: always
    environment:
      SA_PASSWORD: "$MSSQL_SA_PASSWORD"
      ACCEPT_EULA: "Y"
    ports:
      - "${SqlPort}:1433"
    volumes:
      - dos_data_mssql:/var/opt/mssql

volumes:
  dos_data_mssql:

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.SqlServer.yaml" -Encoding utf8

    Write-Output "Copying the docker-compose file to $dockerComposeFileName ..."
    Copy-Item -Path "docker-compose.${DatabaseProvider}.yaml" -Destination $dockerComposeFileName -Force

    Write-Output "Showing the contents of the docker-compose.yaml file"
    Get-Content -Path $dockerComposeFileName

    Write-Output "Starting DevOps Shield Application"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "DevOps Shield Application update completed."
    Write-ActionLog "DevOps Shield Application update completed"
  }
  catch {
    Write-Output "Error updating DevOps Shield Application: $_"
    Write-ActionLog "Error updating DevOps Shield Application: $_"
  }
}

function Update-DefectDojoApp {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "8080",
    [string]$LETSENCRYPT_HOST = "",
    [string]$NGINX_METRICS_ENABLED = "false"
  )

  Write-Output "Updating Defect Dojo Application..."
  Write-ActionLog "Updating Defect Dojo Application"
  try {
    Set-Location "${rootFolder}/django-DefectDojo"
    Write-Output "Pulling latest from git repo ..."
    sudo git pull
    Write-Output "Checking if your installed toolkit is compatible..."
    sudo ./docker/docker-compose-check.sh
    Write-Output "Building Docker images..."
    sudo docker compose build
    Write-Output "Stopping containers..."
    sudo docker compose down

    @"
services:
  nginx:
    restart: always
    ${environmentPrefix}environment:
    ${environmentPrefix}  VIRTUAL_HOST: $VIRTUAL_HOST
    ${environmentPrefix}  VIRTUAL_PORT: $VIRTUAL_PORT
    ${environmentPrefix}  LETSENCRYPT_HOST: $LETSENCRYPT_HOST
    ${environmentPrefix}  NGINX_METRICS_ENABLED: `"$NGINX_METRICS_ENABLED`"

  uwsgi:
    restart: always

  celerybeat:
    restart: always

  celeryworker:
    restart: always

  postgres:
    restart: always

  redis:
    restart: always

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.override.yml"

    Write-Output "Showing the contents of the docker-compose.override.yml file"
    Get-Content -Path "docker-compose.override.yml"

    Write-Output "Starting Defect Dojo Application"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "Defect Dojo Application update completed."
    Write-ActionLog "Defect Dojo Application update completed"
  }
  catch {
    Write-Output "Error updating Defect Dojo Application: $_"
    Write-ActionLog "Error updating Defect Dojo Application: $_"
  }
}

function Update-DependencyTrackApp {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$IP_ADDRESS = $(hostname -I | cut -d' ' -f1),
    [string]$VIRTUAL_HOST_BACKEND = "",
    [string]$VIRTUAL_PORT_BACKEND = "8080",
    [string]$LETSENCRYPT_HOST_BACKEND = "",
    [string]$VIRTUAL_HOST_FRONTEND = "",
    [string]$VIRTUAL_PORT_FRONTEND = "8080",
    [string]$LETSENCRYPT_HOST_FRONTEND = ""
  )

  Write-Output "Updating Dependency Track Application..."
  Write-ActionLog "Updating Dependency Track Application"
  try {
    Set-Location "${rootFolder}/dependency-track"
    Write-Output "Pulling latest images..."
    sudo docker pull dependencytrack/frontend
    sudo docker pull dependencytrack/apiserver
    Write-Output "Stopping containers..."
    sudo docker compose down
    Write-Output "Dependency-Track will be available at http://${IP_ADDRESS}:8082"

    @"
volumes:
  dependency-track:

services:
  dtrack-apiserver:
    image: dependencytrack/apiserver
    deploy:
      resources:
        limits:
          memory: 12288m
        reservations:
          memory: 8192m
      restart_policy:
        condition: on-failure
    ${environmentPrefix}environment:
    ${environmentPrefix}  VIRTUAL_HOST: $VIRTUAL_HOST_BACKEND
    ${environmentPrefix}  VIRTUAL_PORT: $VIRTUAL_PORT_BACKEND
    ${environmentPrefix}  LETSENCRYPT_HOST: $LETSENCRYPT_HOST_BACKEND
    ${portPrefix}ports:
    ${portPrefix}  - "8081:8080"
    volumes:
      - "dependency-track:/data"
    restart: unless-stopped

  dtrack-frontend:
    image: dependencytrack/frontend
    depends_on:
      - dtrack-apiserver
    environment:
      ${environmentPrefix}VIRTUAL_HOST: $VIRTUAL_HOST_FRONTEND
      ${environmentPrefix}VIRTUAL_PORT: $VIRTUAL_PORT_FRONTEND
      ${environmentPrefix}LETSENCRYPT_HOST: $LETSENCRYPT_HOST_FRONTEND
      ${environmentPrefix}API_BASE_URL: https://${VIRTUAL_HOST_BACKEND}
      ${portPrefix}API_BASE_URL: http://${IP_ADDRESS}:8081      
    ${portPrefix}ports:
    ${portPrefix}  - "8082:8080"
    restart: unless-stopped

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.yml"

    Write-Output "Showing the contents of the docker-compose.yml file"
    Get-Content -Path "docker-compose.yml"

    Write-Output "Starting Dependency Track Application"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "Dependency-Track IS available at http://${IP_ADDRESS}:8082"
    Write-Output "Dependency-Track API is available at http://${IP_ADDRESS}:8081"
    Write-Output "Dependency-Track is available at https://${VIRTUAL_HOST_FRONTEND}"
    Write-Output "Dependency-Track API is available at https://${VIRTUAL_HOST_BACKEND}"
    Write-Output "Dependency Track Application update completed."
    Write-ActionLog "Dependency Track Application update completed"
  }
  catch {
    Write-Output "Error updating Dependency Track Application: $_"
    Write-ActionLog "Error updating Dependency Track Application: $_"
  }
}

function Update-SonarQubeCommunity {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$SONARQUBE_VERSION = "community", # latest community version
    [string]$POSTGRES_VERSION = "13",
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "9000",
    [string]$LETSENCRYPT_HOST = ""
  )

  Write-Output "Updating SonarQube..."
  Write-ActionLog "Updating SonarQube"
  try {
    Set-Location "${rootFolder}/sonarqube"
    Write-Output "Pulling latest images..."
    sudo docker pull sonarqube:${SONARQUBE_VERSION}
    sudo docker pull postgres:${POSTGRES_VERSION}
    Write-Output "Stopping containers..."
    sudo docker compose down

    @"
services:
  sonarqube:
    image: sonarqube:$SONARQUBE_VERSION
    restart: always
    depends_on:
      - sonar_db
    environment:
      ${environmentPrefix}VIRTUAL_HOST: $VIRTUAL_HOST
      ${environmentPrefix}VIRTUAL_PORT: $VIRTUAL_PORT
      ${environmentPrefix}LETSENCRYPT_HOST: $LETSENCRYPT_HOST
      SONAR_JDBC_URL: jdbc:postgresql://sonar_db:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ${portPrefix}ports:
    ${portPrefix}  - "9001:9000"
    volumes:
      - sonarqube_conf:/opt/sonarqube/conf
      - sonarqube_data:/opt/sonarqube/data
      - sonarqube_extensions:/opt/sonarqube/extensions
      - sonarqube_logs:/opt/sonarqube/logs
      - sonarqube_temp:/opt/sonarqube/temp

  sonar_db:
    image: postgres:$POSTGRES_VERSION
    restart: always
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonar_db:/var/lib/postgresql
      - sonar_db_data:/var/lib/postgresql/data

volumes:
  sonarqube_conf:
  sonarqube_data:
  sonarqube_extensions:
  sonarqube_logs:
  sonarqube_temp:
  sonar_db:
  sonar_db_data:

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.yaml"

    Write-Output "Showing the contents of the docker-compose.yaml file"
    Get-Content -Path "docker-compose.yaml"

    Write-Output "Starting SonarQube Community"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "SonarQube update completed."
    Write-ActionLog "SonarQube update completed"
  }
  catch {
    Write-Output "Error updating SonarQube: $_"
    Write-ActionLog "Error updating SonarQube: $_"
  }
}

function Install-NginxProxy {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$DEFAULT_EMAIL = ""
  )

  Write-Output "Installing Nginx Proxy..."
  Write-ActionLog "Installing Nginx Proxy"
  try {
    # Set the default email if not provided
    if ($DEFAULT_EMAIL -eq "") {
      $DEFAULT_EMAIL = Read-Host "Enter your email address for Let's Encrypt"
    }
    else {
      Write-Output "Using provided email address: $DEFAULT_EMAIL"
    }
    Write-Output "Default email is $DEFAULT_EMAIL"

    Write-Output "Creating external network $common_network_name..."
    sudo docker network create $common_network_name

    Set-Location -Path $rootFolder
    Write-Output "Creating Nginx Proxy directory..."
    Write-ActionLog "Creating Nginx Proxy directory"
    if (Test-Path -Path "proxy") {
      Write-Output "Nginx Proxy directory already exists. Deleting..."
      Write-ActionLog "Nginx Proxy directory already exists. Deleting..."
      Set-Location -Path "proxy"
      Write-Output "Stopping Nginx Proxy containers..."
      Write-ActionLog "Stopping Nginx Proxy containers..."
      sudo docker compose down
      Set-Location -Path $rootFolder
      Write-Output "Removing Nginx Proxy directory..."
      Write-ActionLog "Removing Nginx Proxy directory..."
      Remove-Item -Path "proxy" -Recurse -Force
    }
    sudo docker network create $common_network_name
    New-Item -ItemType Directory -Path "proxy"
    Set-Location -Path "proxy"

    $proxyConfContent = @"
client_max_body_size 800m;
"@
    $proxyConfContent | Out-File -FilePath "proxy.conf"
    # create folder /etc/nginx if it does not exist
    if (-not (Test-Path -Path "/etc/nginx")) {
      Write-Output "Creating /etc/nginx directory..."
      New-Item -ItemType Directory -Path "/etc/nginx"
    }
    Copy-Item -Path "proxy.conf" -Destination "/etc/nginx/proxy.conf" -Force

    $dockerComposeContent = @"
services:
  nginx-proxy:
    image: jwilder/nginx-proxy
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/tmp/docker.sock:ro
      - letsencrypt-certs:/etc/nginx/certs
      - letsencrypt-vhost-d:/etc/nginx/vhost.d
      - letsencrypt-html:/usr/share/nginx/html
      - /etc/nginx/proxy.conf:/etc/nginx/conf.d/my_proxy.conf:ro
    restart: always
  letsencrypt-proxy:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: letsencrypt-proxy
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - letsencrypt-certs:/etc/nginx/certs
      - letsencrypt-vhost-d:/etc/nginx/vhost.d
      - letsencrypt-html:/usr/share/nginx/html
    restart: always
    environment:
      - DEFAULT_EMAIL=$DEFAULT_EMAIL
      - NGINX_PROXY_CONTAINER=nginx-proxy    

networks:
  default:
    external:
      name: $common_network_name

volumes:
  letsencrypt-certs:
  letsencrypt-vhost-d:
  letsencrypt-html:
"@
    $dockerComposeContent | Out-File -FilePath "docker-compose.yaml"

    Write-Output "Showing the contents of the docker-compose.yaml file"
    Get-Content -Path "docker-compose.yaml"

    Write-Output "Starting Nginx Proxy"
    sudo docker compose up -d

    # Get first IP address from the list of network interfaces
    $IP_ADDRESS = (hostname -I).Split(' ')[0]
    Write-Output "Nginx Proxy is available internally at $IP_ADDRESS"

    # Get external IP address
    $EXTERNAL_IP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content.Trim()
    Write-Output "Nginx Proxy is available externally at $EXTERNAL_IP"

    Write-Output "Nginx Proxy installation completed."
    Write-ActionLog "Nginx Proxy installation completed"
  }
  catch {
    Write-Output "Error installing Nginx Proxy: $_"
    Write-ActionLog "Error installing Nginx Proxy: $_"
  }
}

function Set-DevOpsShieldOneVm {
  param (
    [string]$rootFolder = "/home/ubuntu"
  )

  Write-Output "Configuring DevOps Shield One VM..."
  Write-ActionLog "Configuring DevOps Shield One VM"
  try {
    # Obtain configuration details from the user
    $configData = @{
      Hostname                       = $(hostname)
      PrettyHostname                 = $(hostnamectl --pretty)
      IPAddress                      = $(hostname -I | cut -d' ' -f1)
      DefaultEmail                   = Read-Host "Enter your email address for Let's Encrypt"
      ExternalIP                     = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content.Trim()
      DefectDojoDNSName              = Read-Host "Enter the DNS name for Defect Dojo"
      DependencyTrackBackendDNSName  = Read-Host "Enter the DNS name for Dependency Track Backend"
      DependencyTrackFrontendDNSName = Read-Host "Enter the DNS name for Dependency Track Frontend"
      SonarQubeDNSName               = Read-Host "Enter the DNS name for SonarQube"
      DevOpsShieldDNSName            = Read-Host "Enter the DNS name for DevOps Shield"
      DNSNameServer                  = Read-Host "Enter the DNS server for the above DNS names"
      Tested                         = $false
      TestedTimestamp                = ""
      TestResult                     = ""
    }

    # Format JSON nicely
    $jsonConfigData = $configData | ConvertTo-Json -Depth 4
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config.json"
    $jsonConfigData | Out-File -FilePath $configFilePath -Encoding utf8

    Write-Output "Configuration data:"
    Write-Output $jsonConfigData
    Write-Output "Configuration file created at $configFilePath"

    Write-Output "Configuration completed."
    Write-ActionLog "Configuration completed"
  }
  catch {
    Write-Output "Error configuring DevOps Shield One VM: $_"
    Write-ActionLog "Error configuring DevOps Shield One VM: $_"
  }
}

function Get-IpAddress {
  param (
    [string]$dnsName,
    [string]$dnsServer
  )
  try {
    # Use nslookup to get the IP address    
    $resolvedIPs = @()
    $currentName = $dnsName

    do {
      Write-ActionLog "Resolving DNS name: $currentName"
      Write-Output "Resolving DNS name: $currentName"

      $dnsLookupResult = Resolve-DnsNameCrossPlatform -Name $currentName -Server $dnsServer 

      # echo result
      Write-Output "DNS Lookup Result: $dnsLookupResult"

      # keep searching till we find an IP address
      foreach ($result in $dnsLookupResult) {
        if ($result.IPAddress -and $result.IPAddress -notin $resolvedIPs) {
          $resolvedIPs += $result.IPAddress
          Write-Output "Resolved IP address: $($result.IPAddress)"

          # if format is an IP address, set it as the current name and return
          if ($result.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
            Write-Output "Found IP address: $($result.IPAddress)"
            $ipAddress = $result.IPAddress
            Write-Output "IP address: $ipAddress"
            # return the IP address
            return $ipAddress
          }
          # if format is a DNS name, set it as the current name and continue
          else {
            $currentName = $result.IPAddress
            Write-Output "Found DNS name: $($result.IPAddress)"
            break
          }
        }
      }
            
    } while ($currentName)

    # if we reach here, we have not found an IP address
    Write-Output "No IP address found for DNS name: $dnsName"
    Write-Output "Resolved IP addresses: $resolvedIPs"
    return $null
  }
  catch {
    Write-Output "Error getting IP address for ${dnsName}: $_"
    Write-ActionLog "Error getting IP address for ${dnsName}: $_"
    return $null
  }
}

function Test-VMConfiguration {
  param (
    [string]$rootFolder = "/home/ubuntu"
  )

  Write-Output "Testing VM Configuration..."
  Write-ActionLog "Testing VM Configuration"
  try {
    # Load the configuration file
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config.json"

    if (Test-Path -Path $configFilePath) {
      $configData = Get-Content -Path $configFilePath | ConvertFrom-Json
      Write-Output "==================================="
      Write-Output "Configuration data loaded from $configFilePath"
      Write-Output "Hostname: $($configData.Hostname)"
      Write-Output "Pretty Hostname: $($configData.PrettyHostname)"
      Write-Output "IP Address: $($configData.IPAddress)"
      Write-Output "Default Email: $($configData.DefaultEmail)"
      Write-Output "External IP: $($configData.ExternalIP)"
      Write-Output "Defect Dojo DNS Name: $($configData.DefectDojoDNSName)"
      Write-Output "Dependency Track Backend DNS Name: $($configData.DependencyTrackBackendDNSName)"
      Write-Output "Dependency Track Frontend DNS Name: $($configData.DependencyTrackFrontendDNSName)"
      Write-Output "SonarQube DNS Name: $($configData.SonarQubeDNSName)"
      Write-Output "DevOps Shield DNS Name: $($configData.DevOpsShieldDNSName)"
      Write-Output "DNS Name Server: $($configData.DNSNameServer)"
      Write-Output "Tested: $($configData.Tested)"
      Write-Output "Tested Timestamp: $($configData.TestedTimestamp)"
      Write-Output "Test Result: $($configData.TestResult)"
      Write-Output "==================================="

      Write-Output "Testing DNS names..."

      # Test the configuration
      Write-Output "Testing the configuration..."
      $dnsNames = @(
        $configData.DefectDojoDNSName,
        $configData.DependencyTrackBackendDNSName,
        $configData.DependencyTrackFrontendDNSName,
        $configData.SonarQubeDNSName,
        $configData.DevOpsShieldDNSName
      )

      $dnsServer = $configData.DNSNameServer
      Write-Output "Testing DNS names..."
      Write-Output "DNS server: $dnsServer"
      foreach ($dnsName in $dnsNames) {
        $ipAddress = Get-IpAddress -dnsName $dnsName -dnsServer $dnsServer
        if ($null -eq $ipAddress) {
          Write-Error "DNS name $dnsName does not resolve to an IP address."
          throw "DNS name $dnsName does not resolve to an IP address."
        }

        Write-Output "DNS name: $dnsName resolves to IP address: $ipAddress"
        if ($ipAddress -eq $configData.ExternalIP) {
          Write-Host "DNS name $dnsName resolves to the correct IP address: $ipAddress" -ForegroundColor Green
        }
        else {
          Write-Host "DNS name $dnsName does not resolve to the correct IP address: $ipAddress" -ForegroundColor Red
          throw "DNS name $dnsName does not resolve to the correct IP address: $ipAddress"
        }
      }
      Write-Output "All DNS names resolve to the correct IP address."
      Write-Output "Testing completed."
      Write-ActionLog "All DNS names resolve to the correct IP address."
      # add a boolean to the config file
      $configData.Tested = $true
      # add a timestamp to the config file
      $configData.TestedTimestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
      # add a test result to the config file
      $configData.TestResult = "Success"
      # save the config file
      $jsonConfigData = $configData | ConvertTo-Json -Depth 4
      $jsonConfigData | Out-File -FilePath $configFilePath -Encoding utf8
      Write-Output "Configuration file updated with test result."
    }
    else {
      Write-Output "Configuration file not found at $configFilePath"
    }

    Write-Output "VM Configuration test completed."
    Write-ActionLog "VM Configuration test completed"
  }
  catch {
    Write-Output "Error testing VM Configuration: $_"
    Write-ActionLog "Error testing VM Configuration: $_"
  }
}

function Update-AllAppsToNginxProxy {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "true"
  )

  Write-Output "Updating all applications to Nginx Proxy..."
  Write-ActionLog "Updating all applications to Nginx Proxy"
  try {
    # Call the update functions for each application  
    
    # first ensure that config file is created and has been tested with status true
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config.json"
    if (Test-Path -Path $configFilePath) {
      $configData = Get-Content -Path $configFilePath | ConvertFrom-Json
      if ($configData.Tested -eq $false) {
        Write-Output "Configuration file has not been tested. Please test the configuration first."
        Write-ActionLog "Configuration file has not been tested. Please test the configuration first."
        return
      }
    }
    else {
      Write-Output "Configuration file not found at $configFilePath"
      Write-ActionLog "Configuration file not found at $configFilePath"
      return
    }

    # Ready to update all applications
    Write-Output "Ready to update all applications to Nginx Proxy"
    Write-ActionLog "Ready to update all applications to Nginx Proxy"

    # echo the config file
    Write-Output "Configuration file contents:"
    Write-Output $configData | ConvertTo-Json -Depth 4
    
    # Install-NginxProxy
    Write-Output "Installing Nginx Proxy..."
    Write-ActionLog "Installing Nginx Proxy"

    Write-Output "With the following parameters:"
    Write-Output "rootFolder: $rootFolder"
    Write-Output "common_network_name: $common_network_name"
    Write-Output "Default Email: $($configData.DefaultEmail)"

    Install-NginxProxy -rootFolder $rootFolder `
      -common_network_name $common_network_name `
      -DEFAULT_EMAIL $configData.DefaultEmail 

    # press enter to continue
    Read-Host "Press Enter to continue..."

    # Update-DevOpsShieldApp
    Write-Output "Updating DevOps Shield Application..."
    Write-ActionLog "Updating DevOps Shield Application"

    Write-Output "With the following parameters:"

    Update-DevOpsShieldApp -rootFolder $rootFolder `
      -common_network_name $common_network_name `
      -external "true" `
      -environmentPrefix "" `
      -networkPrefix "" `
      -portPrefix "#" `
      -VIRTUAL_HOST $configData.DevOpsShieldDNSName `
      -VIRTUAL_PORT "8080" `
      -LETSENCRYPT_HOST $configData.DevOpsShieldDNSName

    # can delete default network
    sudo docker network rm "devops-shield_default"

    # press enter to continue
    Read-Host "Press Enter to continue..."

    # Update-DefectDojoApp
    Write-Output "Updating Defect Dojo Application..."
    Write-ActionLog "Updating Defect Dojo Application"

    Write-Output "With the following parameters:"
    Write-Output "rootFolder: $rootFolder"
    Write-Output "common_network_name: $common_network_name"
    Write-Output "VIRTUAL_HOST: $($configData.DefectDojoDNSName)"
    Write-Output "VIRTUAL_PORT: 8080"
    Write-Output "LETSENCRYPT_HOST: $($configData.DefectDojoDNSName)"
    Write-Output "NGINX_METRICS_ENABLED: false"

    Update-DefectDojoApp -rootFolder $rootFolder `
      -common_network_name $common_network_name `
      -external "true" `
      -environmentPrefix "" `
      -networkPrefix "" `
      -portPrefix "#" `
      -VIRTUAL_HOST $configData.DefectDojoDNSName `
      -VIRTUAL_PORT "8080" `
      -LETSENCRYPT_HOST $configData.DefectDojoDNSName `
      -NGINX_METRICS_ENABLED "false"

    # press enter to continue
    Read-Host "Press Enter to continue..."

    # Update-DependencyTrackApp
    Write-Output "Updating Dependency Track Application..."
    Write-ActionLog "Updating Dependency Track Application"

    Write-Output "With the following parameters:"
    Write-Output "rootFolder: $rootFolder"
    Write-Output "common_network_name: $common_network_name"
    Write-Output "VIRTUAL_HOST_BACKEND: $($configData.DependencyTrackBackendDNSName)"
    Write-Output "VIRTUAL_PORT_BACKEND: 8081"
    Write-Output "LETSENCRYPT_HOST_BACKEND: $($configData.DependencyTrackBackendDNSName)"
    Write-Output "VIRTUAL_HOST_FRONTEND: $($configData.DependencyTrackFrontendDNSName)"
    Write-Output "VIRTUAL_PORT_FRONTEND: 8082"
    Write-Output "LETSENCRYPT_HOST_FRONTEND: $($configData.DependencyTrackFrontendDNSName)"

    Update-DependencyTrackApp -rootFolder $rootFolder `
      -common_network_name $common_network_name `
      -external "true" `
      -environmentPrefix "" `
      -networkPrefix "" `
      -portPrefix "#" `
      -VIRTUAL_HOST_BACKEND $configData.DependencyTrackBackendDNSName `
      -VIRTUAL_PORT_BACKEND "8080" `
      -LETSENCRYPT_HOST_BACKEND $configData.DependencyTrackBackendDNSName `
      -VIRTUAL_HOST_FRONTEND $configData.DependencyTrackFrontendDNSName `
      -VIRTUAL_PORT_FRONTEND "8080" `
      -LETSENCRYPT_HOST_FRONTEND $configData.DependencyTrackFrontendDNSName

    # can delete default network
    sudo docker network rm "dependency-track_default"

    # press enter to continue
    Read-Host "Press Enter to continue..."

    # Update-SonarQubeCommunity
    Write-Output "Updating SonarQube Community..."
    Write-ActionLog "Updating SonarQube Community"

    Write-Output "With the following parameters:"
    Write-Output "rootFolder: $rootFolder"
    Write-Output "common_network_name: $common_network_name"
    Write-Output "VIRTUAL_HOST: $($configData.SonarQubeDNSName)"
    Write-Output "VIRTUAL_PORT: 9000"
    Write-Output "LETSENCRYPT_HOST: $($configData.SonarQubeDNSName)"
    Write-Output "SONARQUBE_VERSION: community"
    Write-Output "POSTGRES_VERSION: 13"

    Update-SonarQubeCommunity -rootFolder $rootFolder `
      -common_network_name $common_network_name `
      -external "true" `
      -environmentPrefix "" `
      -networkPrefix "" `
      -portPrefix "#" `
      -SONARQUBE_VERSION "community" `
      -POSTGRES_VERSION "13" `
      -VIRTUAL_HOST $configData.SonarQubeDNSName `
      -VIRTUAL_PORT "9000" `
      -LETSENCRYPT_HOST $configData.SonarQubeDNSName

    # can delete default network
    sudo docker network rm "sonarqube_default"

    # press enter to continue
    Read-Host "Press Enter to continue..."

    Write-Output "All applications updated to Nginx Proxy."
    Write-ActionLog "All applications updated to Nginx Proxy"
  }
  catch {
    Write-Output "Error updating all applications to Nginx Proxy: $_"
    Write-ActionLog "Error updating all applications to Nginx Proxy: $_"
  }
}

function Show-Menu {
  Write-Output "Select an option:"
  Write-Output "-----------------------------------"
  Write-Output " 0. Run docker without sudo"
  Write-Output " 1. Change hostname"
  Write-Output " 2. Update the DevOps Shield One VM Operating System"
  Write-Output " 3. Update the DevOps Shield Application"
  Write-Output " 4. Update the Defect Dojo Application"
  Write-Output " 5. Update the Dependency Track Application"
  Write-Output " 6. Update SonarQube Community"
  Write-Output " 7. Install Nginx Proxy"
  Write-Output " 8. Configure the DevOps Shield One VM"
  Write-Output " 9. Test VM Configuration"
  Write-Output "10. Update All Applications to Nginx Proxy"
  Write-Output "11. Exit"
  Write-Output "-----------------------------------"
}

while ($true) {
  Show-Menu
  $choice = Read-Host "Enter your choice (0-11)"
  switch ($choice) {
    0 {
      Write-Output "Running docker without sudo..."
      Write-ActionLog "Running docker without sudo"
      # Add the current user to the docker group
      sudo usermod -aG docker $USER
      Write-Output "You need to log out and log back in for the changes to take effect."
    }
    1 {
      if (Read-Host "Are you sure you want to change the hostname? (y/n)" -eq 'y') {
        Update-Hostname
      }
    }
    2 {
      if (Read-Host "Are you sure you want to update the Operating System? (y/n)" -eq 'y') {
        Update-OperatingSystem
      }
    }
    3 {
      if (Read-Host "Are you sure you want to update the DevOps Shield Application? (y/n)" -eq 'y') {
        Update-DevOpsShieldApp
      }
    }
    4 {
      if (Read-Host "Are you sure you want to update the Defect Dojo Application? (y/n)" -eq 'y') {
        Update-DefectDojoApp
      }
    }
    5 {
      if (Read-Host "Are you sure you want to update the Dependency Track Application? (y/n)" -eq 'y') {
        Update-DependencyTrackApp
      }
    }
    6 {
      if (Read-Host "Are you sure you want to update SonarQube? (y/n)" -eq 'y') {
        Update-SonarQubeCommunity
      }
    }
    7 {
      if (Read-Host "Are you sure you want to install Nginx Proxy? (y/n)" -eq 'y') {
        Install-NginxProxy
      }
    }
    8 {
      if (Read-Host "Are you sure you want to configure the DevOps Shield One VM? (y/n)" -eq 'y') {
        Set-DevOpsShieldOneVm
      }
    }
    9 {
      if (Read-Host "Are you sure you want to test the VM configuration? (y/n)" -eq 'y') {
        Test-VMConfiguration
      }
    }
    10 {
      if (Read-Host "Are you sure you want to update all applications to Nginx Proxy? (y/n)" -eq 'y') {
        Update-AllAppsToNginxProxy
      }
    }
    11 {
      Write-Output "Exiting..."
      Write-ActionLog "Script exited by user"
      Write-Output "Log file can be found at $logFile"
      Write-Output "Type 'cat $logFile' to see the actions taken"
      Write-Output "You can view th VM configuration file at $rootFolder/DevOpsShieldOneVM_Config.json"
      # Show the contents of the configuration file
      Write-Output "Configuration file contents:"
      # check if it exists
      if (Test-Path -Path "$rootFolder/DevOpsShieldOneVM_Config.json") {
        Get-Content -Path "$rootFolder/DevOpsShieldOneVM_Config.json"
      }
      else {
        Write-Output "Configuration file not found."
      }
      Write-Output "Please check the log file for details."

      # Show docker volumes      
      Write-Output "Docker containers:"
      sudo docker ps -a
      Write-Output "Docker volumes:"
      sudo docker volume ls
      Write-Output "Docker networks:"
      sudo docker network ls
      # Write-Output "Docker images:"
      # sudo docker images
      # Write-Output "Docker system prune:"
      # sudo docker system prune -a -f
      # Write-Output "Docker system df:"
      # sudo docker system df
      # Write-Output "Docker system info:"
      # sudo docker system info

      Write-Output "Exiting script."
      exit 0
    }
    default {
      Write-Output "Invalid choice. Please select a valid option."
    }
  }
}
