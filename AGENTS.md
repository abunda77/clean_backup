# Repository Guidelines

## Project Structure & Module Organization
<code>clean_backup.sh</code> is the primary entry point; it stages system cleanup, user cache pruning, and backup rotation. Python companions (<code>backup_quota_manager.py</code>, <code>cek_quota.py</code>, <code>disk_checker.py</code>) handle quota analysis and disk reporting—keep each script self-contained so it can run alone. Reference documents (<code>README.md</code>, <code>docker.md</code>, model-specific guides) live at the root; add new tooling notes alongside them for discoverability. Logs default to <code>/var/log/clean_backup.log</code>, so document alternate paths in code comments and PR descriptions.

## Build, Test, and Development Commands
Run the cleanup workflow locally with <code>bash clean_backup.sh</code>; export <code>BACKUP_DIR=/tmp/test-backups</code> to rehearse against disposable data. Validate syntax quickly via <code>bash -n clean_backup.sh</code> and, when available, <code>shellcheck clean_backup.sh</code>. Python utilities should be exercised with <code>python backup_quota_manager.py --help</code> (or module-specific flags) and their happy-path scenarios verified against a staged backup directory.

## Coding Style & Naming Conventions
Bash functions follow snake_case, constants stay uppercase, and indentation sticks to four spaces for readability. Maintain the existing use of ANSI color variables and Unicode icons—extend them via shared helper functions rather than inline escape sequences. Python code should observe PEP 8 spacing, use descriptive snake_case naming, and provide docstrings for public functions that touch the filesystem. Favor f-strings for formatting and wrap filesystem mutations with clear guard clauses.

## Testing Guidelines
Every change must document the manual scenario exercised (for example, “ran clean_backup.sh against /tmp/test-backups with two expired snapshots”). When scripts gain branching logic, include lightweight regression checks: <code>bash -n</code>, <code>shellcheck</code>, or small pytest-style functions under a future <code>tests/</code> folder. For quota tools, stage fixtures under <code>./fixtures</code> (create if absent) and clean them afterwards to avoid polluting backups. Target at least smoke coverage for destructive operations before requesting review.

## Commit & Pull Request Guidelines
Follow the emerging Conventional Commit style used here (feat:, chore:, update:) with an imperative summary under 72 characters. Commits should be scoped logically—separate script changes from documentation updates. Pull requests need a concise description, reproduction or verification steps, and screenshots or terminal captures when visuals change. Link tracking issues with “Refs #123” when applicable and call out any sudo or environment prerequisites explicitly.

## Security & Configuration Notes
These scripts execute privileged commands; always test with non-production directories before enabling sudo paths. Never commit real backup paths or secrets—use placeholder directories in examples. When introducing new environment variables, provide sane defaults and note them in <code>README.md</code> so operators can configure them safely.
