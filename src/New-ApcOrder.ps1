[CmdletBinding(
    SupportsShouldProcess = $true
	,
    ConfirmImpact = 'Medium'
	,
	HelpURI = 'http://docs.appclusive.net/en/latest/Examples/Examples/'
)]
PARAM
(
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String] $AppclusiveApiBaseUri = 'http://appclusive/api/'
	,
	[Parameter(Mandatory = $false)]
	[ValidateNotNullOrEmpty()]
	[String] $PathToPublicAssembly = 'C:\src\Net.Appclusive\src\Net.Appclusive.Public\bin\Debug\Net.Appclusive.Public.dll'
)

# Parameter validation
$AppclusiveApiBaseUri = $AppclusiveApiBaseUri.TrimEnd('/');

if(!(Test-Path($PathToPublicAssembly) -PathType Leaf))
{
	Write-Error "Net.Appclusive.Public.dll ('$PathToPublicAssembly') not found.";
	Exit;
}

Add-Type -Path $PathToPublicAssembly;

# global variables
[string] $coreEndpoint = 'Core';
[hashtable] $postHeaders = @{'Content-Type' = 'application/json'};

# Load CatalogueItem
$requestUri = "{0}/{1}/{2}?$filter=Name eq 'Example Catalogue'" -f $AppclusiveApiBaseUri, $coreEndpoint, 'Catalogues';
$result = Invoke-RestMethod -Method Get -Uri $requestUri;
Contract-Assert($result);
Contract-Assert($result.value);
$exampleCatalogue = $result.value;

$requestUri = "{0}/{1}/{2}?$filter=CatalogueId eq {3}" -f $AppclusiveApiBaseUri, $coreEndpoint, 'CatalogueItems', $exampleCatalogue.Id;
$result = Invoke-RestMethod -Method Get -Uri $requestUri;
Contract-Assert($result);
Contract-Assert($result.value);
$rectangleCatalogueItem = $result.value;

# Create Cart
$requestUri = "{0}/{1}/{2}" -f $AppclusiveApiBaseUri, $coreEndpoint, 'Carts';
$cart = [Net.Appclusive.Public.Domain.Catalogue.Cart]::new();
$cart.Name = 'MyCart';
$cart.Description = $cart.Name;
$result = Invoke-RestMethod -Method Post -Uri $requestUri -Headers $postHeaders -Body ($cart | ConvertTo-Json);

# Create CartItem
$requestUri = "{0}/{1}/{2}" -f $AppclusiveApiBaseUri, $coreEndpoint, 'CartItem';

# Create Order
$requestUri = "{0}/{1}/{2}" -f $AppclusiveApiBaseUri, $coreEndpoint, 'Orders';


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
