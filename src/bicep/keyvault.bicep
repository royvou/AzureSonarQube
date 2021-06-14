param location string = resourceGroup().location
param prefix string = resourceGroup().name

var keyVaultName = '${prefix}-kv'
var tenantId = subscription().tenantId

@secure()
param secrets object
param whitelistedIps array = []


resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption:false
    tenantId: tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: [     
    ]
    enableSoftDelete: true
    enablePurgeProtection: true
    /*
    https://docs.microsoft.com/en-us/azure/app-service/app-service-key-vault-references#access-network-restricted-vaults
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'    
      ipRules:  [for (ip, index) in whitelistedIps: {      
          value: ip        
      }]
    }
    */
  }
}

@batchSize(1)
resource keyvaultSecrets 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = [for secret in secrets.secrets: if (secret.name != '') {
  name: '${keyVaultName}/${secret.name}'
  properties: {
    value: secret.value
  }
  dependsOn: [
    keyVault
  ]
}]


output keyVaultUri string = keyVault.properties.vaultUri
