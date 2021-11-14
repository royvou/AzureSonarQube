param sqlserverName string
@secure()
param administratorLogin string
@secure()
param sqlAdministratorLoginPassword string

resource sqlserver 'Microsoft.Sql/servers@2021-02-01-preview' = {
  name: sqlserverName
  location: resourceGroup().location
  properties: {
    administratorLogin: administratorLogin
    administratorLoginPassword: sqlAdministratorLoginPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
    // Allow Azure services to connect
    restrictOutboundNetworkAccess: 'Enabled'
  }
}

output id string = sqlserver.id
output sqlServerName string = sqlserver.name
output fullyQualifiedDomainName string = sqlserver.properties.fullyQualifiedDomainName
