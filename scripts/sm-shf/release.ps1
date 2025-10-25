param(
    [string]$Message = "Automated commit",
    [ValidateSet("major","minor","patch")] [string]$Part = "",
    [switch]$Auto
)

Write-Host "=== ScreenManager Release Script ==="


# === CLEAN-UP ===
$baseExeName    = "sm"
$versionedExe   = "${baseExeName}_v$version.exe"
$versionedZip   = "${baseExeName}_v$version.zip"
$finalExe       = "${baseExeName}_${localTag}.exe"
$zipName        = "${baseExeName}_${localTag}.zip"

Write-Host ":: Cleaning previous builds..."
Remove-Item $versionedExe, $versionedZip, "build.log", $zipName, $finalExe -ErrorAction SilentlyContinue

# Define build folder
$buildFolder = "new_builds"

# Only remove if defined and exists
if ($buildFolder -and (Test-Path $buildFolder)) {
    Remove-Item -Recurse -Force $buildFolder
    Write-Host ":: Removed old build folder"
}

# === COMMIT ===
if (-not (git status --porcelain))
{
    Write-Host ":: No changes to commit."
}
else
{
    git add .
    git commit -m "$Message"
    git push
}


# === VERSION ===
$lastTag = git tag --list "v*" | Sort-Object { [version]($_ -replace '^v', '') } -Descending | Select-Object -First 1

if ($lastTag -match '^v(\d+)\.(\d+)\.(\d+)$')
{
    $major = [int]$matches[1]
    $minor = [int]$matches[2]
    $patch = [int]$matches[3]
}
else
{
    $major = 0; $minor = 0; $patch = 0
    $lastTag = "v0.0.0"
}

Write-Host ":: Last tag: $lastTag"

# Ask user which part to increment
$choice = Read-Host "Which part would you like to increment? (1=major, 2=minor, 3=patch, default=patch):"
switch ( $choice.ToLower())
{
    "major" {
        $major++; $minor = 0; $patch = 0
    }
    "1"     {
        $major++; $minor = 0; $patch = 0
    }
    "minor" {
        $minor++; $patch = 0
    }
    "2"     {
        $minor++; $patch = 0
    }
    "patch" {
        $patch++
    }
    "3"     {
        $patch++
    }
    default {
        $patch++
    }
}

# New semantic version
$newTag = "v$major.$minor.$patch"
Write-Host ":: Creating and pushing tag $newTag..."

# Tag and push
git tag $newTag
git push
git push origin $newTag

Write-Host ":: Committed and tagged as $newTag."

# === Update changelog automatically ===
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm"
$changelogPath = "changelog.txt"

# Get all commits since last tag
if ($lastTag -ne "v0.0.0")
{
    $commits = git log $lastTag..HEAD --pretty=format:"- %s"
}
else
{
    $commits = git log --pretty=format:"- %s"
}

# Build changelog entry
$changelogEntry = "[$timestamp] $newTag`n$commits`n"

# Append to changelog.txt
Add-Content -Path $changelogPath -Value $changelogEntry
Write-Host ":: Updated changelog.txt:"
Write-Host ":: $changelogEntry"

# Stage and push changelog
git add $changelogPath
git commit -m "Update changelog for $newTag"
git push

# === Update version.txt ===
$versionFile = "version.txt"
$versionInfo = "$newTag ($timestamp)"
Set-Content -Path $versionFile -Value $versionInfo
Write-Host ":: Updated version.txt: $versionInfo"

git add $versionFile
git commit -m "Update version file for $newTag"
git push

Write-Host ":: Release complete: $newTag"


$workflowUrl = "https://github.com/RobertoTorino/ScreenManager/actions/workflows/sm.yml"
Write-Host ":: Monitor workflow here: $workflowUrl"


Write-Host ":: Removing Old Releases: "
$repo       = "RobertoTorino/ScreenManager"
$token      = $env:GITHUB_TOKEN
$keepLatest = 1

# Get all releases sorted by created_at descending
$releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" `
                              -Headers @{ Authorization = "token $token" } |
        Sort-Object { $_.created_at } -Descending

# Skip the newest $keepLatest releases
$oldReleases = $releases | Select-Object -Skip $keepLatest

foreach ($rel in $oldReleases) {
    Write-Host ":: Deleting release: $($rel.name) / tag: $($rel.tag_name)"

    # Delete release
    Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/$($rel.id)" `
                      -Method Delete `
                      -Headers @{ Authorization = "token $token" }

    # Delete the tag on GitHub
    git push origin --delete $rel.tag_name
    Write-Host ":: Deleted release and tag: $($rel.tag_name)"
}

# === Keep only the latest 2 tags ===
$allTags = git tag --sort=-creatordate
$tagsToDelete = $allTags | Select-Object -Skip 1

foreach ($tag in $tagsToDelete) {
    Write-Host ":: Deleting old tag: $tag"

    # Delete local tag
    git tag -d $tag

    # Delete remote tag
    git push origin :refs/tags/$tag
}


Write-Host ":: Old releases and tags cleaned up, keeping the latest $keepLatest release(s)."


# CHECK GITHUB WORKFLOW STATUS + SHOW RELEASE
Write-Host ":: Now checking workflow status and release info... "
#$repoOwner = "YourUserName"
#$repoName  = "YourRepoName"
$branch    = "main"        # or whatever branch triggers the workflow
$headers = @{
    "Accept"        = "application/vnd.github+json"
    "Authorization" = "Bearer $env:GITHUB_TOKEN"
}

Write-Host "`n:: Checking latest GitHub Actions workflow run..."

# --- Wait for workflow completion (poll every 15s) ---
$maxAttempts = 40
$attempt = 0
$runCompleted = $false

do {
    $response = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/actions/runs?branch=$branch&per_page=1" -Headers $headers
    $latestRun = $response.workflow_runs[0]

    Write-Host (":: Current status: {0} (conclusion: {1})" -f $latestRun.status, $latestRun.conclusion)

    if ($latestRun.status -eq "completed") {
        $runCompleted = $true
        break
    }

    Start-Sleep -Seconds 15
    $attempt++
} while ($attempt -lt $maxAttempts)

if (-not $runCompleted) {
    Write-Warning ":: Timeout waiting for GitHub workflow to complete."
    Exit 1
}

if ($latestRun.conclusion -ne "success") {
    Write-Host "❌ GitHub workflow failed. Conclusion: $($latestRun.conclusion)"
    Exit 1
}

Write-Host "✅ GitHub workflow succeeded!"
Write-Host ":: Commit: $($latestRun.head_commit.message)"
Write-Host ":: Run URL: $($latestRun.html_url)`n"


# --- Find latest release and show link ---
$releaseResponse = Invoke-RestMethod -Uri "https://api.github.com/repos/$repoOwner/$repoName/releases/latest" -Headers $headers

if ($releaseResponse) {
    Write-Host "================ RELEASE INFO ================"
    Write-Host ":: Tag: $($releaseResponse.tag_name)"
    Write-Host ":: Name: $($releaseResponse.name)"
    Write-Host ":: URL: $($releaseResponse.html_url)"
    Write-Host "=============================================="
} else {
    Write-Warning ":: No release found."
}

Write-Host ":: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: :: "