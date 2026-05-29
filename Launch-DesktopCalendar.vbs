Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$startup = [Environment]::GetFolderPath('Startup')
$shortcutPath = Join-Path $startup 'DesktopCalendarFloat.lnk'
$launcher = Join-Path $PSScriptRoot 'Launch-DesktopCalendar.vbs'
$wscript = Join-Path $env:SystemRoot 'System32\wscript.exe'

if (-not (Test-Path -LiteralPath $launcher)) {
    throw "找不到隐藏启动器：$launcher"
}

if (-not (Test-Path -LiteralPath $wscript)) {
    throw "找不到 Windows Script Host：$wscript"
}

$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $wscript
$shortcut.Arguments = "`"$launcher`""
$shortcut.WorkingDirectory = $PSScriptRoot
$shortcut.Description = '桌面日历浮窗'
$shortcut.WindowStyle = 7
$shortcut.Save()

Write-Host "已启用开机自启动：$shortcutPath"
