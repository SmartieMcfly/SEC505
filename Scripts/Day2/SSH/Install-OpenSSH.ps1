########################################################
#.SYNOPSIS
#  Installs OpenSSH service from a GitHub release.
#
#.DESCRIPTION
#  This script installs the OpenSSH server using a
#  release from GitHub.  This is *not* how OpenSSH is 
#  installed when using Add-WindowsCapability. Get
#  the latest release zip and extract it into a folder
#  named \OpenSSH-Win64 somewhere:
#
#     https://github.com/PowerShell/Win32-OpenSSH/releases
#
#.PARAMETER SourceFiles
#  Path to the folder which contains the GitHub files for
#  installing OpenSSH.  This folder will probably be 
#  named "OpenSSH-Win64" and must have sshd.exe inside it.
#
#.NOTES
#  This script deletes any existing OpenSSH service files
#  located in $env:ProgramFiles\OpenSSH, but it does not
#  delete any settings files from $env:ProgramData\ssh.
#
#  This script removes C:\Windows\System32\OpenSSH from
#  the PATH environment variable for both the machine and
#  the user, then appends $env:ProgramFiles\OpenSSH.  This
#  is required with OpenSSH for Windows version 7.7.1.0p1
#  and later when a default shell is set for OpenSSH, which
#  is something we do in SEC505.  
#
#  Last Updated: 18.Dec.2023
########################################################

Param ($SourceFiles = "C:\SANS\Tools\OpenSSH\OpenSSH-Win64") 

# Note the current directory in order to return to it later:
$CurrentDir = $PWD


# Confirm the presence of sshd.exe:
if (-not (Test-Path -Path "$SourceFiles\sshd.exe"))
{ 
    "Could not find sshd.exe in $SourceFiles"
    Exit
} 


# Stop the sshd and ssh-agent services, if they exist:
Stop-Service -Name sshd -ErrorAction SilentlyContinue
Stop-Service -Name ssh-agent -ErrorAction SilentlyContinue
#Start-Sleep -Seconds 1


# Delete inbound firewall allow rules named like *OpenSSH*, if any:
Get-NetFirewallRule -Name "*OpenSSH*" |
Where { ($_.Direction -eq 'Inbound') -and ($_.Action -eq 'Allow') } |
Remove-NetFirewallRule 


# Delete the C:\Program Files\OpenSSH folder, if it exists:
Remove-Item -Path "$env:ProgramFiles\OpenSSH\" -Recurse -Force -ErrorAction SilentlyContinue


# Create a new, empty C:\Program Files\OpenSSH folder:
New-Item -Path "$env:ProgramFiles\OpenSSH\" -ItemType Directory -Force | Out-Null 


# Copy the OpenSSH binaries into this folder:
Copy-Item -Path "$SourceFiles\*" -Destination "$env:ProgramFiles\OpenSSH\" -Force -Recurse


# Ensure files are not read-only, especially openssh-events.man:
dir -File -Path $env:ProgramFiles\OpenSSH\ | ForEach { $_.IsReadOnly = $False } 


# Move into the $env:ProgramFiles\OpenSSH folder to run the official installer script:
cd $env:ProgramFiles\OpenSSH\

if ($PWD.Path -notlike "*Files\OpenSSH")
{ 
    "Not in the $env:ProgramFiles\OpenSSH folder!"
    Exit 
} 


# Run the official OpenSSH installer script:
.\Install-SSHD.ps1


# Create a new inbound firewall rule to allow TCP/22 for SSH traffic:
New-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -DisplayName 'OpenSSH SSH Server (sshd)' -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null




# Change PATH environment variable for MACHINE;
# This must be done before the sshd service is started:
$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine") -split ';' | Where { $_ -notlike "*OpenSSH*" } 
$MachinePath += "$env:ProgramFiles\OpenSSH"
$MachinePath = $MachinePath -join ';'
[Environment]::SetEnvironmentVariable("Path", $MachinePath, "Machine")



# Change PATH environment variable for USER:
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User") -split ';' | Where { $_ -notlike "*OpenSSH*" } 
$UserPath += "$env:ProgramFiles\OpenSSH"
$UserPath = $UserPath -join ';'
$UserPath = $UserPath -replace ';;',';'
[Environment]::SetEnvironmentVariable("Path", $UserPath, "User")

# Update the $env:Path variable for this posh session too:
$env:Path = $env:Path + ";" + $UserPath



# Start the OpenSSH Agent (ssh-agent) service first, before sshd:
Start-Service -Name ssh-agent


# Start the OpenSSH Server (sshd) service, which also creates the $env:ProgramData\ssh files:
Start-Service -Name sshd


# Configure the OpenSSH Server service to start automatically:
Set-Service -Name sshd -StartupType Automatic 


# Configure OpenSSH Agent service to start automatically:
Set-Service -Name ssh-agent -StartupType Automatic 


# Return to previous directory:
cd $CurrentDir



