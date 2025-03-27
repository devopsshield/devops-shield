# MIT License

# Copyright (c) 2025 DevOps Shield

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

Set-StrictMode -Version Latest

# Menu driven script to update the DevOps Shield One VM
# It is recommended to run this script as a root user
# The script will prompt for confirmation before proceeding with each update
# The script will log all actions to a log file
# The script will check for updates and install them if available
# The script will check for the latest version of each application and update it if necessary

# log file path depends on the OS
# For Windows, the log file is stored in C:\DevOpsShieldOneVM_UpdateLog_${instanceName}.txt
# For Linux, the log file is stored in /var/log/DevOpsShieldOneVM_UpdateLog_${instanceName}.txt
# The script will create the log file if it does not exist
# The script will append to the log file if it already exists


function Write-ActionLog {
  param (
    [string]$message
  )
  $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
  $logMessage = "$timestamp - $message"
  Add-Content -Path $logFile -Value $logMessage
}

function Get-SystemInfo {
  # check if the OS is Windows or Linux
  if ($IsWindows) {
    Write-Output "This is a Windows VM."
    # get free memory
    Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object FreePhysicalMemory, FreeVirtualMemory
    # get disk space
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" | Select-Object DeviceID, VolumeName, FreeSpace, Size
    return $true
  }
  else {
    Write-Output "This is a Linux VM."
    # get free memory
    free -h
    # get disk space
    df -h
    return $true
  }  
}

function Get-MachineIpAddress {

  if ($IsWindows) {
    $IP_ADDRESS = (Get-NetIPAddress | Where-Object { $_.AddressState -eq 'Preferred' -and $_.ValidLifetime -lt '24:00:00' }).IPAddress
    
    if ($IP_ADDRESS.GetType().Name -eq 'Object[]') {
      #Write-Output "The variable is an array."
      # pick the first IP address from the list
      if ($IP_ADDRESS.Count -gt 0) {
        $IP_ADDRESS = $IP_ADDRESS[0]
      }
      #Write-Output "The first IP address is: $IP_ADDRESS"
    }
    else {
      #Write-Output "The variable is not an array."
      #Write-Output "The IP address is: $IP_ADDRESS"
    }    
  }
  else {
    $IP_ADDRESS = (hostname -I | cut -d ' ' -f1).Trim()
  }
  return $IP_ADDRESS
}

function  Remove-DockerNetwork {
  param (
    [string]$networkName
  )
  # if OS is Linux, use sudo to check the network
  if ($IsWindows) {
    Write-Output "Checking if network $networkName exists..."
    $networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern "^${networkName}$"
  }
  else {
    Write-Output "Checking if network $networkName exists..."
    $networkExists = sudo docker network ls --format '{{.Name}}' | Select-String -Pattern "^${networkName}$"
  }
  if ($networkExists) {
    Write-ActionLog "Network $networkName already exists."
    # can delete default network
    # if OS is Linux, use sudo to delete the network
    if ($IsWindows) {
      Write-Output "Deleting $networkName ..."
      docker network rm "$networkName"
    }
    else {
      Write-Output "Deleting network $networkName ..."      
      sudo docker network rm "$networkName"
    }
  }
  else {
    Write-Output "Network $networkName does not exist."
    Write-ActionLog "Network $networkName does not exist."   
    # nothing to do here         
  }
}

function Get-FirstUnusedPort {
  param (
    [int]$StartPort = 3000
  )

  if ($IsWindows) {

    $activePorts = Get-NetTCPConnection -State Listen | Select-Object -ExpandProperty LocalPort
    $port = $StartPort

    while ($activePorts -contains $port) {
      $port++
    }
  }
  else {
    $activePorts = sudo netstat -tuln | Select-String -Pattern "LISTEN"   
    $uniqueActivePorts = @()
    # get active ports
    foreach ($line in $activePorts) {
      $port = $line -replace '.*:(\d+).*', '$1'
      Write-Output "Active port: $port"
      # add to the list of active ports if not already present
      if ($activePorts -notcontains $port) {
        Write-Output "Adding port $port to the list of active ports"
        $uniqueActivePorts += [int]$port
      }
      else {
        Write-Output "Port $port already in the list of active ports"
      }
    }
    Write-Output "Unique active ports: $uniqueActivePorts"
    Write-ActionLog "Active ports: $uniqueActivePorts"
    $port = $StartPort

    while ($uniqueActivePorts -contains $port) {
      $port++
    }
  }

  Write-Output "First unused port: $port"
  Write-ActionLog "First unused port: $port"
  # return as hash table
  $returnHashTable = @{}
  $returnHashTable["port"] = $port

  return $returnHashTable
}

function Initialize-Script {
  param (
    [int]$StartPortHttp = 10081,
    [int]$StartPortHttps = 10443
  )

  # return hash table with the following values
  # instanceName, rootFolder, logFile, common_network_name, isAzureVM, isRootUser, IP_ADDRESS, externalIP
  #initialize the return hash table
  $returnHashTable = @{}
 
  Write-Output "========================================"
  Write-Output "Welcome to the DevOps Shield One VM update script"
  Write-Output "This script will update the DevOps Shield One VM"
  Write-Output "========================================"
  #ask user for an instance name such as mcx-001
  $instanceName = Read-Host "Enter the instance name (e.g. mcx-001)"
  # check if the instance name is empty
  if ($instanceName -eq "") {
    Write-Output "Instance name cannot be empty. Please enter a valid instance name."
    exit
  }
  else {
    Write-Output "Instance name: $instanceName"
  }

  # ensure script is run with sudo privileges
  if ($IsLinux) {
    # check if it's an azure vm if and only if the folder /var/lib/waagent exists
    # if azure vm, set the variable $isAzureVM to true
    if (Test-Path -Path "/var/lib/waagent") {
      Write-Output "This is an Azure VM."
      # set the variable $isAzureVM to true
      $isAzureVM = $true
    }
    else {
      Write-Output "This is not an Azure VM."
      # set the variable $isAzureVM to false
      $isAzureVM = $false
    }

    if ($(whoami) -ne "root") {
      # echo setting the variable $isRootUser to false
      Write-Output "Running as non-root user ${env:USER}"
      $isRootUser = $false

      # if this is an azure vm, this is acceptable
      if ($isAzureVM) {
        Write-Output "Running as non-root user ${env:USER} on Azure VM"
        # set rootFolder
        $rootFolder = "${HOME}"
        Write-Output "Setting root folder to $rootFolder"
        # set the log file path
        $logFile = "${rootFolder}/DevOpsShieldOneVM_UpdateLog_${instanceName}.txt"
        Write-Output "Setting log file path to ${logFile}"      
      }
      else {
        Write-Output "Running as non-root user ${env:USER} on non-Azure VM"
        Write-Output "This script must be run as root user. Please run the script with sudo."        
        Write-Output "Please run with: sudo pwsh Update-DevOpsShieldOneVm.ps1"
        Write-Output "Exiting script."
        exit
      }
    }
    else {
      Write-Output "Running as root user"
      $isRootUser = $true

      # if this is an azure vm, this is NOT acceptable
      if ($isAzureVM) {
        Write-Output "Running as root user ${env:USER} on Azure VM"
        # not allowed exiting script
        Write-Output "This script must not be run as root user on Azure VM. Please run the script with a non-root user."
        Write-Output "Please run with: pwsh Update-DevOpsShieldOneVm.ps1"
        Write-Output "Exiting script."
        exit
      }
      else {
        Write-Output "Running as root user ${env:USER} on non-Azure VM"
        # set rootFolder
        # find the home directory of the first non-root user
        $homeDir = Get-ChildItem -Path /home | Where-Object { $_.Name -ne "root" } | Select-Object -First 1
        if ($homeDir) {
          $rootFolder = "/home/$($homeDir.Name)"
        }
        else {
          # if no non-root user found, set rootFolder to $HOME
          Write-Output "No non-root user found. Setting root folder to $HOME"
          $rootFolder = "${HOME}"
        }
        Write-Output "Setting root folder to $rootFolder"
        # set the log file path
        $logFile = "${rootFolder}/DevOpsShieldOneVM_UpdateLog_${instanceName}.txt"
        Write-Output "Setting log file path to ${logFile}"      
      }
    }
  }
  else {
    # should be running on Windows
    Write-Output "This is a Windows VM."
    # set the variable $isAzureVM to false
    $isAzureVM = $false
    Write-Output "Setting root folder to ${HOME}/DevOpsShieldOneVM"
    $rootFolder = "${HOME}/DevOpsShieldOneVM"
    Write-Output "Setting log file path to ${rootFolder}/DevOpsShieldOneVM_UpdateLog_${instanceName}.txt"
    $logFile = "${rootFolder}/DevOpsShieldOneVM_UpdateLog_${instanceName}.txt"
    # check if the folder exists, if not create it
    if (-not (Test-Path -Path $rootFolder)) {
      Write-Output "Creating folder $rootFolder..."
      New-Item -ItemType Directory -Path $rootFolder
    }
    else {
      Write-Output "Folder $rootFolder already exists."
    }
    # Ensure script is run with admin privileges
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      Write-Output "This script must be run as administrator. Please run the script with admin privileges."
      Write-Output "Please run with: Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File $PSCommandPath'"
      Write-Output "Exiting script."
      exit
    }
    else {
      Write-Output "Running as administrator."
      $isRootUser = $true
    }
  }

  # get the current location
  $initialLocation = Get-Location
  Write-Output "Current location: $initialLocation"

  # echo out vars so far
  $common_network_name = "nginx-proxy"
  $POSTGRES_VERSION = "16" # for SonarQube
  $SONARQUBE_VERSION = "community" # latest community version
  $devopsShieldImage = "devopsshield/devopsshield:latest" # "devopsshield/devopsshield-enterprise:latest"

  # set the default values for the variables
  $unusedPortHttpOutput = Get-FirstUnusedPort -StartPort $startPortHttp
  # get from last line of the output
  $unusedPortHttp = $($unusedPortHttpOutput[-1].port)
  Write-Output "First unused port above $startPortHttp is: $unusedPortHttp"
  Write-ActionLog "First unused port above $startPortHttp is: $unusedPortHttp"
  $unusedPortHttpsOutput = Get-FirstUnusedPort -StartPort $StartPortHttps
  # get from last line of the output
  $unusedPortHttps = $($unusedPortHttpsOutput[-1].port)
  Write-Output "First unused port above $startPortHttps is: $unusedPortHttps"
  Write-ActionLog "First unused port above $startPortHttps is: $unusedPortHttps"

  Write-Output "========================================"
  Write-Output "Common network name: $common_network_name"
  Write-Output "POSTGRES_VERSION: $POSTGRES_VERSION"
  Write-Output "SONARQUBE_VERSION: $SONARQUBE_VERSION"
  Write-Output "devopsShieldImage: $devopsShieldImage"
  Write-Output "rootFolder: $rootFolder"
  Write-Output "isAzureVM: $isAzureVM"
  Write-Output "isRootUser: $isRootUser"
  Write-Output "logFile: $logFile"
  # echo out the current user
  # if OS is Linux
  # if OS is Windows, use $env:USERNAME
  if ($IsWindows) {
    Write-Output "Current user: ${env:USERNAME}"
  }
  else {  
    Write-Output "Current user: ${env:USER}"
  }
  # echo out the current hostname
  Write-Output "Current hostname: $(hostname)"
  # echo out the current pretty hostname
  # if OS is Linux, use hostnamectl --pretty
  if ($IsWindows) {
    Write-Output "Current pretty hostname: $(hostname)"
  }
  else {
    Write-Output "Current pretty hostname: $(hostnamectl --pretty)"
  }
  # echo out the current IP address
  # if OS is Linux, use hostname -I | cut -d ' ' -f1
  $IP_ADDRESS = Get-MachineIpAddress
  Write-Output "Current IP address: $IP_ADDRESS"
  # echo out the current external IP address
  # get the external IP address using ifconfig.me
  $externalIP = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content.Trim()
  Write-Output "Current external IP address: $externalIP"
  # give HOME directory
  Write-Output "HOME directory: $HOME"
  # echo out the current date and time
  Write-Output "Current date and time: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")"
  # echo out the current date and time in UTC
  Write-Output "Current date and time in UTC: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss" -AsUTC)"
  Write-Output "========================================"

  $returnHashTable = @{
    instanceName        = $instanceName
    rootFolder          = $rootFolder
    logFile             = $logFile
    common_network_name = $common_network_name
    isAzureVM           = $isAzureVM
    isRootUser          = $isRootUser
    IP_ADDRESS          = $IP_ADDRESS
    externalIP          = $externalIP
    unusedPortHttp      = $unusedPortHttp  
    unusedPortHttps     = $unusedPortHttps
    devopsShieldImage   = $devopsShieldImage
    SONARQUBE_VERSION   = $SONARQUBE_VERSION
    POSTGRES_VERSION    = $POSTGRES_VERSION
    initialLocation     = $initialLocation
  }

  # return the values
  return $returnHashTable
}

function Install-RequiredModules {
 
  # Requires PowerShell Module Resolve-DnsNameCrossPlatform
  # Check if the module is installed
  # if OS is Windows, check for module Resolve-DnsName, otherwise check for Resolve-DnsNameCrossPlatform
  # if OS is Linux, check for module Resolve-DnsNameCrossPlatform
  if ($IsWindows) {
    Write-Output "Checking if Resolve-DnsName module is installed..."
    $moduleName = "Resolve-DnsName"
    $moduleFound = Get-Module -ListAvailable -Name $moduleName

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
  }
  else {
    Write-Output "Checking if Resolve-DnsNameCrossPlatform module is installed..."
    $moduleName = "Resolve-DnsNameCrossPlatform"
    $moduleFound = Get-Module -ListAvailable -Name $moduleName

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
  }
}

function Update-Hostname {
  # if OS is Linux
  if ($IsWindows) {
    Write-Output "This script is not supported on Windows OS."
    Write-Output "Please run the script on Linux OS."
    Write-Output "Change the hostname manually."
  }
  else {
    Write-Output "This script is supported on Linux OS."
  
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
      if ($IsWindows) {
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
}

function Update-OperatingSystem {
  # if OS is Linux
  if ($IsWindows) {
    # update the OS using Windows update commands    
    Write-Output "Updating Operating System..."
    Write-ActionLog "Updating Operating System"
    try {
      Write-Output "Running Windows update commands..."
      Write-ActionLog "Running Windows update commands"

      # check if the module is installed
      $moduleName = "PSWindowsUpdate"
      $moduleFound = Get-Module -ListAvailable -Name $moduleName
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
      
      Import-Module PSWindowsUpdate
      
      Write-Output "Checking for Windows updates..."
      Get-WindowsUpdate

      Write-Output "Installing Windows updates..."      
      Install-WindowsUpdate -AcceptAll -Install #-AutoReboot

      Write-Output "Windows update completed."
      Write-ActionLog "Windows update completed"
    }
    catch {
      Write-Output "Error updating Operating System: $_"
      Write-ActionLog "Error updating Operating System: $_"
    }
  }
  else {
    Write-Output "This script is supported on Linux OS."  
    Write-Output "Updating Operating System..."
    Write-ActionLog "Updating Operating System"
    try {
      if ($IsWindows) {
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
    [string]$Volume = "",
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
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
  # set volume name if not provided
  # set according to the OS
  if ($Volume -eq "") {
    if ($IsWindows) {
      $Volume = "/data"
    }
    else {
      $Volume = "/data"
    }
  }
  Write-Output "Volume name: $Volume"
  Write-ActionLog "Volume name: $Volume"
  try {
    # create folder if it does not exist
    if (-not (Test-Path -Path "${rootFolder}/devops-shield-${instanceName}")) {
      Write-Output "Creating folder ${rootFolder}/devops-shield-${instanceName} ..."
      New-Item -ItemType Directory -Path "${rootFolder}/devops-shield-${instanceName}"
    }
    Set-Location  "${rootFolder}/devops-shield-${instanceName}"
    Write-ActionLog "Pulling latest images..."
    # if OS is Linux, use sudo to pull the images
    if ($IsWindows) {
      Write-Output "Pulling latest images..."
      docker pull $devopsShieldImage
      docker pull $sqlServerImage
    }
    else {
      Write-Output "Pulling latest images..."
      sudo docker pull $devopsShieldImage
      sudo docker pull $sqlServerImage
    }
    Write-ActionLog "Stopping containers..."
    # if OS is Linux, use sudo to stop the containers
    if ($IsWindows) {
      Write-Output "Stopping containers..."
      docker compose down
    }
    else {
      Write-Output "Stopping containers..."
      sudo docker compose down
    } 

    @"
services:
  ${containerName}-${instanceName}:
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
      - dos_data_sqlite_${instanceName}:${Volume}

volumes:
  dos_data_sqlite_${instanceName}:

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.SQLite.yaml" -Encoding utf8

    @"
services:
  ${containerName}-${instanceName}:
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
      - ${sqlServerContainerName}-${instanceName}

  ${sqlServerContainerName}-${instanceName}:
    image: $sqlServerImage
    restart: always
    environment:
      SA_PASSWORD: "$MSSQL_SA_PASSWORD"
      ACCEPT_EULA: "Y"
    ports:
      - "${SqlPort}:1433"
    volumes:
      - dos_data_mssql_${instanceName}:/var/opt/mssql

volumes:
  dos_data_mssql_${instanceName}:

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

    Write-ActionLog "Starting containers..."
    # if OS is Linux, use sudo to start the containers
    if ($IsWindows) {
      Write-Output "Starting containers..."
      docker compose up -d
    }
    else {
      Write-Output "Starting containers..."
      sudo docker compose up -d
    }
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "8080",
    [string]$LETSENCRYPT_HOST = "",
    [string]$NGINX_METRICS_ENABLED = "false",
    [int]$DD_PORT_START_HTTP = 10081,
    [int]$DD_PORT_START_HTTPS = 10443,
    [string]$DD_PORT = "",
    [string]$DD_TLS_PORT = ""
  )

  # set the default values for DD_PORT and DD_TLS_PORT if not provided
  if ($DD_PORT -eq "") {
    Write-Output "DD_PORT is not provided. Will set to first unused port above $DD_PORT_START_HTTP"
    Write-ActionLog "DD_PORT is not provided. Will set to first unused port above $DD_PORT_START_HTTP"
    $DD_PORTOutput = Get-FirstUnusedPort -StartPort $DD_PORT_START_HTTP    
    # get from last line of the output
    $DD_PORT = $($DD_PORTOutput[-1].port)
    Write-Output "DD_PORT set to $DD_PORT"    
    Write-ActionLog "DD_PORT set to $DD_PORT"
  }
  if ($DD_TLS_PORT -eq "") {
    Write-Output "DD_TLS_PORT is not provided. Will set to first unused port above $DD_PORT_START_HTTPS"
    Write-ActionLog "DD_TLS_PORT is not provided. Will set to first unused port above $DD_PORT_START_HTTPS"
    $DD_TLS_PORTOutput = Get-FirstUnusedPort -StartPort $DD_PORT_START_HTTPS
    # get from last line of the output
    $DD_TLS_PORT = $($DD_TLS_PORTOutput[-1].port)
    Write-Output "DD_TLS_PORT set to $DD_TLS_PORT"    
    Write-ActionLog "DD_TLS_PORT set to $DD_TLS_PORT"
  }

  #set environment variables
  Write-Output "Setting environment variables..." 
  # if OS is Linux, use sudo to set the environment variables
  if ($IsWindows) {
    Write-Output "Setting environment variables for Windows..."    
    $env:DD_PORT = $DD_PORT  
    $env:DD_TLS_PORT = $DD_TLS_PORT
    Write-ActionLog "Setting environment variables for Windows..."
    Write-Output "DD_PORT: $DD_PORT"
    Write-Output "DD_TLS_PORT: $DD_TLS_PORT"
  }
  else {
    Write-Output "Setting environment variables for Linux..."
    $env:DD_PORT = "$DD_PORT"
    $env:DD_TLS_PORT = "$DD_TLS_PORT"
    #sudo export DD_PORT=$DD_PORT
    #sudo export DD_TLS_PORT=$DD_TLS_PORT
    printenv | Sort-Object
    Write-ActionLog "Setting environment variables for Linux..."
    Write-Output "DD_PORT: $DD_PORT"
    Write-Output "DD_TLS_PORT: $DD_TLS_PORT"
  }
  

  # for windows, you may need to run under WSL2
  # or follow https://github.com/DefectDojo/django-DefectDojo/discussions/9379

  Write-Output "Updating Defect Dojo Application..."
  Write-ActionLog "Updating Defect Dojo Application"
  try {
    # create folder if it does not exist
    if (-not (Test-Path -Path "${rootFolder}/django-DefectDojo-${instanceName}")) {
      Write-Output "Creating folder ${rootFolder}/django-DefectDojo-${instanceName} ..."
      # by git clone
      Write-Output "Cloning Defect Dojo repository..."
      Write-ActionLog "Cloning Defect Dojo repository"      
      git clone https://github.com/DefectDojo/django-DefectDojo "${rootFolder}/django-DefectDojo-${instanceName}"	  
    }
    Set-Location "${rootFolder}/django-DefectDojo-${instanceName}"
    # if OS is Windows
    if ($IsWindows) {
      # set line endings to LF
      # set the git config to use LF line endings
      Write-Output "Setting git config to use LF line endings..."
      git config core.autocrlf input 
      git config core.eol lf
      Write-Output "Setting git config to use LF line endings completed."
      git config --list
    }
    Write-ActionLog "Pulling latest from git repo"
    # if OS is Linux, use sudo to pull the images
    if ($IsWindows) {
      Write-Output "Pulling latest from git repo ..."
      git pull
      #To check current line endings:
      Write-Output "Checking current line endings..."
      git ls-files --eol
      #Reset line endings for already checked out files: 
      Write-Output "Resetting line endings for already checked out files..."
      git rm -rf --cached . 
      #and 
      git reset --hard HEAD
    }
    else {
      Write-Output "Pulling latest from git repo ..."
      sudo git pull
    }

    Write-Output "Showing the contents of the docker-compose.yml file"
    Get-Content -Path "docker-compose.yml"
    # find and replace the following lines in the docker-compose.yml file
    # 1. find container name "nginx:" and replace with "nginx-${instanceName}:"
    # 2. find container name "uwsgi:" and replace with "uwsgi-${instanceName}:"
    # 3. find container name "celerybeat:" and replace with "celerybeat-${instanceName}:"
    # 4. find container name "celeryworker:" and replace with "celeryworker-${instanceName}:"
    # 5. find container name "postgres:" and replace with "postgres-${instanceName}:"
    # 6. find container name "redis:" and replace with "redis-${instanceName}:"
    # 7. find container name "initializer:" and replace with "initializer-${instanceName}:"
    # 8. find volume name "defectdojo_postgres:" and replace with "defectdojo_postgres_${instanceName}:"
    # 9. find volume name "defectdojo_redis:" and replace with "defectdojo_redis_${instanceName}:"
    # 10. find volume name "defectdojo_media:" and replace with "defectdojo_media_${instanceName}:"

    $currentDockerComposeFileContent = Get-Content -Path "docker-compose.yml"
    $updatedDockerComposeFileContent = $currentDockerComposeFileContent -replace "nginx:", "nginx-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "uwsgi:", "uwsgi-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "celerybeat:", "celerybeat-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "celeryworker:", "celeryworker-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "postgres:", "postgres-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "redis:", "redis-${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "initializer:", "initializer-${instanceName}:"
    # volumes
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "defectdojo_postgres:", "defectdojo_postgres_${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "defectdojo_redis:", "defectdojo_redis_${instanceName}:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "defectdojo_media:", "defectdojo_media_${instanceName}:"
    # depends on
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "- uwsgi", "- uwsgi-${instanceName}"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "- postgres", "- postgres-${instanceName}"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "- redis", "- redis-${instanceName}"
    # now fix image pull
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "image: postgres-${instanceName}:", "image: postgres:"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "image: redis-${instanceName}:", "image: redis:"

    # fix host issues
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "DD_UWSGI_HOST:-uwsgi", "DD_UWSGI_HOST:-uwsgi-${instanceName}"
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "DD_DATABASE_HOST:-postgres", "DD_DATABASE_HOST:-postgres-${instanceName}"

    # fix No such transport for redis
    $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "DD_CELERY_BROKER_URL:-redis-${instanceName}://", "DD_CELERY_BROKER_URL:-redis://"

    # additional hacks for Linux
    if ($IsLinux) {
      # hack to remove double -${instanceName} in the docker-compose.yml file
      # do while docker-compose.yml file has -${instanceName}-${instanceName}
      while ($updatedDockerComposeFileContent -match "-${instanceName}-${instanceName}") {
        Write-Output "Removing double -${instanceName}-${instanceName} from docker-compose.yml file"
        $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace "-${instanceName}-${instanceName}", "-${instanceName}"
      }
      # replace DD_PORT:-8080
      $pattern = "DD_PORT:-\d+"
      $replacement = "DD_PORT:-$DD_PORT"

      # Replace the pattern with the new value
      $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace $pattern, $replacement
      # replace DD_TLS_PORT:-8443
      $pattern = "DD_TLS_PORT:-\d+"
      $replacement = "DD_TLS_PORT:-$DD_TLS_PORT"
      $updatedDockerComposeFileContent = $updatedDockerComposeFileContent -replace $pattern, $replacement
    }

    # write the updated content to the docker-compose.yml file
    $updatedDockerComposeFileContent | Out-File -FilePath "docker-compose.yml" -Encoding utf8
    Write-Output "Updated docker-compose.yml file"
    Write-Output "Showing the contents of the docker-compose.yml file"
    Get-Content -Path "docker-compose.yml"

    Write-ActionLog "Checking if your installed toolkit is compatible"
    # if OS is Linux, use sudo to check the compatibility
    if ($IsWindows) {
      Write-Output "Checking if your installed toolkit is compatible..."
      ./docker/docker-compose-check.sh
    }
    else {
      Write-Output "Checking if your installed toolkit is compatible..."
      sudo ./docker/docker-compose-check.sh
    }
    Write-ActionLog "Building Docker images"
    # if OS is Linux, use sudo to build the images
    if ($IsWindows) {
      Write-Output "Building Docker images..."
      docker compose build
    }
    else {
      Write-Output "Building Docker images..."
      sudo docker compose build
    }
    Write-ActionLog "Stopping containers"
    # if OS is Linux, use sudo to stop the containers
    if ($IsWindows) {
      Write-Output "Stopping containers..."
      docker compose down
    }
    else {
      Write-Output "Stopping containers..."
      sudo docker compose down
    }

    @"
services:
  nginx-${instanceName}:
    restart: always
    ${environmentPrefix}environment:
    ${environmentPrefix}  VIRTUAL_HOST: $VIRTUAL_HOST
    ${environmentPrefix}  VIRTUAL_PORT: $VIRTUAL_PORT
    ${environmentPrefix}  LETSENCRYPT_HOST: $LETSENCRYPT_HOST
    ${environmentPrefix}  NGINX_METRICS_ENABLED: `"$NGINX_METRICS_ENABLED`"

  uwsgi-${instanceName}:
    restart: always

  celerybeat-${instanceName}:
    restart: always

  celeryworker-${instanceName}:
    restart: always

  postgres-${instanceName}:
    restart: always

  redis-${instanceName}:
    restart: always

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.override.yml"

    Write-Output "Showing the contents of the docker-compose.override.yml file"
    Get-Content -Path "docker-compose.override.yml"

    Write-Output "Starting Defect Dojo Application"

    Write-ActionLog "Starting containers..."
    # if OS is Linux, use sudo to start the containers
    if ($IsWindows) {
      Write-Output "Starting containers..."
      docker compose up -d
    }
    else {
      Write-Output "Starting containers..."
      sudo docker compose up -d
    }
    
    Write-Output "Waiting for containers to start..."
    # loop until the containers are up: especially django-defectdojo-${instanceName}-initializer-1 container
    # actually loop until the logs show "Admin password:"
    $maxRetries = 30
    $retryCount = 0
    $containerName = "django-defectdojo-${instanceName}-initializer-${instanceName}-1"
    $containerStatus = ""
    while ($retryCount -lt $maxRetries) {
      Write-Output "Checking if the container $containerName is up..."
      # check if the container is up
      if ($IsWindows) {
        $containerStatus = docker inspect -f '{{.State.Running}}' $containerName
      }
      else {
        $containerStatus = sudo docker inspect -f '{{.State.Running}}' $containerName
      }
      if ($containerStatus -eq "true") {
        Write-Output "Container $containerName is up."
        break
      }
      else {
        Write-Output "Container $containerName is not up. Retrying in 10 seconds..."
        Start-Sleep 10
        $retryCount++
      }
    }
    if ($retryCount -eq $maxRetries) {
      Write-Output "Container $containerName is not up after $maxRetries retries. Continuing..."
      Write-ActionLog "Container $containerName is not up after $maxRetries retries. Continuing..."
      # do not exit the script
      # exit
    }
    Write-Output "Container $containerName is up."
    # now loop until the logs show "Admin password:"
    $maxRetries = 30
    $retryCount = 0
    $logMessage = "Admin password:"
    $logFound = $false
    while ($retryCount -lt $maxRetries) {
      Write-Output "Checking if the logs show '$logMessage'..."
      # check if the logs show "Admin password:"
      if ($IsWindows) {
        $logFound = docker logs $containerName | Select-String -Pattern $logMessage
      }
      else {
        $logFound = sudo docker logs $containerName | Select-String -Pattern $logMessage
      }
      if ($logFound) {
        Write-Output "Logs show '$logMessage'."
        break
      }
      else {
        Write-Output "Logs do not show '$logMessage'. Retrying in 10 seconds..."
        Start-Sleep 10
        $retryCount++
      }
    }
    if ($retryCount -eq $maxRetries) {
      Write-Output "Container $containerName is not up after $maxRetries retries. Continuing..."
      Write-ActionLog "Container $containerName is not up after $maxRetries retries. Continuing..."
      # do not exit the script
      # exit
    }
    # get admin password
    Write-Output "Getting admin password..."
    Write-ActionLog "Getting admin password"
    if ($IsWindows) {
      Write-Output "Getting admin password..."
      #Check admin password
      docker compose logs "initializer-$instanceName" | Select-String -Pattern "Admin password:"
    }
    else {
      Write-Output "Getting admin password..."
      sudo docker compose logs "initializer-$instanceName" | Select-String -Pattern "Admin password:"
    }
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$IP_ADDRESS = "",
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
    # set the IP address if not provided
    if ($IP_ADDRESS -eq "") {
      $IP_ADDRESS = Get-MachineIpAddress
    }
    Write-Output "IP address: $IP_ADDRESS"

    # create folder if it does not exist
    if (-not (Test-Path -Path "${rootFolder}/dependency-track-${instanceName}")) {
      Write-Output "Creating folder ${rootFolder}/dependency-track-${instanceName} ..."
      New-Item -ItemType Directory -Path "${rootFolder}/dependency-track-${instanceName}"
    }
    Set-Location "${rootFolder}/dependency-track-${instanceName}"
    Write-ActionLog "Pulling latest images..."
    # if OS is Linux, use sudo to pull the images
    if ($IsWindows) {
      Write-Output "Pulling latest images..."
      docker pull dependencytrack/frontend
      docker pull dependencytrack/apiserver
    }
    else {
      Write-Output "Pulling latest images..."
      sudo docker pull dependencytrack/frontend
      sudo docker pull dependencytrack/apiserver
    }
    Write-ActionLog "Stopping containers..."
    # if OS is Linux, use sudo to stop the containers
    if ($IsWindows) {
      Write-Output "Stopping containers..."
      docker compose down
    }
    else {
      Write-Output "Stopping containers..."
      sudo docker compose down
    }
    Write-Output "Dependency-Track will be available at http://${IP_ADDRESS}:8082"

    @"
volumes:
  dependency-track-${instanceName}:

services:
  dtrack-apiserver-${instanceName}:
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
      - "dependency-track-${instanceName}:/data"
    restart: unless-stopped

  dtrack-frontend-${instanceName}:
    image: dependencytrack/frontend
    depends_on:
      - dtrack-apiserver-${instanceName}
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

    Write-ActionLog "Starting containers..."
    # if OS is Linux, use sudo to start the containers
    if ($IsWindows) {
      Write-Output "Starting containers..."
      docker compose up -d
    }
    else {
      Write-Output "Starting containers..."
      sudo docker compose up -d
    }
    Write-Output "Waiting for containers to start..."
    # loop until the containers are up #dependency-track-mcx-001-dtrack-frontend-mcx-001-1
    # actually loop until container dependency-track-${instanceName}-dtrack-frontend-${instanceName}-1 is up
    $maxRetries = 30
    $retryCount = 0
    $containerName = "dependency-track-${instanceName}-dtrack-frontend-${instanceName}-1"
    $containerStatus = ""
    while ($retryCount -lt $maxRetries) {
      Write-Output "Checking if the container $containerName is up..."
      # check if the container is up
      if ($IsWindows) {
        $containerStatus = docker inspect -f '{{.State.Running}}' $containerName
      }
      else {
        $containerStatus = sudo docker inspect -f '{{.State.Running}}' $containerName
      }
      if ($containerStatus -eq "true") {
        Write-Output "Container $containerName is up."
        break
      }
      else {
        Write-Output "Container $containerName is not up. Retrying in 10 seconds..."
        Start-Sleep 10
        $retryCount++
      }
    }
    if ($retryCount -eq $maxRetries) {
      Write-Output "Container $containerName is not up after $maxRetries retries. Continuing..."
      Write-ActionLog "Container $containerName is not up after $maxRetries retries. Continuing..."
      # do not exit the script
      # exit
    }
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
    [string]$external = "false",
    [string]$environmentPrefix = "#",
    [string]$networkPrefix = "#",
    [string]$portPrefix = "",
    [string]$SONARQUBE_VERSION = "$SONARQUBE_VERSION", # latest community version
    [string]$POSTGRES_VERSION = "$POSTGRES_VERSION", # for SonarQube
    [string]$VIRTUAL_HOST = "",
    [string]$VIRTUAL_PORT = "9000",
    [string]$LETSENCRYPT_HOST = ""
  )

  Write-Output "Updating SonarQube..."
  Write-ActionLog "Updating SonarQube"
  try {
    # create folder if it does not exist
    if (-not (Test-Path -Path "${rootFolder}/sonarqube-${instanceName}")) {
      Write-Output "Creating folder ${rootFolder}/sonarqube-${instanceName} ..."
      New-Item -ItemType Directory -Path "${rootFolder}/sonarqube-${instanceName}"
    }
    Set-Location "${rootFolder}/sonarqube-${instanceName}"
    Write-ActionLog "Pulling latest images..."
    # if OS is Linux, use sudo to pull the images
    if ($IsWindows) {
      Write-Output "Pulling latest images..."
      docker pull sonarqube:${SONARQUBE_VERSION}
      docker pull postgres:${POSTGRES_VERSION}
    }
    else {
      Write-Output "Pulling latest images..."
      sudo docker pull sonarqube:${SONARQUBE_VERSION}
      sudo docker pull postgres:${POSTGRES_VERSION}
    }
    Write-ActionLog "Stopping containers..."
    # if OS is Linux, use sudo to stop the containers
    if ($IsWindows) {
      Write-Output "Stopping containers..."
      docker compose down
    }
    else {
      Write-Output "Stopping containers..."
      sudo docker compose down
    }

    @"
services:
  sonarqube-${instanceName}:
    image: sonarqube:$SONARQUBE_VERSION
    restart: always
    depends_on:
      - sonar_db-${instanceName}
    environment:
      ${environmentPrefix}VIRTUAL_HOST: $VIRTUAL_HOST
      ${environmentPrefix}VIRTUAL_PORT: $VIRTUAL_PORT
      ${environmentPrefix}LETSENCRYPT_HOST: $LETSENCRYPT_HOST
      SONAR_JDBC_URL: jdbc:postgresql://sonar_db-${instanceName}:5432/sonar
      SONAR_JDBC_USERNAME: sonar
      SONAR_JDBC_PASSWORD: sonar
    ${portPrefix}ports:
    ${portPrefix}  - "9001:9000"
    volumes:
      - sonarqube_conf_${instanceName}:/opt/sonarqube/conf
      - sonarqube_data_${instanceName}:/opt/sonarqube/data
      - sonarqube_extensions_${instanceName}:/opt/sonarqube/extensions
      - sonarqube_logs_${instanceName}:/opt/sonarqube/logs
      - sonarqube_temp_${instanceName}:/opt/sonarqube/temp

  sonar_db-${instanceName}:
    image: postgres:$POSTGRES_VERSION
    restart: always
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: sonar
      POSTGRES_DB: sonar
    volumes:
      - sonar_db_${instanceName}:/var/lib/postgresql
      - sonar_db_data_${POSTGRES_VERSION}_${instanceName}:/var/lib/postgresql/data

volumes:
  sonarqube_conf_${instanceName}:
  sonarqube_data_${instanceName}:
  sonarqube_extensions_${instanceName}:
  sonarqube_logs_${instanceName}:
  sonarqube_temp_${instanceName}:
  sonar_db_${instanceName}:
  sonar_db_data_${POSTGRES_VERSION}_${instanceName}:

${networkPrefix}networks:
${networkPrefix}  default:
${networkPrefix}    name: $common_network_name
${networkPrefix}    external: $external
"@ | Out-File -FilePath "docker-compose.yaml"

    Write-Output "Showing the contents of the docker-compose.yaml file"
    Get-Content -Path "docker-compose.yaml"

    Write-Output "Starting SonarQube Community"

    Write-ActionLog "Starting containers..."
    # if OS is Linux, use sudo to start the containers
    if ($IsWindows) {
      Write-Output "Starting containers..."
      docker compose up -d
    }
    else {
      Write-Output "Starting containers..."
      sudo docker compose up -d
    }
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
    [string]$DEFAULT_EMAIL = ""
  )

  # for windows, you may need to run under WSL2

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
    Write-ActionLog "Creating external network $common_network_name"
    # Check if the network already exists
    # if OS is Linux, use sudo to check the network
    if ($IsWindows) {
      Write-Output "Checking if network $common_network_name exists..."
      $networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern "^$common_network_name$"
    }
    else {
      Write-Output "Checking if network $common_network_name exists..."
      $networkExists = sudo docker network ls --format '{{.Name}}' | Select-String -Pattern "^$common_network_name$"
    }
    if ($networkExists) {
      Write-Output "Network $common_network_name already exists."
      Write-ActionLog "Network $common_network_name already exists."
    }
    else {
      Write-ActionLog "Creating network $common_network_name"    
      # if OS is Linux, use sudo to create the network
      if ($IsWindows) {
        Write-Output "Creating network $common_network_name..."
        docker network create $common_network_name
      }
      else {
        Write-Output "Creating network $common_network_name..."
        # create the network with sudo      
        sudo docker network create $common_network_name
      }
    }

    # create folder if it does not exist
    if (-not (Test-Path -Path "${rootFolder}/proxy")) {
      Write-Output "Creating folder ${rootFolder}/proxy..."
      New-Item -ItemType Directory -Path "${rootFolder}/proxy"
    }
    Set-Location -Path $rootFolder
    Write-Output "Creating Nginx Proxy directory..."
    Write-ActionLog "Creating Nginx Proxy directory"
    if (Test-Path -Path "proxy") {
      Write-Output "Nginx Proxy directory already exists. Deleting..."
      Write-ActionLog "Nginx Proxy directory already exists. Deleting..."
      Set-Location -Path "proxy"
      Write-ActionLog "Stopping Nginx Proxy containers..."
      # if OS is Linux, use sudo to stop the containers
      if ($IsWindows) {
        Write-Output "Stopping Nginx Proxy containers..."
        docker compose down
      }
      else {
        Write-Output "Stopping Nginx Proxy containers..."
        sudo docker compose down
      }
      Set-Location -Path $rootFolder
      Write-Output "Removing Nginx Proxy directory..."
      Write-ActionLog "Removing Nginx Proxy directory..."
      Remove-Item -Path "proxy" -Recurse -Force
    }
    # check if the network already exists
    # if OS is Linux, use sudo to check the network
    if ($IsWindows) {
      Write-Output "Checking if network $common_network_name exists..."
      $networkExists = docker network ls --format '{{.Name}}' | Select-String -Pattern "^$common_network_name$"
    }
    else {
      Write-Output "Checking if network $common_network_name exists..."
      $networkExists = sudo docker network ls --format '{{.Name}}' | Select-String -Pattern "^$common_network_name$"
    }
    if ($networkExists) {
      Write-Output "Network $common_network_name already exists."
      Write-ActionLog "Network $common_network_name already exists."
    }
    else {
      Write-ActionLog "Creating network $common_network_name"    
      # if OS is Linux, use sudo to create the network
      if ($IsWindows) {
        Write-Output "Creating network $common_network_name..."
        docker network create $common_network_name
      }
      else {
        Write-Output "Creating network $common_network_name..."
        # create the network with sudo      
        sudo docker network create $common_network_name
      }
    }
    New-Item -ItemType Directory -Path "proxy"
    Set-Location -Path "proxy"

    $proxyConfContent = @"
client_max_body_size 800m;
"@
    $proxyConfContent | Out-File -FilePath "proxy.conf"
    # create folder $etcNginxFolder if it does not exist
    # set the path according to the OS
    if ($IsWindows) {
      $etcNginxFolder = "C:/etc/nginx"
    }
    else {
      $etcNginxFolder = "/etc/nginx"
    }
    if (-not (Test-Path -Path $etcNginxFolder)) {
      Write-Output "Creating $etcNginxFolder directory..."
      Write-ActionLog "Creating $etcNginxFolder directory..."
      # create the directory with sudo
      if ($IsWindows) {
        Write-Output "Creating $etcNginxFolder directory..."
        mkdir -p $etcNginxFolder
      }
      else {
        Write-Output "Creating $etcNginxFolder directory..."
        Write-ActionLog "Creating $etcNginxFolder directory..."      
        sudo mkdir -p $etcNginxFolder
      }
    }
    #Copy-Item -Path "proxy.conf" -Destination "/etc/nginx/proxy.conf" -Force
    # copy according to the OS
    if ($IsWindows) {
      Write-Output "Copying proxy.conf to $etcNginxFolder..."
      Write-ActionLog "Copying proxy.conf to $etcNginxFolder..."
      Copy-Item -Path "proxy.conf" -Destination "$etcNginxFolder/proxy.conf" -Force
    }
    else {
      Write-Output "Copying proxy.conf to $etcNginxFolder..."
      Write-ActionLog "Copying proxy.conf to $etcNginxFolder..."      
      sudo cp -f proxy.conf $etcNginxFolder/proxy.conf
    }

    # set docker socket path according to the OS
    if ($IsWindows) {
      $dockerSocketPath = "//var/run/docker.sock"
    }
    else {
      $dockerSocketPath = "/var/run/docker.sock"
    }

    $dockerComposeContent = @"
services:
  nginx-proxy:
    image: jwilder/nginx-proxy
    container_name: nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ${dockerSocketPath}:/tmp/docker.sock:ro
      - letsencrypt-certs:/etc/nginx/certs
      - letsencrypt-vhost-d:/etc/nginx/vhost.d
      - letsencrypt-html:/usr/share/nginx/html
      - $etcNginxFolder/proxy.conf:/etc/nginx/conf.d/my_proxy.conf:ro
    restart: always
  letsencrypt-proxy:
    image: jrcs/letsencrypt-nginx-proxy-companion
    container_name: letsencrypt-proxy
    volumes:
      - ${dockerSocketPath}:/var/run/docker.sock:ro
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

    Write-ActionLog "Starting Nginx Proxy"
    # if OS is Linux, use sudo to start the containers
    if ($IsWindows) {
      Write-Output "Starting Nginx Proxy..."
      docker compose up -d
    }
    else {
      Write-Output "Starting Nginx Proxy..." 
      sudo docker compose up -d
    }

    # Get first IP address from the list of network interfaces
    # set IP_ADDRESS according to the OS
    $IP_ADDRESS = Get-MachineIpAddress
    Write-Output "IP Address: $IP_ADDRESS"
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder
  )

  Write-Output "Configuring DevOps Shield One VM..."
  Write-ActionLog "Configuring DevOps Shield One VM"
  try {
    # set hostname according to the OS
    $hostname = $(hostname)
    Write-Output "Hostname: $hostname"
    Write-ActionLog "Hostname: $hostname"

    # Get the first IP address from the list of network interfaces
    # set IP_ADDRESS according to the OS
    $IP_ADDRESS = Get-MachineIpAddress
    Write-Output "IP Address: $IP_ADDRESS"
    Write-ActionLog "IP Address: $IP_ADDRESS"

    # set pretty hostname according to the OS
    if ($IsWindows) {
      $prettyHostname = $(hostname)
    }
    else {
      $prettyHostname = $(hostnamectl --pretty)
    }


    # Obtain configuration details from the user
    $configData = @{
      Hostname                       = $hostname
      PrettyHostname                 = $prettyHostname
      IPAddress                      = $IP_ADDRESS
      DefaultEmail                   = Read-Host "Enter your email address for Let's Encrypt"
      ExternalIP                     = (Invoke-WebRequest -uri "http://ifconfig.me/ip").Content.Trim()
      DefectDojoDNSName              = Read-Host "Enter the DNS name for Defect Dojo"
      DependencyTrackBackendDNSName  = Read-Host "Enter the DNS name for Dependency Track Backend"
      DependencyTrackFrontendDNSName = Read-Host "Enter the DNS name for Dependency Track Frontend"
      SonarQubeDNSName               = Read-Host "Enter the DNS name for SonarQube"
      DevOpsShieldDNSName            = Read-Host "Enter the DNS name for DevOps Shield"      
      DNSNameServer                  = Read-Host "Enter the DNS name server (default: <NONE>)" -Default "<NONE>"
      Tested                         = $false
      TestedTimestamp                = ""
      TestResult                     = ""
    }

    # Format JSON nicely
    $jsonConfigData = $configData | ConvertTo-Json -Depth 4
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json"
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
    [Parameter(Mandatory = $true)]
    [string]$dnsName,

    [Parameter(Mandatory = $false)]
    [string]$dnsServer = "<NONE>",

    [Parameter(Mandatory = $false)]
    [int]$maximumNumberOfIterations = 10
  )

  try {
    # Initialize variables
    $resolvedIPs = @()
    $resolvedIP6s = @()
    $currentName = $dnsName
    $currentIteration = 0

    # Loop until an IP address is found or the maximum number of iterations is reached
    do {
      Write-Output "Resolving DNS name: $currentName"
      Write-ActionLog "Resolving DNS name: $currentName"

      # Perform DNS lookup using Resolve-DnsNameCrossPlatform for Linux
      # or Resolve-DnsName for Windows      
      if ($dnsServer -eq "<NONE>" -or [string]::IsNullOrEmpty($dnsServer)) {
        Write-Output "Using default DNS server."
        if ($IsWindows) {
          Write-Output "Using Resolve-DnsName for Windows."
          $dnsLookupResult = Resolve-DnsName -Name $currentName -ErrorAction SilentlyContinue
        }
        else {
          Write-Output "Using Resolve-DnsNameCrossPlatform for Linux."
          $dnsLookupResult = Resolve-DnsNameCrossPlatform -Name $currentName -ErrorAction SilentlyContinue
        }
      }
      else {
        Write-Output "Using DNS server: $dnsServer"
        if ($IsWindows) {
          Write-Output "Using Resolve-DnsName for Windows."
          $dnsLookupResult = Resolve-DnsName -Name $currentName -Server $dnsServer -ErrorAction SilentlyContinue
        }
        else {
          Write-Output "Using Resolve-DnsNameCrossPlatform for Linux."
          $dnsLookupResult = Resolve-DnsNameCrossPlatform -Name $currentName -Server $dnsServer -ErrorAction SilentlyContinue
        }
      }

      # Process DNS lookup results
      # give count of results
      #Write-Output "Number of results: $($dnsLookupResult.Count)"
      foreach ($result in $dnsLookupResult) {
        # if OS is Linux
        if ($IsLinux) {
          # Check if the result is an IP address
          Write-Output $result
          if ($result.IPAddress -and $result.IPAddress -notin $resolvedIPs) {
            $resolvedIPs += $result.IPAddress
            Write-Output "Resolved IP address: $($result.IPAddress)"

            # Check if the result is an IP address
            if ($result.IPAddress -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
              Write-Output "Found IP address: $($result.IPAddress)"
              return $result.IPAddress
            }
            else {
              $currentName = $result.IPAddress
              Write-Output "Found DNS name: $($result.IPAddress)"
              break
            }
          }
        }
        else {
          # OS is Windows
          # Check if the result is an IP address
          Write-Output $result
          # check if Type is CNAME
          if ($result.Type -eq "CNAME") {
            Write-Output "Found CNAME: $($result.NameHost)"
            $currentName = $result.NameHost
            Write-Output "Current name: $currentName"
            #break
          }
          # check if Type is A
          if ($result.Type -eq "A") {
            Write-Output "Found A record: $($result.Name)"
            $currentName = $result.Name
            Write-Output "Current name: $currentName"
            # get the IP address from the result
            $ipAddress = $result.IP4Address
            Write-Output "Found IP address: $($result.IPAddress)"            
            if ($ipAddress -and $ipAddress -notin $resolvedIPs) {
              $resolvedIPs += $ipAddress
              Write-Output "Resolved IP address: $ipAddress"
            }
            return $ipAddress
          }
          # check if Type is AAAA
          if ($result.Type -eq "AAAA") {
            Write-Output "Found AAAA record: $($result.Name)"
            $currentName = $result.Name
            Write-Output "Current name: $currentName"
            # get the IP address from the result
            $ipAddress = $result.IP6Address
            Write-Output "Found IP address: $($result.IPAddress)"
            #return $ipAddress
            if ($ipAddress -and $ipAddress -notin $resolvedIP6s) {
              $resolvedIP6s += $ipAddress
              Write-Output "Resolved IP6 address: $ipAddress"
            }
          }
        }
      }    

      # Increment iteration count
      $currentIteration++
      Write-Output "Current iteration: $currentIteration"

      # Check if maximum number of iterations is reached
      if ($currentIteration -ge $maximumNumberOfIterations) {
        Write-Output "Reached maximum number of iterations: $maximumNumberOfIterations"
        break
      }
    } while ($currentName)

    # If no IP address is found
    Write-Output "No IP address found for DNS name: $dnsName"
    Write-Output "Resolved IP addresses: $resolvedIPs"
    Write-Output "Resolved IP6 addresses: $resolvedIP6s"
    return $null
  }
  catch {
    Write-Error "Error getting IP address for ${dnsName}: $_"
    Write-ActionLog "Error getting IP address for ${dnsName}: $_"
    return $null
  }
}

function Test-VMConfiguration {
  param (
    [Parameter(Mandatory = $true)]
    [string]$rootFolder
  )

  Write-Output "Testing VM Configuration..."
  Write-ActionLog "Testing VM Configuration"
  try {
    # Load the configuration file
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json"

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
        # Check if DNS name is empty or == <NONE>
        if ($dnsName -eq "" -or $dnsName -eq "<NONE>") {
          Write-Output "DNS name is empty or <NONE>."
          $ipAddress = Get-IpAddress -dnsName $dnsName
        }
        else {
          $ipAddress = Get-IpAddress -dnsName $dnsName -dnsServer $dnsServer
        }
        if ($null -eq $ipAddress) {
          Write-Error "DNS name $dnsName does not resolve to an IP address."
          throw "DNS name $dnsName does not resolve to an IP address."
        }

        Write-Output "DNS name: $dnsName resolves to IP address: $ipAddress"
        if ($ipAddress -eq $configData.ExternalIP) {
          Write-Host "DNS name $dnsName resolves to the correct External IP address ($($configData.ExternalIP)): $ipAddress" -ForegroundColor Green
        }
        else {
          Write-Host "DNS name $dnsName does not resolve to the correct External IP address ($($configData.ExternalIP)): $ipAddress" -ForegroundColor Red
          throw "DNS name $dnsName does not resolve to the correct External IP address ($($configData.ExternalIP)): $ipAddress"
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
    [Parameter(Mandatory = $true)]
    [string]$rootFolder,
    [Parameter(Mandatory = $true)]
    [string]$common_network_name,
    [string]$external = "true",
    [bool]$doNginxProxy = $true,
    [bool]$doDevOpsShield = $true,
    [bool]$doDefectDojo = $true,
    [bool]$doDependencyTrack = $true,
    [bool]$doSonarQube = $true,
    [bool]$doFirewallTest = $true,
    [string]$hostname = ""
  )

  # set the hostname if not provided
  if ($hostname -eq "") {
    Write-Output "Hostname not provided. Using the current hostname."
    Write-ActionLog "Hostname not provided. Using the current hostname."
    $hostname = $(hostname)
    Write-Output "Hostname: $hostname"
    Write-ActionLog "Hostname: $hostname"
  }

  Write-Output "Updating all applications to Nginx Proxy..."
  Write-ActionLog "Updating all applications to Nginx Proxy"
  try {
    # Call the update functions for each application  
    
    # first ensure that config file is created and has been tested with status true
    $configFilePath = "$rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json"
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
    if ($doNginxProxy) {
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
    }
    else {
      Write-Output "Skipping Nginx Proxy installation..."
      Write-ActionLog "Skipping Nginx Proxy installation..."
    }

    # Update-DevOpsShieldApp
    if ($doDevOpsShield) {
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
        -LETSENCRYPT_HOST $configData.DevOpsShieldDNSName `
        -devopsShieldImage $devopsShieldImage

      # can delete default network if it exists
      # check if the network exists
      Remove-DockerNetwork -networkName "devops-shield-${instanceName}_default"

      # press enter to continue
      Read-Host "Press Enter to continue..."
    }
    else {
      Write-Output "Skipping DevOps Shield Application update..."
      Write-ActionLog "Skipping DevOps Shield Application update..."
    }

    # Update-DefectDojoApp
    if ($doDefectDojo) {
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
    }
    else {
      Write-Output "Skipping Defect Dojo Application update..."
      Write-ActionLog "Skipping Defect Dojo Application update..."
    }

    # Update-DependencyTrackApp
    if ($doDependencyTrack) {
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

      # can delete default network if it exists
      # check if the network exists
      Remove-DockerNetwork -networkName "dependency-track-${instanceName}_default"  

      # press enter to continue
      Read-Host "Press Enter to continue..."
    }
    else {
      Write-Output "Skipping Dependency Track Application update..."
      Write-ActionLog "Skipping Dependency Track Application update..."
    }

    # Update-SonarQubeCommunity
    if ($doSonarQube) {
      Write-Output "Updating SonarQube Community..."
      Write-ActionLog "Updating SonarQube Community"

      Write-Output "With the following parameters:"
      Write-Output "rootFolder: $rootFolder"
      Write-Output "common_network_name: $common_network_name"
      Write-Output "VIRTUAL_HOST: $($configData.SonarQubeDNSName)"
      Write-Output "VIRTUAL_PORT: 9000"
      Write-Output "LETSENCRYPT_HOST: $($configData.SonarQubeDNSName)"
      Write-Output "SONARQUBE_VERSION: $SONARQUBE_VERSION"
      Write-Output "POSTGRES_VERSION: $POSTGRES_VERSION"

      Update-SonarQubeCommunity -rootFolder $rootFolder `
        -common_network_name $common_network_name `
        -external "true" `
        -environmentPrefix "" `
        -networkPrefix "" `
        -portPrefix "#" `
        -SONARQUBE_VERSION "$SONARQUBE_VERSION" `
        -POSTGRES_VERSION "$POSTGRES_VERSION" `
        -VIRTUAL_HOST $configData.SonarQubeDNSName `
        -VIRTUAL_PORT "9000" `
        -LETSENCRYPT_HOST $configData.SonarQubeDNSName

      # can delete default network if it exists
      # check if the network exists
      Remove-DockerNetwork -networkName "sonarqube-${instanceName}_default"

      # press enter to continue
      Read-Host "Press Enter to continue..."
    }
    else {
      Write-Output "Skipping SonarQube Community update..."
      Write-ActionLog "Skipping SonarQube Community update..."
    }

    if ($doFirewallTest) {
      Write-Output "Testing firewall rules..."
      Write-ActionLog "Testing firewall rules..."
      # Test the firewall rules
      Write-Output "From another machine, test the port 80 and 443 connectivity to the hostname $hostname"
      Write-Output "Test the port 80 and 443 connectivity to the hostname $hostname"
      Write-ActionLog "Test the port 80 and 443 connectivity to the hostname $hostname"
      # Test the firewall rules
      # check if the OS is Linux or Windows
      if ($IsWindows) {
        Write-Output "Testing firewall rules on Windows..."
        Write-ActionLog "Testing firewall rules on Windows..."
        # Test the firewall rules
        Test-NetConnection -ComputerName $hostname -Port 80
        Test-NetConnection -ComputerName $hostname -Port 443
      }
      else {
        Write-Output "Testing firewall rules on Linux..."
        Write-ActionLog "Testing firewall rules on Linux..."
        # Test the firewall rules
        # need to set the firewall rules for Linux manually
        # sudo ufw allow 80/tcp
        # sudo ufw allow 443/tcp
      }
      Write-Output "Firewall test completed."
      Write-ActionLog "Firewall test completed"
      # create a firewall rule to allow port 80 and 443
      Write-Output "Creating firewall rules to allow port 80 and 443..."
      Write-ActionLog "Creating firewall rules to allow port 80 and 443..."
      # check if the OS is Linux or Windows
      if ($IsWindows) {
        # check if the firewall is enabled
        $firewallEnabled = Get-NetFirewallProfile | Where-Object { $_.Enabled -eq "True" }
        if ($firewallEnabled) {
          Write-Output "Firewall is enabled."
          Write-ActionLog "Firewall is enabled."
        }
        else {
          Write-Output "Firewall is not enabled. Enabling firewall..."
          Write-ActionLog "Firewall is not enabled. Enabling firewall..."
          Set-NetFirewallProfile -Enabled True
        }
        Write-Output "Creating firewall rules to allow port 80 and 443..."
        Write-ActionLog "Creating firewall rules to allow port 80 and 443..."
        # check if the firewall rules already exist
        $devopsShieldHttpFirewallRuleName = "DevOps Shield - Allow HTTP"
        $devopsShieldHttpsFirewallRuleName = "DevOps Shield - Allow HTTPS"
        $firewallRuleExists = Get-NetFirewallRule | `
          Where-Object { $_.DisplayName -eq $devopsShieldHttpFirewallRuleName -or $_.DisplayName -eq $devopsShieldHttpsFirewallRuleName }
        if ($firewallRuleExists) {
          Write-Output "Firewall rules already exist."
          Write-ActionLog "Firewall rules already exist."
        }
        else {
          Write-Output "Creating firewall rules..."
          Write-ActionLog "Creating firewall rules..."        
          # create firewall rules for Windows
          New-NetFirewallRule -DisplayName $devopsShieldHttpFirewallRuleName -Direction Inbound -Protocol TCP -LocalPort 80 -Action Allow
          New-NetFirewallRule -DisplayName $devopsShieldHttpsFirewallRuleName -Direction Inbound -Protocol TCP -LocalPort 443 -Action Allow
        }
      }
      else {
        # need to set the firewall rules for Linux manually
        Write-Output "Please set the firewall rules for Linux manually."
        Write-ActionLog "Please set the firewall rules for Linux manually."
        # # create firewall rules for Linux
        # sudo ufw allow 80/tcp
        # sudo ufw allow 443/tcp
      }
    }
    else {
      Write-Output "Skipping firewall test..."
      Write-ActionLog "Skipping firewall test..."
    }

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
  Write-Output " 3. Install or Update DevOps Shield Application"
  Write-Output " 4. Install or Update Defect Dojo Application"
  Write-Output " 5. Install or Update Dependency Track Application"
  Write-Output " 6. Install or Update SonarQube Community"
  Write-Output " 7. Install or Update Nginx Proxy"
  Write-Output " 8. Configure the DevOps Shield One VM"
  Write-Output " 9. Test VM Configuration"
  Write-Output "10. Update All Applications to Nginx Proxy"
  Write-Output "11. Exit"
  Write-Output "-----------------------------------"
}

############# Main Script Execution #############

$sysInfo = Get-SystemInfo
$sysInfo

$allOutput = Initialize-Script

# initializedValues is a hashtable - last element in the array
$initializedValues = $allOutput[-1]

$rootFolder = $($initializedValues.rootFolder)
$common_network_name = $($initializedValues.common_network_name)
$instanceName = $($initializedValues.instanceName)
$logFile = $($initializedValues.logFile)
$devopsShieldImage = $($initializedValues.devopsShieldImage)
$SONARQUBE_VERSION = $($initializedValues.SONARQUBE_VERSION)
$POSTGRES_VERSION = $($initializedValues.POSTGRES_VERSION)
$initialLocation = $($initializedValues.initialLocation)
$unusedPortHttp = $($initializedValues.unusedPortHttp)
$unusedPortHttps = $($initializedValues.unusedPortHttps)

Write-Output "DevOps Shield One VM Script"
Write-Output "-----------------------------------"
Write-Output "Root Folder: $rootFolder"
Write-Output "Common Network Name: $common_network_name"
Write-Output "Instance Name: $instanceName" 
Write-Output "Log File: $logFile"
Write-Output "DevOps Shield Image: $devopsShieldImage"
Write-Output "SonarQube Version: $SONARQUBE_VERSION"
Write-Output "Postgres Version: $POSTGRES_VERSION"
Write-Output "Initial Location: $initialLocation"
Write-Output "Unused Port HTTP: $unusedPortHttp"
Write-Output "Unused Port HTTPS: $unusedPortHttps"
Write-Output "-----------------------------------"

Install-RequiredModules

while ($true) {
  Show-Menu
  $choice = Read-Host "Enter your choice (0-11)"
  switch ($choice) {
    0 {
      Write-Output "Running docker without sudo..."
      Write-ActionLog "Running docker without sudo"
      # only for Linux
      if ($IsWindows) {
        Write-Output "This option is only available for Linux."
        Write-ActionLog "This option is only available for Linux."
        break
      }
      # Add the current user to the docker group
      Write-Output "Adding user ${env:USER} to the docker group..."
      Write-ActionLog "Adding user ${env:USER} to the docker group"
      Write-Output "COMMAND: sudo usermod -aG docker ${env:USER}"
      sudo usermod -aG docker ${env:USER}
      Write-Warning "You need to log out and log back in for the changes to take effect."
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
        Update-DevOpsShieldApp -rootFolder $rootFolder `
          -common_network_name $common_network_name
      }
    }
    4 {
      if (Read-Host "Are you sure you want to update the Defect Dojo Application? (y/n)" -eq 'y') {
        Update-DefectDojoApp -rootFolder $rootFolder `
          -common_network_name $common_network_name `
          -DD_PORT $unusedPortHttp `
          -DD_TLS_PORT $unusedPortHttps
      }
    }
    5 {
      if (Read-Host "Are you sure you want to update the Dependency Track Application? (y/n)" -eq 'y') {
        Update-DependencyTrackApp -rootFolder $rootFolder `
          -common_network_name $common_network_name
      }
    }
    6 {
      if (Read-Host "Are you sure you want to update SonarQube? (y/n)" -eq 'y') {
        Update-SonarQubeCommunity -rootFolder $rootFolder `
          -common_network_name $common_network_name `
          -SONARQUBE_VERSION "$SONARQUBE_VERSION" `
          -POSTGRES_VERSION "$POSTGRES_VERSION"
      }
    }
    7 {
      if (Read-Host "Are you sure you want to install Nginx Proxy? (y/n)" -eq 'y') {
        Install-NginxProxy -rootFolder $rootFolder `
          -common_network_name $common_network_name
      }
    }
    8 {
      if (Read-Host "Are you sure you want to configure the DevOps Shield One VM? (y/n)" -eq 'y') {
        Set-DevOpsShieldOneVm -rootFolder $rootFolder
      }
    }
    9 {
      if (Read-Host "Are you sure you want to test the VM configuration? (y/n)" -eq 'y') {
        Test-VMConfiguration -rootFolder $rootFolder
      }
    }
    10 {
      if (Read-Host "Are you sure you want to update all applications to Nginx Proxy? (y/n)" -eq 'y') {
        Update-AllAppsToNginxProxy -rootFolder $rootFolder `
          -common_network_name $common_network_name
      }
    }
    11 {
      Write-Output "Exiting..."
      Write-ActionLog "Script exited by user"
      Write-Output "Log file can be found at $logFile"
      Write-Output "Type 'cat $logFile' to see the actions taken"
      Write-Output "You can view th VM configuration file at $rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json"
      # Show the contents of the configuration file
      Write-Output "Configuration file contents:"
      # check if it exists
      if (Test-Path -Path "$rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json") {
        Get-Content -Path "$rootFolder/DevOpsShieldOneVM_Config_${instanceName}.json"
      }
      else {
        Write-Output "Configuration file not found."
      }
      Write-Output "Please check the log file for details."

      # Show docker volumes  
      # if OS is Linux, use sudo to show the containers      
      Write-ActionLog "Docker containers"   
      if ($IsWindows) {
        Write-Output "Docker containers:"
        docker ps -a
      }
      else {
        Write-Output "Docker containers:"     
        # show the containers with sudo
        sudo docker ps -a
      }
      # if OS is Linux, use sudo to show the volumes      
      Write-ActionLog "Docker volumes"   
      if ($IsWindows) {
        Write-Output "Docker volumes:"
        docker volume ls
      }
      else {
        Write-Output "Docker volumes:"     
        # show the volumes with sudo  
        sudo docker volume ls
      }
      # if OS is Linux, use sudo to show the networks      
      Write-ActionLog "Docker networks"      
      if ($IsWindows) {
        Write-Output "Docker networks:"
        docker network ls
      }
      else {
        Write-Output "Docker networks:"  
        # show the networks with sudo  
        sudo docker network ls
      }
      # Write-Output "Docker images:"
      # sudo docker images
      # Write-Output "Docker system prune:"
      # sudo docker system prune -a -f
      # Write-Output "Docker system df:"
      # sudo docker system df
      # Write-Output "Docker system info:"
      # sudo docker system info

      # go back to initial directory
      Write-Output "Going back to initial directory $initialLocation ..."
      Set-Location -Path $initialLocation

      Write-Output "Exiting script."
      exit 0
    }
    default {
      Write-Output "Invalid choice. Please select a valid option."
    }
  }
}
