#!/bin/bash
# Cập nhật các gói đã cài đặt
sudo yum update -y

# Cài đặt Docker
sudo yum install docker -y

# Khởi động dịch vụ Docker
sudo systemctl start docker

# Thêm người dùng ec2-user vào nhóm docker để có thể chạy lệnh docker mà không cần sudo
# Điều này giúp Jenkins container có thể tương tác với Docker daemon
sudo usermod -aG docker ec2-user

# Bật Docker để tự động khởi động cùng hệ thống
sudo systemctl enable docker

# TẠO THƯ MỤC LƯU TRỮ DỮ LIỆU CHO JENKINS (RẤT QUAN TRỌNG)
# Dữ liệu của Jenkins (jobs, plugins, configurations) sẽ được lưu ở đây,
# ngay cả khi container bị xóa hoặc khởi động lại.
mkdir -p /home/ec2-user/jenkins_home
sudo chown -R 1000:1000 /home/ec2-user/jenkins_home
docker run -d \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /home/ec2-user/jenkins_home:/var/jenkins_home \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --name jenkins \
  jenkins/jenkins:lts-jdk17