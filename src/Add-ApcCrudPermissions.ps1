#Requires -Modules @{ ModuleName = 'biz.dfch.PS.System.Data'; ModuleVersion = "1.1.2" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Installation/Setup/#initialise-database'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
PARAM
(
	[Parameter(Mandatory = $true, Position = 0)]
	[ValidateSet('LocalDB', 'SQLServer')]
	[String] $ConnectionType
	,
	[Parameter(Mandatory = $false)]
	[String] $AppConfig = 'C:\src\Net.Appclusive\src\Net.Appclusive.Core\app.config'
	,
	[Parameter(Mandatory = $false)]
	[String] $DataDirectory = 'C:\src\App_Data'
	,
	[Parameter(Mandatory = $false)]
	[String] $ConnectionStringKey = 'Net.Appclusive.Core.DbContext.ApcDbContext'
	,
	[Parameter(Mandatory = $false)]
	[String] $Schema = 'core'
	,
	[Parameter(Mandatory = $false)]
	[String] $SystemUserExternalId = ('{0}\{1}' -f $ENV:COMPUTERNAME, $ENV:USERNAME).ToLower()
)

if(!(Test-Path($AppConfig) -PathType Leaf))
{
	Write-Error "AppConfig '$AppConfig' not found.";
	Exit;
}

[xml] $xmlConfig = Get-Content -Raw $AppConfig;
$connectionStringEntry = $xmlConfig.Configuration.ConnectionStrings.Add |? name -eq $ConnectionStringKey;
$connectionString = $connectionStringEntry.connectionString;

switch($ConnectionType)
{
	'LocalDB'
	{
		$fReturn = $connectionString -match 'Initial Catalog=([^;]+);';
		if(!$fReturn)
		{
			Write-Error "ConnectionString '$connectionString' does not contain 'Initial Catalog'. Aborting ...";
			Exit;
		}

		$database = $Matches[1];

		if(!(Test-Path($DataDirectory) -PathType Container))
		{
			Write-Error "DataDirectory '$DataDirectory' not found. Aborting ...";
			Exit;
		}
	}
	'SQLServer'
	{
		$hasDatabaseProperty = $connectionString -match 'Database=([^;]+);';
		if($hasDatabaseProperty)
		{
			$database = $Matches[1];
		}
		$hasInitialCatalogProperty = $connectionString -match 'Initial.Catalog=([^;]+);';
		if($hasInitialCatalogProperty)
		{
			$database = $Matches[1];
		}
		if(!$hasDatabaseProperty -and !$hasInitialCatalogProperty)
		{
			Write-Error "ConnectionString '$connectionString' does not contain 'Database' or 'Initial Catalog'. Aborting ...";
			Exit;
		}
	}
	default
	{
		Write-Error "Unsupported ConnectionType '$ConnectionType'. Aborting ...";
		Exit;
	}
}

# SQL script templates
$sqlCmdTextPermissionInsert = @"
    INSERT INTO [{0}].[{1}].[Permission]
            (
				[Tid]
				,
				[Name]
				,
				[Description]
				,
				[CreatedById]
				,
				[ModifiedById]
				,
				[Created]
				,
				[Modified]
				,
				[Type]
            )
        VALUES
            (
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                '{2}'
                ,
                '{2} permission'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				0
            )
"@


# Execution of SQL scripts with biz.dfch.PS.System.Data

# Test DB connection
try
{
	Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT @@VERSION AS [Version]" -As Table;
}
catch
{
	Write-Warning "Connection to database '$database' FAILED.`r`n$_";
	Exit;
}


# Insertion of Appclusive entity CRUD permission
$domainDirectory = 'C:\src\Net.Appclusive.Public\src\Net.Appclusive.Public\Domain';
$entityNames = $fileNames -notlike "*Type";
$fileNames = Get-ChildItem $domainDirectory -Recurse -File | select -expand basename;
$entityNames = $entityNames -notlike "Public*";
$permissionNames = [System.Collections.ArrayList]::new();

foreach ($entityName in $entityNames)
{
	$canCreatePermission = "{0}CanCreate" -f $entityName;
	$null = $permissionNames.Add($canCreatePermission);
	
	$canReadPermission = "{0}CanRead" -f $entityName;
	$null = $permissionNames.Add($canReadPermission);
	
	$canUpdatePermission = "{0}CanUpdate" -f $entityName;
	$null = $permissionNames.Add($canUpdatePermission);
	
	$canDeletePermission = "{0}CanDelete" -f $entityName;
	$null = $permissionNames.Add($canDeletePermission);
}

foreach ($permissionName in $permissionNames)
{
	$Error.Clear();
	try {
		Write-Host ("START Inserting '{0}' permission [sqlCmdTextPermissionInsert] ..." -f $permissionName);
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query ("SELECT Id FROM [$Schema].[Permission] WHERE Name = '{0}'" -f $permissionName) -As Default;
		if($result.Count -lt 1)
		{
			$query = $sqlCmdTextPermissionInsert -f $database, $Schema, $permissionName;
			Write-Verbose $query;
			$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
			Write-Host -ForegroundColor Green ("Inserting '{0} 'permission SUCCEEDED." -f $permissionName);
		}
		else
		{
			Write-Warning ("'{0}' permission already exists. Skipping ..." -f $permissionName);
		}
	}
	catch
	{
		Write-Warning ("Inserting '{0}' permission FAILED" -f $permissionName);
		Write-Warning ($Error | Out-String);
	}
}


#
# Copyright 2017 d-fens GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#