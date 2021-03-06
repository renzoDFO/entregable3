// SG
resource "aws_security_group" "frontend" {
  name = "${var.namespace}-frontend"
  description = "inbound de ssh tipo publico"
  vpc_id = var.vpc.vpc_id
  ingress {
    description = "SSH desde mi backend"
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  ingress {
    description = "80 desde internet"
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
  tags = {
    Name = "${var.namespace}-frontend-sg"
  }
}
output "security_group_id" {
  value = aws_security_group.frontend.id
}

// EC2
// busco en aws por filtro la versión disponible (aws educate solo deja una)
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners = [
    "amazon"]
  filter {
    name = "name"
    values = [
      "amzn2-ami-hvm*"]
  }
}
resource "aws_instance" "instance" {
  ami = data.aws_ami.amazon-linux-2.id
  associate_public_ip_address = true
  key_name = var.private_key_name
  instance_type = "t2.micro"
  subnet_id = var.vpc.public_subnets[0]
  security_groups = [
    aws_security_group.frontend.id]
  tags = {
    "Name" = "${var.namespace}-EC2-FRONTEND"
  }
  # Init Script
  provisioner "file" {
    content = templatefile("${path.module}/init.script", {
      backend_ip = var.backend_ip
    })
    destination = "/home/ec2-user/init.script"
    connection {
      timeout = "15m"
      type = "ssh"
      user = "ec2-user"
      private_key = file("${var.private_key_name}.pem")
      host = self.public_ip
    }
  }
  // Le añado permisos & ejecuto el init script
  provisioner "remote-exec" {
    inline = [
      "chmod 400 /home/ec2-user/init.script",
      "sh /home/ec2-user/init.script"]
    connection {
      type = "ssh"
      user = "ec2-user"
      private_key = file("${var.private_key_name}.pem")
      host = self.public_ip
    }
  }
}

output "public_ip" {
  value = aws_instance.instance.public_ip
}
output "private_ip" {
  value = aws_instance.instance.private_ip
}