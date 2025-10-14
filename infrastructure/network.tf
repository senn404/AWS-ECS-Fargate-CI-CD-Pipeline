data "aws_vpc" "default" {
  default = true
}

data "aws_subnet" "public" {
  availability_zone = "ap-southeast-1b"
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "default-for-az"
    values = [true]
  }
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

resource "aws_eip" "ec2-server-eip" {
  for_each = aws_instance.server
  instance = each.value.id
  domain = "vpc"
  tags = {
    Name = "EIP-${each.key}"
  } 
}

resource "aws_eip_association" "ec2-server-eip-assoc" {
  for_each = aws_instance.server
  instance_id = each.value.id
  allocation_id = aws_eip.ec2-server-eip[each.key].id
}