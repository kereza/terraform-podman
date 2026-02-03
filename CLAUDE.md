# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Terraform module that deploys and manages Podman containers as systemd services on remote Linux hosts. The module uses the `neuspaces/system` provider (v0.5.0) to execute commands on remote hosts via SSH.

## Architecture

### Core Resource Flow

1. **User/Group Creation** ([main.tf:42-53](main.tf#L42-L53))
   - `system_group.group`: Creates service group (conditional on `!run_via_root`)
   - `system_user.user`: Creates service user with nologin shell (conditional on `!run_via_root`)
   - `system_folder.home_folder`: Creates home directory for service user

2. **Mount Preparation** ([main.tf:62-70](main.tf#L62-L70))
   - `system_folder.folder_mounts`: Creates all directories needed for folder mounts and config file parent directories
   - `system_file.configs_mounts`: Copies configuration files from `path_config_files/config/{service_name}/` to target locations

3. **Service Creation** ([main.tf:21-30](main.tf#L21-L30))
   - `system_file.file`: Generates systemd service file at `/etc/systemd/system/container-{service_name}.service`
   - `system_service_systemd.service`: Enables and starts/stops the service

### Command Generation

The Podman run command is assembled in locals ([main.tf:1-19](main.tf#L1-L19)):
- Conditionally sets user to `root:root` or `{uid}:{gid}` based on `run_via_root`
- Builds command with `--rm`, `--replace`, `--name`, `--user` flags
- Appends custom network, file mounts, folder mounts, environment variables, exposed ports
- Joins all parts with line continuation for readability in systemd service

### Configuration File Handling

The module uses explicit paths for config files with template support:
- **source_path**: Explicit path to the template or static config file
- **host_path**: Where the file is placed on the remote host
- **container_path**: Where the file is mounted in the container
- **template_vars**: Optional variables for Terraform's `templatefile()` function

Files are rendered using `templatefile()` which works for both:
- Static config files (no template variables)
- Dynamic templates (with `${variable}` interpolation)

Example structure:
```hcl
file_mounts = {
  app_config = {
    source_path    = "${path.module}/templates/config.yaml.tftpl"
    host_path      = "/etc/app/config.yaml"
    container_path = "/app/config.yaml"
    template_vars  = { database_host = "db.example.com" }
  }
}
```

## Development Commands

### Validate Terraform Syntax
```bash
terraform fmt -check
terraform validate
```

### Test with Examples
```bash
# Navigate to an example directory
cd examples/basic
# or cd examples/full_user
# or cd examples/full_root

# Initialize and plan (requires configured system provider)
terraform init
terraform plan

# Apply changes (requires SSH access to target host)
terraform apply

# Clean up
terraform destroy
```

### Format Code
```bash
terraform fmt -recursive
```

## Key Patterns

### Conditional Resource Creation
Resources like `system_user`, `system_group`, and `system_folder.home_folder` use `count = var.run_via_root ? 0 : 1` to conditionally create resources only when running as non-root.

### Dynamic Lists and Maps
- Use `for_each` with `toset()` for creating multiple similar resources (folders, file mounts)
- Transform variable maps into lists of command-line arguments using `for` expressions in locals

### Dependency Management
Explicit `depends_on` relationships ensure proper ordering:
- Folders must exist before files are copied
- Files and folders must exist before the systemd service starts

## Systemd Service Template

The [container.service.tftpl](container.service.tftpl) template generates services with:
- `Restart=always`: Containers restart automatically on failure
- `TimeoutStopSec=70`: 70-second grace period before forced termination
- `ExecStop` with `-t 10`: Gives containers 10 seconds to stop gracefully
- Network dependency: Waits for `network-online.target`
