# Contributing

Contributions are welcome. Please:

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Ensure all scripts pass `shellcheck`
4. Test on Proxmox VE 8.x
5. Submit a pull request

## Script Standards

- Source `lib/common.sh`
- Use `set -euo pipefail`
- Include `--help` flag
- Validate all user inputs
- Use `log_*` functions for output
- Default to safe mode for destructive operations (`--dry-run` or confirmation prompt)
