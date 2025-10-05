# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a backup and quota management system containing both Python and Bash scripts for monitoring disk usage, managing backup directories, and performing system cleanup operations. The repository is written primarily in Indonesian with mixed English/Indonesian documentation.

## Core Components

### Main Scripts
- **clean_backup.sh**: Interactive bash script for comprehensive system cleaning with animated terminal UI
- **backup_quota_manager.py**: Python utility for managing backup directory quotas and cleanup
- **cek_quota.py**: Real-time disk quota monitoring with curses-based TUI interface
- **disk_checker.py**: Disk usage monitoring utility

### Key Features
- System cleaning (APT cache, journal logs, Netdata cache)
- User directory cache cleanup
- Backup directory management with size-based deletion
- Real-time quota monitoring with visual indicators
- Animated terminal interface optimized for dark themes

## Development Commands

### Running Scripts
```bash
# Make executable and run bash script
chmod +x clean_backup.sh
./clean_backup.sh

# Run Python tools
python3 backup_quota_manager.py
python3 cek_quota.py
python3 disk_checker.py
```

### Code Quality
```bash
# Python formatting and linting
black .
isort .
flake8 .

# Run tests
pytest
pytest path/to/test_file.py::test_function_name
```

## Architecture

### Configuration
- Backup directory configured in `clean_backup.sh:7` (default: `/home/clp/backups`)
- Log file location: `/var/log/clean_backup.log`
- Uses temporary stats file for processing

### Script Dependencies
- **clean_backup.sh**: Requires sudo for system operations, Bash 4.0+ for Unicode support
- **Python scripts**: Standard library only (os, shutil, pathlib, curses, threading, subprocess)
- System tools: `apt`, `journalctl`, `systemctl`, `df`, `du`

### Error Handling
- Bash scripts use `set -euo pipefail` for strict error handling
- Python utilities catch specific exceptions and handle permission errors gracefully
- Logging to both console and system log files

### Visual Design
- Optimized for dark terminal themes with high-contrast ANSI colors
- Unicode symbols and box-drawing characters for visual appeal
- Animated spinners and progress bars using Braille patterns
- Real-time status feedback with success/failure indicators

## Important Notes

### Safety Considerations
- Scripts perform destructive operations (file deletion)
- Always verify backup directories before running cleanup
- Requires careful review of target paths in configuration
- System operations need sudo privileges

### Localization
- Primary language: Indonesian for user-facing messages
- Code comments mix Indonesian and English
- Error messages and logs primarily in Indonesian

### Performance
- Directory size calculations use caching in `cek_quota.py`
- Multithreading for responsive TUI updates
- Efficient file operations with proper error handling