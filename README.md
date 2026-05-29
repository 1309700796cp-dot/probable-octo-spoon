Option Explicit

Dim shell, fso, appDir, scriptPath, command

Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")

appDir = fso.GetParentFolderName(WScript.ScriptFullName)
scriptPath = fso.BuildPath(appDir, "DesktopCalendarFloat.ps1")

If Not fso.FileExists(scriptPath) Then
    MsgBox "DesktopCalendarFloat.ps1 was not found. Please extract the whole zip first.", 48, "Desktop Countdown Widget"
    WScript.Quit 1
End If

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File " & Chr(34) & scriptPath & Chr(34)
shell.Run command, 0, False
