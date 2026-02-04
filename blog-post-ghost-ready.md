---
GHOST POST METADATA (Copy these into Ghost settings):
---
Title: Managing Podman with Terraform
Slug: managing-podman-with-terraform
Excerpt: Learn how to automate Podman container deployment as systemd services using Terraform, with support for templated configurations and automatic service restarts.
Tags: terraform, podman, containers, systemd, infrastructure-as-code, devops
Feature Image: (Suggest: A banner with Podman + Terraform logos)
---

When I decided to move away from Docker for my home server setup, I chose Podman as the alternative. Podman is an open-source container management tool that operates without a central daemon, making it more secure and lightweight. One of its standout features is support for **Quadlets** - a way to manage containers using systemd unit files.

However, manually writing systemd unit files and managing container configurations isn't scalable. That's why I created a Terraform module to automate the entire process: [terraform-podman](https://github.com/kereza/terraform-podman).

## Why Podman?

Podman offers several advantages over Docker:
- **No daemon** - Containers run directly under systemd
- **Rootless containers** - Enhanced security by running as non-root users
- **Systemd integration** - Native support for systemd service management
- **Drop-in replacement** - Compatible with Docker CLI commands

## The Terraform Module

The module deploys Podman containers as systemd services on remote Linux hosts via SSH. It uses the `neuspaces/system` provider to manage files, users, and systemd services remotely.

### Minimal Example

Here's a simple example deploying a Ghost blog:

```hcl
provider "system" {
  host        = "your-server.com"
  user        = "terraform"
  private_key = file("~/.ssh/id_rsa")
}

module "ghost" {
  source = "github.com/kereza/terraform-podman?ref=v2.0.0"

  service_name  = "ghost"
  image_version = "docker.io/library/ghost:5.54.0"
  run_via_root  = false
  port_exposed  = ["-p 2368:2368"]

  env_variables = {
    "NODE_ENV" = "production"
  }
}
```

This creates:
- A dedicated `ghost` system user
- A systemd service named `container-ghost.service`
- Automatic container restart if it crashes
- Automatic service restart on configuration changes

## Production-Ready Setup with Templates

For real-world deployments, you'll want persistent storage and custom configuration. The module now supports Terraform's `templatefile()` function for dynamic configuration:

### Directory Structure
```
.
├── main.tf
├── provider.tf
└── templates/
    └── ghost-config.json.tftpl
```

### Template File (templates/ghost-config.json.tftpl)
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
    "transport": "${mail_transport}",
    "from": "${mail_from}"
  },
  "server": {
    "host": "0.0.0.0",
    "port": 2368
  }
}
```

### Module Configuration (main.tf)
```hcl
module "ghost" {
  source = "github.com/kereza/terraform-podman?ref=v2.0.0"

  service_name  = "ghost"
  image_version = "docker.io/library/ghost:5.54.0"
  run_via_root  = false
  port_exposed  = ["-p 2368:2368"]

  # Persistent storage
  folder_mounts = {
    "/home/ghost/data/content" : "/var/lib/ghost/content"
  }

  # Templated configuration with variables
  file_mounts = {
    ghost_config = {
      source_path    = "${path.module}/templates/ghost-config.json.tftpl"
      host_path      = "/home/ghost/config/config.production.json"
      container_path = "/var/lib/ghost/config.production.json"
      template_vars = {
        domain         = var.domain
        db_path        = "/var/lib/ghost/content/data/ghost.db"
        mail_transport = "SMTP"
        mail_from      = "noreply@${var.domain}"
      }
    }
  }

  env_variables = {
    "NODE_ENV" = "production"
  }
}
```

### Provider Configuration (provider.tf)
```hcl
provider "system" {
  host        = var.host
  user        = var.user
  private_key = file("~/.ssh/id_rsa")
  port        = var.ssh_port

  # Needed for creating users, directories, and systemd services
  sudo = true
}
```

## Key Features

### 1. Template Support
The module uses Terraform's `templatefile()` function for all configuration files. This allows you to:
- Use the same template across environments (dev, staging, prod)
- Reference Terraform variables and data sources
- Keep sensitive values in Terraform variables instead of config files

### 2. Automatic Restart on Changes
When you modify a configuration file or update the service definition, Terraform automatically restarts the systemd service. The module uses SHA256 content hashing to detect changes efficiently without verbose plan output.

### 3. Input Validation
The module validates inputs to prevent common mistakes:
- Service names must be lowercase alphanumeric (systemd requirement)
- Image versions must be in proper format (`registry/image:tag`)
- All mount paths must be absolute paths

### 4. Security by Default
- Containers run as dedicated non-root users by default
- Service users have `/usr/sbin/nologin` shell (no login access)
- Configuration files have proper ownership and permissions

## How It Works

The module creates resources in this order:

1. **User & Group** (if `run_via_root = false`) - Creates a dedicated system user
2. **Directories** - Creates all mount point directories with proper ownership
3. **Configuration Files** - Renders templates and deploys them to the host
4. **Systemd Service** - Generates and installs the systemd unit file
5. **Service Activation** - Enables and starts the service

All configuration files are rendered locally by Terraform, then uploaded to the host. When you run `terraform apply`, changes are detected and the service restarts automatically.

## Multiple Configuration Files

You can mount multiple configuration files with different templates:

```hcl
file_mounts = {
  # Static config file
  nginx_conf = {
    source_path    = "${path.module}/config/nginx.conf"
    host_path      = "/etc/app/nginx.conf"
    container_path = "/etc/nginx/nginx.conf"
    template_vars  = {}  # Empty for static files
  }

  # Templated config file
  app_config = {
    source_path    = "${path.module}/templates/app.yaml.tftpl"
    host_path      = "/etc/app/config.yaml"
    container_path = "/app/config.yaml"
    template_vars = {
      environment = var.environment
      region      = var.region
      log_level   = var.environment == "production" ? "WARN" : "DEBUG"
    }
  }
}
```

## Verifying the Deployment

After running `terraform apply`, you can verify the deployment:

```bash
# Check service status
systemctl status container-ghost

# View logs
journalctl -u container-ghost -f

# Inspect the container
podman ps
podman inspect ghost
```

## Benefits Over Manual Management

Using this Terraform module provides several advantages:
- **Infrastructure as Code** - All configuration is versioned in Git
- **Consistency** - Same deployment process across all containers
- **Automation** - No manual systemd file creation or service management
- **Template Reusability** - Share configuration templates across environments
- **Automatic Restarts** - Services restart when configuration changes
- **Validation** - Catch configuration errors during `terraform plan`

## Conclusion

This Terraform module makes managing Podman containers on remote hosts straightforward and maintainable. The template support allows for environment-specific configurations while keeping your infrastructure as code.

The module is production-ready and handles all the complexity of systemd service management, user creation, and configuration deployment.

Check out the full module with examples on GitHub: [terraform-podman](https://github.com/kereza/terraform-podman)
