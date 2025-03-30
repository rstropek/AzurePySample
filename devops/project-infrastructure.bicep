param projectName string
param adminPrincipalId string
param tags object

module appInsightsModule './project-appinsights.bicep' = {
  name: '${deployment().name}-appInsightsDeploy'
  params: {
    projectName: projectName
    tags: tags
  }
}

module postgresModule './project-postgres.bicep' = {
  name: '${deployment().name}-postgresDeploy'
  params: {
    projectName: projectName
    adminPrincipalId: adminPrincipalId
    tags: tags
  }
}

module oaiModule './project-oai.bicep' = {
  name: '${deployment().name}-oaiDeploy'
  params: {
    projectName: projectName
    adminPrincipalId: adminPrincipalId
    tags: tags
  }
}

module appserviceModule './project-appservice.bicep' = {
  name: '${deployment().name}-appserviceDeploy'
  params: {
    projectName: projectName
    tags: tags
  }
  dependsOn: [
    appInsightsModule
    postgresModule
    oaiModule
  ]
}
