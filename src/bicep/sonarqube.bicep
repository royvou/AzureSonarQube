param location string = resourceGroup().location
param prefix string = resourceGroup().name

@allowed([
  'F1'
  'B1'
  'B2'
  'B3'
  'S1'
  'S2'
  'S3'
  'P1V2'
  'P2V2'
  'P3V2'
  'P1V3'
  'P2V3'
  'P3V3'
])
param hostingPlanskuName string = 'P1V3'

@minValue(1)
param hostingPlanSkuCapacity int = 1

@minValue(10)
param sqlServerSkuDtu int = 10

param sqlServerDatabaseSize int = 10737418240 //10 GB
param sqlServerCollation string = 'SQL_Latin1_General_CP1_CS_AS'

@allowed([
'Standard_LRS' 
'Standard_GRS'
'Standard_RAGRS'
'Standard_ZRS'
'Premium_LRS'
'Premium_ZRS'
'Standard_GZRS'
'Standard_RAGZRS'
])
param storageSkuName string = 'Standard_LRS'

param storageFileShareAccessTier string = 'TransactionOptimized'

@allowed([
  'lts-community'
  'lts-developer'
  'lts-enterprise'
  'lts-datacenter'
  'lts'
])
param sonarqubeTag string = 'lts-community'

param whitelistedIps array = []

var hostingPlanName = '${prefix}-asp'
var webSiteName = '${prefix}-app'
var sqlserverName = '${prefix}-sql'
var databaseName = '${prefix}-sql-db'
var storageName = '${prefix}-storage'
var storageNameTidy = replace(storageName, '-', '')
var fileShareNames = [
  'data'
  'logs'
  'extensions'
]
var dockerImageWithTag = 'sonarqube:${sonarqubeTag}'
var linuxFxVersion = 'DOCKER|${dockerImageWithTag}'
var keyvaultName = '${prefix}-kv'

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' existing = {
  name: keyvaultName
}

resource keyvaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2021-04-01-preview' = {
  name: '${keyVault.name}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: webSite.identity.tenantId
        objectId: webSite.identity.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

// Save the secret in KV :) 
resource keyVaultSecretUri 'Microsoft.KeyVault/vaults/secrets@2021-04-01-preview' = {
  name: '${keyVault.name}/SQLJDBCCONNECTIONSTRING'
  properties: {
    value: 'jdbc:sqlserver://${sqlserver.outputs.fullyQualifiedDomainName};databaseName=${databaseName}'
  }
}
//encrypt=true;trustServerCertificate=false;hostNameInCertificate=*${environment().suffixes.sqlServerHostname}loginTimeout=30

module sqlserver './modules/sqlServer.bicep' = {
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

resource sqlserverName_AllowAllWindowsAzureIps 'Microsoft.Sql/servers/firewallRules@2021-02-01-preview' = {
  name: '${sqlserver.name}/AllowAllWindowsAzureIps'
  properties: {
    endIpAddress: '0.0.0.0'
    startIpAddress: '0.0.0.0'
  }
}

// Web App resources
resource hostingPlan 'Microsoft.Web/serverfarms@2021-01-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: hostingPlanskuName
    capacity: hostingPlanSkuCapacity
  }
  properties: {
    reserved: true 
  }
  kind: 'linux'
}

resource storage 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: storageNameTidy
  kind: startsWith(storageSkuName, 'Premium') ? 'FileStorage' :  'StorageV2'
  location: location
  sku: {
    name: storageSkuName
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    /*
    Doesn't work with BYOS :( 
    networkAcls: {      
      bypass: 'AzureServices' 
      defaultAction: 'Deny'
      ipRules: [for (ip, index) in whitelistedIps: {
        action: 'Allow'
         value: ip
      }]
    } 
    */ 
  }
}

resource fileshares 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-04-01' = [for fileShare in fileShareNames: {
  name: '${storage.name}/default/${fileShare}'
  properties: {
    accessTier: storageFileShareAccessTier
    shareQuota: 10 //GB
  }
}]

resource webSite 'Microsoft.Web/sites@2021-01-01' = {
  name: webSiteName
  location: location
  kind: 'app,linux,container'
  properties: {
    serverFarmId: hostingPlan.id
    httpsOnly: true
    clientAffinityEnabled: false
    siteConfig: {
      acrUseManagedIdentityCreds: false
      minTlsVersion: '1.2'
      http20Enabled: true
      webSocketsEnabled: true
      alwaysOn: true
      linuxFxVersion: linuxFxVersion
      httpLoggingEnabled: true
      logsDirectorySizeLimit: 35 //MB
      ipSecurityRestrictions: [for (ip, i) in whitelistedIps: {
        name: ip
        ipAddress: '${ip}/32'
        priority: i
      }]
      azureStorageAccounts: {
        '1': {
          type: 'AzureFiles'
          mountPath: '/opt/sonarqube/data'
          shareName: 'data'
          accountName: storageNameTidy
          accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
        }
        '2': {
          type: 'AzureFiles'
          mountPath: '/opt/sonarqube/logs'
          shareName: 'logs'
          accountName: storageNameTidy
          accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
        }
        '3': {
          type: 'AzureFiles'
          mountPath: '/opt/sonarqube/extensions'
          shareName: 'extensions'
          accountName: storageNameTidy
          accessKey: listKeys(storage.id, storage.apiVersion).keys[0].value
        }
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
  }
  dependsOn: [
    fileshares
  ]
}

resource webSiteConnectionStrings 'Microsoft.Web/sites/config@2021-01-01' = {
  name: '${webSite.name}/appsettings'
  properties: {
    SONAR_JDBC_URL: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=SQLJDBCCONNECTIONSTRING)'
    SONAR_JDBC_USERNAME: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=SQLUSERNAME)'
    SONAR_JDBC_PASSWORD: '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=SQLPASSWORD)'
    // workaround for Docker Host Requirements (ElasticSearch)
    // https://www.elastic.co/guide/en/cloud-on-k8s/master/k8s-virtual-memory.html#k8s-virtual-memory
    // Not recommended for production usage! (So AKS might be beter for that, since we can't change it on a WebApp)
    SONAR_SEARCH_JAVAADDITIONALOPTS: '-Dnode.store.allow_mmap=false'
    DOCKER_REGISTRY_SERVER_URL: 'https://index.docker.io/v1"'
  }
}

output webSiteUri string = webSite.properties.defaultHostName
