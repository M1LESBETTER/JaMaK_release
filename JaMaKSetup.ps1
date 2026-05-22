param(
    [string]$ManifestUrl = "https://raw.githubusercontent.com/M1LESBETTER/JaMaK_release/main/latest.json",
    [string]$InstallDir = (Join-Path $env:LOCALAPPDATA "Programs\JaMaK"),
    [string]$PythonVersion = "3.12.10",
    [switch]$NoPython,
    [switch]$NoShortcuts
)

$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "== $Message =="
}

function Resolve-ReleaseUrl {
    param(
        [string]$BaseUrl,
        [string]$Value
    )
    if ($Value -match "^https?://") {
        return $Value
    }
    $base = [Uri]$BaseUrl
    return ([Uri]::new($base, $Value)).AbsoluteUri
}

function Read-JsonFromUrl {
    param([string]$Url)
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Url
    return $response.Content | ConvertFrom-Json
}

function Add-CacheBust {
    param([string]$Url)
    if ($Url -notmatch "^https://raw\.githubusercontent\.com/") {
        return $Url
    }
    $separator = "?"
    if ($Url.Contains("?")) {
        $separator = "&"
    }
    return "$Url${separator}jamak_cache=$([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())"
}

function Download-File {
    param(
        [string]$Url,
        [string]$Destination,
        [string]$Activity
    )
    $request = [System.Net.HttpWebRequest]::Create($Url)
    $request.UserAgent = "JaMaKSetup/0.1.0"
    $response = $request.GetResponse()
    try {
        $total = $response.ContentLength
        $stream = $response.GetResponseStream()
        $out = [System.IO.File]::Open($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $buffer = New-Object byte[] 1048576
            $readTotal = 0L
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $out.Write($buffer, 0, $read)
                $readTotal += $read
                if ($total -gt 0) {
                    $percent = [int](($readTotal / $total) * 100)
                    Write-Progress -Activity $Activity -Status "$percent% complete" -PercentComplete $percent
                } else {
                    Write-Progress -Activity $Activity -Status "$readTotal bytes" -PercentComplete -1
                }
            }
        } finally {
            $out.Dispose()
            $stream.Dispose()
            Write-Progress -Activity $Activity -Completed
        }
    } finally {
        $response.Dispose()
    }
}

function Assert-Sha256 {
    param(
        [string]$Path,
        [string]$Expected
    )
    if ([string]::IsNullOrWhiteSpace($Expected)) {
        return
    }
    $actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $Path).Hash.ToLowerInvariant()
    if ($actual -ne $Expected.ToLowerInvariant()) {
        throw "SHA256 mismatch for $Path. Expected $Expected but got $actual."
    }
}

function Install-EmbeddedPython {
    param(
        [string]$Root,
        [string]$Version
    )
    $pythonRoot = Join-Path $Root ".runtime\python"
    $pythonExe = Join-Path $pythonRoot "python.exe"
    if (Test-Path -LiteralPath $pythonExe) {
        return $pythonExe
    }

    Write-Step "Installing embedded Python"
    New-Item -ItemType Directory -Force -Path $pythonRoot | Out-Null
    $zip = Join-Path ([System.IO.Path]::GetTempPath()) "python-$Version-embed-amd64.zip"
    $url = "https://www.python.org/ftp/python/$Version/python-$Version-embed-amd64.zip"
    Download-File -Url $url -Destination $zip -Activity "Downloading Python $Version"
    Expand-Archive -LiteralPath $zip -DestinationPath $pythonRoot -Force

    $pth = Get-ChildItem -LiteralPath $pythonRoot -Filter "python*._pth" | Select-Object -First 1
    if ($pth) {
        $lines = Get-Content -LiteralPath $pth.FullName
        if ($lines -notcontains "import site") {
            Add-Content -LiteralPath $pth.FullName -Value "import site"
        }
    }
    return $pythonExe
}

function New-JaMaKShortcut {
    param(
        [string]$ShortcutPath,
        [string]$InstallRoot,
        [string]$TargetFile = "run.bat"
    )
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($ShortcutPath)
    $shortcut.TargetPath = Join-Path $InstallRoot $TargetFile
    $shortcut.WorkingDirectory = $InstallRoot
    $icon = Join-Path $InstallRoot "JaMaK_logo.ico"
    if (Test-Path -LiteralPath $icon) {
        $shortcut.IconLocation = $icon
    }
    $shortcut.Save()
}

function Write-UninstallEntry {
    param(
        [string]$InstallRoot,
        [string]$Version
    )
    $key = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\JaMaK"
    New-Item -Path $key -Force | Out-Null
    New-ItemProperty -Path $key -Name DisplayName -Value "JaMaK" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name DisplayVersion -Value $Version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name Publisher -Value "M1LESBETTER" -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $key -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
    $icon = Join-Path $InstallRoot "JaMaK_logo.ico"
    New-ItemProperty -Path $key -Name DisplayIcon -Value $icon -PropertyType String -Force | Out-Null
    $uninstall = "powershell -NoProfile -ExecutionPolicy Bypass -Command `"Remove-Item -LiteralPath '$InstallRoot' -Recurse -Force`""
    New-ItemProperty -Path $key -Name UninstallString -Value $uninstall -PropertyType String -Force | Out-Null
}

Write-Step "Reading JaMaK release manifest"
$latest = Read-JsonFromUrl -Url (Add-CacheBust $ManifestUrl)
$releaseManifestUrl = Resolve-ReleaseUrl -BaseUrl $ManifestUrl -Value $latest.latest.manifest_url
$manifest = Read-JsonFromUrl -Url (Add-CacheBust $releaseManifestUrl)
$artifact = $manifest.artifacts | Where-Object { $_.kind -eq "core_app_zip" } | Select-Object -First 1
if (-not $artifact) {
    throw "Release manifest does not include a core_app_zip artifact."
}

$installRoot = [System.IO.Path]::GetFullPath($InstallDir)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("jamak-setup-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Force -Path $tempRoot | Out-Null

try {
    Write-Step "Downloading JaMaK $($manifest.version)"
    New-Item -ItemType Directory -Force -Path $installRoot | Out-Null
    $zipPath = Join-Path $tempRoot $artifact.name
    $artifactSource = $artifact.url
    if ([string]::IsNullOrWhiteSpace($artifactSource)) {
        $artifactSource = $artifact.name
    }
    $artifactUrl = Resolve-ReleaseUrl -BaseUrl $releaseManifestUrl -Value $artifactSource
    Download-File -Url $artifactUrl -Destination $zipPath -Activity "Downloading JaMaK"
    Assert-Sha256 -Path $zipPath -Expected $artifact.sha256

    Write-Step "Installing app files"
    Expand-Archive -LiteralPath $zipPath -DestinationPath $installRoot -Force

    if (-not $NoPython) {
        Install-EmbeddedPython -Root $installRoot -Version $PythonVersion | Out-Null
    }

    if (-not $NoShortcuts) {
        Write-Step "Creating shortcuts"
        $desktop = [Environment]::GetFolderPath("Desktop")
        if ($desktop) {
            New-JaMaKShortcut -ShortcutPath (Join-Path $desktop "JaMaK.lnk") -InstallRoot $installRoot
        }
        $startMenu = Join-Path ([Environment]::GetFolderPath("StartMenu")) "Programs\JaMaK"
        New-Item -ItemType Directory -Force -Path $startMenu | Out-Null
        New-JaMaKShortcut -ShortcutPath (Join-Path $startMenu "JaMaK.lnk") -InstallRoot $installRoot
        New-JaMaKShortcut -ShortcutPath (Join-Path $startMenu "Update JaMaK.lnk") -InstallRoot $installRoot -TargetFile "update.bat"
    }

    Write-UninstallEntry -InstallRoot $installRoot -Version $manifest.version

    Write-Step "Complete"
    Write-Host "Installed JaMaK to $installRoot"
    Write-Host "Launch it with: $(Join-Path $installRoot 'run.bat')"
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
