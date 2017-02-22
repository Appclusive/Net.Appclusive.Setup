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
)

# Parameter validation
$AppclusiveApiBaseUri = $AppclusiveApiBaseUri.TrimEnd('/');

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
$cart = '{
    "Id":  "0",
    "Details":  {
                    "Tid":  "00000000-0000-0000-0000-000000000000",
                    "CreatedById":  "0",
                    "ModifiedById":  "0",
                    "Created":  "\/Date(-62135596800000)\/",
                    "Modified":  "\/Date(-62135596800000)\/",
                    "RowVersion":  null
                },
    "Name":  "MyCart",
    "Description":  "MyCart"
}';

$result = Invoke-RestMethod -Method Post -Uri $requestUri -Headers $postHeaders -Body $cart;
$cartId = $result.Id;

# Create CartItem
$requestUri = "{0}/{1}/{2}" -f $AppclusiveApiBaseUri, $coreEndpoint, 'CartItem';
$cartItem = '{
    "Id":  "0",
    "Details":  {
                    "Tid":  "00000000-0000-0000-0000-000000000000",
                    "CreatedById":  "0",
                    "ModifiedById":  "0",
                    "Created":  "\/Date(-62135596800000)\/",
                    "Modified":  "\/Date(-62135596800000)\/",
                    "RowVersion":  null
                },
    "Name":  "Rectangle",
    "Description":  "Rectangle",
	"CartId": "{0}"
}' -f $cartId;

$result = Invoke-RestMethod -Method Post -Uri $requestUri -Headers $postHeaders -Body $cartItem;


# Create Order
$requestUri = "{0}/{1}/{2}/Create" -f $AppclusiveApiBaseUri, $coreEndpoint, 'Orders';

$createOrderDto = '{
    "CartId":  "{0}"
}' -f $cartId;

$result = Invoke-RestMethod -Method Post -Uri $requestUri -Headers $postHeaders -Body $createOrderDto;

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
