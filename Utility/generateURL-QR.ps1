# Generate a printable URL QR card (high-res PNG, black & white)
# Requires: QRCodeGenerator module (v2.6.0+)

param(
    [string]$URL = "https://github.com/",
    [string]$Title = "Scan This Link",
    [string]$OutPath = ".\url_card.png",
    [int]$QrPixels = 1200,         # 1200px = perfect for ~4x4 print at 300 DPI
    [int]$DPI = 300,
    [string]$FontName = "Arial",
    [int]$FontSize = 26
)

# ---------------------------
# Ensure module installed
# ---------------------------
$requiredModule = "QRCodeGenerator"
$requiredVersion = [version]"2.6.0"

if (-not (Get-Module -ListAvailable -Name $requiredModule -ErrorAction SilentlyContinue)) {
    Write-Host "Installing module $requiredModule..."
    Install-Module -Name $requiredModule -RequiredVersion $requiredVersion -Force -Scope CurrentUser
}

Import-Module -Name $requiredModule -ErrorAction Stop

# ---------------------------
# Validate URL
# ---------------------------
if (-not $URL) {
    throw "You must provide a URL using -URL"
}

if (-not ($URL -match '^https?://')) {
    Write-Host "No scheme detected, prepending https://"
    $URL = "https://$URL"
}

Write-Host "Encoding URL: $URL"

# ---------------------------
# Generate QR (temporary)
# ---------------------------
$tempQr = Join-Path $env:TEMP "url_qr_temp.png"

New-PSOneQRCodeText -Text $URL -OutPath $tempQr -Width 40

if (-not (Test-Path $tempQr)) {
    throw "QR generation failed."
}

# ---------------------------
# Compose printable card
# ---------------------------
Add-Type -AssemblyName System.Drawing

$qrImg = [System.Drawing.Image]::FromFile($tempQr)

$margin = 60
$textSpacing = 20
$qrSize = $QrPixels
$cardWidth = $qrSize + (2 * $margin)
$footerFontSize = [int]($FontSize * 0.75)

$cardHeight = $margin + $qrSize + $textSpacing + $FontSize + ($textSpacing/2) + $FontSize + $textSpacing + $footerFontSize + $margin
$cardHeight = [int]$cardHeight

$bmp = New-Object System.Drawing.Bitmap $cardWidth, $cardHeight
$bmp.SetResolution($DPI, $DPI)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.InterpolationMode = "HighQualityBicubic"
$g.SmoothingMode = "AntiAlias"
$g.TextRenderingHint = "AntiAliasGridFit"

# QR placement
$qrTargetX = [int](($cardWidth - $qrSize) / 2)
$qrTargetY = $margin

$qrResized = New-Object System.Drawing.Bitmap $qrSize, $qrSize
$qrResized.SetResolution($DPI, $DPI)
$gQr = [System.Drawing.Graphics]::FromImage($qrResized)
$gQr.InterpolationMode = "HighQualityBicubic"
$gQr.DrawImage($qrImg, 0, 0, $qrSize, $qrSize)

$g.DrawImage($qrResized, $qrTargetX, $qrTargetY)
$gQr.Dispose()
$qrResized.Dispose()
$qrImg.Dispose()

# Fonts
$font = New-Object System.Drawing.Font($FontName, $FontSize, "Regular", "Pixel")
$footerFont = New-Object System.Drawing.Font($FontName, $footerFontSize, "Regular", "Pixel")
$brush = [System.Drawing.Brushes]::Black

$format = New-Object System.Drawing.StringFormat
$format.Alignment = "Center"
$format.LineAlignment = "Near"

$rectWidth = $cardWidth - (2 * $margin)
$firstTextY = $qrTargetY + $qrSize + $textSpacing

# Title
$rectTitle = New-Object System.Drawing.RectangleF($margin, $firstTextY, $rectWidth, 200)
$g.DrawString($Title, $font, $brush, $rectTitle, $format)

# URL
$rectUrlY = $firstTextY + $FontSize + ($textSpacing/2)
$rectURL = New-Object System.Drawing.RectangleF($margin, $rectUrlY, $rectWidth, 200)
$g.DrawString($URL, $font, $brush, $rectURL, $format)

# Footer
$footerY = $rectUrlY + $FontSize + $textSpacing
$footerRect = New-Object System.Drawing.RectangleF($margin, $footerY, $rectWidth, 100)
$g.DrawString("Scan to open link", $footerFont, $brush, $footerRect, $format)

# Save PNG
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
           Where-Object { $_.MimeType -eq "image/png" }

$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter(
    [System.Drawing.Imaging.Encoder]::Compression, 0
)

$finalBmp = New-Object System.Drawing.Bitmap($cardWidth, $cardHeight,
              [System.Drawing.Imaging.PixelFormat]::Format24bppRgb)

$finalBmp.SetResolution($DPI, $DPI)
$gFinal = [System.Drawing.Graphics]::FromImage($finalBmp)
$gFinal.Clear([System.Drawing.Color]::White)
$gFinal.DrawImage($bmp, 0, 0)

$fullOutPath = Join-Path (Get-Location) $OutPath
$finalBmp.Save($fullOutPath, $encoder, $encParams)

# Cleanup
$g.Dispose()
$bmp.Dispose()
$gFinal.Dispose()
$finalBmp.Dispose()
$footerFont.Dispose()
$font.Dispose()
$format.Dispose()
Remove-Item $tempQr -ErrorAction SilentlyContinue

Write-Host "Saved printable URL card to: $OutPath (DPI=$DPI)"
