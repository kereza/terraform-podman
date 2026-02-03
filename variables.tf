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
  type        = string
  default     = "started"
}

variable "run_via_root" {
  description = "If the container will be run from ROOT user. If that is false - a special user will be creted with service name"
  type        = bool
  default     = false
}

variable "env_variables" {
  description = "Environment variables to be provided to the container"
  type        = map(string)
  default     = {}
}

variable "folder_mounts" {
  description = "Folders to be mounted in the containers from the host"
  type        = map(string)
  default     = {}
}

variable "file_mounts" {
  description = "Configuration files to mount in the container with template support"
  type = map(object({
    source_path    = string
    host_path      = string
    container_path = string
    template_vars  = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.file_mounts : (
        length(v.source_path) > 0 &&
        length(v.host_path) > 0 &&
        length(v.container_path) > 0 &&
        startswith(v.host_path, "/") &&
        startswith(v.container_path, "/")
      )
    ])
    error_message = "All paths must be non-empty, and host_path and container_path must be absolute paths."
  }
}

variable "path_config_files" {
  description = "Path to the config files to be provided when the module is called."
  type        = string
  default     = ""
}

variable "port_exposed" {
  description = "A list of ports to be eposed when the container starts"
  type        = list(any)
  default     = []
}

variable "create_folder_mounts" {
  description = "A flag which if FALSE will NOT create the directories mounted. Needed in very special cases"
  type        = bool
  default     = true
}

variable "custom_network" {
  description = "Run the container in a specific network"
  type        = string
  default     = ""
}