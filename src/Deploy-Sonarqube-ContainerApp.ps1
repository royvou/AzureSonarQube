Import-Module -Name './modules/Set-PsEnv.psm1'

if (-not (Test-Path 'Env:SUBSCRIPTION_ID')) {
    Write-Error "No SubscriptionID Found, please configure an environment!"
    exit
}

$SUBSCRIPTION_ID = $Env:SUBSCRIPTION_ID
$PREFIX = "$Env:PREFIX_CUSTOMER-$Env:PREFIX_ENVIRONMENT-$Env:PREFIX_APP"
$RESOURCEGROUP_LOCATION = $Env:RESOURCEGROUP_LOCATION
$WHITELIST_IP = $ENV:WHITELIST_IP

az account set --subscription $SUBSCRIPTION_ID

az group create --location $RESOURCEGROUP_LOCATION --resource-group $PREFIX
az deployment group create -f .\bicep\containerApp\deploy.bicep -g $PREFIX --parameters prefix=$PREFIX whitelistedIps=$WHITELIST_IP