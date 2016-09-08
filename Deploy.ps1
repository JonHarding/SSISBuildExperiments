param([string]$targetConnectionString, [string]$Dacpac, [string]$targetDatabaseName, [string]$Profile)
 
#$dacfxPath = 'C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\Microsoft.SqlServer.Dac.dll'
<#
 .SYNOPSIS
 Finds the DAC File that you specify
 .DESCRIPTION
 Looks through the supplied PathList array and searches for the file you specify.  It will return the first one that it finds.
 .PARAMETER FileName
 Name of the file you are looking for
 .PARAMETER PathList
 Array of Paths to search through.
 .EXAMPLE
 Find-DacFile -FileName "Microsoft.SqlServer.TransactSql.ScriptDom.dll" -PathList @("${env:ProgramFiles}\Microsoft SQL Server", "${env:ProgramFiles(x86)}\Microsoft SQL Server")
#>
Function Find-DacFile {
	Param(
		[Parameter(Mandatory=$true)]
		[string]$FileName,
		[Parameter(Mandatory=$true)]
		[string[]]$PathList
	)

	$File = $null

	ForEach($Path in $PathList)
	{
		Write-Debug ("Searching: {0}" -f $Path)

		If (!($File))
		{
			$File = (
				Get-ChildItem $Path -ErrorAction SilentlyContinue -Filter $FileName -Recurse |
				Sort-Object FullName -Descending |
				Select -First 1
				)

			If ($File)
			{
				Write-Debug ("Found: {0}" -f $File.FullName)
			}
		}
	}

	Return $File
}
 
$logs = "C:\DacpacReport"
 
#create log path
$validate = Test-Path $logs
if (!$logs){
$logs = New-Item -ItemType Directory -Force -Path C:\DacpacReport
}
 
# Load the DAC assembly
Write-Verbose "Loading the DacFX Assemblies"

$SearchPathList = @("${env:ProgramFiles}\Microsoft SQL Server", "${env:ProgramFiles(x86)}\Microsoft SQL Server")

Write-Debug "Searching for: Microsoft.SqlServer.TransactSql.ScriptDom.dll"
$ScriptDomDLL = (Find-DacFile -FileName "Microsoft.SqlServer.TransactSql.ScriptDom.dll" -PathList $SearchPathList)

Write-Debug "Searching for: Microsoft.SqlServer.Dac.dll"
$DacDLL = (Find-DacFile -FileName "Microsoft.SqlServer.Dac.dll" -PathList $SearchPathList)

If (!($ScriptDomDLL))
{
	Throw "Could not find the file: Microsoft.SqlServer.TransactSql.ScriptDom.dll"
}
If (!($DacDLL))
{
	Throw "Could not find the file: Microsoft.SqlServer.Dac.dll"
}

Write-Debug ("Adding the type: {0}" -f $ScriptDomDLL.FullName)
Add-Type -Path $ScriptDomDLL.FullName

Write-Debug ("Adding the type: {0}" -f $DacDLL.FullName)
Add-Type -Path $DacDLL.FullName

Write-Host "Loaded the DAC assemblies"
#Write-Verbose 'Testing if DACfx was installed...'
#$validate = Test-Path $dacfxPath
#if (!$dacfxPath){
#throw 'No usable version of Dac Fx found.'
#}
#Write-Verbose -Verbose 'DacFX found, attempting to load DAC assembly...'
#Add-Type -Path $dacfxPath
#Write-Verbose -Verbose 'Loaded DAC assembly.'
 
# Load DacPackage
$dacPackage = [Microsoft.SqlServer.Dac.DacPackage]::Load($Dacpac)
 
# Load DacProfile
if ($profile -ne " ") {
$dacProfile = [Microsoft.SqlServer.Dac.DacProfile]::Load($Profile)
Write-Host ('Loaded publish profile ''{0}''.' -f $Profile)
} else {
$dacProfile = New-Object Microsoft.SqlServer.Dac.DacDeployOptions -Property @{
'BlockOnPossibleDataLoss' = $true;
'DropObjectsNotInSource' = $false;
'ScriptDatabaseOptions' = $true;
'IgnorePermissions' = $true;
'IgnoreRoleMembership' = $true
}
}
 
# Setup DacServices
$server = "server=$targetConnectionString"
$dacServices = New-Object Microsoft.SqlServer.Dac.DacServices $server
 
# Deploy package
try {
Write-Host 'Starting Dacpac deployment...'
$dacServices.GenerateDeployScript($dacPackage,$targetDatabaseName, $dacProfile.DeployOptions) | Out-File "$logs\$targetDatabaseName.sql"
$dacServices.Deploy($dacPackage, $targetDatabaseName, $true, $dacProfile.DeployOptions, $null)
Write-Host 'Deployment succeeded!'
} catch [Microsoft.SqlServer.Dac.DacServicesException] {
throw ('Deployment failed: ''{0}'' Reason: ''{1}''' -f $_.Exception.Message, $_.Exception.InnerException.Message)
}