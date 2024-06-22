#!/bin/bash
sudo su
export DEBIAN_FRONTEND=non-interactive

apt-get update && apt-get upgrade -y
apt-get install -y openjdk-11-jdk apt-transport-https curl gnupg2

wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key
echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

apt-get update -y
apt-get install -y jenkins

systemctl enable jenkins
systemctl start Jenkins