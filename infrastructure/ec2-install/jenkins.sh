#!/bin/bash
sudo dnf update -y

sudo dnf install docker -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo systemctl enable docker

# Run Jenkins container
docker run -d \
  --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --restart always \
  jenkins/jenkins:lts-jdk21