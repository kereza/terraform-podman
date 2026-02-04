# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Terraform module that deploys Podman containers as systemd services on remote Linux hosts via SSH. It uses the `neuspaces/system` provider (v0.5.0) to manage files, users, and systemd services remotely.

## Architecture

### Resource Flow
The module creates resources in this dependency order:
1. **User/Group** (optional) - Created when `run_via_root = false`
2. **Home Directory** (optional) - Created for the service user
3. **Mount Directories** - All directories needed for file/folder mounts
4. **Config Files** - Rendered using `templatefile()` and deployed to host
5. **Systemd Service File** - Generated from template at `/etc/systemd/system/container-{service_name}.service`
6. **Systemd Service** - Enabled and started, with automatic restart on config changes

### Key Design Decisions

**Configuration File Templating**: The `file_mounts` variable accepts both static files and Terraform templates (`.tftpl`). The `templatefile()` function is used for all files, with empty `template_vars = {}` for static files.

**Automatic Restart Mechanism**: The `system_service_systemd.service` resource uses the `restart_on` parameter with SHA256 content hashing:
```hcl
restart_on = toset([
  sha256(system_file.file.content),
  sha256(jsonencode([for v in system_file.configs_mounts : v.content]))
])
```
This approach prevents verbose Terraform plan output (no 50+ line diffs) while still detecting changes.

**Validation Rules**:
- `service_name`: Must be lowercase alphanumeric with hyphens (systemd naming requirements)
- `image_version`: Format `registry/image:tag` or `registry/image` (tag optional, defaults to `latest`)
- `folder_mounts` and `file_mounts`: Require absolute paths (must start with `/`)

## Testing and Validation

Since this module requires a remote host with SSH access, there are no automated tests. Manual testing workflow:

1. Use one of the examples: `examples/basic/`, `examples/full_user/`, or `examples/full_root/`
2. Run `terraform init` in the example directory
3. Run `terraform plan` to review changes
4. Run `terraform apply` to deploy
5. Verify service: `systemctl status container-{service_name}`
6. Check logs: `journalctl -u container-{service_name} -f`
7. Test config changes by modifying a template and re-applying
8. Run `terraform destroy` to clean up

## Template System

Two templates exist in the module:

1. **container.service.tftpl** - Systemd service unit file template
   - Variables: `service_name`, `exec_start`
   - Controls restart policy, timeouts, and dependencies

2. **User-provided templates** (via `file_mounts[].source_path`)
   - Variables: Defined in `file_mounts[].template_vars`
   - Can be any format: YAML, JSON, INI, etc.

## Common Operations

**Format code**: `terraform fmt -recursive`

**Validate syntax**: `terraform validate` (requires `terraform init` first)

**Check examples**: All examples in `examples/` directory should be kept in sync with module changes

## Important Patterns

**For each resources**: `system_file.configs_mounts` and `system_folder.folder_mounts` use `for_each` to create multiple resources. When referencing them, use iteration: `[for v in system_file.configs_mounts : v.property]`

**Conditional resources**: User/group resources use `count = var.run_via_root ? 0 : 1` pattern. Reference them with `[0]` index when used.

**Path handling**: The module extracts directory paths from file paths using `dirname()` to auto-create parent directories.

## Git Workflow

- Main branch: `main`
- Feature branches: `feature/*`
- Keep commits atomic with single-sentence messages
- README.md should always reflect current module capabilities
