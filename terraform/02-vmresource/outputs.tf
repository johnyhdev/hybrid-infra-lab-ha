# ==========================================================
# RESOURCE GROUP & NETWORK
# ==========================================================
output "resource_group_name" {
  description = "Resource group name"
  value       = data.azurerm_resource_group.main.name
}

output "vnet_name" {
  description = "Virtual network name"
  value       = azurerm_virtual_network.main.name
}

output "automation_subnet_id" {
  description = "Subnet ID for Control Manager"
  value       = azurerm_subnet.automation.id
}

output "workload_subnet_id" {
  description = "Subnet ID for Workload VMs"
  value       = azurerm_subnet.workload.id
}

# ==========================================================
# SSH / ACCESS INFO
# ==========================================================
output "admin_username" {
  description = "Admin username for SSH access"
  value       = var.admin_username
}

# ==========================================================
# CONTROL MANAGER VMS
# ==========================================================
output "control_vm_names" {
  description = "List of Control Manager VM names"
  value       = keys(var.control_vms)
}

output "control_vm_private_ips" {
  description = "Map of Control Manager VM names to Private IPs"
  value = {
    for name, nic in azurerm_network_interface.cm :
    name => nic.private_ip_address
  }
}

output "control_vm_ids" {
  description = "Map of Control Manager VM names to Resource IDs"
  value = {
    for name, vm in azurerm_linux_virtual_machine.cm :
    name => vm.id
  }
}

# ==========================================================
# WORKLOAD VMS
# ==========================================================
output "workload_vm_names" {
  description = "List of Workload VM names"
  value       = keys(var.workload_vms)
}

output "workload_vm_private_ips" {
  description = "Map of Workload VM names to Private IPs"
  value = {
    for name, nic in azurerm_network_interface.workload :
    name => nic.private_ip_address
  }
}

output "workload_vm_ids" {
  description = "Map of Workload VM names to Resource IDs"
  value = {
    for name, vm in azurerm_linux_virtual_machine.workload :
    name => vm.id
  }
}