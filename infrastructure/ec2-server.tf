variable "server_definitions" {
  description = "CI/CD Server"
  type = map(object({
    instance_type        = string
    script_file          = string
    tags                 = map(string)
    health_check_path    = string
    root_volume_size     = number
    iam_instance_profile = optional(string, "")
  }))

  default = {
    "jenkins" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/jenkins.sh"

      iam_instance_profile = "jenkins"
      health_check_path    = "/health"
      root_volume_size     = 20

      tags = {
        Name = "jenkins"
      }
    }

    "sonar-qube" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/sonar-qube.sh"

      iam_instance_profile = "sonarqube"
      health_check_path    = "/api/system/status"
      root_volume_size     = 20

      tags = {
        Name = "sonar-qube"
      }
    }

    "grafana" = {
      instance_type = "t3.medium"
      script_file   = "ec2-install/grafana.sh"

      iam_instance_profile = "grafana"
      health_check_path    = "/api/health"
      root_volume_size     = 20

      tags = {
        Name = "grafana"
      }
    }
  }
}

variable "slave_definitions" {
  description = "CI/CD Server"
  type = map(object({
    instance_type        = string
    script_file          = string
    tags                 = map(string)
    iam_instance_profile = optional(string, "")
    root_volume_size     = number
  }))

  default = {
    "slave-1" = {
      instance_type        = "t3.medium"
      script_file          = "ec2-install/slave.sh"
      root_volume_size     = 20
      iam_instance_profile = "slave"
      tags = {
        Name = "slave"
      }
    }

    "slave-2" = {
      instance_type        = "t3.medium"
      script_file          = "ec2-install/slave.sh"
      root_volume_size     = 20
      iam_instance_profile = "slave"
      tags = {
        Name = "slave"
      }
    }
  }
}

locals {
  server_security_groups = {
    "jenkins"    = [aws_security_group.jenkins-sg.id]
    "sonar-qube" = [aws_security_group.ec2-server-sg.id]
    "grafana"    = [aws_security_group.ec2-server-sg.id]
  }
}

resource "aws_instance" "server" {
  ami      = "ami-02fb5ef6a4a46a62d"
  for_each = var.server_definitions

  instance_type = each.value.instance_type

  vpc_security_group_ids = local.server_security_groups[each.key]
  subnet_id              = aws_subnet.public-subnet-1a.id

  associate_public_ip_address = true
  user_data_base64            = filebase64(each.value.script_file)
  tags                        = merge(each.value.tags, { "Project" = "ECS-CI/CD" })
  iam_instance_profile        = each.value.iam_instance_profile

  root_block_device {
    volume_size           = each.value.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

resource "aws_instance" "slave" {
  ami      = "ami-02fb5ef6a4a46a62d"
  for_each = var.slave_definitions

  instance_type = each.value.instance_type

  vpc_security_group_ids = [aws_security_group.slave-sg.id]
  subnet_id              = aws_subnet.public-subnet-1a.id

  associate_public_ip_address = true
  user_data_base64            = filebase64(each.value.script_file)
  iam_instance_profile        = each.value.iam_instance_profile

  tags = merge(each.value.tags, { "Project" = "ECS-CI/CD" })

  root_block_device {
    volume_size           = each.value.root_volume_size
    volume_type           = "gp3"
    delete_on_termination = true
  }
}

