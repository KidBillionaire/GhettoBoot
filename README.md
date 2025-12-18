# 😊 GhettoBoot Process Listing Script

A friendly command-line utility for listing and managing system processes with style!

## Features

- 😊 List all running processes
- 📊 Sort by memory or CPU usage
- 👤 Filter processes by user
- 🌳 Display process tree view
- 🎯 Simple, clean output with helpful headers

## Installation

The script is ready to use! Just make sure it's executable:

```bash
chmod +x list_processes.sh
```

## Usage

### Basic Commands

```bash
# Show all processes (default)
./list_processes.sh

# Show all processes explicitly
./list_processes.sh -a
./list_processes.sh --all

# Sort by memory usage (top 20)
./list_processes.sh -m
./list_processes.sh --memory

# Sort by CPU usage (top 20)
./list_processes.sh -c
./list_processes.sh --cpu

# Filter by specific user
./list_processes.sh -u root
./list_processes.sh --user username

# Show process tree
./list_processes.sh -t
./list_processes.sh --tree

# Show help
./list_processes.sh -h
./list_processes.sh --help
```

## Examples

```bash
# Find memory-intensive processes
./list_processes.sh -m

# See what a specific user is running
./list_processes.sh -u root

# View the entire process hierarchy
./list_processes.sh -t
```

## Output Format

Each command displays a friendly smiley face (😊) before showing results to keep things positive while managing your system!

## Requirements

- Bash shell
- Standard Unix utilities: `ps`, `grep`, `awk`
- Optional: `pstree` for enhanced tree view

## License

GhettoBoot - Because even process management should make you smile! 😊

---

*Created with love for system administrators who need their processes listed with a smile.*
