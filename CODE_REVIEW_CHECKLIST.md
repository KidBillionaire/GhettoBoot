# GhettoBoot Code Review Security Checklist

Use this checklist before merging any changes to ensure no post-stop execution mechanisms are introduced.

## Pre-Merge Security Checklist

### ✅ Shell Script Changes

- [ ] **No trap handlers added** (except `trap '' EXIT`)
  - Search for: `trap '[^']'` or `trap "[^"]"`
  - Allowed: `trap '' EXIT` (no-op trap)
  - Forbidden: Any trap that executes code

- [ ] **No background processes**
  - Search for: `&` at end of commands
  - Search for: `nohup`
  - Forbidden: Any background process spawning

- [ ] **No cron job installation**
  - Search for: `crontab`
  - Search for: `at `
  - Forbidden: Any scheduled task creation

- [ ] **No service installation**
  - Search for: `launchctl load`
  - Search for: `launchctl bootstrap`
  - Search for: `systemctl enable`
  - Search for: `systemctl start`
  - Allowed: `launchctl disable` (removes persistence)
  - Forbidden: Any service installation

### ✅ Configuration Files

- [ ] **No .plist files added**
  - Check: `find . -name "*.plist"`
  - Forbidden: Any launchd service definitions

- [ ] **No systemd service files**
  - Check: `find . -name "*.service" -o -name "*.timer"`
  - Forbidden: Any systemd unit files

- [ ] **No cron configuration files**
  - Check: `find . -name "crontab*" -o -name "*.cron"`
  - Forbidden: Any cron configuration

### ✅ Script Behavior

- [ ] **Changes are temporary only**
  - Verify: All changes reset on reboot
  - Check: No persistent modifications to system files

- [ ] **Clean exit behavior**
  - Verify: Scripts exit cleanly without side effects
  - Check: No cleanup functions that run on exit

- [ ] **No persistence mechanisms**
  - Check: No modifications to ~/.bashrc, ~/.zshrc, etc.
  - Check: No startup script installation
  - Check: No login item creation

## Automated Security Scan

Run these commands before merging:

```bash
# Check for trap handlers
grep -n "trap [^']" *.sh

# Check for background processes
grep -n "&\|nohup" *.sh

# Check for cron/scheduled tasks
grep -n "crontab\|at " *.sh

# Check for service installation
grep -n "launchctl load\|launchctl bootstrap\|systemctl enable" *.sh

# Find service configuration files
find . -name "*.plist" -o -name "*.service" -o -name "*.timer" -o -name "crontab*"

# List all executable files
find . -type f -executable | grep -v '.git'
```

All commands should return **no results** (except allowed patterns).

## Quick Security Test

```bash
# Run the security verification script
./verify_no_persistence.sh

# Check git diff for dangerous patterns
git diff main | grep -E "trap|&|nohup|crontab|launchctl (load|bootstrap)|systemctl enable"
```

## Review Sign-Off

- [ ] All automated checks passed
- [ ] Manual code review completed
- [ ] No post-stop execution mechanisms found
- [ ] Changes maintain temporary-only behavior
- [ ] Security documentation updated if needed

**Reviewer:** _______________
**Date:** _______________
**Branch:** _______________

---

## Common Violations to Watch For

### ❌ FORBIDDEN Examples

```bash
# DO NOT ADD these patterns:

# Trap with execution
trap 'cleanup_function' EXIT
trap "rm -rf /tmp/data" TERM

# Background processes
./my_daemon &
nohup ./service.sh &

# Cron installation
echo "0 * * * * /path/to/script" | crontab -

# Service installation
launchctl load ~/Library/LaunchAgents/my.service.plist
systemctl enable my-service

# Persistent modifications
echo "source /path/to/malicious.sh" >> ~/.bashrc
```

### ✅ ALLOWED Examples

```bash
# These patterns are safe:

# No-op trap (explicitly ignores EXIT)
trap '' EXIT

# Service disabling (removes persistence)
launchctl disable system/com.apple.example

# Temporary changes that reset on reboot
mount -u -o noexec /Volumes/Data
kill -9 $PID

# Read-only operations
ps aux
mount | grep noexec
```

---

## Emergency Response

If dangerous patterns are found in a merged PR:

1. **Immediate Actions:**
   - Revert the commit immediately
   - Notify team of security violation
   - Re-run security audit on all branches

2. **Investigation:**
   - Identify what persistence mechanisms were added
   - Check if any systems have been compromised
   - Review access logs

3. **Remediation:**
   - Remove all persistence mechanisms
   - Re-review code with security focus
   - Update this checklist if new patterns emerge

---

## Update History

- **2025-12-18:** Initial checklist created
  - Added comprehensive security checks
  - Added automated scan commands
  - Added violation examples
