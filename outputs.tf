output "user_id" {
  description = "UID of the service user (null if run_via_root = true)"
  value       = var.run_via_root ? null : system_user.user[0].uid
}

output "group_id" {
  description = "GID of the service group (null if run_via_root = true)"
  value       = var.run_via_root ? null : system_group.group[0].gid
}

output "folders_created" {
  description = "List of absolute paths to directories created for mounts"
  value       = [for k, v in system_folder.folder_mounts : v.path]
}

output "files_copied" {
  description = "List of absolute paths to configuration files deployed on the host"
  value       = [for k, v in system_file.configs_mounts : v.path]
}

output "config_files_deployed" {
  description = "Map of deployed configuration files"
  value = {
    for k, v in var.file_mounts : k => {
      host_path      = v.host_path
      container_path = v.container_path
      source         = v.source_path
    }
  }
}

output "service_name" {
  description = "Name of the service"
  value       = var.service_name
}