module "prometheus" {
  source = "../../"

  run_via_root = true

  image_version = "docker.io/prom/prometheus:v3.5.0"
  service_name  = "prometheus"
  service_arguments = [
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=30d",
    "--config.file=/etc/prometheus/prometheus.yml"
  ]

  folder_mounts = {
    "/root/data" : "/prometheus"
  }
  file_mounts = {
    prometheus_config = {
      source_path    = "${path.module}/config/prometheus/prometheus.yml"
      host_path      = "/root/config/prometheus.yml"
      container_path = "/etc/prometheus/prometheus.yml"
    }
  }
}