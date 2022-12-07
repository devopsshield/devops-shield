// MIT License

// Copyright (c) 2022 DevOps Shield

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

targetScope = 'subscription'

param resourceGroupName string
param location string
param tempResourceGroupName string = 'rg-temp-devopsshield-calculate-unique-string-${uniqueString(subscription().id)}'

var resourceGroupId = '${subscription().id}/resourceGroups/${resourceGroupName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: tempResourceGroupName
  location: location
}

var uniqueNameComponent = uniqueString(resourceGroupId)
var tenantId = tenant().tenantId

output uniqueStringValue string = uniqueNameComponent
output tenantId string = tenantId
output tempResourceGroupNameGenerated string = resourceGroup.name
output tempResourceGroupIdGenerated string = resourceGroup.id
