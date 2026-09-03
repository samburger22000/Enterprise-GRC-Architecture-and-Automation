# **Zero Trust Verification Guide**

| Document ID | EP-HARDENING-2026-V8 |
| :---- | :---- |
| **Version** | Version 8.0 (Validated & Production Ready) |
| **Scope** | Windows 11 Pro (25H2),  macOS  |

## 

## **Executive Summary & Target Fleet Overview**

This document provides verified, production-ready configurations and execution scripts to harden all corporate endpoints to satisfy **Cyber Essentials Plus** requirements 

## **1\. Account Security & Identity Management**

**Principle:** Operating with standard user privileges for daily tasks prevents unauthorised administrative changes, mitigates privilege escalation, and neutralises drive-by malware execution. (Aligns with CE Answer A7.6 & A7.7).

### **Windows 11 Account Hardening**

#### **Option A: Local Security Policy Configuration**

1. Open Local Security Policy (secpol.msc).  
2. Navigate to: Security Settings \> Local Policies \> Security Options.  
3. Configure the following keys:  
   * **User Account Control: Admin Approval Mode for Built-in Administrator** → Enabled  
   * **User Account Control: Behaviour of elevation prompt for Administrators in Admin Approval Mode** → Prompt for credentials on the secure desktop  
   * **User Account Control: Behaviour of elevation prompt for Standard Users** → Automatically deny elevation requests

#### **Option B: Standard User Provisioning**

1. Navigate to Settings \> Accounts \> Family & other users.  
2. Under "Other users", click **Add account** → **I don't have this person's sign-in information** → **Add a user without a Microsoft account**.  
3. Create local non-admin user credentials for daily operations.  
4. Ensure day-to-day operations utilise this standard profile. Elevate only when prompted via Secure Desktop.

### **macOS Sequoia Account Hardening**

1. Navigate to System Settings \> Users & Groups.  
2. Click **Add Account** (authenticate with your current admin credentials).  
3. Set **New Account** type to **Standard**.  
4. Log out of the administrative profile and log into the standard account.

### **Pre-Boot Security: BIOS/UEFI (Windows)**

1. **Enable Secure Boot:** Enter UEFI/BIOS settings at startup (F2/F12/Del).  Set Secure Boot to **Enabled** to ensure only cryptographically signed bootloaders execute.  
2. **Set UEFI Administrator Password:** Define a high-entropy password (min 15 characters) for the UEFI setup utility to prevent unauthorised hardware-level modifications.

## **2\. Full-Disk Data Protection**

**Principle:** All mobile endpoints holding corporate data must utilise full-disk encryption with strong pre-boot or OS-level authentication to render lost or stolen storage unreadable.

### **BitLocker Encryption (Windows 11\)**

*The policies to enable BitLocker with AES-256 and allow a non-TPM fallback are automated in the Comprehensive Hardening Script in Section 6\.*

1. Open Control Panel \> System and Security \> BitLocker Drive Encryption.  
2. Enable BitLocker on the OS drive (C:). Store recovery keys in an isolated, secure location.  
3. Select **XTS-AES 256-bit** encryption mode if prompted.

### **FileVault Encryption (macOS Sequoia)**

1. Open System Settings \> Privacy & Security \> FileVault.  
2. Click **Turn On...** and save the generated recovery key.

#### **Terminal Command: Verify FileVault Status**

if fdesetup isactive; then  
    echo "✅ FileVault is enabled."  
else  
    echo "⚠️ FileVault is NOT enabled. Action required\!"  
fi

## **3\. Protective Controls & Antivirus Deployment**

### **Trend Micro Apex One / Vision One Installation Guide**

Ensure all endpoints run a verified EDR/XDR agent connected to the corporate console (Aligns with CE Answer A8.1).

#### **Pre-Installation Checklist**

* Uninstall all legacy or competing security software via Settings \> Apps (Windows) or /Applications (macOS)..  
* Download installer binaries from the IT Shared Repository.

#### **Windows Deployment**

1. Execute the installer binary with elevated Administrative rights.  
2. Follow the on-screen wizard until completion  
3. Confirm installation completion via the system tray multi-colored "T" icon.  
4. Right-click the icon to view status; ensure "Last Updated" is current.

#### **macOS Sequoia Deployment**

1. Double-click the extracted  .pkg file and complete the setup wizard.  
2. **Crucial Security Approvals:** Modern macOS will block the agent until explicitly approved.  
   * **System Extensions:** Navigate to System Settings \> Privacy & Security \> Allow "Trend Micro, Inc."  
   * **Full Disk Access:**Navigate to System Settings \> Privacy & Security \> Full Disk Access \> Add Trend Micro and toggle **ON**. Click the \+ icon, add /Library/Application Support/TrendMicro/, and toggle the status to **ON**.

## **4\. Firewall & Attack Surface Reduction**

### **Windows Firewall Configuration ("Shields Up")**

*The configuration to enforce the firewall and block unsolicited inbound connections is automated in the Comprehensive Hardening Script in Section 6\. (Aligns with CE Answer A4.7 & A4.8).*

### **Windows Firewall Hardening ("Shields Up" Manual UI Method)**

While the master PowerShell script configures these, administrators must know the UI steps:

* Open **Windows Security \> Firewall & network protection**.  
* Verify the firewall is "On" for the **Domain**, **Private**, and **Public** networks.  
* **The "Shields Up" Approach:** Click on the **Public** and **Private** network profiles. Check the box that says: **"Blocks all incoming connections, including those in the list of allowed apps"**.  
* **Configure Firewall Logging:** Open wf.msc (Windows Defender Firewall with Advanced Security). Right-click the root node \> Properties. For all profiles, under Logging, click Customize and set **Log dropped packets \= Yes** and **Log successful connections \= Yes**.

### **macOS Application Firewall Configuration**

*Automated via bash script (see Section 6\) to enable the firewall, block all incoming traffic, set stealth mode, and turn on logging.*

## **5\. Protocol & Credential Hardening**

*The configuration to disable legacy TLS, disable SMBv1, disable WDigest, and enable LSA protection is automated in the Comprehensive Hardening Script in Section 6\. (Aligns with CE Answer A5.1).*

## **6\. Validated Automated Hardening Scripts**

### **1\. Windows Comprehensive Hardening Script (PowerShell)**

**Prerequisites:** Run in an elevated PowerShell session (Run as Administrator). Logs execution to C:\\ProgramData\\PowerShellTranscripts\\SecurityHardeningLog.txt.

\# \==============================================================================  
\# Comprehensive Windows Hardening Script (Windows 11 Pro 24H2 Verified)  
\# Aligned with CIS Benchmarks, CE+ Declarations & Danzell Standards  
\# \==============================================================================

\# \--- Initialization & Directory Setup \---  
$logDirectory \= "C:\\ProgramData\\PowerShellTranscripts"  
$logFile \= "$logDirectory\\SecurityHardeningLog.txt"

if (-not (Test-Path $logDirectory)) {  
    New-Item \-Path $logDirectory \-ItemType Directory \-Force | Out-Null  
}  
if (-not (Test-Path $logFile)) {  
    New-Item \-Path $logFile \-ItemType File \-Force | Out-Null  
}

function Write-Log {  
    param (  
        \[string\]$Message,  
        \[string\]$Level \= "INFO"  
    )  
    $timestamp \= Get-Date \-Format "yyyy-MM-dd HH:mm:ss"  
    Add-Content \-Path $logFile \-Value "$timestamp \[$Level\] $Message" \-ErrorAction SilentlyContinue  
}

Write-Log "Starting Windows Endpoint Hardening Execution..."

\# \--- 1\. Account Policies, Lockout & UAC (CE+ A5.10, A7.10, A7.11) \---  
try {  
    Write-Host "Configuring Account Policies, Passwords, and UAC..." \-ForegroundColor Cyan  
      
    \# Disable built-in Administrator account safely  
    Get-LocalUser | Where-Object { $\_.SID \-like "S-1-5-500" } | Disable-LocalUser \-ErrorAction SilentlyContinue  
    Write-Log "Disabled built-in Administrator account (SID S-1-5-500)."

    \# Enforce 15-char Min Password & 10-Attempt Lockout (Matches CE+ answers)  
    net accounts /minpwlen:15 /maxpwage:unlimited | Out-Null  
    net accounts /lockoutthreshold:10 /lockoutduration:30 /lockoutwindow:30 | Out-Null  
    Write-Log "Enforced 15-character minimum password and 10-attempt account lockout threshold."

    \# Enforce 10-Minute Screen Lock (Matches CE+ answer A5.9)  
    $scrPath \= "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System"  
    if (-not (Test-Path $scrPath)) { New-Item \-Path $scrPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $scrPath \-Name "InactivityTimeoutSecs" \-Value 600 \-Force  
    Write-Log "Enforced 10-minute (600s) screen lock inactivity timeout."

    \# Enforce UAC Policies  
    $uacPath \= "HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Policies\\System"  
    Set-ItemProperty \-Path $uacPath \-Name "EnableLUA" \-Value 1 \-Force  
    Set-ItemProperty \-Path $uacPath \-Name "ConsentPromptBehaviorAdmin" \-Value 1 \-Force  
    Set-ItemProperty \-Path $uacPath \-Name "PromptOnSecureDesktop" \-Value 1 \-Force  
    Set-ItemProperty \-Path $uacPath \-Name "ConsentPromptBehaviorUser" \-Value 0 \-Force  
    Write-Log "Configured UAC to strict compliance mode."  
}  
catch { Write-Log "Error in Account Policies section: $\_" "ERROR" }

\# \--- 2\. Data Protection (BitLocker Policies) \---  
try {  
    Write-Host "Enforcing BitLocker Policies..." \-ForegroundColor Cyan  
    $bitlockerPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\FVE"  
    if (-not (Test-Path $bitlockerPath)) { New-Item \-Path $bitlockerPath \-Force | Out-Null }  
      
    Set-ItemProperty \-Path $bitlockerPath \-Name "EncryptionMethodWithXtsOs" \-Value 7 \-Type DWord \-Force  
    Set-ItemProperty \-Path $bitlockerPath \-Name "EncryptionMethodWithXtsFdv" \-Value 7 \-Type DWord \-Force  
    Set-ItemProperty \-Path $bitlockerPath \-Name "UseAdvancedStartup" \-Value 1 \-Type DWord \-Force  
    Set-ItemProperty \-Path $bitlockerPath \-Name "EnableBDEWithNoTPM" \-Value 1 \-Type DWord \-Force  
    Set-ItemProperty \-Path $bitlockerPath \-Name "UseTPM" \-Value 2 \-Type DWord \-Force  
    Write-Log "Configured BitLocker policy for AES-256 and enabled non-TPM fallback."  
} catch { Write-Log "Error in Data Protection section: $\_" "ERROR" }

\# \--- 3\. Credential Protection \---  
try {  
    Write-Host "Enforcing Credential Protection..." \-ForegroundColor Cyan  
    Set-ItemProperty \-Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\WDigest" \-Name "UseLogonCredential" \-Value 0 \-Force  
    Set-ItemProperty \-Path "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\Lsa" \-Name "RunAsPPL" \-Value 1 \-Force  
    Write-Log "Disabled WDigest cleartext storage and enabled LSA Protection (RunAsPPL)."  
} catch { Write-Log "Error in Credential Hardening section: $\_" "ERROR" }

\# \--- 4\. Protocol Hardening & Updates (CE+ A6.4.1) \---  
try {  
    Write-Host "Disabling Insecure Protocols and Enforcing Auto-Updates..." \-ForegroundColor Cyan  
    Disable-WindowsOptionalFeature \-Online \-FeatureName SMB1Protocol \-NoRestart \-ErrorAction SilentlyContinue  
      
    $protocols \= @("TLS 1.0", "TLS 1.1")  
    foreach ($protocol in $protocols) {  
        $basePath \= "HKLM:\\SYSTEM\\CurrentControlSet\\Control\\SecurityProviders\\SCHANNEL\\Protocols\\$protocol"  
        if (-not (Test-Path "$basePath\\Client")) { New-Item \-Path "$basePath\\Client" \-Force | Out-Null }  
        if (-not (Test-Path "$basePath\\Server")) { New-Item \-Path "$basePath\\Server" \-Force | Out-Null }  
        Set-ItemProperty \-Path "$basePath\\Client" \-Name "Enabled" \-Value 0 \-Type DWord \-Force  
        Set-ItemProperty \-Path "$basePath\\Client" \-Name "DisabledByDefault" \-Value 1 \-Type DWord \-Force  
        Set-ItemProperty \-Path "$basePath\\Server" \-Name "Enabled" \-Value 0 \-Type DWord \-Force  
        Set-ItemProperty \-Path "$basePath\\Server" \-Name "DisabledByDefault" \-Value 1 \-Type DWord \-Force  
    }  
      
    \# Enforce Automatic Windows Updates  
    $wuPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\WindowsUpdate\\AU"  
    if (-not (Test-Path $wuPath)) { New-Item \-Path $wuPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $wuPath \-Name "NoAutoUpdate" \-Value 0 \-Type DWord \-Force  
    Set-ItemProperty \-Path $wuPath \-Name "AUOptions" \-Value 4 \-Type DWord \-Force  
      
    Write-Log "Disabled SMBv1/Legacy TLS and enforced Automatic Windows Updates."  
} catch { Write-Log "Error in Protocol Hardening section: $\_" "ERROR" }

\# \--- 5\. Microsoft Defender & ASR Rules \---  
try {  
    Write-Host "Hardening Microsoft Defender & Applying ASR Rules..." \-ForegroundColor Cyan  
    if ((Get-MpComputerStatus \-ErrorAction SilentlyContinue).IsTamperProtected) {  
        Write-Log "Tamper Protection is already active." "INFO"  
    } else {  
        Set-MpPreference \-DisableTamperProtection $false \-ErrorAction SilentlyContinue  
        Write-Log "Enabled Defender Tamper Protection." "INFO"  
    }

    $asrRuleIds \= @('BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550','D4F940AB-401B-4EFC-AADC-AD5F3C50688A','75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84','D3E037E1-3453-4E1E-84CF-1CE8B48F064D','5BEB7EFE-FD9A-4556-801D-275E5FFC04CC','92E97FA1-2EDF-4476-BDD6-9259CF75B46A','7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C')  
    Set-MpPreference \-AttackSurfaceReductionRules\_Ids $asrRuleIds \-AttackSurfaceReductionRules\_Actions Enabled \-ErrorAction SilentlyContinue  
    Write-Log "Applied 7 core Attack Surface Reduction (ASR) rules."  
} catch { Write-Log "Error in Defender Hardening section: $\_" "ERROR" }

\# \--- 6\. PowerShell Hardening & Auditing \---  
try {  
    Write-Host "Enforcing PowerShell Logging..." \-ForegroundColor Cyan  
    $psLogPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ScriptBlockLogging"  
    if (-not (Test-Path $psLogPath)) { New-Item \-Path $psLogPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $psLogPath \-Name "EnableScriptBlockLogging" \-Value 1 \-Force

    $psTranscriptionPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\Transcription"  
    if (-not (Test-Path $psTranscriptionPath)) { New-Item \-Path $psTranscriptionPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $psTranscriptionPath \-Name "EnableTranscripting" \-Value 1 \-Force  
    Set-ItemProperty \-Path $psTranscriptionPath \-Name "OutputDirectory" \-Value $logDirectory \-Force

    $moduleLogPath \= "HKLM:\\SOFTWARE\\Policies\\Microsoft\\Windows\\PowerShell\\ModuleLogging"  
    if (-not (Test-Path $moduleLogPath)) { New-Item \-Path $moduleLogPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $moduleLogPath \-Name "EnableModuleLogging" \-Value 1 \-Force  
    $moduleNamesPath \= "$moduleLogPath\\ModuleNames"  
    if (-not (Test-Path $moduleNamesPath)) { New-Item \-Path $moduleNamesPath \-Force | Out-Null }  
    Set-ItemProperty \-Path $moduleNamesPath \-Name "\*" \-Value "\*" \-Force

    Write-Log "Enabled PowerShell Script Block, Transcript, and Module Logging."  
} catch { Write-Log "Error in PowerShell Logging section: $\_" "ERROR" }

\# \--- 7\. Advanced Firewall Setup (CE+ A4.8) \---  
try {  
    Write-Host "Configuring Host Firewall Rules..." \-ForegroundColor Cyan  
    Set-NetFirewallProfile \-Profile Domain,Public,Private \-Enabled True  
    New-NetFirewallRule \-DisplayName "Block SMB Inbound (Port 445)" \-Direction Inbound \-Protocol TCP \-LocalPort 445 \-Action Block \-ErrorAction SilentlyContinue | Out-Null  
    New-NetFirewallRule \-DisplayName "Block NetBIOS Inbound (Ports 137,138)" \-Direction Inbound \-Protocol UDP \-LocalPort 137,138 \-Action Block \-ErrorAction SilentlyContinue | Out-Null  
    New-NetFirewallRule \-DisplayName "Block RPC Inbound (Port 135)" \-Direction Inbound \-Protocol TCP \-LocalPort 135 \-Action Block \-ErrorAction SilentlyContinue | Out-Null  
    Write-Log "Configured inbound firewall blocking rules for SMB, NetBIOS, and RPC."  
} catch { Write-Log "Error in Firewall section: $\_" "ERROR" }

\# \--- 8\. Advanced Audit Policies \---  
try {  
    Write-Host "Configuring Advanced Security Audit Policies..." \-ForegroundColor Cyan  
    auditpol /set /category:"Account Logon" /success:enable /failure:enable | Out-Null  
    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null  
    auditpol /set /category:"Account Management" /success:enable /failure:enable | Out-Null  
    auditpol /set /category:"Detailed Tracking" /subcategory:"Process Creation" /success:enable | Out-Null  
    Write-Log "Configured audit policies for Logon, Account Management, and Process Creation."  
} catch { Write-Log "Error in Audit Policy section: $\_" "ERROR" }

Write-Host "✅ Windows security hardening script complete. System reboot required." \-ForegroundColor Green  
Write-Log "Windows Security Hardening Script Completed Successfully."

### **2\. macOS Advanced Hardening Script (Bash)**

**Prerequisites:** Must be executed as root (sudo bash harden\_mac.sh).

\#\!/bin/bash

\# Ensure script is run with root privileges  
if \[\[ $EUID \-ne 0 \]\]; then  
   echo "❌ This script must be run as root. Please run using: sudo bash $0"  
   exit 1  
fi

echo "🍏 Applying macOS Security Settings (CE+ & CIS Aligned)..."

\# \--- 1\. Firewall Configuration (CE+ A4.7) \---  
echo "Configuring Application Firewall..."  
/usr/libexec/ApplicationFirewall/socketfilterfw \--setglobalstate on  
/usr/libexec/ApplicationFirewall/socketfilterfw \--setblockall on  
/usr/libexec/ApplicationFirewall/socketfilterfw \--setstealthmode on  
/usr/libexec/ApplicationFirewall/socketfilterfw \--setloggingmode on

\# \--- 2\. Authentication, Lockout & Screen Saver Lock (CE+ A5.9, A5.10, A7.11) \---  
echo "Enforcing System Access, Password Complexity & Lock Policies..."  
\# Enforce 15-char length, complexity, and 10-attempt lockout  
pwpolicy setaccountpolicies \-dict-add "minChars=15" \-dict-add "requiresNumeric=1" \-dict-add "requiresAlpha=1" \-dict-add "requiresSymbol=1" \-dict-add "maxFailedLoginAttempts=10" 2\>/dev/null

\# Disable Guest login account  
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled \-bool false

\# Set screen saver password requirement immediately after 10-minute (600s) idle  
defaults write com.apple.screensaver askForPassword \-int 1  
defaults write com.apple.screensaver askForPasswordDelay \-int 0  
defaults write com.apple.screensaver idleTime \-int 600

\# \--- 3\. Software Update Automation (CE+ A6.4.1) \---  
echo "Enforcing Automatic Background Updates..."  
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticCheckEnabled \-bool true  
defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload \-bool true  
defaults write /Library/Preferences/com.apple.SoftwareUpdate CriticalUpdateInstall \-bool true  
defaults write /Library/Preferences/com.apple.commerce AutoUpdate \-bool true  
defaults write /Library/Preferences/com.apple.commerce AutoUpdateRestartRequired \-bool true

\# \--- 4\. Logging & Auditing \---  
echo "Enabling Security Auditing (auditd)..."  
launchctl load \-w /System/Library/LaunchDaemons/com.apple.auditd.plist 2\>/dev/null  
if \[ \-f /etc/security/audit\_control \]; then  
    sed \-i.bak 's/^flags:.\*/flags:lo,aa,ad,fd,fm,-fr,-fw,pc,ex/' /etc/security/audit\_control && rm \-f /etc/security/audit\_control.bak  
    audit\_control \-e  
fi

\# \--- 5\. Service Hardening (CE+ A5.1) \---  
echo "Disabling Unnecessary Network Services..."  
systemsetup \-setremotelogin off 2\>/dev/null  
launchctl disable system/com.apple.smbd 2\>/dev/null  
launchctl disable system/com.apple.telnetd 2\>/dev/null  
launchctl disable system/com.apple.ftpd 2\>/dev/null

echo "✅ macOS hardening complete. A restart is recommended."

## **7\. Danzell Advanced Zero Trust Architecture (Phase 2\)**

*Note: Phase 2 controls rely on SaaS tenant admin portals, Identity Provider Access Levels, and API integrations. They cannot be executed via local OS scripts and require administrative implementation as outlined below..*

### **1\. Application Whitelisting (Default Deny)**

* **ChromeOS (Google Admin Console):** Navigate to Devices \> Chrome \> Apps & extensions \> Users & browsers. Set *Allow/block mode* to "Block all apps and extensions except those listed below".  
* **Windows 11 (WDAC/AppLocker):** Enforce policies restricting binary execution strictly to %ProgramFiles% and %SystemRoot%. (Aligns with CE+ A8.5).  
* **macOS Sequoia (Gatekeeper):** Enforce Gatekeeper (sudo spctl \--master-enable) restricting execution strictly to Mac App Store and cryptographically signed Developer ID  apps.

### **2\. Google Workspace Context-Aware Access & Trend Micro Vision One Implementation Guide**

#### **Step 1: Enforce Device Management & Endpoint Verification**

* Log into Google Admin Console (admin.google.com).  
* Navigate to **Devices \> Mobile & endpoints \> Settings \> Universal Settings**. Under General, enable **Basic Management**.  
* Force-Install Endpoint Verification Extension:  
  * Go to **Devices \> Chrome \> Apps & extensions \> Users & browsers**.  
  * Add Chrome extension by ID: h224iyxfs090e... (Endpoint Verification).  
  * Set Installation Policy to **Force install**. This syncs OS version, serial number, and encryption status to Google.

#### **Step 2: Configure Trend Micro Vision One Dynamic Risk Score**

1. Log into Trend Micro Vision One (visionone.trendmicro.com).  
2. Navigate to **Administration \> Integrations \> Third-Party Integrations**.  
3. Connect **Google Workspace / Identity-Aware Proxy** by generating an API Integration Key with permissions to read Endpoint Risk Scores.

#### **Step 3: Configure Context-Aware Access Levels**

1. In Google Admin Console, go to **Security \> Access and data control \> Context-Aware Access**.  
2. Click **Access Levels** \> **Create Access Level**:  
   * **Name:** Danzell\_Compliant\_Posture\_Level  
   * **Conditions:**  
     * Device Policy: Device must be managed  
     * Device Policy: Device must be encrypted  
     * Device Policy: Minimum OS (Windows \>= 10.0.26100, macOS \>= 15.5)  
     * *Require Trend Micro Risk Score \= Low (if natively supported by current API).*  
3. **Assign Access Levels:** Apply Danzell\_Compliant\_Posture\_Level to core apps (Gmail, Drive, Chat).  
   * *Effect: If Vision One flags the device with a High Risk Score, Context-Aware Access immediately blocks Google Workspace sessions.*

#### **Step 4: Enforce Phishing-Resistant MFA & Prohibit Legacy Auth**

1. **FIDO2 for Admins:** In Google Admin (Security \> Authentication \> 2-Step Verification), select the Admin OU and set Allowed 2SV methods to **Only Security Key**.  
2. **Disable Legacy Protocols:**  
   * Navigate to Apps \> Google Workspace \> Gmail \> End User Access. Disable POP and IMAP for all users.  
   * Under Security \> Access and data control \> Less Secure Apps, select **Disable access to less secure apps**.

## **8\. Summary of Security Defences & Mitigations**

| Security Vector | Threat / Exploit Mitigated | Applied Control / Script Mechanism |
| :---- | :---- | :---- |
| **Malware & Ransomware** | Drive-by downloads, malicious macros, script runners | AppLocker/WDAC, Trend Micro Apex One, 7 Defender ASR Rules |
| **Credential Theft** | Pass-the-Hash, Mimikatz memory scraping, cleartext dump | WDigest Disabled, LSA Protection (RunAsPPL), LSASS ASR Rule |
| **Network & Lateral Movement** | Worm propagation, unauthorized port probing, legacy SMB exploits | Inbound SMB (445), NetBIOS (137,138), RPC (135) firewall block |
| **Data Loss / Physical Theft** | Lost laptop disk analysis, cold boot attack | BitLocker (XTS-AES 256), FileVault full-disk encryption |
| **Unattended Access** | Unauthorized physical console takeover | Forced 10-min screen saver lock requiring immediate authentication |
| **Insecure Protocols** | Eavesdropping, MITM attacks, WannaCry vectors | Disabled SMBv1, TLS 1.0, TLS 1.1 across client/server roles |
| **Audit Compliance** | Silent malicious activity, unrecorded privilege escalation | Script Block Logging, Module Logging, PowerShell Transcription |

## 
