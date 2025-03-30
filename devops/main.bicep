@description('Name of the project')
param projectName string = 'uzh-training'

@description('Deployment location, uses Sweden Central by default')
param location string = 'swedencentral'

param principalIds array

var tags = {
  Project: projectName
}

module acrModule './acr.bicep' = {
  name: '${deployment().name}-acrDeploy'
  params: {
    location: location
    projectName: projectName
    tags: tags
    principalIds: principalIds
  }
}

module monitorModule './monitor.bicep' = {
  name: '${deployment().name}-monitorDeploy'
  params: {
    location: location
    projectName: projectName
    principalIds: principalIds
    tags: tags
  }
}

module postgresModule './postgres.bicep' = {
  name: '${deployment().name}-postgresDeploy'
  params: {
    location: location
    projectName: projectName
    principalIds: principalIds
    tags: tags
  }
}

module oaiModule './oai.bicep' = {
  name: '${deployment().name}-oaiDeploy'
  params: {
    location: location
    projectName: projectName
    principalIds: principalIds
    tags: tags
  }
}

module appserviceModule './appservice.bicep' = {
  name: '${deployment().name}-appserviceDeploy'
  params: {
    location: location
    projectName: projectName
    tags: tags
  }
}

output acrName string = acrModule.outputs.registryName
output appInsightsConnectionString string = monitorModule.outputs.appInsightsConnectionString
