#Requires -Modules @{ ModuleName = 'biz.dfch.PS.System.Data'; ModuleVersion = "1.1.2" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Installation/Setup/'
)]
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
$sqlCmdTextTenantInsert = @"
    INSERT INTO [{0}].[{1}].[Tenant]
            (
				[Id]
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
				[MappedId]
				,
				[MappedType]
				,
				[ParentId]
				,
				[Namespace]
				,
				[CustomerId]
			)
        VALUES
            (
                CONVERT(uniqueidentifier, '{2}')
                ,
				'{3}'
				,
				'{3}'
				,
				1
				,
				1
				,
                GETDATE()
                ,
                GETDATE()
                ,
				'{2}'
				,
				'Internal'
				,
                CONVERT(uniqueidentifier, '{2}')
				,
				'Net.Appclusive'
				,
				0
            )
"@

$sqlCmdTextSystemUserInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[User] ON;
    INSERT INTO [{0}].[{1}].[User]
            (
				[Id]
				,
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
				[MappedId]
				,
				[MappedType]
				,
				[Mail]
				,
				[IsHidden]
            )
        VALUES
            (
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'SYSTEM'
                ,
                'This is the system user'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				'{2}'
				,
				'Integrated'
				,
				'system@appclusive.net'
				,
				'false'
            )
    SET IDENTITY_INSERT [{0}].[{1}].[User] OFF;
"@

$sqlCmdTextRootModelInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[Model] ON;
    INSERT INTO [{0}].[{1}].[Model]
            (
				[Id]
				,
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
				[ParentId]
				,
				[IsActionModel]
				,
				[BehaviourDefinitionForId]
            )
        VALUES
            (
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'Net.Appclusive.Public.Engine.BaseModel'
                ,
                'BaseModel'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				1
				,
				'false'
				,
				1
            )
    SET IDENTITY_INSERT [{0}].[{1}].[Model] OFF;
"@

$sqlCmdTextRootBehaviourInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[Behaviour] ON;
    INSERT INTO [{0}].[{1}].[Behaviour]
            (
				[Id]
				,
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
				[BehaviourDefinitionId]
            )
        VALUES
            (
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'Net.Appclusive.Public.Engine.BaseBehaviour'
                ,
                'BaseBehaviour'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				1
            )
    SET IDENTITY_INSERT [{0}].[{1}].[Behaviour] OFF;
"@

$sqlCmdTextRootItemInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[Item] ON;
    INSERT INTO [{0}].[{1}].[Item]
            (
				[Id]
				,
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
				[ParentId]
				,
				[ModelId]
				,
				[Status]
				,
				[NoInheritance]
            )
        VALUES
            (
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'System root item'
                ,
                'This is the System root item'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				1
				,
				1
				,
				'InitialState'
				,
				'false'
            )
    SET IDENTITY_INSERT [{0}].[{1}].[Item] OFF;
"@

$sqlCmdTextRootAclInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[Acl] ON;
    INSERT INTO [{0}].[{1}].[Acl]
            (
				[Id]
				,
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
				[ParentId]
				,
				[NoInheritance]
            )
        VALUES
            (
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'System root acl'
                ,
                'This is the System root acl'
                ,
                1
                ,
                1
                ,
                GETDATE()
                ,
                GETDATE()
				,
				1
				,
				'true'
            )
    SET IDENTITY_INSERT [{0}].[{1}].[Acl] OFF;
"@

$sqlCmdTextFullControlPermissionInsert = @"
    SET IDENTITY_INSERT [{0}].[{1}].[Permission] ON;
    INSERT INTO [{0}].[{1}].[Permission]
            (
				[Id]
				,
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
                1
                ,
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                'FullControl'
                ,
                'FullControl permission'
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
    SET IDENTITY_INSERT [{0}].[{1}].[Permission] OFF;
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

# Insertion of system tenant
$Error.Clear();
try {
	Write-Host "START Inserting system tenant [sqlCmdTextTenantInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Tenant] WHERE Id = CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextTenantInsert -f $database, $Schema, '11111111-1111-1111-1111-111111111111', 'SYSTEM_TENANT';
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting system tenant SUCCEEDED.";
	}
	else
	{
		Write-Warning "System tenant already exists. Skipping ...";
	}
}
catch
{
	Write-Warning ("Inserting system tenant FAILED");
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of SYSTEM user
$Error.Clear();
try {
	Write-Host "START Inserting system user [sqlCmdTextSystemUserInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[User] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextSystemUserInsert -f $database, $Schema, $SystemUserExternalId;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting system user SUCCEEDED.";
	}
	else
	{
		Write-Warning "System user already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting system user FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of root model
$Error.Clear();
try {
	Write-Host "START Inserting root model [sqlCmdTextRootModelInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Model] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextRootModelInsert -f $database, $Schema;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting root model SUCCEEDED.";
	}
	else
	{
		Write-Warning "Root model already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting root model FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of root behaviour
$Error.Clear();
try {
	Write-Host "START Inserting root behaviour [sqlCmdTextRootBehaviourInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Behaviour] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextRootBehaviourInsert -f $database, $Schema;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting root behaviour SUCCEEDED.";
	}
	else
	{
		Write-Warning "Root behaviour already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting root behaviour FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of root item
$Error.Clear();
try {
	Write-Host "START Inserting root item [sqlCmdTextRootItemInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Item] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextRootItemInsert -f $database, $Schema;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting root item SUCCEEDED.";
	}
	else
	{
		Write-Warning "Root item already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting root item FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of root ACL
$Error.Clear();
try {
	Write-Host "START Inserting root acl [sqlCmdTextRootAclInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Acl] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextRootAclInsert -f $database, $Schema;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting root acl SUCCEEDED.";
	}
	else
	{
		Write-Warning "Root acl already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting root acl FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
}

# Insertion of FullControl Permission
$Error.Clear();
try {
	Write-Host "START Inserting FullControl permission [sqlCmdTextFullControlPermissionInsert] ...";
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query "SELECT Id FROM [$Schema].[Permission] WHERE Id = 1" -As Default;
	if($result.Count -lt 1)
	{
		$query = $sqlCmdTextFullControlPermissionInsert -f $database, $Schema;
		Write-Verbose $query;
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
		Write-Host -ForegroundColor Green "Inserting FullControl permission SUCCEEDED.";
	}
	else
	{
		Write-Warning "FullControl permission already exists. Skipping ...";
	}
}
catch
{
	Write-Warning "Inserting FullControl permission FAILED";
	Write-Warning ($Error | Out-String);
	Exit;
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