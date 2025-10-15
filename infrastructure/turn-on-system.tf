resource "aws_ec2_instance_state" "server_state" {
  depends_on = [aws_instance.server]
  for_each = aws_instance.server
  instance_id = each.value.id
  state = "running"
}
