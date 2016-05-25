Param(
    [string]$projectFilePath,
    [string]$projectFileName
)

$projectFileLocation = "$projectFilePath\$projectFileName"
$etlOutputFolder = "$projectFilePath\ETL"

$projectFile = New-Object XML
$packageToAdd = New-Object XML
$projectFile.Load($projectFileLocation)

Get-ChildItem $etlOutputFolder -Recurse -Filter *.dtsx |
    ForEach-Object {
        Write-Host $_.FullName
        $packageToAdd.Load($_.FullName)
        $projectFile.project.deploymentmodelspecificcontent.manifest.project.packages.AppendChild($_.Name)
    }

$projectFile.project.deploymentmodelspecificcontent.manifest.project.packages