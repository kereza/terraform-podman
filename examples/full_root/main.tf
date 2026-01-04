module "ghost" {
  source = "../../"

  service_status = "started"

  image_version = "docker.io/library/ghost:latest"
  service_name = "ghost"

  path_config_files = path.module
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
    "/home/ghost/config/config.production.json" : "/var/lib/ghost/config.production.json"
  }
}