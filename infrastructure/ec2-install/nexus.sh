#!/bin/bash
sudo dnf update -y

sudo dnf install docker -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo systemctl enable docker

docker run -d \
  --name nexus \
  -p 8080:8081 \
  -v nexus_data:/nexus-data \
  --restart always \
  sonatype/nexus3:latest