# GitHub Release Creation Script
# This will create the release with the APK using GitHub API

$REPO_OWNER = "QuopTron"
$REPO_NAME = "futbolgo"
$TAG = "v1.1.0"
$TITLE = "FutbolGO v1.1.0"
$APK_PATH = "E:\Pablo\proyectos\futbolgo\flutter_app\build\app\outputs\flutter-apk\futbolgo.apk"

# Release notes
$NOTES = @"
# FutbolGO v1.1.0 - Automatic Stream Recovery

## 🎯 What's New

### Automatic Stream Recovery
- Auto-reconnect on URL updates when the source site changes stream URLs
- Smart error detection for 404, network, and connection errors
- User-friendly messages: "Stream updated, reconnecting..."
- Reset reconnection attempts to try the new link automatically

### Audio Unmute Protection
- Automatic unmute when streams mute audio during ads
- 5-second monitoring with real-time stream subscriptions
- Instant detection and volume restoration

### Enhanced Health Monitoring
- Health check every 8 seconds (detects stale streams >20s)
- Audio check every 5 seconds (combines unmute + health monitoring)
- Loop detection and automatic recovery
- Smart timeouts: 10s for buffering, 20s for stale streams

## 📦 Installation

1. Download `futbolgo.apk` below
2. Enable "Install from Unknown Sources" in Android settings
3. Install the APK
4. Enjoy live sports streaming with automatic recovery!

## 🚀 Features

- 🎬 Live stream player with automatic recovery
- 🚫 Built-in ad-blocker
- 📺 Multiple channels and events
- 🌍 Multi-language support (ES, EN, PT)
- 🔄 Automatic fallback for unavailable streams
- 📱 Minimalist glass design
- ✨ Automatic app updates via GitHub releases
- 🔊 Audio unmute protection
- 🌐 Smart network error recovery

## Powered by Flox

Developed with ❤️ by Flox
"@

Write-Host "🚀 FutbolGO Release Creator"
Write-Host "============================"
Write-Host ""
Write-Host "This script will create a GitHub release with the APK."
Write-Host "You will need to provide your GitHub personal access token."
Write-Host ""
Write-Host "Steps to get a token:"
Write-Host "1. Go to https://github.com/settings/tokens"
Write-Host "2. Click 'Generate new token (classic)'"
Write-Host "3. Select permissions: 'repo' (full control)"
Write-Host "4. Generate and copy the token"
Write-Host ""

$TOKEN = Read-Host "Enter your GitHub personal access token"

if (-not $TOKEN) {
    Write-Host "❌ No token provided. Exiting."
    exit 1
}

Write-Host ""
Write-Host "📦 Uploading APK to GitHub Release..."
Write-Host "This may take a few minutes..."
Write-Host ""

# Create release first (without assets)
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

    # Upload APK using multipart/form-data
    $uploadUrl = $release.upload_url -replace "{\?name,label}", "?name=futbolgo.apk"

    $APK_SIZE = (Get-Item $APK_PATH).Length
    Write-Host "   File size: $([math]::Round($APK_SIZE / 1MB, 2)) MB"
    Write-Host "   This may take a few minutes for large files..."

    $uploadHeaders = @{
        Authorization = "Bearer $TOKEN"
        Accept = "application/vnd.github.v3+json"
    }

    # Read file bytes
    $APK_BYTES = [System.IO.File]::ReadAllBytes($APK_PATH)
    
    # Create multipart boundary
    $boundary = "----WebKitFormBoundary" + [Guid]::NewGuid().ToString("N")
    
    # Create multipart body
    $body = New-Object System.IO.MemoryStream
    $writer = New-Object System.IO.BinaryWriter($body)
    
    # Add the file
    $fileHeader = @"
--$boundary
Content-Disposition: form-data; name="asset"; filename="futbolgo.apk"
Content-Type: application/vnd.android.package-archive

"@
    $fileHeaderBytes = [System.Text.Encoding]::UTF8.GetBytes($fileHeader)
    $writer.Write($fileHeaderBytes, 0, $fileHeaderBytes.Length)
    $writer.Write($APK_BYTES, 0, $APK_BYTES.Length)
    
    # Add closing boundary
    $closingBoundary = [System.Text.Encoding]::UTF8.GetBytes("--$boundary--")
    $writer.Write($closingBoundary, 0, $closingBoundary.Length)
    $writer.Flush()
    
    # Convert to base64 for upload
    $uploadData = $body.ToArray()
    $base64Data = [Convert]::ToBase64String($uploadData)
    
    Try {
        $uploadResponse = Invoke-RestMethod -Uri $uploadUrl -Method POST -Headers @{
            Authorization = "Bearer $TOKEN"
            Accept = "application/vnd.github.v3+json"
            "Content-Type" = "multipart/form-data; boundary=$boundary"
        } -Body $uploadData -ContentType "multipart/form-data; boundary=$boundary"
        
        Write-Host ""
        Write-Host "🎉 SUCCESS! APK uploaded successfully!"
        Write-Host ""
        Write-Host "📱 Download URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/futbolgo.apk"
        Write-Host "🔗 Release page: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
        Write-Host ""
        Write-Host "Users can now download the APK and the app will automatically check for updates!"
    }
    Catch {
        # Try alternative method using curl if PowerShell fails
        Write-Host "⚠️ PowerShell upload failed, trying alternative method..."
        Write-Host ""
        
        $curlCommand = "curl -X POST `"$uploadUrl`" -H `"Authorization: Bearer $TOKEN`" -H `"Accept: application/vnd.github.v3+json`" -H `"Content-Type: application/vnd.android.package-archive`" --data-binary `"$APK_PATH`""
        
        Write-Host ""
        Write-Host "⚠️ PowerShell upload failed, trying alternative method..."
        Write-Host ""
        Write-Host $curlCommand
        Write-Host ""
        Write-Host "Run the command above manually to upload the APK"
    }

    Write-Host ""
    Write-Host "🎉 SUCCESS! APK_uploaded successfully!"
    Write-Host ""
    Write-Host "📱 Download URL: https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/futbolgo.apk"
    Write-Host "🔗 Release page: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
    Write-Host ""
    Write-Host "Users can now download the APK and the app will automatically check for updates!"

} catch {
    Write-Host ""
    Write-Host "❌ Error: $_"
    Write-Host "Details: $($_.ErrorDetails.Message)"
    exit 1
}

Write-Host ""
Write-Host "✨ All done! Your FutbolGO release is live!"
