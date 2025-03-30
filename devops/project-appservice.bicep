param location string = resourceGroup().location

param projectName string

param tags object

var abbrs = loadJsonContent('abbreviations.json')

resource appServicePlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${abbrs.webServerFarms}${uniqueString(projectName)}'
  location: location
  tags: tags
  sku: {
    name: 'P0v3'
    capacity: 1
  }
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux
  }
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' existing = {
  name: '${abbrs.managedIdentityUserAssignedIdentities}cr-${uniqueString(projectName)}'
}

resource registry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: '${abbrs.containerRegistryRegistries}${uniqueString(projectName)}'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: '${abbrs.insightsComponents}${uniqueString(projectName)}'
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-11-01-preview' existing = {
  name: '${abbrs.dBforPostgreSQLServers}${uniqueString(projectName)}'
}

resource account 'Microsoft.CognitiveServices/accounts@2024-10-01' existing = {
  name: '${abbrs.cognitiveServicesAccounts}${uniqueString(projectName)}'
}

resource webApp 'Microsoft.Web/sites@2024-04-01' = {
  name: '${abbrs.webSitesAppService}${uniqueString(projectName)}'
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    httpsOnly: true
    publicNetworkAccess: 'Enabled'
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${registry.name}.azurecr.io/fastapi:latest'
      acrUseManagedIdentityCreds: true
      acrUserManagedIdentityID: identity.properties.clientId
      alwaysOn: true
      cors: {
        allowedOrigins: ['*']
      }
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
    }
  }

  resource settings 'config@2024-04-01' = {
    name: 'appsettings'
    properties: {
      DOCKER_ENABLE_CI: 'true'
      APPINSIGHTS_INSTRUMENTATIONKEY: appInsights.properties.ConnectionString
      PGHOST: postgresServer.properties.fullyQualifiedDomainName
      PGUSER: identity.name
      PGPORT: '5432'
      PGDATABASE: 'demodatabase'
      AZURE_OPENAI_ENDPOINT: account.properties.endpoint
      MODEL_NAME: 'gpt-4o'
      AZURE_CLIENT_ID: identity.properties.clientId
      EXCLUDE_MANAGED_IDENTITY: 'false'
    }
  }
}

resource publishingcreds 'Microsoft.Web/sites/config@2024-04-01' existing = {
  name: '${abbrs.webSitesAppService}${uniqueString(projectName)}/publishingcredentials'
}

var creds = list(publishingcreds.id, publishingcreds.apiVersion).properties.scmUri

resource hook 'Microsoft.ContainerRegistry/registries/webhooks@2020-11-01-preview' = {
  parent: registry
  location: location
  name: 'webhook' 
  properties: {
    serviceUri: '${creds}/api/registry/webhook'
    status: 'enabled'
  
    actions: [
      'push'
    ]
  }
}
