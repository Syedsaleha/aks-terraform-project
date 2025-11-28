locals {
  name_prefix = "${var.project_name}-${var.environment}"

  tags = {
    environment = var.environment
    project     = var.project_name
    owner       = "devops"
  }
}
