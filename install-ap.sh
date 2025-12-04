#!/bin/bash

curl "https://www.raspberryconnect.com/images/scripts/AccessPopup.tar.gz" -o AccessPopup.tar.gz
tar -xvf ./AccessPopup.tar.gz
cd AccessPopup
sudo ./installconfig.sh
