resource "aws_instance" "example_ec2" {
  ami           = var.ami_id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.example_sg.id]

  iam_instance_profile = aws_iam_instance_profile.example_profile.name

  tags = {
    Name = "example-ec2"
  }
}

# IAM Instance Profile for attaching IAM Role to EC2
resource "aws_iam_instance_profile" "example_profile" {
  name = "example-ec2-profile"
  role = aws_iam_role.example_role.name
}
