<#
    .Synopsis
        Installation of Microsoft Roles and Features for Citrix Delivery Controller
    .Description
        Installation of Microsoft Roles and Features for Citrix Delivery Controller
        This script installs the following roles:
          -.Net Framework 3.5 (W2K8R2 only)
          -.Net Framework 4.6 (W2K12 + W2K16)
          -Desktop experience (W2K8R2 + W2K12)
          -Group Policy Management Console
          -Remote Server Administration Tools (AD DS Snap-Ins)
          -Remote Desktop Licensing Tools
          -Telnet Client
          -Windows Process Activation Service



    .NOTES  
        Copyright: (c)2020 by EducateIT GmbH - http://educateit.ch - info@educateit.ch
        Version		:	1.0

        History:
        V1.0 - 14.12.2020 - M.Trojahn - Initial creation
           
#>	


if ($env:EducateITLogs -eq $null) {
    New-Item "C:\EducateITLogs"
    $env:EducateITLogs = "C:\EducateITLogs"
}

$LogDir     = $env:EducateITLogs
$LogFile    = $env:EducateITLogs + "\" + $MyInvocation.MyCommand.Name + ".log"
$MyLogger   = New-EitFileLogger -LogFilePath $LogFile	



# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1


$MyLogger.Info("Add Windows roles and features:")
$MyLogger.Info("-.Net Framework 4.6 ")
$MyLogger.Info("-Group Policy Management Console")
$MyLogger.Info("-Remote Server Administration Tools (AD DS Snap-Ins)")
$MyLogger.Info("-Remote Desktop Licensing Tools")
$MyLogger.Info("-Telnet Client")
$MyLogger.Info("-Windows Process Activation Service")

$MyLogger.Info("Retrieve the OS version and name")

# Check the windows version
# URL: https://en.wikipedia.org/wiki/List_of_Microsoft_Windows_versions
# -Windows Server 2016    -> NT 10.0
# -Windows Server 2012 R2 -> NT 6.3
# -Windows Server 2012    -> NT 6.2
# -Windows Server 2008 R2 -> NT 6.1
# -Windows Server 2008	  -> NT 6.0
[string]$WindowsVersion = ( Get-WmiObject -class Win32_OperatingSystem ).Version
switch -wildcard ($WindowsVersion)
    { 
        "*10*" { 
                $OSVER = "W2K16"
                $OSName = "Windows Server 2016"
                $Install_RolesAndFeaturesLogFile = Join-Path $LogDir "Install_RolesAndFeatures.log"
                $MyLogger.Info("The current operating system is $($OSNAME) ($($OSVER))")
                $MyLogger.Info("Start the installation ...")

                # Install Windows Features
                try {
                    Install-WindowsFeature NET-Framework-45-Core,GPMC,RSAT-ADDS-Tools,RDS-Licensing-UI,WAS,Telnet-Client -logpath $Install_RolesAndFeaturesLogFile
                    $MyLogger.Info("The windows features were installed successfully!")
                } catch {
                    $MyLogger.Error("An error occurred while installing the windows features (error: $($error[0]))")
                    Exit 1
                }
            } 
        default { 
            $OSName = ( Get-WmiObject -class Win32_OperatingSystem ).Caption
            $MyLogger.Error("The current operating system $($OSName) is unsupported")
            $MyLogger.Info("This script will now be terminated")
            Exit 1
            }
    }

# Enable File Security  
Remove-Item env:\SEE_MASK_NOZONECHECKS

$MyLogger.Info("End of script")

