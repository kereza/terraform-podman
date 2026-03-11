# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Terraform module** that deploys Podman containers as systemd services on remote Linux hosts, using the `neuspaces/system` provider (~>0.5.0) to execute operations over SSH. Requires Terraform ≥1.5.0.

## Architecture

The module manages the full lifecycle of a containerized service:

1. **User/group creation** — Creates a dedicated non-root service user/group unless `run_via_root=true`
2. **Directory setup** — Creates home directory and any `folder_mounts` paths with correct ownership
3. **Config file deployment** — Copies files to host paths, with optional Terraform template rendering (`.tftpl` files use `templatefile()`)
4. **Systemd service** — Renders `container.service.tftpl` and installs it at `/etc/systemd/system/container-{service_name}.service`
5. **Service lifecycle** — Enables and starts via systemd; restarts are triggered by SHA256 hashes of config/service file content

**Key files:**
- [main.tf](main.tf) — All module resources (system_file, system_service_systemd, system_user, system_group, system_folder)
- [variables.tf](variables.tf) — All inputs with validation rules
- [outputs.tf](outputs.tf) — Outputs including user_id, group_id, folders_created, files_copied
- [container.service.tftpl](container.service.tftpl) — Systemd unit template
- [examples/](examples/) — Three working examples: `basic/` (Nginx, root), `full_user/` (Prometheus, non-root), `full_root/` (Ghost, root)

## Validation Rules

- `service_name`: lowercase alphanumeric and hyphens only (`^[a-z0-9][a-z0-9-]*$`)
- `image_version`: container image format with optional tag (e.g., `nginx:latest` or `nginx`)
- `folder_mounts` values: absolute paths required on both host and container sides
- `file_mounts`: each entry needs `source_path`, `host_path`, `container_path`; `template_vars` is optional

## Development Workflow

This module has no test infrastructure or CI/CD pipeline. Validate changes using:

```bash
# Format
terraform fmt -recursive

# Validate module
terraform validate

# Validate an example
cd examples/basic && terraform init && terraform validate
```

When modifying the module, verify all three examples still validate cleanly.
