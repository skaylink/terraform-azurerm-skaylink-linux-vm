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

#########################
# General Configuration #
#########################

variable "resource_group_name" {
  type        = string
  description = "The resource group where the virtual machine will be deployed"
}

variable "mgmt_resource_group" {
  type        = string
  description = "The resource group where management tools are located, used for VM disk encryption"
  default     = "iq3-basemanagement"
}

variable "vm_name" {
  type        = string
  description = "The name of the virtual machine. This will be also the prefix for all related items"

  validation {
    condition     = length(var.vm_name) >= 3 && length(var.vm_name) <= 15
    error_message = "The vm_name length must be between 3 and 15 characters."
  }
}

#########################
# Network Configuration #
#########################

variable "vnet_resource_group_name" {
  type        = string
  description = "The resource group where network components are located"
}

variable "vnet_name" {
  type        = string
  description = "The virtual network of the virtual machine"
}

variable "vnet_subnet_name" {
  type        = string
  description = "The subnet name inside the virtual network of the virtual machine"
}

variable "application_security_groups" {
  type        = list(string)
  default     = []
  description = "IDs of the ASG which should be attached, if any"
}

####################
# VM Configuration #
####################

variable "vm_size" {
  type        = string
  description = "The size of the virtual machine"
}

variable "vm_publisher" {
  type        = string
  description = "The publisher of the OS VM image"
}

variable "vm_offer" {
  type        = string
  description = "The offer of the OS VM image"
}

variable "vm_sku" {
  type        = string
  description = "The SKU of the OS image"
}

variable "vm_version" {
  type        = string
  description = "The version of the OS VM image"
}

variable "os_disk_size_gb" {
  type        = string
  description = "Set size of the OS disk in GB"
}

variable "os_disk_storage_account_type" {
  type        = string
  description = "Set type of the OS disk"
}

variable "attach_data_disk" {
  type        = bool
  description = "Flag to decide if data disk should be attached to the VM"
  default     = false
}

variable "data_disk_size_gb" {
  type        = string
  default     = "1"
  description = "Set size of the data disk in GB"
}

variable "data_disk_storage_account_type" {
  type        = string
  default     = "Standard_LRS"
  description = "Set type of the data disk"
}

variable "vm_encryption_key_vault_name" {
  type        = string
  description = "The name of the Key Vault which holds the encryption key"
  default     = null
}

variable "vm_enable_disk_encryption" {
  type        = bool
  description = "Flag to decide if disk encryption should be done"
  default     = false
}

variable "vm_encryption_key_name" {
  type        = string
  description = "The name of the encryption key inside the key vault"
  default     = null
}

variable "sshKey" {
  type        = string
  description = "The public key of the SSH key-pair"
}

variable "custom_data" {
  default     = null
  description = "A Custom Data script to execute while the server is booting. We remmend passing in a bash script that executes the run-consul script, which should have been installed in the Consul Image by the install-consul module."
}

###################################
# Monitoring and Patch management #
###################################

variable "vm_recovery_vault_name" {
  type        = string
  description = "The recovery vault to configure virtual machine for Backup in base management (using DefaultPolicy). Make sure, that pipeline has Contributor access to Recovery Vault."
}

variable "la_workspace_name" {
  type        = string
  description = "The name of the log analytics workspace within iq3-basemanagement"
}

variable "iaas_logging_account_name" {
  type        = string
  description = "The logging Account within iq3-basemanagement to enable Patch Management for virtual machine"
}

variable "azure_ad_authentication" {
  type        = bool
  description = "Enables or disables AADSSHLoginForLinux VM extension"
}
