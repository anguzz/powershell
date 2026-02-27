# Generate a printable Web Redirect QR card (high-res PNG, black & white)
param(
    [Parameter(Mandatory=$false)] 
    [string]$URL = "https://tse3.mm.bing.net/th/id/OIP.y7Thbhr0pd0SYl1VmSeWJQHaHa?rs=1&pid=ImgDetMain&o=7&rm=3", # Change your URL here to a funny image
    
    [Parameter(Mandatory=$false)]
    [string]$Label = "Wi-Fi", # Change your text here to something funny like "Scan for free Wi-Fi" or "Scan for a surprise"
    
    [string]$OutPath = ".\SCAN-QR.png",
    [int]$QrPixels = 1200,                        
    [int]$DPI = 300,
    [string]$FontName = "Arial",
    [int]$FontSize = 32
)

# ---------------------------
# Helper: ensure module
# ---------------------------
$requiredModule = "QRCodeGenerator"
if (-not (Get-Module -ListAvailable -Name $requiredModule -ErrorAction SilentlyContinue)) {
    Write-Host "Installing module $requiredModule..."
    Install-Module -Name $requiredModule -Force -Scope CurrentUser -AllowClobber
}
Import-Module -Name $requiredModule -ErrorAction Stop

# ---------------------------
# Generate QR (temporary file)
# ---------------------------
$tempQr = Join-Path $env:TEMP "web_qr_temp.png"

# Using the standard QR cmdlet for a URL payload
New-PSOneQRCodeText -Text $URL -Width 40 -OutPath $tempQr

if (-not (Test-Path $tempQr)) {
    Throw "QR generation failed."
}

# ---------------------------
# Compose printable card using System.Drawing
# ---------------------------
Add-Type -AssemblyName System.Drawing

$qrImg = [System.Drawing.Image]::FromFile($tempQr)

# Layout Constants
$margin = 80            
$textSpacing = 40       
$qrSize = $QrPixels     
$cardWidth = $qrSize + (2 * $margin)

# Calculate height - simplified since we removed the footer URL
$cardHeight = $margin + $qrSize + $textSpacing + $FontSize + $margin

$bmp = New-Object System.Drawing.Bitmap ([int]$cardWidth), ([int]$cardHeight)
$bmp.SetResolution($DPI, $DPI)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.Clear([System.Drawing.Color]::White)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# 1. Draw QR
$qrTargetX = [int](($cardWidth - $qrSize) / 2)
$g.DrawImage($qrImg, $qrTargetX, $margin, $qrSize, $qrSize)
$qrImg.Dispose()

# 2. Draw Main Label
if (-not [string]::IsNullOrWhiteSpace($Label)) {
    $font = New-Object System.Drawing.Font($FontName, $FontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
    $brush = [System.Drawing.Brushes]::Black
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center

    $labelY = $margin + $qrSize + $textSpacing
    $rect = New-Object System.Drawing.RectangleF($margin, $labelY, ($cardWidth - 2*$margin), ($FontSize * 1.5))
    $g.DrawString($Label, $font, $brush, $rect, $format)
}

# ---------------------------
# Save and Cleanup
# ---------------------------
$fullOutPath = (Join-Path (Get-Location) $OutPath)
$bmp.Save($fullOutPath, [System.Drawing.Imaging.ImageFormat]::Png)

# Disposing objects to free memory
$g.Dispose()
$bmp.Dispose()
if ($null -ne $font) { $font.Dispose() }
if ($null -ne $footerFont) { $footerFont.Dispose() } # Fixed the crash here!
if ($null -ne $format) { $format.Dispose() }

Remove-Item $tempQr -ErrorAction SilentlyContinue

Write-Host "Success! Printable web card saved to: $fullOutPath"