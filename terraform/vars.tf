variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
  default     = "udacity"
}

variable "project_name" {
  description = "name of the project to be used as a tag"
  default     = "Azure Infrastructure Operations Project"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "westeurope"
}

variable "username" {
  description = "The username"
  default     = "jhon"
}

variable "password" {
  description = "The password to be used in the vm"
}

variable "machine_count" {
  description = "amount of machine_count"
  type        = number
  default     = "2"
}

