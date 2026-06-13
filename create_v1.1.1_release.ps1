# Create GitHub Release v1.1.1
# Script to create release and upload APK automatically

$REPO_OWNER = "QuopTron"
$REPO_NAME = "futbolgo"
$TAG = "v1.1.1"
$TITLE = "FutbolGO v1.1.1"
$APK_PATH = "E:\Pablo\proyectos\futbolgo\flutter_app\build\app\outputs\flutter-apk\futbolgo.apk"

# You need to provide your GitHub token
$TOKEN = Read-Host "Enter your GitHub personal access token"

$NOTES = @"
# FutbolGO v1.1.1 - Fix Update Repository Detection

## 🐛 Bug Fixes

### Update Repository Detection
- Fixed repository owner from 'flox-app' to 'QuopTron'
- App now correctly detects updates from the proper GitHub repository
- Resolvió el problema donde la app no rescataba actualizaciones

## 📦 What This Means

The app will now properly check for updates from:
https://github.com/QuopTron/futbolgo/releases

When you upload this APK to v1.1.1, users with v1.0.0 will see:
✅ Automatic update prompt
✅ Download link for the new version
✅ Release notes describing the fix

This ensures future updates work seamlessly for all users.

## 🚀 Previous Updates (v1.1.0)

- Automatic stream recovery when URLs change
- Audio unmute protection
- Enhanced health monitoring
- Loop detection

## 📱 Installation

1. Download `futbolgo.apk` below
2. Enable "Install from Unknown Sources" in Android settings
3. Install the APK
4. Enjoy automatic updates!

## Powered by Flox

Developed with ❤️ by Flox
"@

Write-Host "🚀 Creating FutbolGO v1.1.1 Release"
Write-Host "======================================"
Write-Host ""

$releaseUrl = "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/releases"
$releaseBody = @{
    tag_name = $TAG
    name = $TITLE
    body = $NOTES
    draft = $false
    prerelease = $false
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $TOKEN"
    Accept = "application/vnd.github.v3+json"
}

try {
    # Create release
    $response = Invoke-WebRequest -Uri $releaseUrl -Method POST -Headers $headers -Body $releaseBody -ContentType "application/json"
    $release = $response.Content | ConvertFrom-Json

    Write-Host "✅ Release created: $TAG"
    Write-Host "🔗 Release URL: $($release.html_url)"
    Write-Host ""
    Write-Host "📤 Uploading APK..."
    Write-Host "   This may take 2-5 minutes for 219 MB file..."
    Write-Host ""

    # Get upload URL
    $uploadUrl = $release.upload_url -replace "{\?name,label}", "?name=futbolgo.apk"

    $APK_BYTES = [System.IO.File]::ReadAllBytes($APK_PATH)
    Write-Host "   File loaded: $([math]::Round($APK_BYTES.Length / 1MB, 2)) MB"

    # Upload using curl (more reliable for large files)
    $curlCmd = "curl -X POST `"$uploadUrl`" -H `"Authorization: Bearer $TOKEN`" -H `"Accept: application/vnd.github.v3+json`" -H `"Content-Type: application/vnd.android.package-archive`" --data-binary `"$APK_PATH`""

    Write-Host ""
    Write-Host "Executing upload via curl..."
    Write-Host ""

    Try {
        Invoke-Expression $curlCmd

        Write-Host ""
        Write-Host "🎉 SUCCESS! APK uploaded!"
        Write-Host ""
        Write-Host "📱 Download URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/futbolgo.apk"
        Write-Host "🔗 Release page: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
        Write-Host ""
        Write-Host "✅ Users with v1.0.0 will now see the update prompt!"
        Write-Host "✅ Future updates will work automatically!"

    } Catch {
        Write-Host ""
        Write-Host "⚠️ Curl upload failed. Try uploading manually:"
        Write-Host ""
        Write-Host "1. Go to: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
        Write-Host "2. Click Edit release"
        Write-Host "3. Attach: $APK_PATH"
        Write-Host "4. Update release"
    }

} catch {
    Write-Host ""
    Write-Host "❌ Error creating release: $_"
    Write-Host "Details: $($_.ErrorDetails.Message)"
    exit 1
}
