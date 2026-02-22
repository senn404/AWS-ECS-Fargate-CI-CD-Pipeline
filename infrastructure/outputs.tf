data "aws_instance" "server" {
  for_each    = aws_instance.server
  depends_on  = [aws_ec2_instance_state.server_state]
  instance_id = each.value.id
}

output "ec2-info" {
  description = "Thông tin chi tiết của tất cả các EC2 instance"
  depends_on  = [aws_ec2_instance_state.server_state]
  value = {
    # Bắt đầu biểu thức 'for' để lặp qua tất cả các server đã được tạo
    for key, inst in data.aws_instance.server :
    # Với mỗi inst, tạo một cặp key-value trong bản đồ output
    # 'key' là tên logic của instance (ví dụ: "jenkins")
    # '=>' theo sau là giá trị tương ứng (một object chứa thông tin)
    key => {
      id                   = inst.id
      public_ip            = inst.public_ip
      public_dns           = inst.public_dns
      private_ip           = inst.private_ip
      private_dns          = inst.private_dns
      instance_type        = inst.instance_type
      iam_instance_profile = inst.iam_instance_profile
      state                = inst.instance_state
      tags                 = inst.tags
    }
  }
}

output "slave" {
  value = {
    for key, inst in aws_instance.slave :
    key => {
      id            = inst.id
      public_ip     = inst.public_ip
      public_dns    = inst.public_dns
      private_ip    = inst.private_ip
      private_dns   = inst.private_dns
      instance_type = inst.instance_type
      state         = inst.instance_state
      tags          = inst.tags
    }
  }
}
