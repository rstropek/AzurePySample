param location string = resourceGroup().location

param projectName string

param tags object

param principalIds array

var abbrs = loadJsonContent('abbreviations.json')
var roles = loadJsonContent('azure-roles.json')

resource registry 'Microsoft.ContainerRegistry/registries@2024-11-01-preview' = {
  name: '${abbrs.containerRegistryRegistries}${uniqueString(projectName)}'
  location: location
  tags: tags
  sku: {
    name: 'Basic'
  }
  properties: {}
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}cr-${uniqueString(projectName)}'
  location: location
  tags: tags
}

resource registryPushAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principalIds: {
    name: guid(registry.id, p, 'delete')
    scope: registry
    properties: {
      principalId: p
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.AcrPush)
    }
  }
]

resource registryDeleteAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principalIds: {
    name: guid(registry.id, p, 'push')
    scope: registry
    properties: {
      principalId: p
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.AcrDelete)
    }
  }
]

resource registryPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principalIds: {
    name: guid(registry.id, p, 'pull')
    scope: registry
    properties: {
      principalId: p
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.AcrPull)
    }
  }
]

resource registryPullAssignmentManagedIdentity 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(registry.id, '-pull')
  scope: registry
  properties: {
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.AcrPull)
  }
}

output registryName string = registry.name
