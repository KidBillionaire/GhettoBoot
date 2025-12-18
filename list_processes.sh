#!/bin/bash

# GhettoBoot Process Listing Script
# Usage: ./list_processes.sh [option]
# Options:
#   -a, --all       Show all processes (default)
#   -m, --memory    Sort by memory usage
#   -c, --cpu       Sort by CPU usage
#   -u, --user      Filter by user
#   -h, --help      Show this help message

show_help() {
    echo "😊 GhettoBoot Process Listing Script"
    echo "===================================="
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  -a, --all       Show all processes (default)"
    echo "  -m, --memory    Sort by memory usage (highest first)"
    echo "  -c, --cpu       Sort by CPU usage (highest first)"
    echo "  -u, --user      Filter by specific user"
    echo "  -t, --tree      Show process tree"
    echo "  -h, --help      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Show all processes"
    echo "  $0 -m           # Sort by memory usage"
    echo "  $0 -c           # Sort by CPU usage"
    echo "  $0 -u root      # Show only root processes"
    echo "  $0 -t           # Show process tree"
}

# Default action: show all processes
case "$1" in
    -a|--all)
        echo "😊 === All Processes ==="
        ps aux
        ;;
    -m|--memory)
        echo "😊 === Processes Sorted by Memory Usage ==="
        ps aux --sort=-%mem | head -20
        ;;
    -c|--cpu)
        echo "😊 === Processes Sorted by CPU Usage ==="
        ps aux --sort=-%cpu | head -20
        ;;
    -u|--user)
        if [ -z "$2" ]; then
            echo "Error: Please specify a username"
            echo "Usage: $0 -u <username>"
            exit 1
        fi
        echo "😊 === Processes for User: $2 ==="
        ps aux | grep "^$2"
        ;;
    -t|--tree)
        echo "😊 === Process Tree ==="
        if command -v pstree &> /dev/null; then
            pstree -p
        else
            echo "pstree not available, using ps forest view:"
            ps auxf
        fi
        ;;
    -h|--help)
        show_help
        ;;
    "")
        echo "😊 === All Processes ==="
        ps aux
        ;;
    *)
        echo "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac
