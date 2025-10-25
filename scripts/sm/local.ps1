# ===========================================
# Local Build Script - ScreenManager (AHK v1)
# ===========================================

# --- CONFIGURATION ---
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$repoRoot  = Join-Path $scriptDir "../.."

function RPath($relative) { Join-Path $repoRoot $relative }

$scriptName     = RPath "apps/sm/sm.ahk"
$baseExeName    = "sm"
$ahk2exePath    = RPath "core/ahk/Compiler/Ahk2Exe.exe"
$settingsFolder = RPath "graphic-settings"
$iconPath       = RPath "apps/sm/sm.ico"
$iniPath        = RPath "apps/sm/sm.ini"
$versionDat     = RPath "apps/sm/version.dat"
$versionTxt     = RPath "apps/sm/version.txt"
$versionTpl     = RPath "apps/sm/version_template.txt"
$licensePath    = RPath "LICENSE"
$readmePath     = RPath "apps/sm/README.txt"
$extraAssets    = @($readmePath, $iniPath, $licensePath, $versionTxt, $versionDat)
$changelogFile  = RPath "apps/sm/changelog.txt"
$buildFolder    = RPath "dist/sm"


# --- ENVIRONMENT INFO ---
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$localTag  = "localbuild_$timestamp"
$finalExe  = "${baseExeName}_${localTag}.exe"
$versionedExe = "${baseExeName}_v$timestamp.exe"
$versionedZip = "${baseExeName}_v$timestamp.zip"

$finalExePath      = Join-Path $buildFolder $finalExe
$versionedExePath  = Join-Path $buildFolder $versionedExe
$versionedZipPath  = Join-Path $buildFolder $versionedZip


# --- VERSIONING ---
if (Test-Path $versionTpl) {
    Copy-Item $versionTpl $versionTxt -Force
    (Get-Content $versionTxt) -replace "%%DATETIME%%", $timestamp | Set-Content $versionTxt
}
$timestamp | Set-Content $versionDat

try {
    $version = (Get-Content $versionTxt | Select-String -Pattern '\d+\.\d+\.\d+' -AllMatches).Matches.Value | Select-Object -First 1
    if (-not $version) { throw "no version found" }
    Write-Host "`n:: Found version: $version" 
} catch {
    $version = $timestamp
    Write-Host "`n:: Using fallback version: $version"
}


# Write version files
Set-Content -Path $versionTxt -Value "v$version" -Encoding UTF8
Set-Content -Path $versionDat -Value $version -Encoding UTF8

Write-Host "`n:: Versioned output: $finalExe / $versionedZip"


# --- CLEAN-UP ---
Write-Host "================ CLEAN-UP =================" 
Write-Host ":: Cleaning previous builds..."
Remove-Item "$finalExePath", $versionedExePath, $versionedZipPath -ErrorAction SilentlyContinue

if (Test-Path $buildFolder) {
    Remove-Item -Recurse -Force $buildFolder
    Write-Host ":: Removed old build folder"
}

# Ensure build folder exists
if (-not (Test-Path $buildFolder)) {
    New-Item -ItemType Directory -Force -Path $buildFolder | Out-Null
}


# --- COMPILE AHK ---
Write-Host "`n================ COMPILING AHK ================" 
Write-Host ":: Script: $scriptName (exists: $(Test-Path $scriptName))"
Write-Host ":: Ahk2Exe: $ahk2exePath (exists: $(Test-Path $ahk2exePath))"
Write-Host ":: Icon: $iconPath (exists: $(Test-Path $iconPath))"

$arguments = @("/in", $scriptName, "/out", $finalExePath, "/icon", $iconPath)
Write-Host ":: Full command:"
Write-Host ":: $ahk2exePath $([string]::Join(' ', $arguments))`n"

$process = Start-Process -FilePath $ahk2exePath -ArgumentList $arguments -Wait -PassThru -NoNewWindow
if ($process.ExitCode -ne 0) {
    Write-Error "Ahk2Exe failed! Exit code: $($process.ExitCode)"
    Exit 1
}

if (-not (Test-Path $finalExePath)) {
    Write-Error "Output file not created!"
    Exit 1
}

Write-Host ":: Compiled successfully $finalExe`n"


# --- UPX COMPRESSION ---
Write-Host ":: Skipping UPX compression to prevent antivirus false positives."


# --- CREATE ZIP PACKAGE ---
Write-Host "================ CREATING ZIP =================" 
$toZip = @($finalExePath) + $extraAssets
if (Test-Path $settingsFolder) {
    $toZip += Get-ChildItem -Path $settingsFolder -Recurse -File | Select-Object -ExpandProperty FullName
}
$toZip = $toZip | Where-Object { Test-Path $_ }

Compress-Archive -Path $toZip -DestinationPath $versionedZipPath -Force
Write-Host ":: ZIP created $versionedZipPath`n"


# --- UPDATE CHANGELOG ---
Write-Host "================ UPDATE CHANGELOG ==============" 
$changelogEntry = "[$timestamp] Built $finalExe with version $version"
Add-Content -Path $changelogFile -Value $changelogEntry
Write-Host ":: Changelog updated $changelogFile`n"


# === DONE ===
Write-Host "`n:: :: :: BUILD COMPLETE :: :: :: :: :: ::" 
Write-Host ":: :: :: :: :: :: :: :: :: :: :: :: :: ::" 
Write-Host ":: Output folder: $buildFolder"
Write-Host ":: Version: $version"
Write-Host ":: Timestamp: $timestamp`n"

Invoke-Item $buildFolder
