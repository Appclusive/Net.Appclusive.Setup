#Requires -Modules @{ ModuleName = 'Net.Appclusive.PS.Client'; ModuleVersion = "4.0.0" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Installation/Onboarding/#tenant-onboarding'
)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
PARAM
(
	[Parameter(Mandatory = $true, Position = 0)]
	[Guid] $Id
	,
	[Parameter(Mandatory = $true, Position = 1)]
	[ValidateNotNullOrEmpty()]
	[string] $MappedId
	,
	[Parameter(Mandatory = $true, Position = 2)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
	[string] $Name
	,
	[Parameter(Mandatory = $true, Position = 3)]
	[String] $Namespace
	,
	[Parameter(Mandatory = $false, Position = 4)]
	[Guid] $ParentId = [guid]::Parse('11111111-1111-1111-1111-111111111111')
	,
	[Parameter(Mandatory = $false)]
	[string] $TenantDescription = $Name
	,
	[Parameter(Mandatory = $false)]
	[string] $MappedType = 'External'
	,
	[Parameter(Mandatory = $false)]
	[Int64] $CustomerId = 0
)

trap { Log-Exception $_; break; }

# Default variables
[string] $adminUserMappedType = 'Integrated';
[string] $systemMailAddress = 'system@appclusive.net';

[string] $fn = $MyInvocation.MyCommand.Name;
$dateBegin = [datetime]::Now;


Log-Debug -fn $fn -msg ("CALL. Started: '{0}'" -f $dateBegin) -fac 1;

$svc = Enter-ApcServer -UseModuleContext;
Contract-Requires ($svc.Core -is [Net.Appclusive.Api.Core.Core]);
Contract-Requires ($svc.Diagnostics -is [Net.Appclusive.Api.Diagnostics.Diagnostics]);

# check if tenant name already exists
$tenant = Get-ApcTenant -Name $Name;
Contract-Assert (!$tenant) -Message "Tenant with specified name already exists.";

# check if combination of MappedId and MappedType already exists
$filterQuery = "(MappedId eq '{0}') and MappedType eq '{1}'" -f $MappedId, $MappedType;
$tenant = [Net.Appclusive.Api.DataServiceQueryExtensions]::Filter($svc.Core.Tenants, $filterQuery) | Select;
Contract-Assert (!$tenant) -Message "Mapping (MappedId/MappedType) already in use.";

# Functions
function New-ApcTenant
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[Guid] $Id
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[string] $MappedId
		,
		[Parameter(Mandatory = $true, Position = 2)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 3)]
		[string] $Namespace
		,
		[Parameter(Mandatory = $false, Position = 4)]
		[Guid] $ParentId = [guid]::Parse('11111111-1111-1111-1111-111111111111')
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[string] $MappedType = 'External'
		,
		[Parameter(Mandatory = $false)]
		[Int64] $CustomerId = 0
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$tenant = [Net.Appclusive.Public.Domain.Identity.Tenant]::new();
	$tenant.Id = $Id;
	$tenant.MappedId = $MappedId;
	$tenant.Name = $Name;
	$tenant.Namespace = $Namespace;
	$tenant.ParentId = $ParentId;
	$tenant.Description = $Description;
	$tenant.MappedType = $MappedType;
	$tenant.CustomerId = $CustomerId;
	
	$Svc.Core.AddToTenants($tenant);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $tenant;
}

function New-ApcUser
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { [mailaddress]::new($_) } ) ]
		[string] $Mail
		,
		[Parameter(Mandatory = $true, Position = 2)]
		[ValidateNotNullOrEmpty()]
		[string] $MappedId
		,
		[Parameter(Mandatory = $true, Position = 3)]
		[string] $MappedType
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$user = [Net.Appclusive.Public.Domain.Identity.User]::new();
	$user.Name = $Name;
	$user.Mail = $Mail;
	$user.MappedId = $MappedId;
	$user.MappedType = $MappedType;
	$user.Description = $Description;
	
	$Svc.Core.AddToUsers($user);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $user;
}

function New-ApcRole
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateSet('Default', 'Security', 'Distribution', 'Builtin', 'External')]
		[string] $Type
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$role = [Net.Appclusive.Public.Domain.Security.Role]::new();
	$role.Name = $Name;
	$role.Type = $Type;
	$role.Description = $Description;
	
	$Svc.Core.AddToRoles($role);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $role;
}

function New-ApcItem
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $ParentId
		,
		[Parameter(Mandatory = $true, Position = 2)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $ModelId
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$item = [Net.Appclusive.Public.Domain.Inventory.Item]::new();
	$item.Name = $Name;
	$item.ParentId = $ParentId;
	$item.ModelId = $ModelId;
	$item.Description = $Description;
	
	$Svc.Core.AddToItems($item);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $item;
}

function New-ApcAcl
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $ParentId
		,
		[Parameter(Mandatory = $false)]
		[switch] $NoInheritance = $false
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$acl = [Net.Appclusive.Public.Domain.Security.Acl]::new();
	$acl.Name = $Name;
	$acl.ParentId = $ParentId;
	$acl.NoInheritance = $NoInheritance;
	$acl.Description = $Description;
	
	$Svc.Core.AddToAcls($acl);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $acl;
}

function New-ApcAce
{
	[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseShouldProcessForStateChangingFunctions", "")]
	PARAM
	(
		[Parameter(Mandatory = $true, Position = 0)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $AclId
		,
		[Parameter(Mandatory = $true, Position = 1)]
		[ValidateNotNullOrEmpty()]
		[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
		[string] $Name
		,
		[Parameter(Mandatory = $true, Position = 2)]
		[ValidateSet('Audit', 'Alarm', 'Deny', 'Allow', 'Ingress', 'Egress')]
		[string] $Type
		,
		[Parameter(Mandatory = $true, Position = 3)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $PermissionId
		,
		[Parameter(Mandatory = $false)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $RoleId
		,
		[Parameter(Mandatory = $false)]
		[ValidateRange(1, [long]::MaxValue)]
		[long] $UserId
		,
		[Parameter(Mandatory = $false)]
		[string] $Description = $Name
		,
		[Parameter(Mandatory = $false)]
		[hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
	)
	
	$ace = [Net.Appclusive.Public.Domain.Security.Ace]::new();
	$ace.AclId = $AclId;
	$ace.Name = $Name;
	$ace.Type = $Type;
	$ace.PermissionId = $PermissionId;
	if ($RoleId -gt 0)
	{
		$ace.RoleId = $RoleId;
	}
	if ($UserId -gt 0)
	{
		$ace.UserId = $UserId;
	}
	$ace.Description = $Description;
	
	$Svc.Core.AddToAces($ace);
	$response = $Svc.Core.SaveChanges();
	Contract-Assert ($response.StatusCode -eq 201);
	
	return $ace;
}

try {
	# create tenant
	Write-Host "START Creating tenant ...";
	$tenant = New-ApcTenant -Id $Id -MappedId $MappedId -Name $Name -Namespace $Namespace -ParentId $ParentId -Description $TenantDescription -MappedType $MappedType -Svc $svc;
	Write-Host -ForegroundColor Green "Creating tenant SUCCEEDED.";

	# create tenant administrator user
	Write-Host "START Creating tenant administrator user ...";
	$adminUserMappedId = '{0} Admin' -f $Name;
	$svc.Core.TenantId = $Id;
	$tenantAdminUser = New-ApcUser -Name $adminUserMappedId -Mail $systemMailAddress -MappedId $adminUserMappedId -MappedType $adminUserMappedType -Svc $svc;
	Write-Host -ForegroundColor Green "Creating tenant administrator user SUCCEEDED.";

	# create tenant builtIn roles
	$builtInRoleNames = @('TenantAdmin', 'TenantUser', 'TenantGuest', 'TenantEveryone');
	foreach ($builtInRoleName in $builtInRoleNames)
	{
		Write-Host ("START Creating {0} role ..." -f $builtInRoleName);
		$role = New-ApcRole -Name $builtInRoleName -Type Builtin -Svc $svc;
		# DFTODO - change createdById?
		Write-Host -ForegroundColor Green ("Creating {0} role SUCCEEDED." -f $builtInRoleName);
	}

	# create tenant root item
	Write-Host "START Creating root item ...";
	$itemName = '{0} root item' -f $Name;
	$rootItem = New-ApcItem -Name $itemName -ParentId 1 -ModelId 1 -Svc $svc;
	# DFTODO - set NoInheritance of Item to true
	# DFTODO - change createdById?
	Write-Host -ForegroundColor Green "Creating root item SUCCEEDED.";

	# create tenant root ACL
	Write-Host "START Creating root ACL ...";
	$aclName = "{0} root ACL" -f $Name;
	$rootAcl = New-ApcAcl -Name $aclName -ParentId 1 -NoInheritance -Svc $svc;
	# DFTODO - change createdById?
	Write-Host -ForegroundColor Green "Creating root ACL SUCCEEDED.";
	
	# create ACEs for tenant root ACL
	Write-Host "START Creating ACE for TenantAdmin role ...";
	$aceName = "{0} TenantAdmin ACE" -f $Name;
	$ace = New-ApcAce -AclId $rootAcl.Id -Name $aceName -Type Allow -PermissionId 1 -RoleId $role.Id -Svc $svc;
	# DFTODO - change createdById?
	Write-Host -ForegroundColor Green "Creating ACE for TenantAdmin role SUCCEEDED.";

	# DFTODO - verify tenant onboarding by calling tenant information
	# $tenantInfo = $svc.Core.InvokeEntityActionWithSingleResult($tenant, "Information", [Net.Appclusive.Public.Domain.Security.Identity.TenantInformation], $null);
	# Contract-Assert($null -ne $tenantInfo);
	# Contract-Assert($tenantInfo.Id -eq $tenant.Id)
}
catch [System.Management.Automation.MethodInvocationException]
{
	$exceptionHandled = $false;
	$er = $_;
	if($er.Exception.InnerException -is [System.Data.Services.Client.DataServiceRequestException])
	{
		if($er.Exception.InnerException.InnerException -is [System.Data.Services.Client.DataServiceClientException])
		{
			$odataError = $er.Exception.InnerException.InnerException.Message | ConvertFrom-Json;
			
			$erMessage = $odataError.'odata.error'.message.value;
			if($odataError.'odata.error'.innererror) 
			{ 
				$erDescription = $odataError.'odata.error'.innererror.message; 
			}
			$exceptionHandled = $true;
			Log-Error $fn ("{0} {1}" -f $erMessage, $erDescription);
		}
	}
	if(!$exceptionHandled)
	{
		throw;
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
