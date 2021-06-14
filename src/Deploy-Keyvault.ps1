Import-Module -Name './modules/Set-PsEnv.psm1'

if (-not (Test-Path 'Env:SUBSCRIPTION_ID')) {
    Write-Error "No SubscriptionID Found, please configure an environment!"
    exit
}

$SUBSCRIPTION_ID = $Env:SUBSCRIPTION_ID
$PREFIX = "$Env:PREFIX_CUSTOMER-$Env:PREFIX_ENVIRONMENT-$Env:PREFIX_APP"
$RESOURCEGROUP_LOCATION = $Env:RESOURCEGROUP_LOCATION
$WHITELIST_IP=$ENV:WHITELIST_IP

# Wrap Array in Object so we can use SecureObject
$SECRETS = @{
    secrets = @(
        @{
            name  = 'SQLUSERNAME'
            value = 'sa' + (& openssl rand -hex 4 )
        } ,
        @{
            name  = 'SQLPASSWORD'
            # If used in an OLE DB or ODBC connection string, a login or password must not contain the following characters: [] () , ; ? * ! @ =. These characters are used to either initialize a connection or separate connection values.
            value = (& openssl rand -hex 15 ) + '#A1.' + (& openssl rand -hex 15 ).ToUpper()
        } 
    )
} 
$SECRETS_JSON = ($SECRETS | ConvertTo-Json -Compress).Replace('"', '""')  # Escape Json
az account set --subscription $SUBSCRIPTION_ID

az group create --location $RESOURCEGROUP_LOCATION --resource-group $PREFIX
az deployment group create -f ./bicep/keyvault.bicep -g $PREFIX --parameters secrets=""""$SECRETS_JSON"""" whitelistedIps=$WHITELIST_IP