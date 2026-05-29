Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$appSourceDir = if (Test-Path -LiteralPath (Join-Path $root 'app\DesktopCalendarFloat.ps1')) {
    Join-Path $root 'app'
}
else {
    $root
}
$buildDir = Join-Path $PSScriptRoot '_build'
$csPath = Join-Path $buildDir 'DesktopCountdownWidgetSetup.cs'
$output = Join-Path $root 'DesktopCountdownWidgetSetup-v1.0.0.exe'
$cscCandidates = @(
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
    (Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)
$csc = $cscCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if ([string]::IsNullOrWhiteSpace($csc)) {
    throw '找不到 .NET Framework C# 编译器 csc.exe'
}

if (Test-Path -LiteralPath $buildDir) {
    Remove-Item -LiteralPath $buildDir -Recurse -Force
}

New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

$payloadFiles = @(
    'DesktopCalendarFloat.ps1',
    'Launch-DesktopCalendar.vbs',
    'Start-DesktopCalendar.cmd',
    'Enable-Startup.cmd',
    'Enable-Startup.ps1',
    'README.md'
)

$payloadEntries = foreach ($file in $payloadFiles) {
    $path = Join-Path $appSourceDir $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "缺少打包文件：$file"
    }

    $base64 = [Convert]::ToBase64String([System.IO.File]::ReadAllBytes($path))
    '            { "' + $file + '", "' + $base64 + '" },'
}

$payloadSource = $payloadEntries -join "`r`n"

$template = @'
using Microsoft.Win32;
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Text;
using System.Windows.Forms;

namespace DesktopCountdownWidgetInstaller
{
    internal static class Program
    {
        private const string AppId = "ChanpingTools.DesktopCountdownWidget";
        private const string DisplayName = "桌面倒计时浮窗";
        private const string Version = "1.0.0";
        private const string Publisher = "Chanping Tools";

        private static readonly Dictionary<string, string> Payload = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
__PAYLOAD__
        };

        [STAThread]
        private static int Main()
        {
            try
            {
                Install();
                return 0;
            }
            catch (Exception ex)
            {
                MessageBox.Show("安装失败：\r\n" + ex.Message, DisplayName, MessageBoxButtons.OK, MessageBoxIcon.Error);
                return 1;
            }
        }

        private static void Install()
        {
            string installDir = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "ChanpingTools",
                "DesktopCountdownWidget");
            string startMenuDir = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), "Chanping Tools");
            string desktopShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), DisplayName + ".lnk");
            string startShortcut = Path.Combine(startMenuDir, DisplayName + ".lnk");
            string startupShortcut = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Startup), "DesktopCalendarFloat.lnk");
            string uninstallScript = Path.Combine(installDir, "Uninstall-DesktopCountdownWidget.ps1");
            string uninstallShortcut = Path.Combine(startMenuDir, "卸载" + DisplayName + ".lnk");
            string wscript = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), "wscript.exe");
            string launcher = Path.Combine(installDir, "Launch-DesktopCalendar.vbs");

            Directory.CreateDirectory(installDir);
            Directory.CreateDirectory(startMenuDir);

            foreach (KeyValuePair<string, string> item in Payload)
            {
                File.WriteAllBytes(Path.Combine(installDir, item.Key), Convert.FromBase64String(item.Value));
            }

            WriteUninstallScript(uninstallScript, installDir, startMenuDir, desktopShortcut, startShortcut, startupShortcut, uninstallShortcut);

            CreateShortcut(desktopShortcut, wscript, Quote(launcher), installDir, DisplayName);
            CreateShortcut(startShortcut, wscript, Quote(launcher), installDir, DisplayName);
            CreateShortcut(uninstallShortcut, "powershell.exe", "-NoProfile -ExecutionPolicy Bypass -File " + Quote(uninstallScript), installDir, "卸载" + DisplayName);

            RegisterUninstallEntry(installDir, uninstallScript, wscript);

            Process.Start(new ProcessStartInfo
            {
                FileName = wscript,
                Arguments = Quote(launcher),
                UseShellExecute = false
            });

            MessageBox.Show(DisplayName + " 已安装并启动。", DisplayName, MessageBoxButtons.OK, MessageBoxIcon.Information);
        }

        private static void WriteUninstallScript(
            string uninstallScript,
            string installDir,
            string startMenuDir,
            string desktopShortcut,
            string startShortcut,
            string startupShortcut,
            string uninstallShortcut)
        {
            string uninstallKey = @"HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\" + AppId;
            string[] lines = new string[]
            {
                "Set-StrictMode -Version Latest",
                "$ErrorActionPreference = 'Stop'",
                "$displayName = " + PsQuote(DisplayName),
                "$installDir = " + PsQuote(installDir),
                "$startMenuDir = " + PsQuote(startMenuDir),
                "$desktopShortcut = " + PsQuote(desktopShortcut),
                "$startShortcut = " + PsQuote(startShortcut),
                "$startupShortcut = " + PsQuote(startupShortcut),
                "$uninstallShortcut = " + PsQuote(uninstallShortcut),
                "$uninstallKey = " + PsQuote(uninstallKey),
                "Remove-Item -LiteralPath $desktopShortcut -Force -ErrorAction SilentlyContinue",
                "Remove-Item -LiteralPath $startShortcut -Force -ErrorAction SilentlyContinue",
                "Remove-Item -LiteralPath $startupShortcut -Force -ErrorAction SilentlyContinue",
                "Remove-Item -LiteralPath $uninstallShortcut -Force -ErrorAction SilentlyContinue",
                "Remove-Item -LiteralPath $uninstallKey -Recurse -Force -ErrorAction SilentlyContinue",
                "if (Test-Path -LiteralPath $installDir) {",
                "    Remove-Item -LiteralPath $installDir -Recurse -Force -ErrorAction SilentlyContinue",
                "}",
                "if ((Test-Path -LiteralPath $startMenuDir) -and -not (Get-ChildItem -LiteralPath $startMenuDir -Force -ErrorAction SilentlyContinue)) {",
                "    Remove-Item -LiteralPath $startMenuDir -Force -ErrorAction SilentlyContinue",
                "}",
                "try {",
                "    $shell = New-Object -ComObject WScript.Shell",
                "    [void]$shell.Popup(\"$displayName 已卸载。\", 3, \"$displayName\", 64)",
                "}",
                "catch {}"
            };

            File.WriteAllText(uninstallScript, string.Join(Environment.NewLine, lines), new UTF8Encoding(true));
        }

        private static void RegisterUninstallEntry(string installDir, string uninstallScript, string wscript)
        {
            string keyPath = @"Software\Microsoft\Windows\CurrentVersion\Uninstall\" + AppId;
            using (RegistryKey key = Registry.CurrentUser.CreateSubKey(keyPath))
            {
                if (key == null)
                {
                    throw new InvalidOperationException("无法写入卸载注册表项。");
                }

                key.SetValue("DisplayName", DisplayName, RegistryValueKind.String);
                key.SetValue("DisplayVersion", Version, RegistryValueKind.String);
                key.SetValue("Publisher", Publisher, RegistryValueKind.String);
                key.SetValue("InstallLocation", installDir, RegistryValueKind.String);
                key.SetValue("DisplayIcon", wscript + ",0", RegistryValueKind.String);
                key.SetValue("UninstallString", "powershell.exe -NoProfile -ExecutionPolicy Bypass -File " + Quote(uninstallScript), RegistryValueKind.String);
                key.SetValue("QuietUninstallString", "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " + Quote(uninstallScript), RegistryValueKind.String);
                key.SetValue("NoModify", 1, RegistryValueKind.DWord);
                key.SetValue("NoRepair", 1, RegistryValueKind.DWord);
                key.SetValue("EstimatedSize", GetInstallSizeKb(installDir), RegistryValueKind.DWord);
            }
        }

        private static int GetInstallSizeKb(string installDir)
        {
            long total = 0;
            foreach (string file in Directory.GetFiles(installDir, "*", SearchOption.AllDirectories))
            {
                total += new FileInfo(file).Length;
            }

            return Math.Max(1, (int)(total / 1024));
        }

        private static void CreateShortcut(string shortcutPath, string targetPath, string arguments, string workingDirectory, string description)
        {
            Type shellType = Type.GetTypeFromProgID("WScript.Shell");
            if (shellType == null)
            {
                throw new InvalidOperationException("无法创建 WScript.Shell。");
            }

            object shell = Activator.CreateInstance(shellType);
            object shortcut = shellType.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, shell, new object[] { shortcutPath });
            Type shortcutType = shortcut.GetType();
            shortcutType.InvokeMember("TargetPath", BindingFlags.SetProperty, null, shortcut, new object[] { targetPath });
            shortcutType.InvokeMember("Arguments", BindingFlags.SetProperty, null, shortcut, new object[] { arguments });
            shortcutType.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, shortcut, new object[] { workingDirectory });
            shortcutType.InvokeMember("Description", BindingFlags.SetProperty, null, shortcut, new object[] { description });
            shortcutType.InvokeMember("WindowStyle", BindingFlags.SetProperty, null, shortcut, new object[] { 7 });
            shortcutType.InvokeMember("Save", BindingFlags.InvokeMethod, null, shortcut, null);
        }

        private static string Quote(string value)
        {
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private static string PsQuote(string value)
        {
            return "'" + value.Replace("'", "''") + "'";
        }
    }
}
'@

$source = $template.Replace('__PAYLOAD__', $payloadSource)
$encoding = New-Object System.Text.UTF8Encoding($true)
[System.IO.File]::WriteAllText($csPath, $source, $encoding)

if (Test-Path -LiteralPath $output) {
    Remove-Item -LiteralPath $output -Force
}

& $csc /nologo /target:winexe /optimize+ /out:$output /reference:System.Windows.Forms.dll $csPath

if (-not (Test-Path -LiteralPath $output)) {
    throw "安装包生成失败：$output"
}

Get-Item -LiteralPath $output
