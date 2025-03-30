param location string = resourceGroup().location
param projectName string
param tags object

var abbrs = loadJsonContent('abbreviations.json')

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: '${abbrs.operationalInsightsWorkspaces}${uniqueString(projectName)}'
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
