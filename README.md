# RA: https://techcommunity.microsoft.com/t5/azure-architecture-blog/azure-openai-landing-zone-reference-architecture/ba-p/3882102

# install CLI:
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Auto-install extensions:
az config set extension.use_dynamic_install=yes_without_prompt

# install Bicep
az bicep upgrade

# Login to Azure:
az login --use-device-code

LOCATION=eastus
VMPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)
ENVIRONMENT_NAME=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 24 | head -n 1)

# Deploy Hub:
az deployment sub create --location $LOCATION --template-file infra/hub.bicep --parameters infra/hub.parameters.json --parameters adminPassword=$VMPASSWORD

# Deploy Spoke:
az deployment sub create --location $LOCATION --template-file infra/spoke.bicep --parameters infra/spoke.parameters.json --parameters environmentName=$ENVIRONMENT_NAME