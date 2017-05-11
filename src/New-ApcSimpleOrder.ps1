#Requires -Modules @{ ModuleName = 'Net.Appclusive.PS.Client'; ModuleVersion = "4.0.2" }

[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Examples/'
)]
PARAM
(
	[Parameter(Mandatory = $false)]
	[Hashtable] $Svc = (Enter-ApcServer -UseModuleContext)
)


# load Catalogue & CatalogueItem
$filterQuery = "Name eq 'Example Catalogue'";
$exampleCatalogue = [Net.Appclusive.Api.DataServiceQueryExtensions]::Filter($Svc.Core.Catalogues, $filterQuery) | Select;
Contract-Assert($exampleCatalogue);

$filterQuery = "CatalogueId eq {0} and Name eq 'Shape'" -f $exampleCatalogue.Id;
$shapeCatalogueItem = [Net.Appclusive.Api.DataServiceQueryExtensions]::Filter($Svc.Core.CatalogueItems, $filterQuery) | Select;
Contract-Assert($shapeCatalogueItem);


# create Cart
$cart = [Net.Appclusive.Public.Domain.Order.Cart]::new();
$cart.Name = "MyCart";
$cart.Description = $cart.Name;
$Svc.Core.AddToCarts($cart);
$result = $Svc.Core.SaveChanges();
Contract-Assert($result);
Contract-Assert($result.StatusCode -eq 201);


# create CartItem
$cartItem = [Net.Appclusive.Public.Domain.Order.CartItem]::new();
$cartItem.Name = "Shape";
$cartItem.Description = $cartItem.Name;
$cartItem.CartId = $cart.Id;
$cartItem.CatalogueItemId = $shapeCatalogueItem.Id;

$idValuePair1 = [Net.Appclusive.Public.Types.IdValuePair]::new();
$idValuePair1.Id = 1;
$idValuePair1.Value = "1764.00";

$idValuePair2 = [Net.Appclusive.Public.Types.IdValuePair]::new();
$idValuePair2.Id = 2;
$idValuePair2.Value = "42";

$cartItem.Configuration.Add($idValuePair1);
$cartItem.Configuration.Add($idValuePair2);

$Svc.Core.AddToCartItems($cartItem);
$result = $Svc.Core.SaveChanges();
Contract-Assert($result);
Contract-Assert($result.StatusCode -eq 201);


# create Order
$createOrderDto = @{};
$createOrderDto.CartId = $cart.Id;
# DFTODO - adjust to tenant root item id (retrieved via TenantInformation)
$createOrderDto.ParentItemId = "1";
$orderJob = $Svc.Core.InvokeEntitySetActionWithSingleResult("Orders", "Create", [Net.Appclusive.Public.Domain.Control.Job], $createOrderDto);


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
