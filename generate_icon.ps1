Add-Type -AssemblyName System.Drawing

$size = 1024
$bmp = New-Object System.Drawing.Bitmap($size, $size)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

# Blue background circle
$bgBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 25, 90, 195))
$g.FillEllipse($bgBrush, 0, 0, 1024, 1024)

# White outer ring
$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::White, 20)
$g.DrawEllipse($ringPen, 10, 10, 1004, 1004)

# Washing machine body - white rounded rectangle
$bodyBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$g.FillRectangle($bodyBrush, 190, 180, 644, 664)

# Machine body border - dark blue
$machinePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 25, 90, 195), 16)
$g.DrawRectangle($machinePen, 190, 180, 644, 664)

# Control panel top strip - light blue
$panelBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 200, 220, 255))
$g.FillRectangle($panelBrush, 190, 180, 644, 100)

# Control knobs
$knobBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 25, 90, 195))
$g.FillEllipse($knobBrush, 220, 200, 60, 60)
$g.FillEllipse($knobBrush, 310, 200, 60, 60)

# Control display bar
$displayBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 25, 90, 195))
$g.FillRectangle($displayBrush, 400, 205, 220, 50)

# Door outer ring - grey
$doorOuterBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 180, 200, 230))
$g.FillEllipse($doorOuterBrush, 247, 310, 530, 490)

# Door ring border
$doorPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 25, 90, 195), 18)
$g.DrawEllipse($doorPen, 247, 310, 530, 490)

# Door glass - blue gradient circle
$glassBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 80, 150, 240))
$g.FillEllipse($glassBrush, 300, 355, 424, 400)

# Water/bubbles inside drum
$waterBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200, 30, 100, 220))
$g.FillEllipse($waterBrush, 320, 450, 384, 260)

# Bubble 1
$bubbleBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180, 255, 255, 255))
$g.FillEllipse($bubbleBrush, 360, 420, 55, 55)
$g.FillEllipse($bubbleBrush, 450, 400, 40, 40)
$g.FillEllipse($bubbleBrush, 560, 430, 65, 65)
$g.FillEllipse($bubbleBrush, 630, 415, 45, 45)

# Door shine highlight
$shineBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 255, 255, 255))
$g.FillEllipse($shineBrush, 330, 370, 150, 100)

# Save
New-Item -ItemType Directory -Path "assets" -Force | Out-Null
$bmp.Save("assets\launcher_icon.png", [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Host "Icon saved successfully!"
