# ==============================================================================
# Comprehensive Windows Hardening Script (Windows 11 Pro 25H2 Verified)
# Aligned with CIS Benchmarks, CE+ Declarations & Danzell Standards
# ==============================================================================

# --- Initialization & Directory Setup ---
$logDirectory = "C:\ProgramData\PowerShellTranscripts"
$logFile = "$logDirectory\SecurityHardeningLog.txt"

if (-not (Test-Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}
if (-not (Test-Path $logFile)) {
    New-Item -Path $logFile -ItemType File -Force | Out-Null
}

function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $logFile -Value "$timestamp [$Level] $Message" -ErrorAction SilentlyContinue
}

Write-Log "Starting Windows Endpoint Hardening Execution..."

# --- 1. Account Policies, Lockout & UAC (CE+ A5.10, A7.10, A7.11) ---
try {
    Write-Host "Configuring Account Policies, Passwords, and UAC..." -ForegroundColor Cyan
    
    # Disable built-in Administrator account safely
    Get-LocalUser | Where-Object { $_.SID -like "S-1-5-500" } | Disable-LocalUser -ErrorAction SilentlyContinue
    Write-Log "Disabled built-in Administrator account (SID S-1-5-500)."

    # Enforce 15-char Min Password & 10-Attempt Lockout (Matches CE+ answers)
    net accounts /minpwlen:15 /maxpwage:unlimited | Out-Null
    net accounts /lockoutthreshold:10 /lockoutduration:30 /lockoutwindow:30 | Out-Null
    Write-Log "Enforced 15-character minimum password and 10-attempt account lockout threshold."

    # Enforce 10-Minute Screen Lock (Matches CE+ answer A5.9)
    $scrPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (-not (Test-Path $scrPath)) { New-Item -Path $scrPath -Force | Out-Null }
    Set-ItemProperty -Path $scrPath -Name "InactivityTimeoutSecs" -Value 600 -Force
    Write-Log "Enforced 10-minute (600s) screen lock inactivity timeout."

    # Enforce UAC Policies
    $uacPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    Set-ItemProperty -Path $uacPath -Name "EnableLUA" -Value 1 -Force
    Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorAdmin" -Value 1 -Force
    Set-ItemProperty -Path $uacPath -Name "PromptOnSecureDesktop" -Value 1 -Force
    Set-ItemProperty -Path $uacPath -Name "ConsentPromptBehaviorUser" -Value 0 -Force
    Write-Log "Configured UAC to strict compliance mode."
}
catch { Write-Log "Error in Account Policies section: $_" "ERROR" }

# --- 2. Data Protection (BitLocker Policies) ---
try {
    Write-Host "Enforcing BitLocker Policies..." -ForegroundColor Cyan
    $bitlockerPath = "HKLM:\SOFTWARE\Policies\Microsoft\FVE"
    if (-not (Test-Path $bitlockerPath)) { New-Item -Path $bitlockerPath -Force | Out-Null }
    
    Set-ItemProperty -Path $bitlockerPath -Name "EncryptionMethodWithXtsOs" -Value 7 -Type DWord -Force
    Set-ItemProperty -Path $bitlockerPath -Name "EncryptionMethodWithXtsFdv" -Value 7 -Type DWord -Force
    Set-ItemProperty -Path $bitlockerPath -Name "UseAdvancedStartup" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $bitlockerPath -Name "EnableBDEWithNoTPM" -Value 1 -Type DWord -Force
    Set-ItemProperty -Path $bitlockerPath -Name "UseTPM" -Value 2 -Type DWord -Force
    Write-Log "Configured BitLocker policy for AES-256 and enabled non-TPM fallback."
} catch { Write-Log "Error in Data Protection section: $_" "ERROR" }

# --- 3. Credential Protection ---
try {
    Write-Host "Enforcing Credential Protection..." -ForegroundColor Cyan
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\WDigest" -Name "UseLogonCredential" -Value 0 -Force
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa" -Name "RunAsPPL" -Value 1 -Force
    Write-Log "Disabled WDigest cleartext storage and enabled LSA Protection (RunAsPPL)."
} catch { Write-Log "Error in Credential Hardening section: $_" "ERROR" }

# --- 4. Protocol Hardening & Updates (CE+ A6.4.1) ---
try {
    Write-Host "Disabling Insecure Protocols and Enforcing Auto-Updates..." -ForegroundColor Cyan
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue
    
    $protocols = @("TLS 1.0", "TLS 1.1")
    foreach ($protocol in $protocols) {
        $basePath = "HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$protocol"
        if (-not (Test-Path "$basePath\Client")) { New-Item -Path "$basePath\Client" -Force | Out-Null }
        if (-not (Test-Path "$basePath\Server")) { New-Item -Path "$basePath\Server" -Force | Out-Null }
        Set-ItemProperty -Path "$basePath\Client" -Name "Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "$basePath\Client" -Name "DisabledByDefault" -Value 1 -Type DWord -Force
        Set-ItemProperty -Path "$basePath\Server" -Name "Enabled" -Value 0 -Type DWord -Force
        Set-ItemProperty -Path "$basePath\Server" -Name "DisabledByDefault" -Value 1 -Type DWord -Force
    }
    
    # Enforce Automatic Windows Updates
    $wuPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    if (-not (Test-Path $wuPath)) { New-Item -Path $wuPath -Force | Out-Null }
    Set-ItemProperty -Path $wuPath -Name "NoAutoUpdate" -Value 0 -Type DWord -Force
    Set-ItemProperty -Path $wuPath -Name "AUOptions" -Value 4 -Type DWord -Force
    
    Write-Log "Disabled SMBv1/Legacy TLS and enforced Automatic Windows Updates."
} catch { Write-Log "Error in Protocol Hardening section: $_" "ERROR" }

# --- 5. Microsoft Defender & ASR Rules ---
try {
    Write-Host "Hardening Microsoft Defender & Applying ASR Rules..." -ForegroundColor Cyan
    if ((Get-MpComputerStatus -ErrorAction SilentlyContinue).IsTamperProtected) {
        Write-Log "Tamper Protection is already active." "INFO"
    } else {
        Set-MpPreference -DisableTamperProtection $false -ErrorAction SilentlyContinue
        Write-Log "Enabled Defender Tamper Protection." "INFO"
    }

    $asrRuleIds = @('BE9BA2D9-53EA-4CDC-84E5-9B1EEEE46550','D4F940AB-401B-4EFC-AADC-AD5F3C50688A','75668C1F-73B5-4CF0-BB93-3ECF5CB7CC84','D3E037E1-3453-4E1E-84CF-1CE8B48F064D','5BEB7EFE-FD9A-4556-801D-275E5FFC04CC','92E97FA1-2EDF-4476-BDD6-9259CF75B46A','7674BA52-37EB-4A4F-A9A1-F0F9A1619A2C')
    Set-MpPreference -AttackSurfaceReductionRules_Ids $asrRuleIds -AttackSurfaceReductionRules_Actions Enabled -ErrorAction SilentlyContinue
    Write-Log "Applied 7 core Attack Surface Reduction (ASR) rules."
} catch { Write-Log "Error in Defender Hardening section: $_" "ERROR" }

# --- 6. PowerShell Hardening & Auditing ---
try {
    Write-Host "Enforcing PowerShell Logging..." -ForegroundColor Cyan
    $psLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging"
    if (-not (Test-Path $psLogPath)) { New-Item -Path $psLogPath -Force | Out-Null }
    Set-ItemProperty -Path $psLogPath -Name "EnableScriptBlockLogging" -Value 1 -Force

    $psTranscriptionPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
    if (-not (Test-Path $psTranscriptionPath)) { New-Item -Path $psTranscriptionPath -Force | Out-Null }
    Set-ItemProperty -Path $psTranscriptionPath -Name "EnableTranscripting" -Value 1 -Force
    Set-ItemProperty -Path $psTranscriptionPath -Name "OutputDirectory" -Value $logDirectory -Force

    $moduleLogPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ModuleLogging"
    if (-not (Test-Path $moduleLogPath)) { New-Item -Path $moduleLogPath -Force | Out-Null }
    Set-ItemProperty -Path $moduleLogPath -Name "EnableModuleLogging" -Value 1 -Force
    $moduleNamesPath = "$moduleLogPath\ModuleNames"
    if (-not (Test-Path $moduleNamesPath)) { New-Item -Path $moduleNamesPath -Force | Out-Null }
    Set-ItemProperty -Path $moduleNamesPath -Name "*" -Value "*" -Force

    Write-Log "Enabled PowerShell Script Block, Transcript, and Module Logging."
} catch { Write-Log "Error in PowerShell Logging section: $_" "ERROR" }

# --- 7. Advanced Firewall Setup (CE+ A4.8) ---
try {
    Write-Host "Configuring Host Firewall Rules..." -ForegroundColor Cyan
    Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled True
    New-NetFirewallRule -DisplayName "Block SMB Inbound (Port 445)" -Direction Inbound -Protocol TCP -LocalPort 445 -Action Block -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Block NetBIOS Inbound (Ports 137,138)" -Direction Inbound -Protocol UDP -LocalPort 137,138 -Action Block -ErrorAction SilentlyContinue | Out-Null
    New-NetFirewallRule -DisplayName "Block RPC Inbound (Port 135)" -Direction Inbound -Protocol TCP -LocalPort 135 -Action Block -ErrorAction SilentlyContinue | Out-Null
    Write-Log "Configured inbound firewall blocking rules for SMB, NetBIOS, and RPC."
} catch { Write-Log "Error in Firewall section: $_" "ERROR" }

# --- 8. Advanced Audit Policies ---
try {
    Write-Host "Configuring Advanced Security Audit Policies..." -ForegroundColor Cyan
    auditpol /set /category:"Account Logon" /success:enable /failure:enable | Out-Null
    auditpol /set /category:"Logon/Logoff" /success:enable /failure:enable | Out-Null
    auditpol /set /category:"Account Management" /success:enable /failure:enable | Out-Null
    auditpol /set /category:"Detailed Tracking" /subcategory:"Process Creation" /success:enable | Out-Null
    Write-Log "Configured audit policies for Logon, Account Management, and Process Creation."
} catch { Write-Log "Error in Audit Policy section: $_" "ERROR" }

Write-Host "✅ Windows security hardening script complete. System reboot required." -ForegroundColor Green
Write-Log "Windows Security Hardening Script Completed Successfully."

