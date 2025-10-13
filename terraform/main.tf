# Tạo key để ssh
resource "aws_key_pair" "ec2-server" {
  key_name   = "ec2-key-pair"
  public_key = file("~/.ssh/ec2-server.pub")
}

# SG cho jenkins
resource "aws_security_group" "jenkins-sg" {
  name        = "jenkins-sg"
  description = "Security group for Jenkins server"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH access" # Thêm mô tả để dễ hiểu
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Cảnh báo: Nên giới hạn IP của bạn thay vì mở cho toàn thế giới
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Lay VPC mac dinh
data "aws_vpc" "default" {
  default = true
}

# Tao ec2
resource "aws_instance" "jenkins-server" {
  ami                         = "ami-088d74defe9802f14" 
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ec2-server.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  associate_public_ip_address = true

  user_data = file("install-jenkins.sh")

  tags = {
    Name = "Jenkins-Server"
  }
}
