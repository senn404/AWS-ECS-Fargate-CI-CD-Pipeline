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
    root_volume_size = number
  }))

  default = {
    "jenkins" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/jenkins.sh"
      tags = {
        Name = "jenkins"
      }
      root_volume_size = 20
    }

    "sonar-qube" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/sonar-qube.sh"
      tags = {
        Name = "sonar-qube"
      }
      root_volume_size = 20
    }

    "nexus" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/nexus.sh"
      tags = {
        Name = "nexus"
      }
      root_volume_size = 20
    }

    grafana = {
      instance_type = "t3.small"
      script_file   = "ec2-install/grafana.sh"
      tags = {
        Name = "grafana"
      }
      root_volume_size = 20
    }
  }
  
}

resource "aws_instance" "server" {
  ami                         = "ami-02fb5ef6a4a46a62d"  
  for_each                    = var.server_definitions

  instance_type               = each.value.instance_type
  key_name                    = aws_key_pair.ec2-server.key_name
  vpc_security_group_ids      = [aws_security_group.ec2-server-sg.id]
  subnet_id                   = data.aws_subnets.public.ids[0]

  associate_public_ip_address = true
  user_data_base64            = filebase64(each.value.script_file)  
  tags                        = merge(each.value.tags, { "Project" = "ECS-Deployer" })

  root_block_device {
    volume_size = each.value.root_volume_size
    volume_type = "gp3"
    delete_on_termination = true
  }
}

 
