#!/bin/bash

# Ensure script is run with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root. Please run using: sudo bash $0"
   exit 1
fi

echo "🍏 Applying macOS Security Settings (CE+ & CIS Aligned)..."

# --- 1. Firewall Configuration (CE+ A4.7) ---
echo "Configuring Application Firewall..."
/usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
/usr/libexec/ApplicationFirewall/socketfilterfw --setblockall on
/usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
/usr/libexec/ApplicationFirewall/socketfilterfw --setloggingmode on

# --- 2. Authentication, Lockout & Screen Saver Lock (CE+ A5.9, A5.10, A7.11) ---
echo "Enforcing System Access, Password Complexity & Lock Policies..."
# Enforce 15-char length, complexity, and 10-attempt lockout
pwpolicy setaccountpolicies -dict-add "minChars=15" -dict-add "requiresNumeric=1" -dict-add "requiresAlpha=1" -dict-add "requiresSymbol=1" -dict-add "maxFailedLoginAttempts=10" 2>/dev/null

# Disable Guest login account
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

# Set screen saver password requirement immediately after 10-minute (600s) idle
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0
defaults write com.apple.screensaver idleTime -int 600

# --- 3. Software Update Automation (CE+ A6.4.1) ---
echo "Enforcing Automatic Background Updates..."
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall -bool true
defaults write /Library/Preferences/com.apple.commerce AutoUpdate -bool true
defaults write /Library/Preferences/com.apple.commerce AutoUpdateRestartRequired -bool true

# --- 4. Logging & Auditing ---
echo "Enabling Security Auditing (auditd)..."
launchctl load -w /System/Library/LaunchDaemons/com.apple.auditd.plist 2>/dev/null
if [ -f /etc/security/audit_control ]; then
    sed -i.bak 's/^flags:.*/flags:lo,aa,ad,fd,fm,-fr,-fw,pc,ex/' /etc/security/audit_control && rm -f /etc/security/audit_control.bak
    audit_control -e
fi

# --- 5. Service Hardening (CE+ A5.1) ---
echo "Disabling Unnecessary Network Services..."
systemsetup -setremotelogin off 2>/dev/null
launchctl disable system/com.apple.smbd 2>/dev/null
launchctl disable system/com.apple.telnetd 2>/dev/null
launchctl disable system/com.apple.ftpd 2>/dev/null

echo "✅ macOS hardening complete. A restart is recommended."
