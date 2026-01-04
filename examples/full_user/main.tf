module "prometheus" {
  source = "../../"

  run_via_root   = true
  service_status = "started"

  image_version = "docker.io/prom/prometheus:v3.5.0"
  service_name  = "prometheus"
  service_arguments = [
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=30d",
    "--config.file=/etc/prometheus/prometheus.yml"
  ]

  path_config_files = path.module

  folder_mounts = {
    "/root/data" : "/prometheus"
  }
  file_mounts = {
    "/root/config/prometheus.yml" : "/etc/prometheus/prometheus.yml"
  }
}