################# EC2 Network Infrastructure #################

resource "aws_vpc" "main-vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

resource "aws_subnet" "public-subnet-1a" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public-subnet-1b" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "ap-southeast-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private-subnet-1a" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "ap-southeast-1a"
}

resource "aws_subnet" "private-subnet-1b" {
  vpc_id                  = aws_vpc.main-vpc.id
  cidr_block              = "10.0.4.0/24"
  availability_zone       = "ap-southeast-1b"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main-vpc.id

  tags = {
    Name = "main-igw"
  }
}

resource "aws_route_table" "public-rt" {
  vpc_id = aws_vpc.main-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    Name = "public-rt"
  }
}

resource "aws_route_table_association" "public-subnet-1a-assoc" {
  subnet_id      = aws_subnet.public-subnet-1a.id
  route_table_id = aws_route_table.public-rt.id
}

resource "aws_route_table_association" "public-subnet-1b-assoc" {
  subnet_id      = aws_subnet.public-subnet-1b.id
  route_table_id = aws_route_table.public-rt.id
}

### Security Group
resource "aws_security_group" "ec2-server-sg" {
  name        = "ec2-server-sg"
  description = "Security group for server"
  vpc_id = aws_vpc.main-vpc.id

  ingress {
    description = "Allow web access from ALB"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
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

