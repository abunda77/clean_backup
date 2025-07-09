# OpenCode Guidelines for `quota` Repository

## Build & Run
- No build step: scripts are standalone (Python & Bash).
- Execute Python tools: `python3 <script>.py [args]` (e.g. `python3 backup_quota_manager.py`).
- Execute Bash script: `chmod +x clean_backup.sh && ./clean_backup.sh`.

## Lint & Format
- Use **Black** for formatting: `black .`
- Use **isort** for import sorting: `isort .`
- Use **Flake8** for linting: `flake8 .`.

## Testing
- Use **pytest** for tests: `pytest`.
- Run a single test: `pytest path/to/test_file.py::test_function_name`.

## Style Guidelines
- **Imports**: order as `stdlib` → `third-party` → `local`.
- **Formatting**: 4-space indent, max line length 88 (Black default).
- **Naming**: `snake_case` for variables/functions, `PascalCase` for classes.
- **Typing**: add type hints for public functions; use `Path` over raw strings.
- **Error Handling**: catch specific exceptions; avoid bare `except:`; use `sys.exit(code)` or return `None`.
- **Logging**: prefer `logging` module over `print` in Python modules.

## Bash Scripts
- Start with `#!/usr/bin/env bash`, use `set -euo pipefail`.
- Functions in `lower_snake_case`, variables in `UPPER_SNAKE_CASE`.

> Keep these rules concise for agentic code edits and automated checks.
