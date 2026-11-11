param location string
param identityName string
param issuer string
param subject string

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: identityName
  location: location
  tags: {
    'managed-by': 'vulnara-cloud-onboarding'
  }
}

resource federatedCredential 'Microsoft.ManagedIdentity/userAssignedIdentities/federatedIdentityCredentials@2023-01-31' = {
  parent: identity
  name: 'vulnara'
  properties: {
    issuer: issuer
    subject: subject
    audiences: [
      'api://AzureADTokenExchange'
    ]
  }
}

output principalId string = identity.properties.principalId
output clientId string = identity.properties.clientId
