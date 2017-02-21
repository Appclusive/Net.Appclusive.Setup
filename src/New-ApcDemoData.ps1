#Requires -Modules @{ ModuleName = 'biz.dfch.PS.System.Data'; ModuleVersion = "1.1.2" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Examples'
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
$sqlCmdTextBehaviourInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[Behaviour]
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
				[BehaviourDefinitionId]
            )
        VALUES
            (
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                '{2}'
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
				{4}
            )
"@

$sqlCmdTextModelInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[Model]
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
				[ParentId]
				,
				[IsActionModel]
				,
				[BehaviourDefinitionForId]
            )
        VALUES
            (
                CONVERT(uniqueidentifier, '11111111-1111-1111-1111-111111111111')
                ,
                '{2}'
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
				{4}
				,
				{5}
				,
				{6}
            )
"@

$sqlCmdTextModelAttributeInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[ModelAttribute]
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
				'{4}'
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

function GetIdOfEntityByName($Table, $Name)
{
	$query = "SELECT Id FROM [$Schema].[{0}] WHERE Name = '{1}'" -f $Table, $Name;
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Default;
	return $result;
}

function EntityNotExisting($Table, $Name)
{
	$result = GetIdOfEntityByName -Table $Table -Name $Name;
	return ($result.Count -lt 1);
}

function InsertRow($Query)
{
	$Error.Clear();
	try {
		Write-Host "START Inserting entity ...";
		$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $Query -As Default;
		Write-Host -ForegroundColor Green "Inserting entity SUCCEEDED.";
	}
	catch
	{
		Write-Warning ("Inserting entity FAILED");
		Write-Warning ($Error | Out-String);
		Exit;
	}
}

# Insertion of Models
$baseModelId = 1;

if (EntityNotExisting -Table "Model" -Name "Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition")
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition", "ShapeBehaviourDefinition", $baseModelId, $false, $null;
	InsertRow -Query $query;
}

$shapeBehaviourDefinitionId = GetIdOfEntityByName -Table "Model" -Name "Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition";
if (EntityNotExisting -Table "Model" -Name "Net.Appclusive.Examples.Geometry.V001.Shape")
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Geometry.V001.Shape", "Shape", $shapeBehaviourDefinitionId, $false, $null;
	InsertRow -Query $query;
}

$shapeId = GetIdOfEntityByName -Table "Model" -Name "Net.Appclusive.Examples.Geometry.V001.Shape";
if (EntityNotExisting -Table "Model" -Name "Net.Appclusive.Examples.Geometry.V001.Rectangle")
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Geometry.V001.Rectangle", "Rectangle", $shapeId, $false, $null;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table "Model" -Name "Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition")
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition", "LocationBehaviourDefinition", $baseModelId, $false, $null;
	InsertRow -Query $query;
}

# Insertion of Behaviours
if (EntityNotExisting -Table "Behaviour" -Name "Net.Appclusive.Examples.Geometry.V001.ShapeBehaviour")
{
	$query = $sqlCmdTextBehaviourInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Geometry.V001.ShapeBehaviour", "ShapeBehaviour", $shapeBehaviourDefinitionId;
	InsertRow -Query $query;
}

$locationBehaviourDefinitionId = GetIdOfEntityByName -Table "Model" -Name "Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition";
if (EntityNotExisting -Table "Behaviour" -Name "Net.Appclusive.Examples.Engine.V001.LocationBehaviour")
{
	$query = $sqlCmdTextBehaviourInsertTemplate -f $database, $Schema, "Net.Appclusive.Examples.Engine.V001.LocationBehaviour", "LocationBehaviour", $locationBehaviourDefinitionId;
	InsertRow -Query $query;
}

# Insertion of ModelAttributes



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