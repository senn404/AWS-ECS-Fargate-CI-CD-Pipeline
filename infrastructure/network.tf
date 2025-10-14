data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "ec2-server-sg" {
  name        = "ec2-server-sg"
  description = "Security group for Jenkins server"
  vpc_id = data.aws_vpc.default.id

  ingress {
    description = "Allow Jenkins web access"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "Allow SSH access" 
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] 
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
