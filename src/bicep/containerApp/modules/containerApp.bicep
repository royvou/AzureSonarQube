param containerAppName string
param location string
param containerAppenvironmentid string
param sonarImage string
@secure()
param sonarJdbcUrl string
@secure()
param sonarJdbcUsername string
@secure()
param sonarJdbcPassword string

resource containerApp 'Microsoft.Web/containerapps@2021-03-01' = {
  name: containerAppName
  location: location
  kind: 'containerapps'
  properties: {
    kubeEnvironmentId: containerAppenvironmentid
    configuration: {
      activeRevisionsMode: 'Single'
      secrets: [
        {
          // Secrests must be lowercase :/ 
          name: 'sonarjdbcurl'
          value: sonarJdbcUrl
        }
        {
          name: 'sonarjdbcusername'
          value: sonarJdbcUsername
        }
        {
          name: 'sonarjdbcpassword'
          value: sonarJdbcPassword
        }
      ]
      registries: []
      ingress: {
        external: true
        targetPort: 9000
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'sonarqube'
          image: sonarImage
          env: [
            {
              name: 'SONAR_JDBC_URL'
              secretref: 'sonarjdbcurl'
            }
            {
              name: 'SONAR_JDBC_USERNAME'
              secretref: 'sonarjdbcusername'
            }
            {
              name: 'SONAR_JDBC_PASSWORD'
              secretref: 'sonarjdbcpassword'
            }
            {
              name: 'SONAR_SEARCH_JAVAADDITIONALOPTS'
              value: '-Dnode.store.allow_mmap=false'
            }
          ]
          command: []
          resources: {
            cpu: '2'
            memory: '4Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}
