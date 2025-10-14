resource "aws_key_pair" "ec2-server" {
  key_name   = "ec2-key-pair"
  public_key = file("~/.ssh/ec2-server.pub")
}

variable "server_definitions" {
  description = "CI/CD Server"
  type = map(object({
    instance_type = string
    script_file = string
    tags = map(string)
  }))

  default = {
    "jenkins" = {
      instance_type = "t3.small"
      script_file   = "ec2-install/jenkins.sh"
      tags = {
        Name = "Jenkins"
      }
    }

    "sonar-qube" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/sonar-qube.sh"
      tags = {
        Name = "SonarQube"
      }
    }

    "nexus" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/nexus.sh"
      tags = {
        Name = "Nexus"
      }
    }

    grafana = {
      instance_type = "t3.small"
      script_file   = "ec2-install/grafana.sh"
      tags = {
        Name = "Grafana"
      }
    }
  }
  
}

resource "aws_instance" "server" {
  ami                         = "ami-088d74defe9802f14"  
  for_each                    = var.server_definitions

  instance_type               = each.value.instance_type
  key_name                    = aws_key_pair.ec2-server.key_name
  vpc_security_group_ids      = [aws_security_group.ec2-server.id]
  subnet_id                   = aws.subnet.public.id

  associate_public_ip_address = true
  user_data                   = file(each.value.script_file)
  tags                        = merge(each.value.tags, { "Project" = "ECS-Deployer" })
}


     