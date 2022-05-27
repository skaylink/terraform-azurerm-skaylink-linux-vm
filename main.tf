# A Terraform module to create a subset of cloud components
# Copyright (C) 2022 Skaylink GmbH

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# For questions and contributions please contact info@iq3cloud.com

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = data.azurerm_resource_group.resource_group.location
  resource_group_name = data.azurerm_resource_group.resource_group.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "virtual_machine" {
  lifecycle {
    ignore_changes = [
      custom_data
    ]
  }

  name                            = var.vm_name
  resource_group_name             = data.azurerm_resource_group.resource_group.name
  location                        = data.azurerm_resource_group.resource_group.location
  size                            = var.vm_size
  admin_username                  = "cspAdmin"
  disable_password_authentication = true
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "cspAdmin"
    public_key = var.sshKey
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk_storage_account_type
    disk_size_gb         = var.os_disk_size_gb
    name                 = "${var.vm_name}-OsDisk"
  }

  source_image_reference {
    publisher = var.vm_publisher
    offer     = var.vm_offer
    sku       = var.vm_sku
    version   = var.vm_version
  }

  custom_data = var.custom_data

  tags = {
    deploymentType = "terraform"
  }
}

resource "azurerm_managed_disk" "data_disk" {
  count = var.attach_data_disk ? 1 : 0

  lifecycle {
    ignore_changes = [
      disk_size_gb
    ]
  }
  name                 = "${var.vm_name}-DataDisk"
  location             = data.azurerm_resource_group.resource_group.location
  resource_group_name  = data.azurerm_resource_group.resource_group.name
  storage_account_type = var.data_disk_storage_account_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
}

resource "azurerm_virtual_machine_data_disk_attachment" "data_diks_attachment" {
  count              = var.attach_data_disk ? 1 : 0
  managed_disk_id    = azurerm_managed_disk.data_disk[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.virtual_machine.id
  lun                = 0
  caching            = "ReadWrite"
}

resource "azurerm_network_interface_application_security_group_association" "asg_association" {
  for_each                      = toset(var.application_security_groups)
  network_interface_id          = azurerm_network_interface.nic.id
  application_security_group_id = each.key
}

########################
# Backup Configuration #
########################

resource "azurerm_backup_protected_vm" "backup_configuration" {
  resource_group_name = "iq3-basemanagement"
  recovery_vault_name = var.vm_recovery_vault_name
  source_vm_id        = azurerm_linux_virtual_machine.virtual_machine.id
  backup_policy_id    = data.azurerm_backup_policy_vm.backup_policy.id
}

#################
# VM Extensions #
#################

resource "azurerm_virtual_machine_extension" "diskencryption" {
  count                = var.vm_enable_disk_encryption ? 1 : 0
  name                 = "AzureDiskEncryptionForLinux"
  virtual_machine_id   = azurerm_linux_virtual_machine.virtual_machine.id
  publisher            = "Microsoft.Azure.Security"
  type                 = "AzureDiskEncryptionForLinux"
  type_handler_version = "1.1"

  settings = <<SETTINGS
    {
        "EncryptionOperation": "EnableEncryption",
        "KeyVaultURL": "${data.azurerm_key_vault.key_vault.vault_uri}",
        "KeyVaultResourceId": "${data.azurerm_key_vault.key_vault.id}",
        "KeyEncryptionKeyURL": "${data.azurerm_key_vault_key.encryption_key.id}",
        "KekVaultResourceId": "${data.azurerm_key_vault.key_vault.id}",
        "KeyEncryptionAlgorithm": "RSA-OAEP",
        "VolumeType": "ALL",
        "SkipVmBackup" : true
    }
SETTINGS
}

resource "azurerm_virtual_machine_extension" "vm_monitoring" {
  name                       = "iq3-Management-Monitoring"
  virtual_machine_id         = azurerm_linux_virtual_machine.virtual_machine.id
  publisher                  = "Microsoft.EnterpriseCloud.Monitoring"
  type                       = "OmsAgentForLinux"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = jsonencode(
    {
      "workspaceId" : "${data.azurerm_log_analytics_workspace.workspace.workspace_id}",
      "azureResourceId" : "${data.azurerm_log_analytics_workspace.workspace.id}"
    }
  )
  protected_settings = jsonencode(
    {
      "workspaceKey" : "${data.azurerm_log_analytics_workspace.workspace.primary_shared_key}"
    }
  )
}

resource "azurerm_virtual_machine_extension" "iaas_diagnostics" {
  name                       = "${var.vm_name}-IaaSDiagnostics"
  virtual_machine_id         = azurerm_linux_virtual_machine.virtual_machine.id
  publisher                  = "Microsoft.OSTCExtensions"
  type                       = "LinuxDiagnostic"
  type_handler_version       = "2.3"
  auto_upgrade_minor_version = true
  settings                   = data.template_file.iaas_diagnostics_extension_settings.rendered
  protected_settings         = data.template_file.iaas_diagnostics_extension_protected_settings.rendered
}

resource "azurerm_virtual_machine_extension" "linux_vm_access" {
  lifecycle {
    ignore_changes = [
      settings
    ]
  }

  name                       = "VMAccessExtension"
  virtual_machine_id         = azurerm_linux_virtual_machine.virtual_machine.id
  publisher                  = "Microsoft.OSTCExtensions"
  type                       = "VMAccessForLinux"
  type_handler_version       = "1.4"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
      {
      }
      SETTINGS

  protected_settings = <<SETTINGS
      {
        "username": "cspAdmin",
        "ssh_key": "${var.sshKey}"
      }
      SETTINGS
}

