output "user_id" {
  value = var.run_via_root ? null : system_user.user[0].uid
}

output "group_id" {
  value = var.run_via_root ? null : system_group.group[0].gid
}

output "folders_created" {
  value = [ for k, v in system_folder.folder_mounts: v.path]
}

output "files_copied" {
  value = [ for k, v in system_file.configs_mounts: v.path]
}