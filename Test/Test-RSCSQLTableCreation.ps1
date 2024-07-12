################################################
# Function - Test-RSCSQLTableCreation - Testing SQL connectivity by creating the default RSCEvents table
################################################
Function Test-RSCSQLTableCreation {

<#
.SYNOPSIS
Tests you are able to connect to a SQL server using a SqlServer PowerShell module (required, should already be installed) for proving connectivity before using the Write-RSCEvent functions.

.DESCRIPTION
This function requires you to already have the Microsoft Sqlserver PowerShell module installed, use Install-Module Sqlserver, which then allows you to test connectivity to your SQL server.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SQLInstance
The server name to connect to. I.E "localhost" for a local SQL server. If using a named instance include it in the string. I.E "localhost\MSSQLSERVER"
.PARAMETER SQLDB
Verify you can access the specified SQL DB (needs to already exist, no Write-RSCEvent scripts will ever create a DB, only tables)

.OUTPUTS
Returns a list of the table structure of the database specified.

.EXAMPLE
Test-RSCSQLTableCreation -SQLInstance "localhost" -SQLDB "RubrikReporting"

.NOTES
Author: Joshua Stenhouse
Date: 07/12/24
#>
################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$SQLInstance,[Parameter(Mandatory=$true)]$SQLDB
    )

################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Checking SQL module, exiting function with error if not availabile
Test-RSCSQLModule
################################################
# Importing SQL Server Module
################################################
$PSModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
# Specify the name of the SQL Server module to use (either SqlServer or SQLPS)
$SQLModuleName = $PSModules | Where-Object {(($_ -contains "SQLPS") -or ($_ -contains "sqlserver"))} | Select-Object -Last 1
# Checking to see if SQL Server module is loaded
$SQLModuleCheck = Get-Module $SQLModuleName
# If SQL module not found in current session importing
IF ($SQLModuleCheck -eq $null)
{
# Importing SqlServer module
Import-Module $SQLModuleName -ErrorAction SilentlyContinue
}
ELSE
{
# Nothing to do, SQL module already in the current session
}
##########################
# SQL - Checking Tables
##########################
# Creating query
$SQLTableListQuery = "USE $SQLDB;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;"
# Run SQL query
Try
{
$SQLTableList = Invoke-SQLCmd -Query $SQLTableListQuery -ServerInstance $SQLInstance -QueryTimeout 300 
}
Catch
{
$Error[0] | Format-List -Force
}
# Manually setting SQL table name if not specified
IF($SQLTable -eq $null){$SQLTable = "RSCEvents"}
# Selecting
$SQLTableList = $SQLTableList | Select-Object -ExpandProperty TABLE_NAME
# Checking
IF($SQLTableList -match $SQLTable){$SQLTableExists = $TRUE}ELSE{$SQLTableExists = $FALSE}
##########################
# SQL - Creating table if doesn't exist
##########################
IF($SQLTableExists -eq $FALSE)
{
# Logging
Write-Host "----------------------------------
SQLTableNotFound
CreatingSQLTable: $SQLTable"
Start-Sleep 3
# SQL query
$SQLCreateTable = "USE $SQLDB;
CREATE TABLE [dbo].[$SQLTable](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
    [RSCInstance] [varchar](max) NULL,
	[EventID] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
	[ObjectID] [varchar](max) NULL,
	[ObjectCDMID] [varchar](max) NULL,
	[ObjectType] [varchar](max) NULL,
    [Location] [varchar](max) NULL,
	[DateUTC] [datetime] NULL,
	[Type] [varchar](max) NULL,
	[Status] [varchar](50) NULL,
	[Message] [varchar](max) NULL,
	[JobStartUTC] [datetime] NULL,
	[JobEndUTC] [datetime] NULL,
	[Duration] [varchar](50) NULL,
	[DurationSeconds] [varchar](50) NULL,
	[ErrorCode] [varchar](50) NULL,
	[ErrorMessage] [varchar](max) NULL,
	[ErrorReason] [varchar](max) NULL,
    [IsOnDemand] [varchar](5) NULL,
    [IsLogBackup] [varchar](5) NULL,
	[Exported] [varchar](50) NULL,
 CONSTRAINT [PK_$SQLTable] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];"
# Run SQL query
Try
{
Invoke-SQLCmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
}
Catch
{
$Error[0] | Format-List -Force
}
# End of SQL table creation below
}
# End of SQL table creation above

# Creating query
$SQLTableListQuery = "USE $SQLDB;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;"
# Run SQL query
Try
{
$SQLTableList = Invoke-SQLCmd -Query $SQLTableListQuery -ServerInstance $SQLInstance -QueryTimeout 300 
}
Catch
{
$Error[0] | Format-List -Force
}
# Selecting
$SQLTableList = $SQLTableList | Select-Object -ExpandProperty TABLE_NAME
# Checking
IF($SQLTableList -match $SQLTable){$SQLTableExists = $TRUE}ELSE{$SQLTableExists = $FALSE}
# Message
$Message = "RSCEventsTableCreated: $SQLTableExists"
# Returning null
Return $Message
# End of function
}