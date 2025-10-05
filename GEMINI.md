# GEMINI Project Analysis

## Project Overview

This project is a collection of scripts designed for system cleaning and disk space management on Linux systems. The main script, `clean_backup.sh`, automates the process of cleaning system caches, user caches, and a specified backup directory. It features a modern, user-friendly terminal interface with colors, spinners, and progress bars.

The project also includes several Python scripts that provide more interactive and detailed analysis of disk usage:

*   `backup_quota_manager.py`: An interactive tool to manage backup folders, allowing users to view and delete them.
*   `cek_quota.py`: A curses-based file explorer for navigating the filesystem and viewing file/directory sizes.
*   `disk_checker.py`: An interactive tool to analyze the disk space usage of a specific folder.

The main technologies used are **Bash** for the main script and **Python 3** for the helper scripts.

## Building and Running

### Main Script (`clean_backup.sh`)

1.  **Configuration**: Before running the script, you need to configure the `BACKUP_DIR` variable in `clean_backup.sh` to point to your backup directory.

    ```bash
    BACKUP_DIR="/path/to/your/backups"
    ```

2.  **Permissions**: Make the script executable:

    ```bash
    chmod +x clean_backup.sh
    ```

3.  **Execution**: Run the script with:

    ```bash
    ./clean_backup.sh
    ```

    The script requires `sudo` privileges for system-level cleaning tasks.

### Python Scripts

The Python scripts can be run directly from the terminal:

```bash
python3 backup_quota_manager.py
python3 cek_quota.py
python3 disk_checker.py
```

These scripts have their own interactive prompts and do not require any special configuration, although some of them have hardcoded paths that might need to be changed.

## Development Conventions

### Code Style and Linting

*   **Python Formatting**: Use **Black** for formatting (`black .`)
*   **Python Import Sorting**: Use **isort** for import sorting (`isort .`)
*   **Python Linting**: Use **Flake8** for linting (`flake8 .`)
*   **Bash Scripts**: Start with `#!/usr/bin/env bash` and use `set -euo pipefail`.

### Testing

*   Use **pytest** for tests: `pytest`
*   Run a single test: `pytest path/to/test_file.py::test_function_name`

### General Guidelines

*   **Imports**: Order as `stdlib` -> `third-party` -> `local`.
*   **Formatting**: 4-space indent, max line length 88 (Black default).
*   **Naming**: `snake_case` for variables/functions, `PascalCase` for classes.
*   **Typing**: Add type hints for public functions; use `Path` over raw strings.
*   **Error Handling**: Catch specific exceptions; avoid bare `except:`; use `sys.exit(code)` or return `None`.
*   **Logging**: Prefer the `logging` module over `print` in Python modules.