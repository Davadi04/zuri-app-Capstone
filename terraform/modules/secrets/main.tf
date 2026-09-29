variable "env" {
  type = string
}

resource "aws_secretsmanager_secret" "backend" {
  name                    = "zuri/${var.env}/backend"
  recovery_window_in_days = 0
}

output "secret_arns" {
  value = [aws_secretsmanager_secret.backend.arn]
}