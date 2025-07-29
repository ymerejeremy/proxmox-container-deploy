#!/usr/bin/bash

apt update -y
apt install -y curl zip unzip

curl -s "https://get.sdkman.io" | bash
source "/root/.sdkman/bin/sdkman-init.sh"
sdk install java 8.0.462-amzn
java -version
