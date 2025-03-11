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

function Log-Action {
  param (
    [string]$message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logMessage = "$timestamp - $message"
  Add-Content -Path $logFile -Value $logMessage
}

function Update-Hostname {
  Write-Output "Updating hostname..."
  Log-Action "Updating hostname"
  try {
    Write-Output "Changing hostname..."
    Log-Action "Changing hostname"
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
      Log-Action "Changing hostname to $newHostname"
      # Windows command to change hostname
      Rename-Computer -NewName $newHostname -Force
    }
    else {
      Write-Output "Changing hostname to $newHostname..."
      Log-Action "Changing hostname to $newHostname"
      # Linux command to change hostname
      sudo hostnamectl set-hostname $newHostname
      hostnamectl
      sudo hostnamectl set-hostname $newHostnamePretty --pretty
      hostnamectl
    }
    Write-Output "Hostname changed to $newHostname."
    
    Write-Output "Hostname update completed."
    Log-Action "Hostname update completed"
  }
  catch {
    Write-Output "Error updating hostname: $_"
    Log-Action "Error updating hostname: $_"
  }
}

function Update-OperatingSystem {
  Write-Output "Updating Operating System..."
  Log-Action "Updating Operating System"
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
    Log-Action "Operating System update completed"
  }
  catch {
    Write-Output "Error updating Operating System: $_"
    Log-Action "Error updating Operating System: $_"
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
    [string]$portPrefix = "",
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "",
    [string]$LETSENCRYPT_HOST = ""
  )
  Write-Output "Updating DevOps Shield Application..."
  Log-Action "Updating DevOps Shield Application"
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

networks:
  default:
    name: $common_network_name
    external: $external
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

networks:
  default:
    name: $common_network_name
    external: $external
"@ | Out-File -FilePath "docker-compose.SqlServer.yaml" -Encoding utf8

    Write-Output "Copying the docker-compose file to $dockerComposeFileName ..."
    Copy-Item -Path "docker-compose.${DatabaseProvider}.yaml" -Destination $dockerComposeFileName -Force
    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "DevOps Shield Application update completed."
    Log-Action "DevOps Shield Application update completed"
  }
  catch {
    Write-Output "Error updating DevOps Shield Application: $_"
    Log-Action "Error updating DevOps Shield Application: $_"
  }
}

function Update-DefectDojoApp {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$portPrefix = ""
  )

  Write-Output "Updating Defect Dojo Application..."
  Log-Action "Updating Defect Dojo Application"
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
    ${environmentPrefix}  VIRTUAL_HOST: $env:VIRTUAL_HOST
    ${environmentPrefix}  VIRTUAL_PORT: $env:VIRTUAL_PORT
    ${environmentPrefix}  LETSENCRYPT_HOST: $env:LETSENCRYPT_HOST
    ${environmentPrefix}  NGINX_METRICS_ENABLED: $env:NGINX_METRICS_ENABLED

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

networks:
  default:
    name: $common_network_name
    external: $external
"@ | Out-File -FilePath "docker-compose.override.yml"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "Defect Dojo Application update completed."
    Log-Action "Defect Dojo Application update completed"
  }
  catch {
    Write-Output "Error updating Defect Dojo Application: $_"
    Log-Action "Error updating Defect Dojo Application: $_"
  }
}

function Update-DependencyTrackApp {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$portPrefix = "",
    [string]$IP_ADDRESS = $(hostname -I | cut -d' ' -f1)
  )

  Write-Output "Updating Dependency Track Application..."
  Log-Action "Updating Dependency Track Application"
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
    ${environmentPrefix}  VIRTUAL_HOST: $env:VIRTUAL_HOST_BACKEND
    ${environmentPrefix}  VIRTUAL_PORT: $env:VIRTUAL_PORT_BACKEND
    ${environmentPrefix}  LETSENCRYPT_HOST: $env:LETSENCRYPT_HOST_BACKEND
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
      ${environmentPrefix}VIRTUAL_HOST: $env:VIRTUAL_HOST_FRONTEND
      ${environmentPrefix}VIRTUAL_PORT: $env:VIRTUAL_PORT_FRONTEND
      ${environmentPrefix}LETSENCRYPT_HOST: $env:LETSENCRYPT_HOST_FRONTEND
      ${environmentPrefix}API_BASE_URL: https://$env:VIRTUAL_HOST_BACKEND
      ${portPrefix}API_BASE_URL: http://${IP_ADDRESS}:8081      
    ${portPrefix}ports:
    ${portPrefix}  - "8082:8080"
    restart: unless-stopped

networks:
  default:
    name: $common_network_name
    external: $external
"@ | Out-File -FilePath "docker-compose.yml"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "Dependency-Track IS available at http://${IP_ADDRESS}:8082"
    Write-Output "Dependency-Track API is available at http://${IP_ADDRESS}:8081"
    Write-Output "Dependency Track Application update completed."
    Log-Action "Dependency Track Application update completed"
  }
  catch {
    Write-Output "Error updating Dependency Track Application: $_"
    Log-Action "Error updating Dependency Track Application: $_"
  }
}

function Update-SonarQube {
  param (
    [string]$rootFolder = "/home/ubuntu",
    [string]$common_network_name = "nginx-proxy",
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$portPrefix = "",
    [string]$SONARQUBE_VERSION = "community", # latest community version
    [string]$POSTGRES_VERSION = "13"
  )

  Write-Output "Updating SonarQube..."
  Log-Action "Updating SonarQube"
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
      ${environmentPrefix}VIRTUAL_HOST: $env:VIRTUAL_HOST
      ${environmentPrefix}VIRTUAL_PORT: $env:VIRTUAL_PORT
      ${environmentPrefix}LETSENCRYPT_HOST: $env:LETSENCRYPT_HOST
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

networks:
  default:
    name: $common_network_name
    external: $external
"@ | Out-File -FilePath "docker-compose.yaml"

    Write-Output "Building containers..."
    sudo docker compose up -d
    Write-Output "Waiting for containers to start..."
    Start-Sleep 15
    Write-Output "SonarQube update completed."
    Log-Action "SonarQube update completed"
  }
  catch {
    Write-Output "Error updating SonarQube: $_"
    Log-Action "Error updating SonarQube: $_"
  }
}

function Show-Menu {
  Write-Output "Select an option:"
  Write-Output "-----------------------------------"
  Write-Output "0. Change hostname"
  Write-Output "1. Update the DevOps Shield One VM Operating System"
  Write-Output "2. Update the DevOps Shield Application"
  Write-Output "3. Update the Defect Dojo Application"
  Write-Output "4. Update the Dependency Track Application"
  Write-Output "5. Update SonarQube"
  Write-Output "6. Exit"
  Write-Output "-----------------------------------"
}

while ($true) {
  Show-Menu
  $choice = Read-Host "Enter your choice (0-6)"
  switch ($choice) {
    0 {
      if (Read-Host "Are you sure you want to change the hostname? (y/n)" -eq 'y') {
        Update-Hostname
      }
    }
    1 {
      if (Read-Host "Are you sure you want to update the Operating System? (y/n)" -eq 'y') {
        Update-OperatingSystem
      }
    }
    2 {
      if (Read-Host "Are you sure you want to update the DevOps Shield Application? (y/n)" -eq 'y') {
        Update-DevOpsShieldApp
      }
    }
    3 {
      if (Read-Host "Are you sure you want to update the Defect Dojo Application? (y/n)" -eq 'y') {
        Update-DefectDojoApp
      }
    }
    4 {
      if (Read-Host "Are you sure you want to update the Dependency Track Application? (y/n)" -eq 'y') {
        Update-DependencyTrackApp
      }
    }
    5 {
      if (Read-Host "Are you sure you want to update SonarQube? (y/n)" -eq 'y') {
        Update-SonarQube
      }
    }
    6 {
      Write-Output "Exiting..."
      Log-Action "Script exited by user"
      Write-Output "Log file can be found at $logFile"
      Write-Output "Type 'cat $logFile' to see the actions taken"
      Write-Output "Please check the log file for details."
      Write-Output "Exiting script."
      exit 0
    }
    default {
      Write-Output "Invalid choice. Please select a valid option."
    }
  }
}
