variable "namespace" {
  type = string
}

// Genero una tls private key que voy a usar para configurar mis instancias
resource "tls_private_key" "key" {
  algorithm = "RSA"
}
// Escribo la private key a un archivo local (es con la que voy a entrar)
resource "local_file" "private_key" {
  filename = "${var.namespace}-key.pem"
  sensitive_content = tls_private_key.key.private_key_pem
  file_permission = "0400"
}
// subo la clave pública a aws key pair
resource "aws_key_pair" "key_pair" {
  key_name = "${var.namespace}-key"
  public_key = tls_private_key.key.public_key_openssh
}
output "private_key_pem" {
  value = tls_private_key.key.private_key_pem
}
output "key_name" {
  value = aws_key_pair.key_pair.key_name
}