variable "service_name" {
  description = "The name of the service which the container runs"
  type        = string
}

variable "image_version" {
  description = "The container name and version"
  type        = string
}

variable "service_arguments" {
  description = "Special arguments provided during application start"
  type        = list(string)
  default     = []
}

variable "service_status" {
    description = "System start or stop the service"
    type = string
    default = "started"
}

variable "run_via_root" {
    description = "If the container will be run from ROOT user. If that is false - a special user will be creted with service name"
    type = bool
    default = false
}

variable "env_variables" {
  description = "Environment variables to be provided to the container"
  type = map(string)
  default = {}
}

variable "folder_mounts" {
  description = "Folders to be mounted in the containers from the host"
  type = map(string)
  default = {}
}

variable "file_mounts" {
  description = "Files to be mounted in the containers from the host"
  type = map(string)
  default = {}
}

variable "path_config_files" {
  description = "Path to the config files to be provided when the module is called."
  type = string
  default = ""
}

variable "port_exposed" {
  description = "A list of ports to be eposed when the container starts"
  type = list
  default = []
}