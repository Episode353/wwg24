# Run by TrenchBroom's "Launch Engine" (Run > Launch Engine...).
# Plays the Godot project and boots straight into the given map in offline mode.
#
# TrenchBroom engine profile:
#   Path:       C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
#   Parameters: -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "<this file>" -MapName "${MAP_BASE_NAME}"
param(
    [Parameter(Mandatory = $true)][string]$MapName,
    [string]$GameDir
)

# $PSScriptRoot is empty inside param() defaults on Windows PowerShell 5.1
if (-not $GameDir) { $GameDir = Join-Path $PSScriptRoot "..\gadot" }

# Must match PORT in gadot/addons/trenchbroom_launch/plugin.gd
$Port = 6018

# Preferred: ask the open Godot editor to press Play, so output and debugging stay in the editor.
try {
    $client = New-Object System.Net.Sockets.TcpClient
    if ($client.ConnectAsync("127.0.0.1", $Port).Wait(1000)) {
        $stream = $client.GetStream()
        $stream.ReadTimeout = 3000
        $bytes = [System.Text.Encoding]::UTF8.GetBytes("$MapName`n")
        $stream.Write($bytes, 0, $bytes.Length)
        $reply = (New-Object System.IO.StreamReader($stream)).ReadLine()
        $client.Close()
        if ($reply -eq "OK") { exit 0 }
    }
    $client.Close()
} catch {}

# Fallback: the editor plugin isn't reachable, so run the game directly with the same Godot executable.
$godot = Get-Process | Where-Object { $_.ProcessName -like "Godot*" -and $_.Path } |
    Select-Object -First 1 -ExpandProperty Path
if (-not $godot) { $godot = $env:GODOT }

if (-not $godot) {
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Couldn't find Godot. Open the project in the Godot editor (with the 'TrenchBroom Launch' plugin enabled), or set the GODOT environment variable to your Godot .exe.",
        "Launch Godot") | Out-Null
    exit 1
}

$GameDir = (Resolve-Path $GameDir).Path
$env:WWG_LAUNCH_MAP = $MapName
Start-Process -FilePath $godot -WorkingDirectory $GameDir -ArgumentList @("--path", "`"$GameDir`"")
