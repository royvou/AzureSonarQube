# SonarQube on Azure

These are some scripts to provision a working SonarQube LTS instance on Azure

# Getting started

- Create an .env file
- Use ```Set-PsEnv``` to set it as Environment variables for the current session
- ./Deploy-WebAppKeyvault.ps1
- ./Deploy-WebAppSonarqube

# Technologies used

- [Azure](https://azure.microsoft.com/)
- [Bicep](https://github.com/Azure/bicep)
- [Powershell Core](https://github.com/powershell/powershell)
- [Docker](https://www.docker.com/)
- [Azure CLI](https://github.com/Azure/azure-cli)
- [OpenSSL](https://www.openssl.org/)