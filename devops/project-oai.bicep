param location string = resourceGroup().location
param projectName string
param tags object
param sku string = 'S0'
param adminPrincipalId string
param modelName string = 'gpt-4o'
param modelVersion string = '2024-11-20'

var abbrs = loadJsonContent('abbreviations.json')
var roles = loadJsonContent('azure-roles.json')

// Create OpenAI account
resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: '${abbrs.cognitiveServicesAccounts}${uniqueString(projectName)}'
  location: location
  tags: tags
  kind: 'OpenAI'
  properties: {
    publicNetworkAccess: 'Enabled' // Only allow access from private endpoints
    disableLocalAuth: true // Disable local authentication (i.e. no API key, only managed identity)
    customSubDomainName: uniqueString(projectName)
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
  sku: {
    name: sku
  }
}

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(adminPrincipalId, account.id)
  scope: account
  properties: {
    principalId: adminPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.CognitiveServicesUser)
  }
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}cr-${uniqueString(projectName)}'
}

resource roleAssignmentsManagedIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(identity.id, account.id)
  scope: account
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.CognitiveServicesUser)
  }
}

// Add a model deployment.
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  name: 'gpt-4o'
  parent: account
  sku: {
    capacity: 10 // capacity in thousands of TPM
    name: 'GlobalStandard'
  }
  properties: {
    model: {
      name: modelName
      version: modelVersion
      format: 'OpenAI'
    }
    raiPolicyName: 'DefaultV2'
  }
}

output accountName string = account.name
