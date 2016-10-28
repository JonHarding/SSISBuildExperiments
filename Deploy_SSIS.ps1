# Variables
$ProjectFilePath = "C:SSISMyCatalogProjectbinDevelopmentMyCatalogProject.ispac"
$ProjectName = "MyCatalogProject"
$FolderName = "Demo"
$EnvironmentName = "CustomerA"
 
# Load the IntegrationServices Assembly
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Management.IntegrationServices") | Out-Null;
 
# Store the IntegrationServices Assembly namespace to avoid typing it every time
$ISNamespace = "Microsoft.SqlServer.Management.IntegrationServices"
 
Write-Host "Connecting to server ..."
 
# Create a connection to the server
$sqlConnectionString = "Data Source=localhost;Initial Catalog=master;Integrated Security=SSPI;"
$sqlConnection = New-Object System.Data.SqlClient.SqlConnection $sqlConnectionString
 
# Create the Integration Services object
$integrationServices = New-Object $ISNamespace".IntegrationServices" $sqlConnection
 
Write-Host "Removing previous catalog ..."
 
# Drop the existing catalog if it exists
if ($integrationServices.Catalogs.Count -gt 0) { $integrationServices.Catalogs["SSISDB"].Drop() }
 
Write-Host "Creating new SSISDB Catalog ..."
 
# Provision a new SSIS Catalog
$catalog = New-Object $ISNamespace".Catalog" ($integrationServices, "SSISDB", "SUPER#secret1")
$catalog.Create()
 
Write-Host "Creating Folder " $FolderName " ..."
 
# Create a new folder
$folder = New-Object $ISNamespace".CatalogFolder" ($catalog, $FolderName, "Folder description")
$folder.Create()
 
Write-Host "Deploying " $ProjectName " project ..."
 
# Read the project file, and deploy it to the folder
[byte[]] $projectFile = [System.IO.File]::ReadAllBytes($ProjectFilePath)
$folder.DeployProject($ProjectName, $projectFile)
 
Write-Host "Creating environment ..."
 
$environment = New-Object $ISNamespace".EnvironmentInfo" ($folder, $EnvironmentName, "Description")
$environment.Create()
 
Write-Host "Adding server variables ..."
 
# Adding variable to our environment
# Constructor args: variable name, type, default value, sensitivity, description
$environment.Variables.Add(“CustomerID”, [System.TypeCode]::String, "C111", "false", "Customer ID")
$environment.Variables.Add(“FtpUser”, [System.TypeCode]::String, $EnvironmentName, "false", "FTP user")
$environment.Variables.Add(“FtpPassword”, [System.TypeCode]::String, "SECRET1234!", "true", "FTP password")
$environment.Alter()
 
Write-Host "Adding environment reference to project ..."
 
# making project refer to this environment
$project = $folder.Projects[$ProjectName]
$project.References.Add($EnvironmentName, $folder.Name)
$project.Alter()
 
Write-Host "All done."