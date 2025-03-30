param location string = resourceGroup().location

param projectName string

param tags object

param principalIds array

var abbrs = loadJsonContent('abbreviations.json')
var roles = loadJsonContent('azure-roles.json')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${abbrs.operationalInsightsWorkspaces}${uniqueString(projectName)}'
  location: location
  tags: tags
  properties: {
    // Consider turning off public network access for ingestion if not needed.
    // Depends on the project's requirements.
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
    features: {
      disableLocalAuth: false
      enableDataExport: false
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${abbrs.insightsComponents}${uniqueString(projectName)}'
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: true // Change this setting according to your GDPR requirements
    WorkspaceResourceId: logAnalytics.id
  }
}

resource registryPushAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = [
  for p in principalIds: {
    name: guid(logAnalytics.id, p)
    scope: logAnalytics
    properties: {
      principalId: p
      roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roles.MonitoringContributor)
    }
  }
]

output appInsightsConnectionString string = appInsights.properties.ConnectionString
output workspaceName string = logAnalytics.name
