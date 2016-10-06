# MATLAB automatic installation script
# author: Zahradník (radek.zahradnik@msn.com)
# Date: 2016-08-08
# Version: 1.0
# Purpose: This script performs a silent installation of MATLAB (R2016a).
#####################################################
### PATHs
#####################################################
$log_path ='C:\Matlab_instalace' # the path for folder for logs
$path_backup_settings = "$PSScriptRoot\Backup_settings" # the location of setting to copy them into a new installation
$install_input = 'installer_input.txt'  # the file name with an installation instruction
$input_activation = 'activate.ini'  # the file name with activation information for silent activation
$installation_log = 'installation_log.txt'  # the name of log file for current installation
$uninstall_previous_version = 'Yes' # Yes/No (or otherwise) Yes if the you wish to UNINSTALL previous version of MATLAB
$prefs = true # true/false = the preferences from old MATLABs WILL/WILL NOT be removed
$path_license_files = "$PSScriptRoot\License" # for coping a license file(s) where should be placed.
$license_name = 'license_standalone.lic'
#####################################################


#####################################################
# REQUEST for ADMIN RIGHTS
#####################################################
if (!([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) { Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs; exit }
#####################################################


#####################################################
### TEST for x64 or x86 ARCHITECTURE
#####################################################
if ( ([IntPtr]::size -eq 8) -and (Test-Path "$PSScriptRoot\64bit"))
{
  # x64
  $os_type = '64bit'
  $path_install = 'C:\Program Files\MATLAB'
}
else
{
  # x86
  $os_type = '32bit'
  $path_install = 'C:\Program Files (x86)\MATLAB'
}
Write-Output "Running $os_type install."
#####################################################


#####################################################
### TEST for MATLAB version 
# R2015a = 15.0.0.0, R2015b = 15.1.0.0 R2016a = 16.0.0.0
#####################################################
if (Test-Path "$PSScriptRoot\$os_type\Setup.exe")
{
  # Reading of release info
  $version = (Get-ChildItem "$PSScriptRoot\$os_type\Setup.exe").VersionInfo.FileVersion
  $year = $version.Substring(0,2)
  $release = $version.Substring(4,1)

  if ($release -eq '0')
  {
    # R2xxxA version
    $path_install = "$path_install\R20$year" + 'a'
  }
  else
  {
    # R2xxxB version
    $path_install = "$path_install\R20$year" + 'b'
  }
}
else
{
  # Missing Setup.exe
  throw "Missing Setup.exe in $path_install"
}
Write-Output "Installation path: $path_install"
#####################################################


#####################################################
# Test for instruction file
#####################################################
if (Test-Path "$PSScriptRoot\$os_type\$install_input")
{
  # File is present, so inject the log path
  Get-Content "$PSScriptRoot\$os_type\$install_input" | Foreach-Object {$_ -replace '^outputFile=.+$', "outputFile=$log_path\$installation_log"; $_}
}
else
{
  # Missing instruction file
  throw "Missing instruction file: $PSScriptRoot\$os_type\$install_input"
}
Write-Output "The file: $PSScriptRoot\$os_type\$install_input has been checked."
#####################################################


#####################################################
# Test for activation file
#####################################################
if (Test-Path "$PSScriptRoot\$os_type\$input_activation")
{
  # File is present, so inject the lisence path
  Get-Content "$PSScriptRoot\$os_type\$input_activation" | Foreach-Object {$_ -replace '^licenseFile=.+$', "licenseFile=$path_license_files\$license_name"; $_}
}
else
{
  # Missing instruction file
  throw "Missing instruction file: $PSScriptRoot\$os_type\$install_input"
}
Write-Output "The instruction file: $PSScriptRoot\$os_type\$install_input has been checked."
#####################################################


#####################################################
# Test for previous installation of MATLAB
#####################################################
if (Test-Path 'HKLM:\SOFTWARE\MathWorks\MATLAB')
{
  # MATLAB is present
  if ($uninstall_previous_version -eq 'Yes')
  {
    # We want to uninstall previous MATLAB
    $MATLABs = Get-ChildItem 'HKLM:\SOFTWARE\MathWorks\MATLAB'   # Read all installations from registry.
    foreach ($item in $MATLABs)
    {
      $path_old_MATLAB = Get-ItemProperty $item.PSPath | Foreach-Object {$_.MATLABROOT} # the installation path for uninstall.
      # Prepare the uninstall file for a silent run.
      Get-Content "$path_old_MATLAB\uninstall\uninstaller_input.txt" | Foreach-Object {$_ -replace '^outputFile=.+$', "outputFile=$log_path\uninstall_log_$path_old_MATLAB.Substring($path_old_MATLAB.Length-6,6).txt"; $_}
      Get-Content "$path_old_MATLAB\uninstall\uninstaller_input.txt" | Foreach-Object {$_ -replace '^mode=.+$', 'outputFile=silent'; $_}
      Get-Content "$path_old_MATLAB\uninstall\uninstaller_input.txt" | Foreach-Object {$_ -replace '^prefs=.+$', "prefs=$prefs"; $_}
      &"$path_old_MATLAB\uninstall\bin\win64\uninstall.exe" -inputFile "$path_old_MATLAB\uninstall\uninstaller_input.txt" # This will fail on 32bit installation, it isn't in win64 folder.
      Write-Output 'The uninstallation of previous MATLAB version(s) has been completed.'
    }    
  }
  else
  {
    # User whish to keep previous MATLAB installation
    Write-Output 'The uninstallation of previous MATLAB version(s) has been skipped by user.'
  }  
}
else
{
  # Missing instruction file
  Write-Output 'No previous MATLAB version(s) has been found.'
}
#####################################################


#####################################################
#### 64bit (Primary installation)
# The creation of a new directory for MATLAB installation
#####################################################
try
{
  # If the path for a new MATLAB installation already exist
  if (Test-Path $path_install)
  {
    # Report this event to output
    Write-Output "The path $path_install is not empty. Removing the files from the path."
    Remove-Item -Path "$path_install\*" -Recurse 
  }
  else
  {
    # The folder doesn't exist.
    New-Item -Path $path_install -ItemType 'Directory' -Force
  } 
}
catch
{
  "Error was $_"
  $line = $_.InvocationInfo.ScriptLineNumber
  "Error was in Line $line"
}

try
{
  # Content
  Write-Output 'Calling of a MATLAB silent setup...'
  &"$PSScriptRoot\$os_type\setup.exe" -inputFile "$PSScriptRoot\$os_type\$install_input" -activationPropertiesFile "$PSScriptRoot\$os_type\$input_activation" # Main installation command
  Write-Output 'The silent MATLAB setup has been completed.'
}
catch
{
  "Error was $_"
  $line = $_.InvocationInfo.ScriptLineNumber
  "Error was in Line $line"
}
#####################################################

#####################################################
### Copy of additioncal files like license file or
# for warez people additional files.
# Yes, I know that you are there folks!
#####################################################
try
{
  # Content
  Copy-Item "$path_license_files\*" -Destination $path_install -Force
}
catch
{
  "Error was $_"
  $line = $_.InvocationInfo.ScriptLineNumber
  "Error was in Line $line"
}
Write-Output 'The license file(s) copied.'
#####################################################


#####################################################
### Copy of settings
#####################################################
$path_settings = "$env:APPDATA\MathWorks\MATLAB\" + $path_install.Substring($path_install.Length - 6, 6)
try
{
  # Content
  Copy-Item $path_backup_settings -Destination $path_settings -Force
}
catch
{
  "Error was $_"
  $line = $_.InvocationInfo.ScriptLineNumber
  "Error was in Line $line"
}
#####################################################


#####################################################
### Open log for user to check it
#####################################################
Invoke-Item -Path "$log_path\$installation_log"
#####################################################

Start-Sleep 10