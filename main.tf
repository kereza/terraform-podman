locals {
  user = var.run_via_root ? "root:root" : "${system_user.user[0].uid}:${system_group.group[0].gid}"

  container_arguments = [
    "/usr/bin/podman run",
    "--rm",
    "--replace",
    "--name=${var.service_name}",
    "--user ${local.user}"
  ]

  custom_network = var.custom_network == "" ? [] : ["--net ${var.custom_network}"]
  config_folders = [for k, v in var.file_mounts : dirname(v.host_path)]
  file_mounts    = [for k, v in var.file_mounts : "-v ${v.host_path}:${v.container_path}"]
  folder_mounts  = [for k, v in var.folder_mounts : "-v ${k}:${v}"]
  env_variables  = [for k, v in var.env_variables : "-e ${k}=${v}"]

  exec_start = join(" \\\n  ", local.container_arguments, local.custom_network, local.file_mounts, local.folder_mounts, local.env_variables, var.port_exposed, [var.image_version], var.service_arguments)
}

resource "system_file" "file" {
  path  = "/etc/systemd/system/container-${var.service_name}.service"
  mode  = 644
  user  = "root"
  group = "root"
  content = templatefile("${path.module}/container.service.tftpl", {
    exec_start   = local.exec_start,
    service_name = var.service_name
  })
}

resource "system_service_systemd" "service" {
  name    = trimsuffix(system_file.file.basename, ".service")
  enabled = true
  status  = "started"

  restart_on = {
    service_file = system_file.file.content
    config_files = jsonencode({
      for k, v in system_file.configs_mounts : k => v.content
    })
  }

  depends_on = [
    system_file.configs_mounts,
    system_folder.folder_mounts
  ]
}

resource "system_user" "user" {
  count = var.run_via_root ? 0 : 1
  name  = var.service_name
  home  = "/home/${var.service_name}"
  gid   = system_group.group[0].gid
  shell = "/usr/sbin/nologin"
}

resource "system_group" "group" {
  count = var.run_via_root ? 0 : 1
  name  = var.service_name
}

resource "system_folder" "home_folder" {
  count = var.run_via_root ? 0 : 1
  path  = system_user.user[0].home
  group = system_group.group[0].name
  user  = system_user.user[0].name
}

resource "system_folder" "folder_mounts" {
  for_each = var.create_folder_mounts ? toset(concat(local.config_folders, keys(var.folder_mounts))) : toset([])
  path     = each.key
  group    = var.run_via_root ? "root" : (system_user.user[0].name)
  user     = var.run_via_root ? "root" : system_user.user[0].name
  depends_on = [
    system_folder.home_folder
  ]
}

resource "system_file" "configs_mounts" {
  for_each = var.file_mounts
  path     = each.value.host_path
  content  = templatefile(each.value.source_path, each.value.template_vars)
  group    = var.run_via_root ? "root" : system_group.group[0].name
  user     = var.run_via_root ? "root" : system_user.user[0].name
  depends_on = [
    system_folder.folder_mounts
  ]
}