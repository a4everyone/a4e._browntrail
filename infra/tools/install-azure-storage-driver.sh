sudo wget -O /usr/bin/azurefile-dockervolumedriver https://github.com/Azure/azurefile-dockervolumedriver/releases/download/${AZURE_DRIVER_VER}/azurefile-dockervolumedriver && \
sudo chmod +x /usr/bin/azurefile-dockervolumedriver && \
echo -e AZURE_STORAGE_ACCOUNT=${AZURE_STORAGE_ACCOUNT}\\nAZURE_STORAGE_ACCOUNT_KEY=${AZURE_STORAGE_ACCESS_KEY} | sudo tee /etc/default/azurefile-dockervolumedriver && \
sudo wget -O /etc/systemd/system/azurefile-dockervolumedriver.service https://raw.githubusercontent.com/Azure/azurefile-dockervolumedriver/master/contrib/init/systemd/azurefile-dockervolumedriver.service && \
sudo systemctl daemon-reload && \
sudo systemctl enable azurefile-dockervolumedriver && \
sudo systemctl start azurefile-dockervolumedriver && \
sudo systemctl status azurefile-dockervolumedriver
