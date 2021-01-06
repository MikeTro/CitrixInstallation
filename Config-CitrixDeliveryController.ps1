<#
    .Synopsis
        Config Citrix Delivery Controller
    .Description
        this script creates the XenDesktop site and all its databases. It configures the site
        and it adds the first Delivery Controller to the site.

    .NOTES  
        Copyright: (c)2021 by EducateIT GmbH - http://educateit.ch - info@educateit.ch
        Version		:	1.0

        History:
            V1.0 - 04.01.2021 - M.Trojahn - Initial creation based on https://dennisspan.com/citrix-delivery-controller-unattended-installation-with-powershell-and-sccm/#CompleteScriptConfSite
           
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
$ComputerName = $env:ComputerName


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


# Disable File Security
$env:SEE_MASK_NOZONECHECKS = 1

$MyLogger.Info("Create and configure the XenDesktop site")

# -----------------------------------
# CUSTOMIZE THE FOLLOWING VARIABLES IN FILE CitrixSiteConfig.xml TO YOUR REQUIREMENTS
# -----------------------------------

[string]    $ConfigFile = $ScriptDirectory + "\CitrixSiteConfig.xml" 
[string]    $XmlRoot = "SiteConfig"
[xml]       $SiteConfig = [xml] (Get-Content $ConfigFile )

	$Customer	= $cfg.$root.Customer




$SiteName =                 $SiteConfig.$XmlRoot.SiteName
$DatabaseServer =           $SiteConfig.$XmlRoot.DatabaseServer
$DatabaseServerPort =       $SiteConfig.$XmlRoot.DatabaseServerPort
$DatabaseName_Site =        $SiteConfig.$XmlRoot.DatabaseName_Site
$DatabaseName_Logging =     $SiteConfig.$XmlRoot.DatabaseName_Logging
$DatabaseName_Monitoring =  $SiteConfig.$XmlRoot.DatabaseName_Monitoring
$LicenseServer =            $SiteConfig.$XmlRoot.LicenseServer    
$LicenseServerPort =        $SiteConfig.$XmlRoot.LicenseServerPort    
$LicensingModel =           $SiteConfig.$XmlRoot.LicensingModel
$ProductCode =              $SiteConfig.$XmlRoot.ProductCode
$ProductEdition =           $SiteConfig.$XmlRoot.ProductEdition   
$AdminGroup =               $SiteConfig.$XmlRoot.AdminGroup
$Role =                     $SiteConfig.$XmlRoot.Role
$Scope =                    $SiteConfig.$XmlRoot.Scope
$GroomingDays =             $SiteConfig.$XmlRoot.GroomingDays    
# -----------------------------------

# Log Variables
$MyLogger.Info("-Site name = $SiteName")
$MyLogger.Info("-Database server (+ instance) = $DatabaseServer")
$MyLogger.Info("-Database server port = $DatabaseServerPort")
$MyLogger.Info("-Database name for site DB = $DatabaseName_Site")
$MyLogger.Info("-Database name for logging DB = $DatabaseName_Logging")
$MyLogger.Info("-Database name for monitoring DB = $DatabaseName_Monitoring")
$MyLogger.Info("-License server = $DatabaseServer")
$MyLogger.Info("-License server port = $LicenseServerPort")
$MyLogger.Info("-Licensing model = $LicensingModel")
$MyLogger.Info("-Product code = $ProductCode")
$MyLogger.Info("-Product edition = $ProductEdition")
$MyLogger.Info("-Administrator group name = $AdminGroup")
$MyLogger.Info("-Administrator group role = $Role")
$MyLogger.Info("-Administrator group scope = $Scope")
$MyLogger.Info("-Grooming days = $GroomingDays")


# IMPORT MODULES AND SNAPINS
# --------------------------

# Import the XenDesktop Admin module
$MyLogger.Info("Import the XenDesktop Admin module")
try {
    Import-Module Citrix.XenDesktop.Admin
    $MyLogger.Info("The XenDesktop Admin module was imported successfully")
} catch {
    $MyLogger.Error("An error occurred trying to import the XenDesktop Admin module (error: $($Error[0]))")
    Exit 1
}

# Load the Citrix snap-ins
$MyLogger.Info("Load the Citrix snap-ins")
try {
    asnp citrix.*
    $MyLogger.Info("The Citrix snap-ins were loaded successfully")
} catch {
    MyLogger.Error("An error occurred trying to load the Citrix snap-ins (error: $($Error[0]))")
    Exit 1
}


# CREATE DATABASES
# ----------------

# Create the site database (the classical try / catch statement does not work for some reason, so I had to use an "uglier" method for error handling)
$MyLogger.Info("Create the site database")
try {
    New-XDDatabase -AdminAddress $ComputerName -SiteName $SiteName -DataStore Site -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Site -ErrorAction Stop | Out-Null
    $MyLogger.Info("The site database '$DatabaseName_Site' was created successfully")
} catch {
    [string]$ErrorText = $Error[0]
    If ( $ErrorText.Contains("already exists")) {
        $MyLogger.Info("The site database '$DatabaseName_Site' already exists. Nothing to do.")
    } else {
        $MyLogger.Error("An error occurred trying to create the site database '$DatabaseName_Site' (error: $($Error[0]))")
        Exit 1
    }
}

# Create the logging database
$MyLogger.Info("Create the logging database")
try {
    New-XDDatabase -AdminAddress $ComputerName -SiteName $SiteName -DataStore Logging -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Logging -ErrorAction Stop | Out-Null
    $MyLogger.Info("The logging database '$DatabaseName_Logging' was created successfully")
} catch {
    [string]$ErrorText = $Error[0]
    If ( $ErrorText.Contains("already exists")) {
        $MyLogger.Info("The logging database '$DatabaseName_Logging' already exists. Nothing to do.")
    } else {
        $MyLogger.Error("An error occurred trying to create the logging database '$DatabaseName_Logging' (error: $($Error[0]))")
        Exit 1
    }
}

# Create the monitoring database
$MyLogger.Info("Create the monitoring database")
try {
    New-XDDatabase -AdminAddress $ComputerName -SiteName $SiteName -DataStore Monitor -DatabaseServer $DatabaseServer -DatabaseName $DatabaseName_Monitoring -ErrorAction Stop | Out-Null
    $MyLogger.Info("The monitoring database '$DatabaseName_Monitoring' was created successfully")
} catch {
    [string]$ErrorText = $Error[0]
    If ( $ErrorText.Contains("already exists")) {
        $MyLogger.Info("The monitoring database '$DatabaseName_Monitoring' already exists. Nothing to do.")
    } else {
        $MyLogger.Error("An error occurred trying to create the monitoring database '$DatabaseName_Monitoring' (error: $($Error[0]))")
        Exit 1
    }
}


# CREATE OR JOIN XENDESKTOP SITE
# ------------------------------

# Check if the XenDesktop site is configured and retrieve the site version number
$MyLogger.Info("Check if the XenDesktop site is configured and retrieve the site version number")
$SiteExists = $False
try {
    $SQL_ConnectionString = "Server=$DatabaseServer,$DatabaseServerPort;Database=$DatabaseName_Site;Integrated Security=True;"
    $SQL_Connection = New-Object System.Data.SqlClient.SqlConnection
    $SQL_Connection.ConnectionString = $SQL_ConnectionString
    $SQL_Connection.Open()
    $SQL_Command = $SQL_Connection.CreateCommand()
    $SQL_Query = "SELECT [ProductVersion] FROM [ConfigurationSchema].[Site]"
    $SQL_Command.CommandText = $SQL_Query
    $SQL_QUERY_ProductVersion = new-object "System.Data.DataTable"
    $SQL_QUERY_ProductVersion.Load( $SQL_Command.ExecuteReader() )
    foreach ($Element in $SQL_QUERY_ProductVersion) { 
        $SiteVersion = [string]$Element.Productversion
    }
        
    # If the variable '$SiteVersion' is empty, the site has not yet been created
    if ( [string]::IsNullOrEmpty($SiteVersion)) {
        $MyLogger.Info("The site database '$DatabaseName_Site' exists, but the site still needs to be created.")
    } else {
        $MyLogger.Info("The site has already been created. The version of the site is: $SiteVersion")
        $SiteExists = $True
    }
    $SQL_Connection.Close()
} catch {
    $MyLogger.Error("An error occurred trying to retrieve the site and site version (error: $($Error[0]))")
    Exit 1
}

# Create a new site, or if the site exists, compare the site version to the version of the XenDesktop product software installed on the local server and join the local server to the site
if ( $SiteExists ) {
    $MyLogger.Info("Compare the site version to the version of the XenDesktop product software installed on the local server and join the local server to the site")
    
    # Get the version of the XenDesktop product software installed on the local server
    try {
        [string]$XenDesktopSoftwareVersion = (gwmi win32_product | Where-Object { $_.Name -like "*Citrix Broker Service*" }).Version
    } catch {
        $MyLogger.Error("An error occurred trying to retrieve the version of the locally installed XenDesktop software  (error: $($Error[0]))")
    }
    
    # JOIN SITE
    # ---------
    if ( $SiteVersion -eq $XenDesktopSoftwareVersion.Substring(0,$SiteVersion.Length) ) {
        $MyLogger.Info("The site version ($SiteVersion) is equal to the XenDesktop product software installed on the local server ($XenDesktopSoftwareVersion)")
        $MyLogger.Info("Check if the local server already has been joined to the site")

        # Check if the local server already has been joined
        $SQL_ConnectionString = "Server=$DatabaseServer,$DatabaseServerPort;Database=$DatabaseName_Site;Integrated Security=True;"
        $SQL_Connection = New-Object System.Data.SqlClient.SqlConnection
        $SQL_Connection.ConnectionString = $SQL_ConnectionString
        $SQL_Connection.Open()
        $SQL_Command = $SQL_Connection.CreateCommand()
        $SQL_Query = "SELECT [MachineName] FROM [ConfigurationSchema].[Services]"
        $SQL_Command.CommandText = $SQL_Query
        $SQL_QUERY_Controllers = new-object "System.Data.DataTable"
        $SQL_QUERY_Controllers.Load( $SQL_Command.ExecuteReader() )
        $ServerAlreadyJoined = $False
        $x = 0
        foreach ($Element in $SQL_QUERY_Controllers) {
            $x++
            if ( $Element.MachineName -eq $ComputerName ) {
                $ServerAlreadyJoined = $True
            }
        }
        $SQL_Connection.Close()
        
        # Join the local server to the site (if needed)
        if ( $ServerAlreadyJoined ) {
            $MyLogger.Info("The local machine $Computername has already been joined to the site '$SiteName'. Nothing to do.")
        } else {
            $MyLogger.Info("The local machine $Computername is not joined to the site '$SiteName'")
            # Use one of the available controllers for the parameter 'SiteControllerAddress'
            $y = 0
            foreach ($Element in $SQL_QUERY_Controllers) {
                $y++
                $Controller = ($Element.MachineName).ToUpper()
                $MyLogger.Info("Join site using controller $Controller ($y of $x)")
                try {
                    Add-XDController -SiteControllerAddress $Controller  | Out-Null
                    $MyLogger.Info("The local server was successfully joined to the site '$SiteName'")
                    Break
                } catch {
                    $MyLogger.Error("An error occurred trying to join using controller $Controller (error: $($Error[0]))")
                }
            }
        }
    } else {
        $MyLogger.Error("The site version ($SiteVersion) and the version of the locally installed XenDesktop product software ($XenDesktopSoftwareVersion) are not equal!")
        Exit 1
    }
} else {
    # CREATE SITE
    # -----------
    $MyLogger.Info("Create the XenDesktop site '$SiteName'")
    try {
        New-XDSite -DatabaseServer $DatabaseServer -LoggingDatabaseName $DatabaseName_Logging -MonitorDatabaseName $DatabaseName_Monitoring -SiteDatabaseName $DatabaseName_Site -SiteName $SiteName -AdminAddress $ComputerName -ErrorAction Stop  | Out-Null
        $MyLogger.Info("The site '$SiteName' was created successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to create the site '$SiteName' (error: $($Error[0]))")
        Exit 1
    }

    # LICENSE SERVER CONFIG
    # ---------------------
    # Configure license server
    $MyLogger.Info("Configure licensing")
    $MyLogger.Info("Set the license server")
    try {
        Set-XDLicensing -AdminAddress $ComputerName -LicenseServerAddress $LicenseServer -LicenseServerPort $LicenseServerPort -Force  | Out-Null
        $MyLogger.Info("The license server '$LicenseServer' was configured successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to configure the license server '$LicenseServer' (error: $($Error[0]))")
        Exit 1
    }

    # Configure the licensing model, product and edition
    $MyLogger.Info("Configure the licensing model, product and edition")
    try {  
        Set-ConfigSite  -AdminAddress $ComputerName -LicensingModel $LicensingModel -ProductCode $ProductCode -ProductEdition $ProductEdition | Out-Null
        $MyLogger.Info("The licensing model, product and edition have been configured correctly")
    } catch {
        $MyLogger.Error("An error occurred trying to configure the licensing model, product and edition (error: $($Error[0]))")
        Exit 1
    }

    # Register the certificate hash
    $MyLogger.Info("Register the certificate hash")
    try {  
        Set-ConfigSiteMetadata -AdminAddress $ComputerName -Name 'CertificateHash' -Value $(Get-LicCertificate -AdminAddress "https://$($LicenseServer):8083").CertHash | Out-Null
        $MyLogger.Info("The certificate hash from server '$LicenseServer' has been confirmed successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to confirm the certificate hash from server '$LicenseServer' (error: $($Error[0]))")
        Exit 1
    }

    # CREATE ADMINISTRATORS
    # ---------------------
    # Create a full admin group "CTXAdmins"
    $MyLogger.Info("Create the Citrix administrator $AdminGroup")
    try {
        Get-AdminAdministrator $AdminGroup | Out-Null
        $MyLogger.Info("The Citrix administrator $AdminGroup already exists. Nothing to do.")
    } catch { 
        try {
            New-AdminAdministrator -AdminAddress $ComputerName -Name $AdminGroup | Out-Null
            $MyLogger.Info("The Citrix administrator $AdminGroup has been created successfully")
        } catch {
            $MyLogger.Error("An error occurred trying to create the Citrix administrator $AdminGroup (error: $($Error[0]))")
            Exit 1
        }
    }

    # Assign full admin rights to the admin group "CTXAdmins"
    $MyLogger.Info("Assign full admin rights to the Citrix administrator $AdminGroup")
    try {  
        Add-AdminRight -AdminAddress $ComputerName -Administrator $AdminGroup -Role 'Full Administrator' -Scope "All" | Out-Null
        $MyLogger.Info("Successfully assigned full admin rights to the Citrix administrator $AdminGroup")
    } catch {
        $MyLogger.Error("An error occurred trying to assign full admin rights to the Citrix administrator $AdminGroup (error: $($Error[0]))")
        Exit 1
    }

    # ADDITIONAL SITE CONFIGURATIONS
    # ------------------------------
    # Configure grooming settings
    $MyLogger.Info("Configure grooming settings")
    try {  
        Set-MonitorConfiguration -GroomApplicationInstanceRetentionDays $GroomingDays -GroomDeletedRetentionDays $GroomingDays -GroomFailuresRetentionDays $GroomingDays -GroomLoadIndexesRetentionDays $GroomingDays -GroomMachineHotfixLogRetentionDays $GroomingDays -GroomNotificationLogRetentionDays $GroomingDays -GroomResourceUsageDayDataRetentionDays $GroomingDays -GroomSessionsRetentionDays $GroomingDays -GroomSummariesRetentionDays $GroomingDays | Out-Null
        $MyLogger.Info("Successfully changed the grooming settings to $GroomingDays days")
    } catch {
        $MyLogger.Error("An error occurred trying to change the grooming settings to $GroomingDays days (error: $($Error[0]))")
        Exit 1
    }

    # Enable the Delivery Controller to trust XML requests sent from StoreFront (https://docs.citrix.com/en-us/receiver/windows/4-7/secure-connections/receiver-windows-configure-passthrough.html)
    $MyLogger.Info("Enable the Delivery Controller to trust XML requests sent from StoreFront")
    try {  
        Set-BrokerSite -TrustRequestsSentToTheXmlServicePort $true | Out-Null
        $MyLogger.Info("Successfully enabled trusted XML requests")
    } catch {
        $MyLogger.Error("An error occurred trying to enable trusted XML requests (error: $($Error[0]))")
        Exit 1
    }
    # Disable connection leasing (enabled by default in a new site)
    $MyLogger.Info("Disable connection leasing")
    try {
        Set-BrokerSite -ConnectionLeasingEnabled $false | Out-Null
        $MyLogger.Info("Connection leasing was disabled successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to disable connection leasing (error: $($Error[0]))")
        Exit 1
    }

    # Enable Local Host Cache (disabled by default in a new site)
    $MyLogger.Info("Enable Local Host Cache")
    try {
        Set-BrokerSite -LocalHostCacheEnabled $true | Out-Null
        $MyLogger.Info("Local Host Cache was enabled successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to enable Local Host Cache (error: $($Error[0]))")
        Exit 1
    }

    # Disable the Customer Experience Improvement Program (CEIP)
    $MyLogger.Info("Disable the Customer Experience Improvement Program (CEIP)")
    try {
        Set-AnalyticsSite -Enabled $false | Out-Null
        $MyLogger.Info("The Customer Experience Improvement Program (CEIP) was disabled successfully")
    } catch {
        $MyLogger.Error("An error occurred trying to disable the Customer Experience Improvement Program (CEIP) (error: $($Error[0]))")
        Exit 1
    }
}

# Enable File Security  
Remove-Item env:\SEE_MASK_NOZONECHECKS
$MyLogger.Info("End of script")

