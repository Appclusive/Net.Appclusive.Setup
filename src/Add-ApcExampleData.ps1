#Requires -Modules @{ ModuleName = 'biz.dfch.PS.System.Data'; ModuleVersion = "1.1.2" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Examples/Examples/'
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
				'{5}'
				,
				{6}
            )
"@

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

$sqlCmdTextBehaviourChildBehaviourInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[BehaviourChildBehaviour]
            (
				[BehaviourId]
				,
				[ChildBehaviourId]
            )
        VALUES
            (
                {2}
                ,
                {3}
            )
"@

$sqlCmdTextBehaviourParentBehaviourInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[BehaviourParentBehaviour]
            (
				[BehaviourId]
				,
				[ParentBehaviourId]
            )
        VALUES
            (
                {2}
                ,
                {3}
            )
"@

$sqlCmdTextModelBehaviourInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[ModelBehaviour]
            (
				[ModelId]
				,
				[BehaviourId]
            )
        VALUES
            (
                {2}
                ,
                {3}
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

$sqlCmdTextModelModelAttributeInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[ModelModelAttribute]
            (
				[ModelId]
				,
				[ModelAttributeId]
            )
        VALUES
            (
                {2}
                ,
                {3}
            )
"@

$sqlCmdTextAclInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[Acl]
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
				[NoInheritance]
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
				,
				'{5}'
            )
"@

$sqlCmdTextCatalogueInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[Catalogue]
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
				[AclId]
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

$sqlCmdTextCatalogueItemInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[CatalogueItem]
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
				[CatalogueId]
				,
				[BlueprintId]
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
				,
				'{5}'
            )
"@

$sqlCmdTextBlueprintInsertTemplate = @"
    INSERT INTO [{0}].[{1}].[Blueprint]
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
				[Value]
				,
				[AclId]
				,
				[ModelId]
				,
				[XamlDefinition]
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
				,
				'{5}'
				,
				'{6}'
				,
				'{7}'
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
	$result = Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $query -As Table;
	return $result.Id;
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
		Write-Host 'START Inserting row ...';
		Invoke-SqlCmd -ConnectionString $connectionString -IntegratedSecurity:$false -Query $Query -As Default;
		Write-Host -ForegroundColor Green 'Inserting row SUCCEEDED.';
	}
	catch
	{
		Write-Warning ('Inserting row FAILED');
		Write-Warning ($Error | Out-String);
		Exit;
	}
}



# Insertion of Models
$modelTable = 'Model';
$baseModelId = 1;

if (EntityNotExisting -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition')
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition', 'ShapeBehaviourDefinition', $baseModelId, $false, 'NULL';
	InsertRow -Query $query;
}
$shapeBehaviourDefinitionModelId = GetIdOfEntityByName -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviourDefinition';
Contract-Assert($shapeBehaviourDefinitionModelId);

if (EntityNotExisting -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.Shape')
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.V001.Shape', 'Shape', $shapeBehaviourDefinitionModelId, $false, 'NULL';
	InsertRow -Query $query;
}
$shapeModelId = GetIdOfEntityByName -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.Shape';
Contract-Assert($shapeModelId);

if (EntityNotExisting -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.Rectangle')
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.V001.Rectangle', 'Rectangle', $shapeModelId, $false, 'NULL';
	InsertRow -Query $query;
}
$rectangleModelId = GetIdOfEntityByName -Table $modelTable -Name 'Net.Appclusive.Examples.Geometry.V001.Rectangle';
Contract-Assert($rectangleModelId);

if (EntityNotExisting -Table $modelTable -Name 'Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition')
{
	$query = $sqlCmdTextModelInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition', 'LocationBehaviourDefinition', $baseModelId, $false, 'NULL';
	InsertRow -Query $query;
}
$locationBehaviourDefinitionModelId = GetIdOfEntityByName -Table $modelTable -Name 'Net.Appclusive.Examples.Engine.V001.LocationBehaviourDefinition';
Contract-Assert($locationBehaviourDefinitionModelId);



# Insertion of Behaviours
$behaviourTable = 'Behaviour';
if (EntityNotExisting -Table $behaviourTable -Name 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviour')
{
	$query = $sqlCmdTextBehaviourInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviour', 'ShapeBehaviour', $shapeBehaviourDefinitionModelId;
	InsertRow -Query $query;
	
	$shapeBehaviourId = GetIdOfEntityByName -Table $behaviourTable -Name 'Net.Appclusive.Examples.Geometry.V001.ShapeBehaviour';
	Contract-Assert($shapeBehaviourId);
	
	# Behaviour parent/child relations
	$query = $sqlCmdTextBehaviourChildBehaviourInsertTemplate -f $database, $Schema, 1, $shapeBehaviourId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextBehaviourParentBehaviourInsertTemplate -f $database, $Schema, $shapeBehaviourId, 1;
	InsertRow -Query $query;
	
	# Model <-> Behaviour relations
	$query = $sqlCmdTextModelBehaviourInsertTemplate -f $database, $Schema, $shapeBehaviourDefinitionModelId, $shapeBehaviourId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelBehaviourInsertTemplate -f $database, $Schema, $shapeModelId, $shapeBehaviourId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelBehaviourInsertTemplate -f $database, $Schema, $rectangleModelId, $shapeBehaviourId;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table $behaviourTable -Name 'Net.Appclusive.Examples.Engine.V001.LocationBehaviour')
{
	$query = $sqlCmdTextBehaviourInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Engine.V001.LocationBehaviour', 'LocationBehaviour', $locationBehaviourDefinitionModelId;
	InsertRow -Query $query;
	
	$locationBehaviourId = GetIdOfEntityByName -Table $behaviourTable -Name 'Net.Appclusive.Examples.Engine.V001.LocationBehaviour';
	Contract-Assert($locationBehaviourId);
	
	# Behaviour parent/child relations
	$query = $sqlCmdTextBehaviourChildBehaviourInsertTemplate -f $database, $Schema, 1, $locationBehaviourId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextBehaviourParentBehaviourInsertTemplate -f $database, $Schema, $locationBehaviourId, 1;
	InsertRow -Query $query;
	
	# Model <-> Behaviour relations
	$query = $sqlCmdTextModelBehaviourInsertTemplate -f $database, $Schema, $rectangleModelId, $locationBehaviourId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelBehaviourInsertTemplate -f $database, $Schema, $locationBehaviourDefinitionModelId, $locationBehaviourId;
	InsertRow -Query $query;
}



# Insertion of ModelAttributes
$modelAttrTable = 'ModelAttribute';

if (EntityNotExisting -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Shape.Area')
{
	$query = $sqlCmdTextModelAttributeInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.Shape.Area', 'Area', [double].FullName;
	InsertRow -Query $query;
	
	$areaModelAttributeId = GetIdOfEntityByName -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Shape.Area';
	Contract-Assert($areaModelAttributeId);
	
	# Model <-> ModelAttribute relations
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $shapeBehaviourDefinitionModelId, $areaModelAttributeId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $shapeModelId, $areaModelAttributeId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $rectangleModelId, $areaModelAttributeId;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Shape.Vertex')
{
	$query = $sqlCmdTextModelAttributeInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.Shape.Vertex', 'Vertex', [int].FullName;
	InsertRow -Query $query;
	
	$vertexModelAttributeId = GetIdOfEntityByName -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Shape.Vertex';
	Contract-Assert($vertexModelAttributeId);
	
	# Model <-> ModelAttribute relations
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $shapeModelId, $vertexModelAttributeId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $rectangleModelId, $vertexModelAttributeId;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Rectangle.Width')
{
	$query = $sqlCmdTextModelAttributeInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.Rectangle.Width', 'Width', [int].FullName;
	InsertRow -Query $query;
	
	$widthModelAttributeId = GetIdOfEntityByName -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Rectangle.Width';
	Contract-Assert($widthModelAttributeId);
	
	# Model <-> ModelAttribute relations
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $rectangleModelId, $widthModelAttributeId;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Rectangle.Heigth')
{
	$query = $sqlCmdTextModelAttributeInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Geometry.Rectangle.Heigth', 'Heigth', [int].FullName;
	InsertRow -Query $query;
	
	$heigthModelAttributeId = GetIdOfEntityByName -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Geometry.Rectangle.Heigth';
	Contract-Assert($heigthModelAttributeId);
	
	# Model <-> ModelAttribute relations
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $rectangleModelId, $heigthModelAttributeId;
	InsertRow -Query $query;
}

if (EntityNotExisting -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Engine.Location.Name')
{
	$query = $sqlCmdTextModelAttributeInsertTemplate -f $database, $Schema, 'Net.Appclusive.Examples.Engine.Location.Name', 'Name', [string].FullName;
	InsertRow -Query $query;
	
	$locationNameModelAttributeId = GetIdOfEntityByName -Table $modelAttrTable -Name 'Net.Appclusive.Examples.Engine.Location.Name';
	Contract-Assert($locationNameModelAttributeId);
	
	# Model <-> ModelAttribute relations
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $locationBehaviourDefinitionModelId, $locationNameModelAttributeId;
	InsertRow -Query $query;
	
	$query = $sqlCmdTextModelModelAttributeInsertTemplate -f $database, $Schema, $rectangleModelId, $locationNameModelAttributeId;
	InsertRow -Query $query;
}



# Insertion of Catalogue ACL
$aclTable = 'Acl';
if (EntityNotExisting -Table $aclTable -Name 'Example Catalogue ACL')
{
	$query = $sqlCmdTextAclInsertTemplate -f $database, $Schema, 'Example Catalogue ACL', 'Example Catalogue ACL', 1, $false;
	InsertRow -Query $query;
}
$catalogueAclId = GetIdOfEntityByName -Table $aclTable -Name 'Example Catalogue ACL';
Contract-Assert($catalogueAclId);


# Insertion of Catalogue
$catalogueTable = 'Catalogue';

if (EntityNotExisting -Table $catalogueTable -Name 'Example Catalogue')
{
	$query = $sqlCmdTextCatalogueInsertTemplate -f $database, $Schema, 'Example Catalogue', 'Example Catalogue', $catalogueAclId;
	InsertRow -Query $query;
}
$catalogueId = GetIdOfEntityByName -Table $catalogueTable -Name 'Example Catalogue';
Contract-Assert($catalogueId);


# Insertion of Blueprint ACL
$aclTable = 'Acl';

if (EntityNotExisting -Table $aclTable -Name 'Shape Blueprint ACL')
{
	$query = $sqlCmdTextAclInsertTemplate -f $database, $Schema, 'Shape Blueprint ACL', 'Shape Blueprint ACL', 1, $false;
	InsertRow -Query $query;
}
$blueprintAclId = GetIdOfEntityByName -Table $aclTable -Name 'Shape Blueprint ACL';
Contract-Assert($blueprintAclId);


# Insertion of Blueprints and CatalogueItems
$blueprpintTable = 'Blueprint';
$catalogueItemTable = 'CatalogueItem';

if (EntityNotExisting -Table $blueprpintTable -Name 'Shape')
{
	$query = $sqlCmdTextBlueprintInsertTemplate -f $database, $Schema, 'Shape', 'A Shape', '{}', $blueprintAclId, $shapeModelId, $null;
	InsertRow -Query $query;
}
$blueprintId = GetIdOfEntityByName -Table $blueprpintTable -Name 'Shape';


if (EntityNotExisting -Table $catalogueItemTable -Name 'Shape')
{
	$query = $sqlCmdTextCatalogueItemInsertTemplate -f $database, $Schema, 'Shape', 'A Shape', $catalogueId, $blueprintId;
	InsertRow -Query $query;
}

$rectangleActivity = '
<Activity mc:Ignorable="sap sap2010 sads" x:Class="Net.Appclusive.Examples.RectangleActivity"
 xmlns="http://schemas.microsoft.com/netfx/2009/xaml/activities"
 xmlns:bdcc="clr-namespace:biz.dfch.CS.Commons;assembly=biz.dfch.CS.Commons"
 xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
 xmlns:mca="clr-namespace:Microsoft.CSharp.Activities;assembly=System.Activities"
 xmlns:naw="clr-namespace:Net.Appclusive.Workflows;assembly=Net.Appclusive.Workflows"
 xmlns:sads="http://schemas.microsoft.com/netfx/2010/xaml/activities/debugger"
 xmlns:sap="http://schemas.microsoft.com/netfx/2009/xaml/activities/presentation"
 xmlns:sap2010="http://schemas.microsoft.com/netfx/2010/xaml/activities/presentation"
 xmlns:sco="clr-namespace:System.Collections.ObjectModel;assembly=mscorlib"
 xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml">
  <x:Members>
    <x:Property Name="ParentItemId" Type="InArgument(x:Int64)" />
    <x:Property Name="ModelName" Type="InArgument(x:String)" />
    <x:Property Name="Configuration" Type="InArgument(bdcc:DictionaryParameters)" />
  </x:Members>
  <sap2010:ExpressionActivityEditor.ExpressionActivityEditor>C#</sap2010:ExpressionActivityEditor.ExpressionActivityEditor>
  <sap2010:WorkflowViewState.IdRef>Net.Appclusive.Examples.RectangleActivity_1</sap2010:WorkflowViewState.IdRef>
  <TextExpression.NamespacesForImplementation>
    <sco:Collection x:TypeArguments="x:String">
      <x:String>System</x:String>
      <x:String>System.Collections.Generic</x:String>
      <x:String>System.Data</x:String>
      <x:String>System.Linq</x:String>
      <x:String>System.Text</x:String>
      <x:String>biz.dfch.CS.Commons</x:String>
    </sco:Collection>
  </TextExpression.NamespacesForImplementation>
  <TextExpression.ReferencesForImplementation>
    <sco:Collection x:TypeArguments="AssemblyReference">
      <AssemblyReference>biz.dfch.CS.Commons</AssemblyReference>
      <AssemblyReference>Newtonsoft.Json</AssemblyReference>
      <AssemblyReference>System</AssemblyReference>
      <AssemblyReference>System.ComponentModel.Annotations</AssemblyReference>
      <AssemblyReference>System.ComponentModel.DataAnnotations</AssemblyReference>
      <AssemblyReference>Net.Appclusive.Public</AssemblyReference>
      <AssemblyReference>Microsoft.CSharp</AssemblyReference>
      <AssemblyReference>System.Activities</AssemblyReference>
      <AssemblyReference>System.Data</AssemblyReference>
      <AssemblyReference>System.ServiceModel</AssemblyReference>
      <AssemblyReference>System.ServiceModel.Activities</AssemblyReference>
      <AssemblyReference>System.Xaml</AssemblyReference>
      <AssemblyReference>System.Xml</AssemblyReference>
      <AssemblyReference>System.Xml.Linq</AssemblyReference>
      <AssemblyReference>Net.Appclusive.Workflows</AssemblyReference>
      <AssemblyReference>System.Core</AssemblyReference>
      <AssemblyReference>mscorlib</AssemblyReference>
      <AssemblyReference>Net.Appclusive.Examples</AssemblyReference>
    </sco:Collection>
  </TextExpression.ReferencesForImplementation>
  <Parallel sap2010:WorkflowViewState.IdRef="Parallel_1">
    <naw:BuildModel sap2010:WorkflowViewState.IdRef="BuildModel_1">
      <naw:BuildModel.Configuration>
        <InArgument x:TypeArguments="bdcc:DictionaryParameters">
          <mca:CSharpValue x:TypeArguments="bdcc:DictionaryParameters">Configuration</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.Configuration>
      <naw:BuildModel.ModelName>
        <InArgument x:TypeArguments="x:String">
          <mca:CSharpValue x:TypeArguments="x:String">ModelName</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.ModelName>
      <naw:BuildModel.ParentItemId>
        <InArgument x:TypeArguments="x:Int64">
          <mca:CSharpValue x:TypeArguments="x:Int64">ParentItemId</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.ParentItemId>
    </naw:BuildModel>
    <naw:BuildModel>
      <naw:BuildModel.Configuration>
        <InArgument x:TypeArguments="bdcc:DictionaryParameters">
          <mca:CSharpValue x:TypeArguments="bdcc:DictionaryParameters">Configuration</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.Configuration>
      <naw:BuildModel.ModelName>
        <InArgument x:TypeArguments="x:String">
          <mca:CSharpValue x:TypeArguments="x:String">ModelName</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.ModelName>
      <naw:BuildModel.ParentItemId>
        <InArgument x:TypeArguments="x:Int64">
          <mca:CSharpValue x:TypeArguments="x:Int64">ParentItemId</mca:CSharpValue>
        </InArgument>
      </naw:BuildModel.ParentItemId>
      <sap2010:WorkflowViewState.IdRef>BuildModel_2</sap2010:WorkflowViewState.IdRef>
    </naw:BuildModel>
    <sads:DebugSymbol.Symbol>d0hDOlxzcmNcTmV0LkFwcGNsdXNpdmVcc3JjXE5ldC5BcHBjbHVzaXZlLkV4YW1wbGVzXFJlY3RhbmdsZUFjdGl2aXR5LnhhbWwJMwNYDgIBATQFRBYCAQ9FBVYWAgECQQtBVAIBGDwLPFICARQ3CzdnAgEQUgtSVAIBC00LTVICAQdIC0hnAgED</sads:DebugSymbol.Symbol>
  </Parallel>
  <sap2010:WorkflowViewState.ViewStateManager>
    <sap2010:ViewStateManager>
      <sap2010:ViewStateData Id="BuildModel_1" sap:VirtualizedContainerService.HintSize="200,114" />
      <sap2010:ViewStateData Id="BuildModel_2" sap:VirtualizedContainerService.HintSize="200,114" />
      <sap2010:ViewStateData Id="Parallel_1" sap:VirtualizedContainerService.HintSize="554,160" />
      <sap2010:ViewStateData Id="Net.Appclusive.Examples.RectangleActivity_1" sap:VirtualizedContainerService.HintSize="594,240" />
    </sap2010:ViewStateManager>
  </sap2010:WorkflowViewState.ViewStateManager>
</Activity>
';
if (EntityNotExisting -Table $blueprpintTable -Name 'Rectangle')
{
	$query = $sqlCmdTextBlueprintInsertTemplate -f $database, $Schema, 'Rectangle', 'A Rectangle', '{}', $blueprintAclId, $rectangleModelId, $rectangleActivity;
	InsertRow -Query $query;
}
$blueprintId = GetIdOfEntityByName -Table $blueprpintTable -Name 'Rectangle';


if (EntityNotExisting -Table $catalogueItemTable -Name 'Rectangle')
{
	$query = $sqlCmdTextCatalogueItemInsertTemplate -f $database, $Schema, 'Rectangle', 'A Rectangle', $catalogueId, $blueprintId;
	InsertRow -Query $query;
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