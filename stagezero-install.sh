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

function Ensure-FolderShortcut([string]$ShortcutPath, [string]$TargetFolder) {
    # WScript.Shell can fail when the .lnk path contains non-ANSI characters
    # (for example a Thai OneDrive Desktop folder). Use the Unicode-native
    # IShellLinkW interface instead.
    if (-not ('StageZero.UnicodeShortcut' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;

namespace StageZero
{
    [ComImport]
    [Guid("00021401-0000-0000-C000-000000000046")]
    internal class ShellLink
    {
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("000214F9-0000-0000-C000-000000000046")]
    internal interface IShellLinkW
    {
        void GetPath(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszFile,
            int cchMaxPath,
            IntPtr pfd,
            uint fFlags);

        void GetIDList(out IntPtr ppidl);
        void SetIDList(IntPtr pidl);

        void GetDescription(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszName,
            int cchMaxName);

        void SetDescription([MarshalAs(UnmanagedType.LPWStr)] string pszName);

        void GetWorkingDirectory(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszDir,
            int cchMaxPath);

        void SetWorkingDirectory(
            [MarshalAs(UnmanagedType.LPWStr)] string pszDir);

        void GetArguments(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszArgs,
            int cchMaxPath);

        void SetArguments([MarshalAs(UnmanagedType.LPWStr)] string pszArgs);
        void GetHotkey(out short pwHotkey);
        void SetHotkey(short wHotkey);
        void GetShowCmd(out int piShowCmd);
        void SetShowCmd(int iShowCmd);

        void GetIconLocation(
            [Out, MarshalAs(UnmanagedType.LPWStr)] StringBuilder pszIconPath,
            int cchIconPath,
            out int piIcon);

        void SetIconLocation(
            [MarshalAs(UnmanagedType.LPWStr)] string pszIconPath,
            int iIcon);

        void SetRelativePath(
            [MarshalAs(UnmanagedType.LPWStr)] string pszPathRel,
            uint dwReserved);

        void Resolve(IntPtr hwnd, uint fFlags);

        void SetPath([MarshalAs(UnmanagedType.LPWStr)] string pszFile);
    }

    [ComImport]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("0000010b-0000-0000-C000-000000000046")]
    internal interface IPersistFile
    {
        void GetClassID(out Guid pClassID);

        [PreserveSig]
        int IsDirty();

        void Load(
            [MarshalAs(UnmanagedType.LPWStr)] string pszFileName,
            uint dwMode);

        void Save(
            [MarshalAs(UnmanagedType.LPWStr)] string pszFileName,
            bool fRemember);

        void SaveCompleted(
            [MarshalAs(UnmanagedType.LPWStr)] string pszFileName);

        void GetCurFile(
            [MarshalAs(UnmanagedType.LPWStr)] out string ppszFileName);
    }

    public static class UnicodeShortcut
    {
        public static void Create(string shortcutPath, string targetFolder)
        {
            IShellLinkW link = (IShellLinkW)new ShellLink();

            link.SetPath(targetFolder);
            link.SetWorkingDirectory(targetFolder);
            link.SetDescription("SillyTavern folder");
            link.SetIconLocation(
                Environment.ExpandEnvironmentVariables(
                    @"%SystemRoot%\System32\shell32.dll"),
                3);

            IPersistFile persist = (IPersistFile)link;
            persist.Save(shortcutPath, true);
        }
    }
}
'@
    }

    [StageZero.UnicodeShortcut]::Create($ShortcutPath, $TargetFolder)

    if (-not (Test-Path $ShortcutPath)) {
        throw "สร้างทางลัด SillyTavern บน Desktop ไม่สำเร็จ"
    }
}


function Try-Ensure-FolderShortcut([string]$ShortcutPath, [string]$TargetFolder) {
    try {
        Ensure-FolderShortcut $ShortcutPath $TargetFolder
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "⚠ สร้างทางลัด SillyTavern บน Desktop ไม่สำเร็จ" -ForegroundColor Yellow
        Write-Host "แต่ SillyTavern ยังติดตั้งและใช้งานได้ตามปกติ" -ForegroundColor Yellow
        return $false
    }
}

$InstallDir = Join-Path $env:USERPROFILE 'SillyTavern'
$FolderShortcut = Join-Path $DisplayedDesktop 'SillyTavern.lnk'

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
            [void](Try-Ensure-FolderShortcut $FolderShortcut $InstallDir)

            Write-Host ""
            Write-Host 'พบ SillyTavern ที่ติดตั้งอยู่แล้ว' -ForegroundColor Yellow
            Write-Host 'Installer จะไม่เขียนทับของเดิม'
            Write-Host ""
            Write-Host 'กำลังเปิดโฟลเดอร์ SillyTavern ให้...' -ForegroundColor Cyan
            Start-Process explorer.exe -ArgumentList "`"$InstallDir`""
            return
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

    [void](Try-Ensure-FolderShortcut $FolderShortcut $InstallDir)

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

