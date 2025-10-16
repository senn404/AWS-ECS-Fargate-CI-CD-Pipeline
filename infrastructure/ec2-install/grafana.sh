#!/bin/bash
sudo dnf update -y

sudo dnf install docker -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo systemctl enable docker

docker run -d \
  --name grafana \
  -p 8080:3000 \
  -v grafana_data:/var/lib/grafana \
  --restart always \
  grafana/grafana:latest