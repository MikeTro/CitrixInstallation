<#
    .Synopsis
        Install Citrix Delivery Controller
    .Description
        Install Citrix Delivery Controller
        This script only installs the Citrix Delivery Controller. It does not configure it.

    .NOTES  
        Copyright: (c)2020 by EducateIT GmbH - http://educateit.ch - info@educateit.ch
        Version		:	1.0

        History:
            V1.0 - 14.12.2020 - M.Trojahn - Initial creation
           
#>	

########################################################
# Please set Install Source Path
########################################################

$InstallSourcePath = ""

########################################################

if ($env:EducateITLogs -eq $null) {
    if (Test-Path "C:\EducateITLogs" -PathType Leaf) {
        New-Item "C:\EducateITLogs"
    }    
    $env:EducateITLogs = "C:\EducateITLogs"
}

$LogDir     = $env:EducateITLogs
$LogFile    = $env:EducateITLogs + "\" + $MyInvocation.MyCommand.Name + ".log"
$MyLogger   = New-EitFileLogger -LogFilePath $LogFile	


# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1

$MyLogger.Info("Install the Citrix Delivery Controller")

$SetupFile = Join-Path $InstallSourcePath "Files\x64\XenDesktop Setup\XenDesktopServerSetup.exe"
#$Arguments = "/components controller,desktopstudio /configure_firewall /nosql /noreboot /quiet /logpath ""$LogDir"""
$Arguments = "/components controller,desktopstudio /configure_firewall /noreboot /quiet /logpath ""$LogDir"""
Invoke-Executable -FilePath $SetupFile -Arguments $Arguments

# Enable File Security  
Remove-Item env:\SEE_MASK_NOZONECHECKS

$MyLogger.Info("End of script")