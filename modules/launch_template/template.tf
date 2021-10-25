resource "aws_launch_template" "magento" {
  name = "magento"
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 40
    }
  }
  disable_api_termination = true
  image_id = "ami-0747bdcabd34c712a"
  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t2.medium"
  key_name = aws_key_pair.deployer.key_name
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
  monitoring {
    enabled = true
  }
  vpc_security_group_ids = var.sg_id
  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "test"
    }
  }
  user_data = filebase64("${path.module}/inital.sh")
}
output "template-id" { value = aws_launch_template.magento.id }
output "key-pair-name" { value = aws_key_pair.deployer.key_name }
