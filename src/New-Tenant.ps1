#Requires -Modules @{ ModuleName = 'Net.Appclusive.PS.Client'; ModuleVersion = "4.0.0" }
[CmdletBinding(
    SupportsShouldProcess = $true
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Installation/Onboarding/'
)]
PARAM
(
	[Parameter(Mandatory = $true, Position = 0)]
	[Guid] $Id
	,
	[Parameter(Mandatory = $true, Position = 1)]
	[ValidateNotNullOrEmpty()]
	[String] $MappedId
	,
	[Parameter(Mandatory = $true, Position = 2)]
	[ValidateNotNullOrEmpty()]
	[ValidateScript( { Contract-Assert($_ -match '^[a-zA-Z][a-zA-Z0-9 _]+$'); return $true; } ) ]
	[String] $Name
	,
	[Parameter(Mandatory = $true, Position = 3)]
	[String] $Namespace
	,
	[Parameter(Mandatory = $false, Position = 4)]
	[Guid] $ParentId = [guid]::Parse('11111111-1111-1111-1111-111111111111')
	,
	[Parameter(Mandatory = $false)]
	[String] $TenantDescription = ''
	,
	[Parameter(Mandatory = $false)]
	[String] $MappedType = 'External'
	,
	[Parameter(Mandatory = $false)]
	[Int64] $CustomerId
)

trap { Log-Exception $_; break; }

# Default variables
[string] $fn = $MyInvocation.MyCommand.Name;
$datBegin = [datetime]::Now;
Log-Debug -fn $fn -msg ("CALL. Name '{0}'" -f $Name) -fac 1;

$svc = Enter-ApcServer -UseModuleContext;
Contract-Requires ($svc.Core -is [Net.Appclusive.Api.Core.Core]);
Contract-Requires ($svc.Diagnostics -is [Net.Appclusive.Api.Diagnostics.Diagnostics]);

# 1. Check if tenant name already exists
$tenant = Get-ApcTenant -Name $Name;
Contract-Assert (!$tenant) -Message "Tenant with specified name already exists.";

# 2. Check if combination of MappedId and MappedType already exists
$filterQuery = "(MappedId eq '{0}') and MappedType eq '{1}'" -f $MappedId, $MappedType;
$tenant = [Net.Appclusive.Api.DataServiceQueryExtensions]::Filter($svc.Core.Users, $filterQuery) | Select;
Contract-Assert (!$tenant) -Message "Mapping (MappedId/MappedType) already in use.";

# 3. Create tenant
if($TenantDescription -eq '')
{
	$TenantDescription = $Name;
}

try {

	# DFTODO - Create tenant (separate function!!!)

	# DFTODO - Create tenant administrator user (separate function!!!)
	# $user = New-Object Net.Appclusive.Api.Core.User;
	# $user.MappedId = "{0} Admin" -f $Name;
	# $user.MappedType = 'Integrated';
	# $user.Name = $user.MappedId;
	# $user.Description = $user.MappedId;
	# $user.Mail = 'system@appclusive.net'
	# $svc.Core.AddToUsers($user);

	# $response = $svc.Core.SaveChanges();
	# Contract-Assert ($response.StatusCode -eq 201);

	# $adminUserId = $user.Id;
	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetTenant", @{EntityId = $adminUserId; EntitySet = "Net.Appclusive.Core.OdataServices.Core.User"; TenantId = $tenant.Id});
	# Write-Host -ForegroundColor Green "Creating tenant administrator user SUCCEEDED.";
			
	# DFTODO - Create roles (separate function!!!)
	# Write-Host "START Creating CloudAdmin role ...";
	# $cloudAdminRole = New-Object Net.Appclusive.Api.Core.Role;
	# $cloudAdminRole.RoleType = 3;
	# $cloudAdminRole.Name = 'CloudAdmin';
	# $cloudAdminRole.Description = $cloudAdminRole.Name;
	# $svc.core.AddToRoles($cloudAdminRole);
	# $response = $svc.Core.SaveChanges();
	# Contract-Assert ($response.StatusCode -eq 201);

	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetTenant", @{EntityId = $cloudAdminRole.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Role"; TenantId = $tenant.Id});
	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetCreatedBy", @{EntityId = $cloudAdminRole.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Role"; CreatedById = $adminUserId});
	# Write-Host -ForegroundColor Green "Creating CloudAdmin role SUCCEEDED.";

	# DFTODO - Create tenant root item (separate function!!!)
			
	# DFTODO - Create tenant root ACL (separate function!!!)
	# Write-Host "START Creating root ACL ...";
	# $acl = New-Object Net.Appclusive.Api.Core.Acl;
	# $acl.Name = "Root ACL [{0}]" -f $tenant.Id;
	# $acl.Description = $acl.Name;
	# $acl.EntityId = $tenantRootNode.Id;
	# $acl.EntityKindId = 1;
	# $acl.NoInheritanceFromParent = $true;
	# $svc.core.AddToAcls($acl);
	# $response = $svc.Core.SaveChanges();
	# Contract-Assert ($response.StatusCode -eq 201);

	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetTenant", @{EntityId = $acl.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Acl"; TenantId = $tenant.Id});
	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetCreatedBy", @{EntityId = $acl.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Acl"; CreatedById = $adminUserId});
	# Write-Host -ForegroundColor Green "Creating root ACL SUCCEEDED.";

	# Create ACEs for tenant root ACL
	# Write-Host "START Creating ACE for CloudAdmin role ...";
	# $ace = New-Object Net.Appclusive.Api.Core.Ace;
	# $ace.Name = "Root ACE";
	# $ace.Description = $ace.Name;
	# $ace.AclId = $acl.Id;
	# $ace.Type = 2;
	# $ace.PermissionId = 0;
	# $ace.TrusteeId = $cloudAdminRole.Id;
	# $ace.TrusteeType = 0;

	# $svc.core.AddToAces($ace);
	# $response = $svc.Core.SaveChanges();
	# Contract-Assert ($response.StatusCode -eq 201);

	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetTenant", @{EntityId = $ace.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Ace"; TenantId = $tenant.Id});
	# $svc.Core.InvokeEntitySetActionWithVoidResult("SpecialOperations", "SetCreatedBy", @{EntityId = $ace.Id; EntitySet = "Net.Appclusive.Core.OdataServices.Core.Ace"; CreatedById = $adminUserId});
	# Write-Host -ForegroundColor Green "Creating ACE for CloudAdmin role SUCCEEDED.";

	# DFTODO - Verify tenant onboarding by calling tenant information (separate function!!!)
	# $tenantInfo = $svc.Core.InvokeEntityActionWithSingleResult($tenant, "Information", [Net.Appclusive.Core.Managers.TenantManagerInformation], $null);
	# Contract-Assert($tenantInfo.Id -eq $tenant.Id)
	# Contract-Assert($null -ne $tenantInfo);

	# DFTODO Create Customer and link to Tenant -or- link existing Customer (separate function!!!)
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
