#!/bin/bash

sudo dnf update -y
sudo dnf install docker -y
sudo systemctl start docker
sudo usermod -aG docker ec2-user
sudo systemctl enable docker

sudo dnf install java-17-amazon-corretto-devel -y
sudo dnf install maven -y

sudo dnf install git -y

