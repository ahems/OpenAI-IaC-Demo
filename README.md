# OpenAI-IaC-Demo

# install CLI:
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Auto-install extensions:
az config set extension.use_dynamic_install=yes_without_prompt

# Login to Azure:
az login --use-device-code

# Make scripts executable:
chmod +x vnet.azcli
chmod +x acr.azcli
chmod +x cogsvs.azcli
chmod +x storage.azcli
chmod +x vm.azcli
chmod +x kv.azcli
chmod +x aml.azcli
chmod +x delete.azcli
chmod +x role.azcli
chmod +x deploy.sh
chmod +x rg.azcli
chmod +x role-assign.azcli
chmod +x ./delete-then-deploy.sh

# Deploy:
./deploy.sh

# Clean Up first then Deploy:
./delete-then-deploy.sh

# Clean Up
./delete.azcli
