#
# DeploySSRSTask.ps1
#
[CmdletBinding(DefaultParameterSetName = 'None')]
param ()
Trace-VstsEnteringInvocation $MyInvocation

function EscapeSpecialChars {
    param(
        [string]$str
    )

    return $str.Replace('`', '``').Replace('"', '`"').Replace('$', '`$')
}


function DeploySsrsProject {
    param(
        [string]$projpath
    )

    $Folder = Split-Path -Path $projPath
    $ProjFile= Split-Path -leaf $projPath
    Write-Host ("Deploying project")
    if ( (test-path("$($Folder)\OutputLog.txt")) ) {Remove-Item  "$($Folder)\OutputLog.txt"}
    if ( (test-path("$($Folder)\ErrorLog.txt")) ) {Remove-Item "$($Folder)\ErrorLog.txt"}
    $ArgumentList = " ""$($projpath)"" /deploy """" /out ""$($Folder)\ErrorLog.txt"""
    try {

        Write-host "start $devenv $ArgumentList"
        Start-Process $devenv $ArgumentList -NoNewWindow -PassThru -Wait -Verbose -RedirectStandardOutput "$($Folder)\OutputLog.txt" 
        
        #Lees standard output logfile uit #
        $Logfile = Get-Content  "$($Folder)\OutputLog.txt" 
        $MatchCriteria = "Create|avoid|Consolidate|Define|Exception|Does not have|do not exist|Missing|Could not find|Failed to|are not supported|Cannot|Invalid"
        
 
        #Print de gehele standard output inclusief de warnings - Het parsen van de file is uitgecommentarieerd#
        $Logfile | ForEach-Object {
              
            if ($_ -match $MatchCriteria ) {

                write-host "##vso[task.logissue type=warning;] $_"
                $teller += 1 
            }
            Else {write-host $_}
        }
        if ($teller -eq 1) {
            write-host "A warning is identified by reading the logfile and to look for the following keywords ""$($MatchCriteria)"""
            write-host "##vso[task.logissue type=warning;] $($teller) warning occurred while deploying $($ProjFile), see the Build step log for an overview of all the warnings"
        }
        elseif($teller -ge 1) {
            write-host "A warning is identified by reading the logfile and to look for the following keywords ""$($MatchCriteria)"""
            write-host "##vso[task.logissue type=warning;]  $($teller) warnings occurred while deploying $($ProjFile), see the Build step log for an overview of all the warnings"
        }

        #Controleren of er errors zijn in de logfile#
    
        #Controleren of er errors zijn in de logfile#
        $ErrorLogfile = Get-Content "$($Folder)\ErrorLog.txt"
        $Errorlogfile |  ForEach-Object {
            if ( ($_ -notmatch "failed|skipped|succeeded or up-to-date")) {
                write-host  "$_"
            }
            elseif ( ($_ -notmatch "0 failed, 0 skipped")) {
                write-host "##vso[task.logissue type=error;] $($ProjFile):$($_)" 
                $CompleteResultStatus = "##vso[task.complete result=Failed;]"
                
            }
            else {
               Write-Host $_
            }
            
        }
        $CompleteResultStatus

    

    } 
    catch {
        Write-Host ("##vso[task.logissue type=error;]Task_InternalError " + $_.Exception.Message)
    }
} 

function TrimInputs([ref]$Project) {
    Write-Verbose "Triming inputs for excess spaces, double quotes"

    #$sqlUsername.Value = $sqlUsername.Value.Trim()

    $Project.Value = $Project.Value.Trim('"', ' ')
}

function SetProjectConfig {
	param(
		[string]$projpath,
		[string]$TargetServerVersion = "SSRS2016",
		[bool]$CreateSubfolders = $false
	)
	
	if ($CreateSubfolders) {
		# Count the number of reports in the report project
		# If there's more than 1 .rdl file the project will be deployed to a sub-folder
		$countReports = 0
		Get-ChildItem -Path (Split-Path -Path $projpath) -Filter *.rdl -Recurse -File -Name| ForEach-Object {
			if ($_ -inotmatch "bin\\") { $countReports ++ }
		}
		if ($countReports -gt 1) {
			$TargetFolder = $TargetFolder + "/" + ([System.IO.Path]::GetFileNameWithoutExtension($projpath))
		}
	}
	
	[XML]$AppConfig = (Get-Content -path ($projpath))
	IF ($AppConfig.project.PropertyGroup) {
		Foreach ($item in $AppConfig.project.PropertyGroup) {
		
			if (![string]::IsNullOrEmpty($item.TargetReportFolder)) {$item.TargetReportFolder = $TargetFolder}
			if (![string]::IsNullOrEmpty($item.TargetServerVersion)) {$item.TargetServerVersion = $TargetServerVersion}
			if (![string]::IsNullOrEmpty($item.TargetDatasetFolder)) {$item.TargetDatasetFolder = $DataSetFolder}
			if (![string]::IsNullOrEmpty($item.TargetDataSourceFolder)) {$item.TargetDataSourceFolder = $DataSourceFolder}
			if (![string]::IsNullOrEmpty($item.TargetServerURL)) {$item.TargetServerURL = $TargetServerURL}
			if (![string]::IsNullOrEmpty($item.OverwriteDatasets)) {$item.OverwriteDatasets = $OverwriteDatasets}
			if (![string]::IsNullOrEmpty($item.OverwriteDataSources)) {$item.OverwriteDataSources = $OverwriteDataSources}
		}
	}
	Else {
		Foreach ($item in $AppConfig.Project.Configurations.Configuration) {      
			if (![string]::IsNullOrEmpty($item.Options.TargetFolder)) {$item.Options.TargetFolder = $TargetFolder}
			if (![string]::IsNullOrEmpty($item.Options.TargetServerVersion)) {$item.Options.TargetServerVersion = $TargetServerVersion}
			if (![string]::IsNullOrEmpty($item.Options.TargetDatasetFolder)) {$item.Options.TargetDatasetFolder = $DataSetFolder}
			if (![string]::IsNullOrEmpty($item.Options.TargetDataSourceFolder)) {$item.Options.TargetDataSourceFolder = $DataSourceFolder}
			if (![string]::IsNullOrEmpty($item.Options.TargetServerURL)) {$item.Options.TargetServerURL = $TargetServerURL}
			if (![string]::IsNullOrEmpty($item.Options.OverwriteDatasets)) {$item.Options.OverwriteDatasets = $OverwriteDatasets}
			if (![string]::IsNullOrEmpty($item.Options.OverwriteDataSources)) {$item.Options.OverwriteDataSources = $OverwriteDataSources}
			}
	}

	$AppConfig.OuterXml | Out-File -filepath ($projpath) -Force -Encoding UTF8
}

## Main routine start
try {
    # Import the localized strings.
    Import-VstsLocStrings "$PSScriptRoot\Task.json"

    Write-host ("==============================================================================")
	Write-Host (Get-VstsLocString -Key StartingTask)
	
	# Read VSTS input parameters and clean
	$Project = EscapeSpecialChars -str (Get-VstsInput -Name Project -Require)
	$Configuration = EscapeSpecialChars -str (Get-VstsInput -Name Configuration -Require)
	$OverwriteProjectConfiguration = Get-VstsInput -Name OverwriteProjectConfiguration -Require -AsBool
	$TargetServerURL = EscapeSpecialChars -str (Get-VstsInput -Name TargetServerURL -Require)
	$TargetFolder = EscapeSpecialChars -str (Get-VstsInput -Name TargetFolder -Require)
	$DataSourceFolder = EscapeSpecialChars -str (Get-VstsInput -Name DataSourceFolder -Require)
	$DataSetFolder = EscapeSpecialChars -str (Get-VstsInput -Name DataSetFolder -Require)
	$OverwriteDataSources = EscapeSpecialChars -str (Get-VstsInput -Name OverwriteDataSources -Require)
	$OverwriteDatasets = EscapeSpecialChars -str (Get-VstsInput -Name OverwriteDatasets -Require)
	$CreateSubfolders = Get-VstsInput -Name CreateSubfolders -Require -AsBool
	
    Write-Host "Entering script SSRSDeploy.ps1"
    Write-Host "Project = $Project"
    Write-Host "Configuration = $Configuration"
    Write-Host "OverwriteProjectConfiguration = $OverwriteProjectConfiguration"
    Write-Host "TargetServerURL = $TargetServerURL"
    Write-Host "TargetFolder = $TargetFolder"
    Write-Host "DataSourceFolder = $DataSourceFolder"
    Write-Host "DataSetFolder = $DataSetFolder"
    Write-Host "OverwriteDataSources = $OverwriteDataSources"
    Write-Host "OverwriteDatasets = $OverwriteDatasets"
	Write-Host "CreateSubfolders = $CreateSubfolders"
	
    #Username ook nog aan toevoegen als deze wordt meegegeven
    #TrimInputs -Project ([ref]$Project)
	
	# Test if the project file exists
	if (!(Test-Path $Project)) {
		Write-Error (Get-VstsLocString -Key Project0AccessDenied -ArgumentList $Project)
	} else {
		Write-Host (Get-VstsLocString -Key ProjectFile0 -ArgumentList $Project)
	}

	# Determine location of devenv.com
	# Default to the standard, if not available search will be started (takes more time)
	$devenv = "C:\Program Files (x86)\Microsoft Visual Studio 14.0\Common7\IDE\devenv.com"
	if (!(Test-Path($devenv))) {
		# Determine location of devenv.com
		$devenv = (Get-ChildItem D:\ -Filter "devenv.com" -Recurse -Name | Select-Object -First 1)
		if ([string]::IsNullOrEmpty($devenv)) {
			$devenv = (Get-ChildItem C:\ -Filter "devenv.com" -Recurse -Name | Select-Object -First 1)
			$devenv = "C:\$devenv"
		}
		else {
			$devenv = "D:\$devenv"
		}
	}
	Write-Debug $devenv
	
	if (!(Test-Path($devenv))) {
		Write-Host (Get-VstsLocString -Key Devenv0NotFound -ArgumentList $devenv)
	}
	else {
		Write-Host (Get-VstsLocString -Key Devenv0Used -ArgumentList $devenv)
	}
	
	if([System.Convert]::ToBoolean($ConfigurationSettingsDeployment)) {		
		$ConfigurationSettingsDeployment = "Retain"
	} else {
		$ConfigurationSettingsDeployment = "Deploy"
	}
	if([System.Convert]::ToBoolean($OptimizationSettingsDeployment)) {		
		$OptimizationSettingsDeployment = "Retain"
	} else {
		$OptimizationSettingsDeployment = "Deploy"
	}

	# Opgegeven rptproject aanvullen met gewenste properties
    if ($Project.EndsWith(".rptproj") ) {
        Write-host "=================================================================="
        Write-host "Initiate $Project"
        Write-host "=================================================================="
        Write-host "Set config for $($Project)"
        SetProjectConfig -projpath ($Project) -CreateSubfolders $CreateSubfolders      
        Write-host "Deploy $($Project)"
        DeploySsrsProject($Project)
       
    }
    # rptprojecten van de opgegeven solution aanvullen met gewenste properties
    elseif ($Project.EndsWith(".sln")) {
        $Solution = ($Project | Resolve-Path).ProviderPath
        $SolutionRoot = $Solution | Split-Path
        Get-ChildItem -Path $SolutionRoot -Filter *.rptproj -Recurse | ForEach-Object {
            Write-host "=================================================================="  
            Write-host "Initiate $($_.FullName)"
            Write-host "=================================================================="
            Write-host "Set config for $($_.FullName)"
			SetProjectConfig -projpath ($_.FullName) -CreateSubfolders $CreateSubfolders  
            Write-host "Deploy $($_.FullName)"
            DeploySsrsProject($_.FullName)
       }    
    }
    # rptproject zoeken en aanvullen met gewenste properties
    Else { 
        Write-host "Find all RptProjects in $Project"
        Get-ChildItem -Path $Project -Filter *.rptproj -Recurse | ForEach-Object {
            Write-host "=================================================================="
            Write-host "Initiate $($_.FullName)"
            Write-host "=================================================================="
            Write-host "Set config for $($_.FullName)"
			SetProjectConfig -projpath ($_.FullName) -CreateSubfolders $CreateSubfolders      
          
            Write-host "Deploy $($_.FullName)"
            DeploySsrsProject($_.FullName)
           
            
        }
       
    }


} catch {
    Write-Error (Get-VstsLocString -Key InternalError0 -ArgumentList $_.Exception.Message)
} finally {
	Trace-VstsLeavingInvocation $MyInvocation
}

Write-Host (Get-VstsLocString -Key EndingTask)

