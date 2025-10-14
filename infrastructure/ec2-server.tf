resource "aws_key_pair" "ec2-server" {
  key_name   = "ec2-key-pair"
  public_key = file("~/.ssh/ec2-server.pub")
}

resource "aws_instance" "server" {
  ami                         = "ami-088d74defe9802f14" 
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.ec2-server.key_name
  vpc_security_group_ids      = [aws_security_group.jenkins-sg.id]
  associate_public_ip_address = true

  user_data = file("ec2-install/jenkins.sh")

  tags = {
    Name = "Jenkins-Server"
  }
}


     