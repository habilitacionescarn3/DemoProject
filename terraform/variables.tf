variable "resource_group_name" {
  type    = string
  default = "devopslab"
}

variable "location" {
  type    = string
  default = "West Europe" 
}

variable "admin_username" {
  type    = string
  default = "sysadmin"
}

variable "ssh_public_key" {
    type = string
    description = "/labopenssh.pub"
}