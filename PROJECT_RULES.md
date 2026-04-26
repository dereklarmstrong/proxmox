# Project Rules & Coding Conventions

> **Proxmox Utility Toolkit** — Development standards for bash scripts, infrastructure-as-code, and documentation.

---

## 1. Shell Script Standards

### 1.1 Script Header

Every `.sh` file must begin with this exact header:

```bash
#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset
```

- Use `#!/usr/bin/env bash` (portable shebang)
- Always enable strict mode: `errexit`, `pipefail`, `nounset`

### 1.2 Repository Root Resolution

Scripts must locate the repository root relative to their own location:

```bash
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
```

### 1.3 Common Library

All scripts must source `lib/common.sh` and use its utilities:

```bash
source "$REPO_ROOT/lib/common.sh"
source_config
require_root
```

- Use `log_info`, `log_warn`, `log_error` for all output — never raw `echo`
- Use `require_root` to enforce root execution
- Use `source_config` to load `config.sh` settings
- Use `setup_stubs` only in test environments

### 1.4 Naming Conventions

| Entity | Convention | Example |
|--------|-----------|---------|
| Script files | `snake_case.sh` | `create_cloud_init_template.sh` |
| Functions | `snake_case` | `validate_template()` |
| Local variables | `snake_case` | `vm_id`, `template_path` |
| Exported/env vars | `SCREAMING_SNAKE_CASE` | `DEFAULT_STORAGE`, `BACKUP_RETENTION_DAYS` |
| Constants | `SCREAMING_SNAKE_CASE` | `TEMPLATE_ID_START=9000` |

### 1.5 Argument Parsing

Use `getopts` for short arguments. Prefix colon for error handling:

```bash
while getopts ":s:d:n:i:g:h" opt; do
  case "$opt" in
    s) SOURCE="$OPTARG" ;;
    d) DEST="$OPTARG" ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done
```

- Always provide a `usage` function documented with a heredoc
- `-h` flag must print usage and exit 0
- Invalid options must print usage and exit 1

### 1.6 Error Handling

- Exit non-zero on failures
- Provide actionable error messages via `log_error`
- Use `trap` for cleanup when resources are allocated:
  ```bash
  trap 'cleanup' EXIT
  cleanup() { rm -f "$TEMP_FILE" 2>/dev/null; }
  ```

### 1.7 String Quoting

- **Always** double-quote variable expansions: `"$VAR"` not `$VAR`
- Use single quotes for literal strings: `'hello world'`
- Use double quotes for strings with variables: `"Value is $VAR"`

### 1.8 Indentation

- Use **2 spaces** for indentation (no tabs)
- Align `case` statement bodies for readability

---

## 2. Test Standards (BATS)

### 2.1 Structure

```
tests/
├── test_helper.bash       # Shared setup, stubs configuration
├── <feature>.bats          # Test files named after features
└── stubs/                  # Command stubs for isolation
    ├── curl
    ├── qm
    └── ...
```

### 2.2 Conventions

- Every test file must start with: `load test_helper.bash`
- Use descriptive `@test` names in quotes
- Use stubs to isolate tests from real Proxmox infrastructure
- Assert exit codes: `[ "$status" -eq 0 ]`
- Assert output content: `[[ "$output" == *"expected"* ]]`
- Use `$CMD_LOG` to verify commands were called correctly

### 2.3 Coverage Goals

- All public scripts in `scripts/` should have a corresponding `.bats` file
- Test both success and failure paths
- Test interactive prompts with heredoc input: `echo "y" | ./script.sh`

---

## 3. Terraform Standards

### 3.1 Code Style

- Use `terraform fmt` before committing
- Variables must be declared in `variables.tf` with descriptions
- Sensitive variables must use `sensitive = true`
- Use named inputs in resource blocks

### 3.2 Security

- Never hardcode credentials — use environment variables or a secrets manager
- Set `tls_insecure = false` in production configurations
- Store `.tfstate` files securely (not in git)

---

## 4. Ansible Standards

### 4.1 Playbooks

- Always include `become: true` when root is required
- Use `tags` for selective task execution
- Prefer `when` conditions over multiple playbooks

### 4.2 Roles

- Follow standard role layout: `tasks/`, `handlers/`, `templates/`, `vars/`
- Document role requirements in `readme.md`

---

## 5. Documentation Standards

### 5.1 Markdown

- Use level-2 headers (`##`) for main sections
- Include code blocks with language tags: ```bash
- Add warning callouts for critical gotchas: `> **⚠️ PITFALL**: ...`
- Keep tables aligned and concise

### 5.2 README Files

Each subdirectory should have a `readme.md` that:
- Explains the purpose of the directory
- Lists available scripts or resources
- Provides quick examples

---

## 6. Git Rules

### 6.1 Commit Messages

Use conventional commit style:

```
<type>: <short description>

Optional body with more details.

Types: feat, fix, docs, chore, refactor, test, ci
```

Examples:
- `feat: add VM snapshot management script`
- `fix: handle missing config.sh gracefully`
- `docs: update GPU passthrough troubleshooting`
- `test: add bats test for clone_vm.sh`

### 6.2 Branch Strategy

- `main` — stable, tested code
- `feature/<name>` — new features
- `fix/<name>` — bug fixes
- `docs/<name>` — documentation changes

### 6.3 Files Never to Commit

- `config.sh` — use `config.example.sh` as template
- `config.k8s.sh` — use `config.k8s.example.sh` as template
- `*.tfstate` — terraform state
- `.terraform/` — provider plugins
- Any file containing passwords, API keys, or SSH private keys

---

## 7. Security Rules

- **Never** commit secrets, passwords, or API tokens
- **Always** use `config.example.sh` patterns — real configs are gitignored
- **Sanitize** example passwords in documentation before committing
- Prefer API tokens over password authentication for automation
- Use `--dry-run` where available before destructive operations

---

## 8. Pre-Commit Checklist

Before committing, ensure:

- [ ] All new scripts have corresponding BATS tests
- [ ] `shellcheck` passes on all modified scripts
- [ ] `terraform fmt` has been run (if Terraform files changed)
- [ ] No secrets or credentials in committed files
- [ ] File has a trailing newline
- [ ] Script is executable (`chmod +x`)
- [ ] README is updated for new features

---

## 9. File Organization

```
proxmox/
├── scripts/
│   ├── vm/              # VM-related scripts
│   ├── containers/      # LXC container scripts
│   ├── backup/          # Backup scripts
│   ├── api/             # API helper scripts
│   ├── k8s/             # Kubernetes deployment scripts
│   ├── network/         # Network utility scripts
│   ├── storage/         # Storage utility scripts
│   └── setup/           # Setup/initialization scripts
├── lib/
│   └── common.sh        # Shared library (source, don't execute directly)
├── tests/
│   ├── test_helper.bash
│   ├── *.bats
│   └── stubs/
├── automation/
│   ├── ansible/
│   ├── terraform/
│   └── cloud-init/
└── docs/, backup/, security/, etc.  # Documentation directories
```

**Rule:** Do not create directories with numeric suffixes (e.g., `ansible 2/`, `report 2.sh`). These indicate accidental duplicates and should be removed.

---

## 10. Tool Version Requirements

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| bash | 5.0+ | Script interpretation |
| bats | 1.8+ | Test framework |
| shellcheck | 0.8.0+ | Static analysis |
| shfmt | 3.0+ | Formatting |
| terraform | 1.5+ | Infrastructure as code |
| ansible | 8.0+ | Configuration management |

---

## Appendix: Quick Reference

### Common Library Functions (`lib/common.sh`)

| Function | Description |
|----------|-------------|
| `log_info` | Print informational message |
| `log_warn` | Print warning message |
| `log_error` | Print error message (to stderr) |
| `source_config` | Load config.sh from REPO_ROOT |
| `require_root` | Exit if not running as root |

### Config Variables (`config.sh`)

| Variable | Description |
|----------|-------------|
| `GITHUB_USERNAME` | GitHub username for SSH key download |
| `DEFAULT_STORAGE` | Default Proxmox storage pool |
| `DEFAULT_BRIDGE` | Default network bridge |
| `SSH_KEY_PATH` | Path to SSH public key |
| `DEFAULT_GATEWAY` | Default gateway IP |
| `TEMPLATE_ID_START` | Starting VM ID for templates |
| `BACKUP_STORAGE` | Backup destination storage |
| `BACKUP_RETENTION_DAYS` | Days to retain backups |