module "nginx" {
  source = "../../"

  run_via_root = true

  image_version = "docker.io/library/nginx:latest"
  service_name  = "nginx"
  port_exposed  = ["-p 9001:80"]
}
