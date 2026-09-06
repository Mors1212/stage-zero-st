$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

$Version = '1.0.0'
$DisplayedDesktop = [Environment]::GetFolderPath('Desktop')

function Refresh-Path {
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = ($machine, $user -join ';')
}

function Has-Command([string]$Name) {
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Add-KnownPath([string[]]$Candidates) {
    foreach ($dir in $Candidates) {
        if ($dir -and (Test-Path $dir) -and ($env:Path -notlike "*$dir*")) {
            $env:Path += ";$dir"
        }
    }
}

function Install-WingetPackage([string]$Id, [string]$DisplayName) {
    Write-Host ""
    Write-Host "กำลังติดตั้ง $DisplayName..." -ForegroundColor Cyan

    & winget install --exact --id $Id `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent

    if ($LASTEXITCODE -ne 0) {
        throw "ติดตั้ง $DisplayName ไม่สำเร็จ (winget exit code $LASTEXITCODE)"
    }

    Refresh-Path
}

function Ensure-Git {
    Refresh-Path

    if (Has-Command 'git') {
        Write-Host "✓ พบ $(& git --version)" -ForegroundColor Green
        return
    }

    Write-Host "ไม่พบ Git" -ForegroundColor Yellow
    Install-WingetPackage 'Git.Git' 'Git for Windows'

    Add-KnownPath @(
        "$env:ProgramFiles\Git\cmd",
        "${env:ProgramFiles(x86)}\Git\cmd",
        "$env:LOCALAPPDATA\Programs\Git\cmd"
    )

    if (-not (Has-Command 'git')) {
        throw 'ติดตั้ง Git แล้ว แต่ Windows ยังเรียกใช้งาน git ไม่ได้ กรุณาปิด Installer แล้วเปิดใหม่อีกครั้ง'
    }

    Write-Host "✓ Git พร้อมใช้งาน" -ForegroundColor Green
}

function Get-NodeMajor {
    if (-not (Has-Command 'node')) { return $null }

    try {
        $v = (& node --version 2>$null).Trim().TrimStart('v')
        return [int]($v.Split('.')[0])
    }
    catch {
        return $null
    }
}

function Ensure-Node {
    Refresh-Path
    $major = Get-NodeMajor

    if ($null -ne $major -and $major -ge 20) {
        Write-Host "✓ พบ Node.js $(& node --version)" -ForegroundColor Green
        return
    }

    if ($null -eq $major) {
        Write-Host "ไม่พบ Node.js" -ForegroundColor Yellow
    }
    else {
        Write-Host "Node.js ปัจจุบันเก่าเกินไป" -ForegroundColor Yellow
    }

    Install-WingetPackage 'OpenJS.NodeJS.LTS' 'Node.js LTS'

    Add-KnownPath @(
        "$env:ProgramFiles\nodejs",
        "$env:LOCALAPPDATA\Programs\nodejs"
    )

    $major = Get-NodeMajor
    if ($null -eq $major) {
        throw 'ติดตั้ง Node.js แล้ว แต่ Windows ยังเรียกใช้งาน node ไม่ได้ กรุณาปิด Installer แล้วเปิดใหม่อีกครั้ง'
    }

    if ($major -lt 20) {
        throw "Node.js ยังเก่าเกินไป ($(& node --version))"
    }

    Write-Host "✓ Node.js $(& node --version) พร้อมใช้งาน" -ForegroundColor Green
}

function Test-IsOneDriveDesktop([string]$DesktopPath) {
    $roots = @(
        $env:OneDrive,
        $env:OneDriveConsumer,
        $env:OneDriveCommercial
    ) | Where-Object { $_ }

    foreach ($root in $roots) {
        try {
            $rootFull = [IO.Path]::GetFullPath($root).TrimEnd('\')
            $desktopFull = [IO.Path]::GetFullPath($DesktopPath)
            if ($desktopFull.StartsWith($rootFull + '\', [StringComparison]::OrdinalIgnoreCase) -or
                $desktopFull.Equals($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
                return $true
            }
        }
        catch {}
    }

    return ($DesktopPath -match '\\OneDrive(?: - [^\\]+)?\\')
}

function Ensure-FolderShortcut([string]$ShortcutPath, [string]$TargetFolder) {
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = $TargetFolder
    $shortcut.WorkingDirectory = $TargetFolder
    $shortcut.Description = 'SillyTavern folder'
    $shortcut.IconLocation = "$env:SystemRoot\System32\shell32.dll,3"
    $shortcut.Save()
}

$DesktopUsesOneDrive = Test-IsOneDriveDesktop $DisplayedDesktop

if ($DesktopUsesOneDrive) {
    $InstallDir = Join-Path $env:USERPROFILE 'SillyTavern'
    $FolderShortcut = Join-Path $DisplayedDesktop 'SillyTavern.lnk'
}
else {
    $InstallDir = Join-Path $DisplayedDesktop 'SillyTavern'
    $FolderShortcut = $null
}

Clear-Host
Write-Host '========================================' -ForegroundColor Cyan
Write-Host "   Stage Zero's SillyTavern Installer" -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host ""
Write-Host "Installer v$Version"
Write-Host 'Stage Zero จะติดตั้ง SillyTavern จาก staging branch'
Write-Host ""
Write-Host 'ตำแหน่งติดตั้ง:' -ForegroundColor Cyan
Write-Host $InstallDir
Write-Host ""

try {
    if (-not (Has-Command 'winget')) {
        throw 'ไม่พบ winget (App Installer) กรุณาอัปเดต App Installer จาก Microsoft Store แล้วลองใหม่'
    }

    if (-not (Test-Path $DisplayedDesktop)) {
        throw 'Windows ไม่พบตำแหน่ง Desktop ที่ใช้งานอยู่'
    }

    Write-Host 'กำลังตรวจโปรแกรมที่จำเป็น...' -ForegroundColor Cyan
    Ensure-Git
    Ensure-Node

    if (Test-Path $InstallDir) {
        $isST = (Test-Path (Join-Path $InstallDir '.git')) -and
                (Test-Path (Join-Path $InstallDir 'Start.bat'))

        if ($isST) {
            if ($DesktopUsesOneDrive) {
                Ensure-FolderShortcut $FolderShortcut $InstallDir
            }

            Write-Host ""
            Write-Host 'พบ SillyTavern ที่ติดตั้งอยู่แล้ว' -ForegroundColor Yellow
            Write-Host 'Installer จะไม่เขียนทับของเดิม'
            Write-Host ""
            Start-Process explorer.exe -ArgumentList "`"$InstallDir`""
            Read-Host 'กด Enter เพื่อปิดหน้าจอนี้'
            exit 0
        }

        throw "มีโฟลเดอร์ $InstallDir อยู่แล้ว แต่ไม่ใช่ SillyTavern กรุณาเปลี่ยนชื่อหรือย้ายโฟลเดอร์นี้ก่อน"
    }

    Write-Host ""
    Write-Host 'กำลังดาวน์โหลด SillyTavern...' -ForegroundColor Cyan
    Write-Host 'Branch: staging'
    Write-Host ""

    & git clone 'https://github.com/SillyTavern/SillyTavern' -b staging $InstallDir
    if ($LASTEXITCODE -ne 0) {
        throw "ดาวน์โหลด SillyTavern ไม่สำเร็จ (git exit code $LASTEXITCODE)"
    }

    if (-not (Test-Path (Join-Path $InstallDir 'Start.bat'))) {
        throw 'ดาวน์โหลดเสร็จแต่ไม่พบ Start.bat การติดตั้งอาจไม่สมบูรณ์'
    }

    if ($DesktopUsesOneDrive) {
        Ensure-FolderShortcut $FolderShortcut $InstallDir
    }

    Write-Host ""
    Write-Host '========================================' -ForegroundColor Green
    Write-Host '          ติดตั้งเรียบร้อยแล้ว' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Green
    Write-Host ""
    Write-Host 'วิธีเปิด:'
    Write-Host '1. เปิด SillyTavern บน Desktop'
    Write-Host '2. ดับเบิลคลิก Start.bat'
    Write-Host ""
    Write-Host 'ครั้งแรกที่เปิด Start.bat อาจใช้เวลาสักครู่เพื่อเตรียมไฟล์ที่จำเป็น' -ForegroundColor Yellow
    Write-Host ""
    Write-Host 'ส่วนวิธีอัพเดท: เปิด UpdateAndStart.bat'
    Write-Host ""
    Start-Process explorer.exe -ArgumentList "`"$InstallDir`""
}
catch {
    Write-Host ""
    Write-Host '========================================' -ForegroundColor Red
    Write-Host '             ติดตั้งไม่สำเร็จ' -ForegroundColor Red
    Write-Host '========================================' -ForegroundColor Red
    Write-Host ""
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
}

Write-Host ""
Read-Host 'กด Enter เพื่อปิดหน้าจอนี้'
