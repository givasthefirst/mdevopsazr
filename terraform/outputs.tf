output "lb_public_ip" {
  description = "Public ip of the load balancer"
  value       = azurerm_public_ip.lb_public_ip.ip_address
}

output "linux_virtual_machine" {
  description = "Number of machines provisioned"
  value       = var.machine_count
}


output "virtual_machine_admin_user_name" {
  description = "Username of the michines"
  value       = var.username

}

output "password" {
  sensitive = true
  value     = var.password
}