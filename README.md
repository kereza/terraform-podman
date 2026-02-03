# Terraform Podman Module

A Terraform module for deploying and managing Podman containers as systemd services on a remote Linux host. This module automates the creation of systemd service files, manages container configuration with template support, and optionally creates dedicated non-root users for enhanced security.

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

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `service_name` | Name of the service and container. Must be lowercase alphanumeric with hyphens, cannot start or end with hyphen | `string` | n/a | yes |
| `image_version` | Container image in format `registry/image:tag` or `registry/image` (e.g., `docker.io/library/nginx:latest`). Tag defaults to `latest` if omitted | `string` | n/a | yes |
| `run_via_root` | Run container as root user. If false, a dedicated system user is created | `bool` | `false` | no |
| `service_arguments` | Additional arguments passed to the container application on startup | `list(string)` | `[]` | no |
| `env_variables` | Environment variables to pass to the container | `map(string)` | `{}` | no |
| `folder_mounts` | Host directories to mount into the container (host_path => container_path). Both paths must be absolute | `map(string)` | `{}` | no |
| `file_mounts` | Configuration files to mount with template support. See [Configuration File Templating](#configuration-file-templating) section | `map(object({`<br>`source_path = string`<br>`host_path = string`<br>`container_path = string`<br>`template_vars = optional(map(string))`<br>`}))` | `{}` | no |
| `custom_network` | Podman network name to attach the container to (uses default bridge network if empty) | `string` | `""` | no |
| `port_exposed` | List of port mappings (e.g., `["-p 8080:80", "-p 8443:443"]`) | `list(string)` | `[]` | no |
| `create_folder_mounts` | Automatically create mounted directories if they don't exist | `bool` | `true` | no |
| `path_config_files` | **DEPRECATED** - Use `file_mounts[].source_path` instead | `string` | `""` | no |

## Outputs

| Name | Description | Type |
|------|-------------|------|
| `user_id` | UID of the created service user (null if `run_via_root = true`) | `number` |
| `group_id` | GID of the created service group (null if `run_via_root = true`) | `number` |
| `folders_created` | List of absolute paths to directories created for mounts | `list(string)` |
| `files_copied` | List of absolute paths to configuration files deployed on the host | `list(string)` |
| `config_files_deployed` | Map of deployed configuration files with source, host_path, and container_path | `map(object)` |

## Usage

### Basic Example

Deploy an Nginx container running as root:

```hcl
module "nginx" {
  source = "github.com/yourusername/terraform-podman"

  service_name  = "nginx"
  image_version = "docker.io/library/nginx:latest"
  run_via_root  = true
  port_exposed  = ["-p 9001:80"]
}
```

After applying, the container will be running as a systemd service named `container-nginx.service`.

## Advanced Examples

### Non-Root Container with Configuration Files

Deploy Prometheus with a dedicated service user and configuration file:

```hcl
module "prometheus" {
  source = "github.com/yourusername/terraform-podman"

  service_name  = "prometheus"
  image_version = "docker.io/prom/prometheus:v3.5.0"
  run_via_root  = false

  service_arguments = [
    "--storage.tsdb.path=/prometheus",
    "--storage.tsdb.retention.time=30d",
    "--config.file=/etc/prometheus/prometheus.yml"
  ]

  folder_mounts = {
    "/opt/prometheus/data" : "/prometheus"
  }

  file_mounts = {
    prometheus_config = {
      source_path    = "${path.module}/config/prometheus.yml"
      host_path      = "/opt/prometheus/config/prometheus.yml"
      container_path = "/etc/prometheus/prometheus.yml"
    }
  }

  env_variables = {
    "GOGC" = "75"
  }
}
```

This creates:
- A `prometheus` user and group
- `/opt/prometheus/data` directory for persistent storage
- Configuration file at `/opt/prometheus/config/prometheus.yml`
- Systemd service `container-prometheus.service`

### Template Configuration with Variables

Deploy Ghost blog with templated configuration:

```hcl
module "ghost" {
  source = "github.com/yourusername/terraform-podman"

  service_name  = "ghost"
  image_version = "docker.io/library/ghost:5.54.0"
  run_via_root  = false
  port_exposed  = ["-p 2368:2368"]

  folder_mounts = {
    "/var/ghost/content" : "/var/lib/ghost/content"
  }

  file_mounts = {
    ghost_config = {
      source_path    = "${path.module}/templates/ghost-config.json.tftpl"
      host_path      = "/etc/ghost/config.production.json"
      container_path = "/var/lib/ghost/config.production.json"
      template_vars = {
        domain   = "blog.example.com"
        db_path  = "/var/lib/ghost/content/data/ghost.db"
        mail_transport = "SMTP"
      }
    }
  }

  env_variables = {
    "NODE_ENV" = "production"
  }
}
```

**Template file** (`templates/ghost-config.json.tftpl`):
```json
{
  "url": "https://${domain}",
  "database": {
    "client": "sqlite3",
    "connection": {
      "filename": "${db_path}"
    }
  },
  "mail": {
    "transport": "${mail_transport}"
  }
}
```

### Custom Network Example

Deploy a container in a specific Podman network:

```hcl
module "webapp" {
  source = "github.com/yourusername/terraform-podman"

  service_name   = "webapp"
  image_version  = "docker.io/library/httpd:latest"
  custom_network = "my-podman-network"
  port_exposed   = ["-p 8080:80"]
}
```

**Note**: The Podman network must already exist on the host.

## How It Works

1. **User & Group Creation** (if `run_via_root = false`):
   - Creates a dedicated system user and group named `service_name`
   - Sets home directory to `/home/{service_name}`
   - Assigns `/usr/sbin/nologin` as the shell for security

2. **Directory Setup**:
   - Creates necessary directories for file and folder mounts
   - Sets proper ownership and permissions based on `run_via_root` setting

3. **Configuration Files**:
   - Renders config files using Terraform's `templatefile()` function
   - Supports both static files and dynamic templates with variables
   - Copies rendered files to specified host paths with correct ownership

4. **Systemd Service**:
   - Generates a systemd service file at `/etc/systemd/system/container-{service_name}.service`
   - Configures automatic restart, proper stopping, and dependency ordering
   - Enables and starts the service automatically
   - Automatically restarts when systemd file or config files change (using SHA256 content hashing)

## Resources Created

This module creates the following resources on the remote host:

| Resource Type | Count | Description |
|--------------|-------|-------------|
| `system_user.user` | 0-1 | Service user (only if `run_via_root = false`) |
| `system_group.group` | 0-1 | Service group (only if `run_via_root = false`) |
| `system_folder.home_folder` | 0-1 | User home directory (only if `run_via_root = false`) |
| `system_folder.folder_mounts` | 0-N | Directories for mounted folders and config files |
| `system_file.configs_mounts` | 0-N | Configuration files (one per `file_mounts` entry) |
| `system_file.file` | 1 | Systemd service unit file |
| `system_service_systemd.service` | 1 | Systemd service (enables and starts the container) |

## Configuration File Templating

The module supports Terraform's `templatefile()` function for dynamic configuration generation. This allows you to create reusable, environment-specific configurations.

**When to use templates:**
- Configuration values that change between environments (dev/staging/prod)
- Dynamic values derived from other Terraform resources
- Configurations that need to reference variables or data sources

**When to use static files:**
- Configuration files that never change
- Complex configuration with no dynamic values
- Files that should be version-controlled exactly as-is

### Structure

Each entry in `file_mounts` requires:
- **source_path**: Path to your template (`.tftpl`) or static config file
- **host_path**: Absolute path where the file will be placed on the remote host
- **container_path**: Absolute path where the file will be mounted in the container
- **template_vars**: (Optional) Map of variables to interpolate in the template (empty `{}` for static files)

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

## Automatic Restart on Changes

The module automatically restarts the systemd service when:
- The systemd service file content changes
- Any configuration file mounted via `file_mounts` changes

This is implemented using the `restart_on` parameter with SHA256 content hashing to minimize verbose output in Terraform plans. When you modify a configuration file or change the service definition, Terraform will detect the change and restart the service during the apply phase.

## Systemd Service Details

Generated systemd services (`/etc/systemd/system/container-{service_name}.service`) include:

| Feature | Configuration | Description |
|---------|--------------|-------------|
| **Restart Policy** | `Restart=always` | Automatically restart the container if it stops |
| **Stop Timeout** | `TimeoutStopSec=70` | 70 seconds grace period before forceful termination |
| **Network Dependencies** | `After=network-online.target` | Service waits for network to be online |
| **Graceful Stop** | `ExecStop=/usr/bin/podman stop -t 10` | 10-second timeout for graceful container shutdown |
| **Service Type** | `Type=forking` | Proper handling of Podman's daemonization |
| **Auto-start** | `WantedBy=multi-user.target` | Service starts automatically on boot |

## Best Practices

### Security
- **Use Non-Root Users**: Set `run_via_root = false` whenever possible to run containers with limited privileges
- **Limit Mount Points**: Only mount directories and files that the container absolutely needs
- **Use Absolute Paths**: Always use absolute paths for mounts (enforced by validation)
- **Review Port Exposure**: Only expose ports that are necessary for your application
- **Valid Service Names**: Use lowercase alphanumeric names with hyphens only (enforced by validation)

### Configuration Management
- **Use Templates for Dynamic Config**: Leverage `template_vars` for environment-specific values
- **Version Control Templates**: Keep `.tftpl` template files in version control
- **Test Changes Locally**: Test configuration changes before applying to production

### Operational
- **Monitor Service Status**: Use `systemctl status container-{service_name}` to check service health
- **Check Logs**: View container logs with `journalctl -u container-{service_name} -f`
- **Plan Before Apply**: Always review `terraform plan` output before applying changes

## Security Considerations

- **Non-Root Execution** (recommended): Set `run_via_root = false` to run containers with limited privileges
- **File Permissions**: Configuration files are owned by the service user/group with appropriate permissions
- **User Shell**: Service users are created with `/usr/sbin/nologin` shell (no direct login access)
- **Mount Isolation**: Use folder and file mounts to limit container access to specific host resources
- **Network Isolation**: Use `custom_network` to isolate containers in specific Podman networks

## Common Operations

### Check Service Status
```bash
systemctl status container-{service_name}
```

### View Container Logs
```bash
journalctl -u container-{service_name} -f
```

### Manually Restart Service
```bash
systemctl restart container-{service_name}
```

### Stop Service
```bash
systemctl stop container-{service_name}
```

### View Container Details
```bash
podman ps -a | grep {service_name}
podman inspect {service_name}
```

## Troubleshooting

### Service Won't Start
1. Check systemd service status: `systemctl status container-{service_name}`
2. View detailed logs: `journalctl -u container-{service_name} -n 50`
3. Verify Podman can run the container manually: `podman run {image_version}`
4. Check file permissions on mounted directories and files

### Configuration Changes Not Applied
1. Verify the file was updated on the host: `cat {host_path}`
2. Check if service restarted: `systemctl status container-{service_name}`
3. Review Terraform apply output for any errors
4. Manually restart the service: `systemctl restart container-{service_name}`

### Permission Denied Errors
1. Verify folder ownership: `ls -la {folder_path}`
2. Check if the service user exists: `id {service_name}`
3. Ensure `create_folder_mounts = true` if directories should be auto-created
4. For root-owned paths, consider setting `run_via_root = true`

## Complete Examples

See the [`examples/`](./examples) directory for complete working examples with all necessary files:
- **[`examples/basic/`](./examples/basic/)** - Simple Nginx container running as root
- **[`examples/full_user/`](./examples/full_user/)** - Prometheus with non-root user and configuration file
- **[`examples/full_root/`](./examples/full_root/)** - Ghost blog with configuration files and volume mounts

Each example includes:
- Complete Terraform configuration
- Provider setup
- Configuration files (where applicable)
- Instructions for deployment

## Limitations and Known Issues

- **Podman Network**: The `custom_network` must already exist on the host; this module does not create networks
- **systemd Only**: This module requires systemd; it will not work on systems using other init systems
- **SSH Access**: Requires SSH access with sudo privileges to the remote host
- **State Management**: Deleting the Terraform state does not remove the systemd service from the host

## Destroying Resources

When you run `terraform destroy`, the module will:
1. Stop and disable the systemd service
2. Remove the systemd service file
3. Delete configuration files created via `file_mounts`
4. Remove created directories (if empty)
5. Delete the service user and group (if created)

**Note**: The Podman container is run with `--rm` flag, so it's automatically removed when stopped.

## Version Compatibility

| Module Version | Terraform Version | Provider Version |
|---------------|------------------|------------------|
| 1.x | >= 1.5.0 | neuspaces/system ~> 0.5.0 |

## Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with the examples
5. Submit a pull request

## License

See [LICENSE](LICENSE) for details.
