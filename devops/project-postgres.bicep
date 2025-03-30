param location string = resourceGroup().location
param projectName string
param tags object
param sku_name string = 'Standard_B1ms'
param sku_tier string = 'Burstable'

param adminPrincipalId string

var abbrs = loadJsonContent('abbreviations.json')

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-11-01-preview' = {
  name: '${abbrs.dBforPostgreSQLServers}${uniqueString(projectName)}'
  location: location
  tags: union(tags, {
    pii: 'no_pii'
  })
  sku: {
    name: sku_name
    tier: sku_tier
  }
  properties: {
    version: '17'
    storage: {
      storageSizeGB: 32
    }
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2024-11-01-preview' = {
  name: 'demodatabase'
  parent: postgresServer
}

resource firewall_all 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-11-01-preview' = {
  name: 'allow-all-IPs'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '255.255.255.255'
  }
}

resource firewall_azure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2024-11-01-preview' = {
  name: 'allow-all-azure-internal-IPs'
  parent: postgresServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource configurations 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2024-11-01-preview' = {
  name: 'azure.extensions'
  parent: postgresServer
  properties: {
    value: 'vector'
    source: 'user-override'
  }
  dependsOn: [
    database
    firewall_all
    firewall_azure
  ]
}

resource addAadUser 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2023-03-01-preview' = {
  name: adminPrincipalId
  parent: postgresServer
  properties: {
    tenantId: subscription().tenantId
    principalType: 'User'
    principalName: 'db'
  }
  dependsOn: [
    firewall_all
    firewall_azure
    configurations
  ]
}
