<#
    .Synopsis
        Install Citrix StoreFront
    .Description
        Install Citrix Delivery Controller
        This script only installs StoreFront. It does not configure it.

    .NOTES  
        Copyright: (c)2021 by EducateIT GmbH - http://educateit.ch - info@educateit.ch
        Version		:	1.0

        History:
            V1.0 - 07.01.2021 - M.Trojahn - Initial creation
           
#>	

#==========================================================================
# define Error handling
#==========================================================================
$global:ErrorActionPreference = "Stop"
if($verbose){ $global:VerbosePreference = "Continue" }

#==========================================================================
# global vars
#==========================================================================
$ScriptPath = $MyInvocation.MyCommand.Path
$ScriptDirectory = Split-Path $ScriptPath -Parent



########################################################
# Please set Install Source Path
########################################################

$InstallSourcePath = "D:\"

########################################################


#==========================================================================
if ($env:EducateITLogs -eq $null) {
    if (Test-Path "C:\EducateITLogs" -PathType Leaf) {
        New-Item "C:\EducateITLogs"
    }    
    $env:EducateITLogs = "C:\EducateITLogs"
}

$LogDir     = $env:EducateITLogs
$LogFile    = $env:EducateITLogs + "\" + $MyInvocation.MyCommand.Name + ".log"
$MyLogger   = New-EitFileLogger -LogFilePath $LogFile	



#==========================================================================
# Main
#==========================================================================

# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1

# Custom variables [edit]
$BaseLogDir = "C:\Logs"                                         # [edit] add the location of your log directory here
$PackageName = "Citrix StoreFront (installation)"               # [edit] enter the display name of the software (e.g. 'Arcobat Reader' or 'Microsoft Office')


$MyLogger.Info("Install Citrix Storefront")

# INSTALL CITRIX STOREFRONT                     
#==========================================================================

# Set the default to the StoreFront log files
$DefaultStoreFrontLogPath = "$env:SystemRoot\temp\StoreFront"


# Install StoreFront
$SetupFile = Join-Path $InstallSourcePath "x64\StoreFront\CitrixStoreFront-x64.exe"
$Arguments = "-silent"

$MyLogger.Info("   Execute $SetupFile $Arguments")

Invoke-EitExecutable -FilePath $SetupFile -Arguments $Arguments

# Copy the StoreFront log files from the StoreFront default log directory to our custom directory
$MyLogger.Info("Copy the log files from the directory $DefaultStoreFrontLogPath to $LogDir")

Copy-Item (Join-Path $DefaultStoreFrontLogPath "*.log") -Destination $LogDir -Force -Recurse
# Enable File Security  
Remove-Item env:\SEE_MASK_NOZONECHECKS

$MyLogger.Info("End of script")