param location string = resourceGroup().location
param prefix string = resourceGroup().name

@allowed([
  'lts-community'
  'lts-developer'
  'lts-enterprise'
  'lts-datacenter'
  'lts'
])
param sonarqubeTag string = 'lts-community'
param whitelistedIps array = []

var sonarImage = 'docker.io/sonarqube:${sonarqubeTag}'

var logAnalyticsWorkspaceName = '${prefix}-la'
var containerAppName = '${prefix}-ca'
var containerAppEnvironmentName = '${prefix}-cae'
var sqlserverName = '${prefix}-sql'
var keyvaultName = '${prefix}-kv'

@minValue(10)
param sqlServerSkuDtu int = 10
param sqlServerDatabaseSize int = 10737418240 //10 GB
var sqlServerCollation = 'SQL_Latin1_General_CP1_CS_AS'
var databaseName = '${prefix}-sql-db'

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyvaultName
}

module logAnalyticsWorkspaceRef '../modules/logAnalytics.bicep' = {
  name: logAnalyticsWorkspaceName
  params: {
    logAnalyticsWorkspaceName: logAnalyticsWorkspaceName
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-08-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerAppenvironment 'Microsoft.Web/kubeEnvironments@2021-03-01' = {
  name: containerAppEnvironmentName
  location: location
  properties: {
    type: 'managed'
    internalLoadBalancerEnabled: false
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  dependsOn: [
    logAnalyticsWorkspaceRef
  ]
}

module sqlserver '../modules/sqlServer.bicep' = {
  name: sqlserverName
  params: {
    administratorLogin: keyVault.getSecret('SQLUSERNAME')
    sqlAdministratorLoginPassword: keyVault.getSecret('SQLPASSWORD')
    sqlserverName: sqlserverName
  }
}

resource sqlserverName_databaseName 'Microsoft.Sql/servers/databases@2021-02-01-preview' = {
  name: '${sqlserver.name}/${databaseName}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
    capacity: sqlServerSkuDtu
  }
  properties: {
    collation: sqlServerCollation
    maxSizeBytes: sqlServerDatabaseSize //10 GB
  }
}

resource keyVaultSecretUri 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  name: '${keyVault.name}/SQLJDBCCONNECTIONSTRING'
  properties: {
    value: 'jdbc:sqlserver://${sqlserver.outputs.fullyQualifiedDomainName};databaseName=${databaseName}'
  }
}

module containerApp './modules/containerApp.bicep' = if (true) {
  name: containerAppName
  params: {
    containerAppenvironmentid: containerAppenvironment.id
    containerAppName: containerAppName
    location: location
    sonarJdbcUrl: keyVault.getSecret('SQLJDBCCONNECTIONSTRING')
    sonarJdbcUsername: keyVault.getSecret('SQLUSERNAME')
    sonarJdbcPassword: keyVault.getSecret('SQLPASSWORD')

    sonarImage: sonarImage
  }
  dependsOn: [
    keyVaultSecretUri
  ]
}
