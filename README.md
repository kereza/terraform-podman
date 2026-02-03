# terraform-podman

A Terraform module for deploying and managing Podman containers as systemd services on a remote host. This module automates the creation of systemd service files, manages container configuration files, and optionally creates dedicated non-root users for enhanced security.

## Features

- 🐳 **Container Management**: Deploy Podman containers as persistent systemd services
- 👤 **Security**: Run containers as non-root users (or as root if needed)
- 📁 **File & Folder Mounts**: Mount host files and directories into containers
- 🔧 **Environment Variables**: Pass environment variables to containers
- 🌐 **Port Mapping**: Expose container ports to the host
- ⚙️ **Systemd Integration**: Full control over service lifecycle and auto-restart policies
- 🔄 **Automatic Management**: Automatic creation of service users, groups, and directories

## Requirements

- **Terraform**: >= 1.5.0
- **Provider**: `neuspaces/system` ~> 0.5.0 (runs Terraform commands on the remote host via SSH)
- **Host OS**: Linux with systemd and Podman installed
- **Permissions**: SSH access with sudo privileges to the remote host

## Provider Setup

This module requires the `neuspaces/system` provider, which executes system commands on a remote host. Configure it in your Terraform code:

```hcl
provider "system" {
  host = "your-remote-host.com"
  user = "terraform"
  private_key = file("~/.ssh/id_rsa")
}
```

## Module Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `service_name` | Name of the service and container | `string` | - | yes |
| `image_version` | Container image name and version (e.g., `docker.io/library/nginx:latest`) | `string` | - | yes |
| `run_via_root` | Run container as root user | `bool` | `false` | no |
| `service_arguments` | Additional arguments passed to the application on startup | `list(string)` | `[]` | no |
| `env_variables` | Environment variables passed to the container | `map(string)` | `{}` | no |
| `folder_mounts` | Host directories to mount into the container (host_path => container_path) | `map(string)` | `{}` | no |
| `file_mounts` | Configuration files to mount with template support (see Configuration File Templating section) | `map(object({source_path=string, host_path=string, container_path=string, template_vars=optional(map(string))}))` | `{}` | no |
| `path_config_files` | (Deprecated) Base path where config files are located | `string` | `""` | no |
| `port_exposed` | List of port mappings (e.g., `["-p 8080:80"]`) | `list(any)` | `[]` | no |
| `create_folder_mounts` | Automatically create mounted directories if they don't exist | `bool` | `true` | no |

## Module Outputs

| Name | Description |
|------|-------------|
| `user_id` | UID of the created service user (null if running as root) |
| `group_id` | GID of the created service group (null if running as root) |
| `folders_created` | List of directories created for mounts |
| `files_copied` | List of configuration files deployed |

## Usage Examples

### Basic Nginx Setup (Run as Root)

```hcl
module "nginx" {
  source = "./"

  service_name  = "nginx"
  image_version = "docker.io/library/nginx:latest"
  run_via_root  = true
  port_exposed  = ["-p 9001:80"]
}
```

### Prometheus with Configuration (Non-Root User)

```hcl
module "prometheus" {
  source = "./"

  service_name  = "prometheus"
  image_version = "docker.io/prom/prometheus:v3.5.0"
  run_via_root  = false

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

  env_variables = {
    "GOGC" = "75"
  }
}
```

### Ghost Blog with Configuration Files

```hcl
module "ghost" {
  source = "./"

  service_name = "ghost"
  image_version = "docker.io/library/ghost:5.54.0"
  run_via_root = false
  port_exposed = ["-p 2368:2368"]

  folder_mounts = {
    "/var/ghost/content" : "/var/lib/ghost/content"
  }

  file_mounts = {
    ghost_config = {
      source_path    = "${path.module}/config/ghost/config.production.json"
      host_path      = "/etc/ghost/config.production.json"
      container_path = "/var/lib/ghost/config.production.json"
    }
  }

  env_variables = {
    "NODE_ENV" = "production"
  }
}
```

## How It Works

1. **User & Group Creation** (if `run_via_root = false`):
   - Creates a dedicated system user and group named `service_name`
   - Sets home directory to `/home/{service_name}`

2. **Directory Setup**:
   - Creates necessary directories for file and folder mounts
   - Sets proper ownership and permissions

3. **Configuration Files**:
   - Renders config files using Terraform's `templatefile()` function
   - Supports both static files and dynamic templates with variables
   - Copies rendered files to specified host paths

4. **Systemd Service**:
   - Generates a systemd service file at `/etc/systemd/system/container-{service_name}.service`
   - Configures automatic restart, proper stopping, and dependency ordering
   - Automatically starts the service and restarts when config files or service definition changes

## Configuration File Templating

The module supports Terraform's `templatefile()` function for dynamic configuration generation. This allows you to create reusable, environment-specific configurations.

### Structure

Each entry in `file_mounts` requires:
- **source_path**: Path to your template or static config file
- **host_path**: Absolute path where the file will be placed on the remote host
- **container_path**: Absolute path where the file will be mounted in the container
- **template_vars**: (Optional) Map of variables to interpolate in the template

### Example: Static Configuration

For simple config files without templating:

```hcl
file_mounts = {
  nginx_conf = {
    source_path    = "${path.module}/config/nginx.conf"
    host_path      = "/etc/myapp/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
  }
}
```

### Example: Templated Configuration

For dynamic configs with variables, create a `.tftpl` template file:

**Template file** (`templates/app.yaml.tftpl`):
```yaml
database:
  host: ${database_host}
  port: ${database_port}
logging:
  level: ${log_level}
```

**Module usage**:
```hcl
file_mounts = {
  app_config = {
    source_path    = "${path.module}/templates/app.yaml.tftpl"
    host_path      = "/etc/myapp/config.yaml"
    container_path = "/app/config.yaml"
    template_vars = {
      database_host = "db.example.com"
      database_port = "5432"
      log_level     = var.environment == "production" ? "WARN" : "DEBUG"
    }
  }
}
```

### Multiple Configuration Files

You can mount multiple config files with different sources:

```hcl
file_mounts = {
  # Static config
  nginx_conf = {
    source_path    = "${path.module}/config/nginx.conf"
    host_path      = "/etc/app/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
  }

  # Templated config
  app_config = {
    source_path    = "${path.module}/templates/app.yaml.tftpl"
    host_path      = "/etc/app/config.yaml"
    container_path = "/app/config.yaml"
    template_vars = {
      environment = "production"
      region      = "us-east-1"
    }
  }
}
```

## Service File Details

Generated systemd services include:
- **Restart Policy**: Always restart the container if it stops
- **Stop Timeout**: 70 seconds grace period before forceful termination
- **Network Dependencies**: Services wait for network to be online
- **ExecStop**: Gracefully stops the container with a 10-second timeout

## Security Considerations

- **Non-Root Execution** (recommended): Set `run_via_root = false` to run containers with limited privileges
- **File Permissions**: Configuration files are owned by the service user/group
- **User Shell**: Service users are created with `/usr/sbin/nologin` shell (no login access)
- **Mount Isolation**: Use folder and file mounts to limit container access to host resources

## Examples

See the `examples/` directory for complete working examples:
- `basic/` - Simple Nginx setup
- `full_user/` - Prometheus with non-root user and configuration
- `full_root/` - Ghost blog with root user and config files

## License

See [LICENSE](LICENSE) for details.
