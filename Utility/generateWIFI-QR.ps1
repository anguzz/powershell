# Generate a printable Wi-Fi QR card (high-res PNG, black & white)
# Requires: QRCodeGenerator module (v2.6.0+)
param(
    [string]$SSID = "",
    [string]$Password = "",
    [ValidateSet("WPA","WEP","nopass")]
    [string]$AuthType = "WPA",
    [switch]$Hidden,
    [string]$OutPath = ".\wifi_card.png",
    [int]$QrPixels = 1200,                        # width/height of QR area in pixels (1200 = good for 4"x4" at 300 DPI)
    [int]$DPI = 300,
    [string]$FontName = "Arial",
    [int]$FontSize = 26
)

# ---------------------------
# Helper: ensure module
# ---------------------------
$requiredModule = "QRCodeGenerator"
$requiredVersion = [version]"2.6.0"
if (-not (Get-Module -ListAvailable -Name $requiredModule -ErrorAction SilentlyContinue)) {
    Write-Host "Installing module $requiredModule..."
    Install-Module -Name $requiredModule -RequiredVersion $requiredVersion -Force -Scope CurrentUser
}

# Import the module to make its cmdlets available
Import-Module -Name $requiredModule -ErrorAction Stop

# ---------------------------
# Build escaped WIFI payload
# ---------------------------
function Escape-WifiField {
    param([string]$s)
    if ($null -eq $s) { return "" }
    # Escape backslash and semicolon and comma per common implementations
    $s -replace '\\', '\\\\' -replace ';', '\;' -replace ',', '\,'
}

$escSSID = Escape-WifiField -s $SSID
$escPwd  = Escape-WifiField -s $Password
$hiddenFlag = if ($Hidden) { "true" } else { "false" }

if ($AuthType -eq "nopass") {
    $payload = "WIFI:T:nopass;S:$escSSID;H:$hiddenFlag;;"
} else {
    $payload = "WIFI:T:$AuthType;S:$escSSID;P:$escPwd;H:$hiddenFlag;;"
}

Write-Host "Payload: $payload"

# ---------------------------
# Generate QR (temporary file)
# ---------------------------
$tempQr = Join-Path $env:TEMP "wifi_qr_temp.png"

# Using your original cmdlet from the module
New-PSOneQRCodeWifiAccess -SSID $SSID -Password $Password -Width 40 -OutPath $tempQr

if (-not (Test-Path $tempQr)) {
    Throw "QR generation failed (expected $tempQr)."
}

# ---------------------------
# Compose printable card using System.Drawing
# ---------------------------
Add-Type -AssemblyName System.Drawing

# Load qr image
$qrImg = [System.Drawing.Image]::FromFile($tempQr)

# Prepare card dimensions:
$margin = 60            # white margin around everything (px)
$textSpacing = 20       # spacing between QR and text
$qrSize = $QrPixels     # square QR area in px (we will center the QR inside)
$cardWidth = $qrSize + (2 * $margin)

# Calculate height based on components: TopMargin + QR + Spacing + SSID + Spacing + PWD + Spacing + Footer + BottomMargin
# Note: Footer font is 0.75 * $FontSize, but we'll use $FontSize for simplicity in spacing.
$footerFontSize = [int]($FontSize * 0.75)
$cardHeight = $margin + $qrSize + $textSpacing + $FontSize + ($textSpacing/2) + $FontSize + $textSpacing + $footerFontSize + $margin
$cardHeight = [int]$cardHeight # Ensure it's an integer

$bmp = New-Object System.Drawing.Bitmap $cardWidth, $cardHeight
$bmp.SetResolution($DPI, $DPI)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit


# Draw the QR centered horizontally, at the top margin
$qrTargetX = [int](($cardWidth - $qrSize) / 2)
$qrTargetY = $margin
# Resize QR image into qrSize x qrSize (ensures crisp B/W)
$qrResized = New-Object System.Drawing.Bitmap $qrSize, $qrSize
$qrResized.SetResolution($DPI, $DPI)
$gQr = [System.Drawing.Graphics]::FromImage($qrResized)
$gQr.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gQr.DrawImage($qrImg, 0, 0, $qrSize, $qrSize)
$g.DrawImage($qrResized, $qrTargetX, $qrTargetY, $qrSize, $qrSize)
$gQr.Dispose()
$qrResized.Dispose()
$qrImg.Dispose()

# Draw SSID and password centered under the QR
$ssidText = "SSID: $SSID"
$pwdText  = "Password: $Password"
$font = New-Object System.Drawing.Font($FontName, $FontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$brush = [System.Drawing.Brushes]::Black

# compute text positions
$format = New-Object System.Drawing.StringFormat
$format.Alignment = [System.Drawing.StringAlignment]::Center
$format.LineAlignment = [System.Drawing.StringAlignment]::Near
$rectWidth = $cardWidth - (2 * $margin)

# first line y:
$firstTextY = $qrTargetY + $qrSize + $textSpacing
$rect = New-Object System.Drawing.RectangleF($margin, $firstTextY, $rectWidth, 200)
$g.DrawString($ssidText, $font, $brush, $rect, $format)

# second line under it
$secondTextY = $firstTextY + $FontSize + ($textSpacing/2)
$rect2 = New-Object System.Drawing.RectangleF($margin, $secondTextY, $rectWidth, 200)
$g.DrawString($pwdText, $font, $brush, $rect2, $format)

# small footer note
$footerFont = New-Object System.Drawing.Font($FontName, $footerFontSize, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$footerText = "Scan to join Wi-Fi"
$footerY = $secondTextY + $FontSize + $textSpacing # Positioned relative to the line above it
$footerRect = New-Object System.Drawing.RectangleF([float]$margin, $footerY, [float]$rectWidth, 100.0)
$g.DrawString($footerText, $footerFont, $brush, $footerRect, $format) | Out-Null

# Save final PNG with high-quality encoder (no lossy colors)
$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/png" }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Compression, 0)

# Ensure black/white only: convert to pixel format 24bppRgb (still RGB, but content is B/W)
$pf = [System.Drawing.Imaging.PixelFormat]::Format24bppRgb
$finalBmp = New-Object System.Drawing.Bitmap($cardWidth, $cardHeight, $pf)
$finalBmp.SetResolution($DPI, $DPI)
$gFinal = [System.Drawing.Graphics]::FromImage($finalBmp)
$gFinal.Clear([System.Drawing.Color]::White)
$gFinal.DrawImage($bmp, 0, 0, $cardWidth, $cardHeight)
$gFinal.Dispose()

$fullOutPath = (Join-Path (Get-Location) $OutPath)
$finalBmp.Save($fullOutPath, $encoder, $encParams)

# cleanup
$g.Dispose()
$bmp.Dispose()
$finalBmp.Dispose()
$footerFont.Dispose()
$font.Dispose()
$format.Dispose()
Remove-Item $tempQr -ErrorAction SilentlyContinue

Write-Host "Saved printable Wi-Fi card to: $OutPath (DPI=$DPI)"