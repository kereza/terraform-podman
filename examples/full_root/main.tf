module "ghost" {
  source = "../../"

  image_version = "docker.io/library/ghost:latest"
  service_name  = "ghost"

  port_exposed = ["-p 3700:2369"]
  env_variables = {
    "url" : "https://example.com.com",
    "database__client" : "sqlite3",
    "database__connection__filename" : "/var/lib/ghost/content/data/ghost.db"
  }

  folder_mounts = {
    "/home/ghost/data" : "/var/lib/ghost/content"
  }
  file_mounts = {
    ghost_config = {
      source_path    = "${path.module}/config/ghost/config.production.json"
      host_path      = "/home/ghost/config/config.production.json"
      container_path = "/var/lib/ghost/config.production.json"
    }
  }
}