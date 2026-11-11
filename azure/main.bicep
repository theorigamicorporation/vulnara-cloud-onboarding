// Read-only access for Vulnara cloud scanning on one Azure subscription.
// Deploy at subscription scope:
//   az deployment sub create --location <region> --template-file main.bicep
// Downloaded from Vulnara, the issuer and subject defaults are already filled in.
targetScope = 'subscription'

@description('Vulnara OIDC issuer URL, as shown in Vulnara.')
param issuer string = '{{VULNARA_ISSUER}}'

@description('The subject shown in Vulnara, vulnara:conn:<connection id>.')
param subject string = '{{VULNARA_SUBJECT}}'

@description('Resource group that holds the managed identity. Created if missing.')
param resourceGroupName string = 'vulnara-scanner'

@description('Region for the resource group and the managed identity.')
param location string = deployment().location

@description('Name of the user-assigned managed identity.')
param identityName string = 'vulnara-scanner'

var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: {
    'managed-by': 'vulnara-cloud-onboarding'
  }
}

module identity 'modules/identity.bicep' = {
  name: 'vulnara-scanner-identity'
  scope: rg
  params: {
    location: location
    identityName: identityName
    issuer: issuer
    subject: subject
  }
}

resource readerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, identityName, readerRoleId)
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: identity.outputs.principalId
    principalType: 'ServicePrincipal'
    description: 'Vulnara cloud scanning, read-only'
  }
}

output tenantId string = tenant().tenantId
output clientId string = identity.outputs.clientId
output subscriptionId string = subscription().subscriptionId
