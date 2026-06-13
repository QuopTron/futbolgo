# Create GitHub Release v1.1.2 - Automatic Popup Updates
# Script to create release with automatic popup detection

$REPO_OWNER = "QuopTron"
$REPO_NAME = "futbolgo"
$TAG = "v1.1.2"
$TITLE = "FutbolGO v1.1.2"
$APK_PATH = "E:\Pablo\proyectos\futbolgo\flutter_app\build\app\outputs\flutter-apk\futbolgo.apk"

# You need to provide your GitHub token
$TOKEN = Read-Host "Enter your GitHub personal access token"

$NOTES = @"
# FutbolGO v1.1.2 - Automatic Popup Updates

## 🎉 Nueva features

### ¡Actualizaciones Automáticas con Popup!
- Removed manual "Actualizar" button
- App now automatically shows popup when update is available
- Users no longer need to manually check for updates
- Popup appears automatically on app launch
- Cleaner UI - no more update button in header

### ¡Hola! Mensaje de Bienvenida
- Added friendly "¡Hola!" greeting in update dialog
- More welcoming user experience
- Clear indicator when new version is available

## 🔧 Changes

- Removed update button from app header
- Automatic update detection on startup
- Auto-popup dialog when new version found
- Better user experience with automatic notifications

## 📱 Users will see:

When a new version is available, app will automatically show:
✅ Popup dialog with ¡Hola! greeting
✅ Version info and release notes
✅ "Actualizar ahora" button
✅ No manual clicking required

## Powered by Flox

Developed with ❤️ by Flox
"@

Write-Host "🚀 Creating FutbolGO v1.1.2 Release"
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
    $response = Invoke-WebRequest -Uri $releaseUrl -Method POST -Headers $headers -Body $releaseBody -ContentType "application/json"
    $release = $response.Content | ConvertFrom-Json

    Write-Host "✅ Release created: $TAG"
    Write-Host "🔗 Release URL: $($release.html_url)"
    Write-Host ""
    Write-Host "📤 Uploading APK..."

    $uploadUrl = $release.upload_url -replace "{\?name,label}", "?name=futbolgo.apk"
    $curlCmd = "curl -X POST `"$uploadUrl`" -H `"Authorization: Bearer $TOKEN`" -H `"Accept: application/vnd.github.v3+json`" -H `"Content-Type: application/vnd.android.package-archive`" --data-binary `"$APK_PATH`""

    Write-Host ""
    Write-Host "Executing upload via curl..."

    Invoke-Expression $curlCmd

    Write-Host ""
    Write-Host "🎉 SUCCESS! v1.1.2 Release Complete!"
    Write-Host ""
    Write-Host "📱 Download: https://github.com/$REPO_OWNER/$REPO_NAME/releases/download/$TAG/futbolgo.apk"
    Write-Host "🔗 Release: https://github.com/$REPO_OWNER/$REPO_NAME/releases/tag/$TAG"
    Write-Host ""
    Write-Host "✅ Automatic popup updates enabled!"
    Write-Host "✅ ¡Hola! message added"

} catch {
    Write-Host ""
    Write-Host "❌ Error: $_"
    Write-Host "Details: $($_.ErrorDetails.Message)"
}
