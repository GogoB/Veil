param(
    [string]$OutputDirectory = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Shared vector geometry drives both the editable SVG and Windows icon.
$shapes = @(
    @{
        Id = 'badge'
        Path = 'M 128 16 L 384 16 C 446 16 496 66 496 128 L 496 384 C 496 446 446 496 384 496 L 128 496 C 66 496 16 446 16 384 L 16 128 C 16 66 66 16 128 16 Z'
        From = '#1B2948'; To = '#080D20'; Stroke = '#35415F'; Width = 1.5
    },
    @{
        Id = 'speech'
        Path = 'M 164 112 L 346 112 C 383 112 410 139 410 176 L 410 274 C 410 313 381 341 343 341 L 257 341 L 184 400 L 184 341 L 164 341 C 126 341 96 313 96 275 L 96 180 C 96 141 125 112 164 112 Z'
        From = '#E3CFFF'; To = '#8B56EF'; Stroke = ''; Width = 0
    },
    @{
        Id = 'fold'
        Path = 'M 316 112 L 346 112 C 383 112 410 139 410 176 L 410 274 C 410 313 381 341 343 341 L 257 341 L 184 400 Z'
        From = '#B894FF'; To = '#6033CD'; Stroke = ''; Width = 0
    },
    @{
        Id = 'hem'
        Path = 'M 316 112 L 208 318 L 184 400 Z'
        From = '#F2E5FF'; To = '#B28BF7'; Stroke = ''; Width = 0
    }
)

function ConvertTo-VectorPath {
    param([string]$Data)
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $parts = [regex]::Matches($Data, '[MLCZ]|-?\d+(?:\.\d+)?')
    $index = 0
    [single]$cursorX = 0
    [single]$cursorY = 0
    while ($index -lt $parts.Count) {
        $operation = $parts[$index].Value
        $index++
        switch ($operation) {
            'M' {
                $cursorX = [single]::Parse($parts[$index].Value, [Globalization.CultureInfo]::InvariantCulture)
                $cursorY = [single]::Parse($parts[$index + 1].Value, [Globalization.CultureInfo]::InvariantCulture)
                $index += 2
                $path.StartFigure()
            }
            'L' {
                $nextX = [single]::Parse($parts[$index].Value, [Globalization.CultureInfo]::InvariantCulture)
                $nextY = [single]::Parse($parts[$index + 1].Value, [Globalization.CultureInfo]::InvariantCulture)
                $path.AddLine($cursorX, $cursorY, $nextX, $nextY)
                $cursorX = $nextX
                $cursorY = $nextY
                $index += 2
            }
            'C' {
                $numbers = @()
                for ($point = 0; $point -lt 6; $point++) {
                    $numbers += [single]::Parse($parts[$index + $point].Value, [Globalization.CultureInfo]::InvariantCulture)
                }
                $path.AddBezier($cursorX, $cursorY, $numbers[0], $numbers[1], $numbers[2], $numbers[3], $numbers[4], $numbers[5])
                $cursorX = $numbers[4]
                $cursorY = $numbers[5]
                $index += 6
            }
            'Z' { $path.CloseFigure() }
            default { throw "Unsupported vector command: $operation" }
        }
    }
    return ,$path
}

$utf8 = [System.Text.UTF8Encoding]::new($false)
$svgParts = [System.Collections.Generic.List[string]]::new()
$svgParts.Add('<svg xmlns="http://www.w3.org/2000/svg" width="512" height="512" viewBox="0 0 512 512" role="img" aria-labelledby="title desc">')
$svgParts.Add('<title id="title">Veil</title>')
$svgParts.Add('<desc id="desc">A violet speech bubble folds into a pale veil on a midnight-blue rounded square.</desc>')
$svgParts.Add('<defs>')
foreach ($shape in $shapes) {
    $svgParts.Add(('<linearGradient id="{0}" gradientUnits="userSpaceOnUse" x1="0" y1="0" x2="512" y2="512"><stop stop-color="{1}"/><stop offset="1" stop-color="{2}"/></linearGradient>' -f $shape.Id, $shape.From, $shape.To))
}
$svgParts.Add('</defs>')
foreach ($shape in $shapes) {
    $strokeAttributes = ''
    if ($shape.Stroke) {
        $strokeAttributes = ' stroke="{0}" stroke-width="{1}"' -f $shape.Stroke, $shape.Width
    }
    $svgParts.Add(('<path d="{0}" fill="url(#{1})"{2}/>' -f $shape.Path, $shape.Id, $strokeAttributes))
}
$svgParts.Add('</svg>')
[System.IO.File]::WriteAllText((Join-Path $OutputDirectory 'veil.svg'), ($svgParts -join [Environment]::NewLine) + [Environment]::NewLine, $utf8)

$master = [System.Drawing.Bitmap]::new(2048, 2048, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($master)
try {
    $graphics.Clear([System.Drawing.Color]::Transparent)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $graphics.ScaleTransform(4, 4)
    foreach ($shape in $shapes) {
        $path = ConvertTo-VectorPath $shape.Path
        $brush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.PointF]::new(0, 0),
            [System.Drawing.PointF]::new(512, 512),
            [System.Drawing.ColorTranslator]::FromHtml($shape.From),
            [System.Drawing.ColorTranslator]::FromHtml($shape.To)
        )
        try {
            $graphics.FillPath($brush, $path)
            if ($shape.Stroke) {
                $pen = [System.Drawing.Pen]::new([System.Drawing.ColorTranslator]::FromHtml($shape.Stroke), [single]$shape.Width)
                try { $graphics.DrawPath($pen, $path) } finally { $pen.Dispose() }
            }
        } finally {
            $brush.Dispose()
            $path.Dispose()
        }
    }
} finally {
    $graphics.Dispose()
}

function Get-IconPng {
    param([System.Drawing.Bitmap]$Source, [int]$Size)
    $bitmap = [System.Drawing.Bitmap]::new($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $drawing = [System.Drawing.Graphics]::FromImage($bitmap)
    $stream = [System.IO.MemoryStream]::new()
    try {
        $drawing.Clear([System.Drawing.Color]::Transparent)
        $drawing.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $drawing.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $drawing.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $drawing.DrawImage($Source, [System.Drawing.Rectangle]::new(0, 0, $Size, $Size))
        $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
        return ,$stream.ToArray()
    } finally {
        $drawing.Dispose()
        $bitmap.Dispose()
        $stream.Dispose()
    }
}

try {
    [System.IO.File]::WriteAllBytes((Join-Path $OutputDirectory 'veil-preview.png'), (Get-IconPng $master 512))
    $sizes = @(16, 24, 32, 48, 64, 128, 256)
    $entries = [System.Collections.Generic.List[byte[]]]::new()
    foreach ($size in $sizes) {
        $entries.Add((Get-IconPng $master $size))
    }
    $iconStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.BinaryWriter]::new($iconStream)
    try {
        $writer.Write([uint16]0)
        $writer.Write([uint16]1)
        $writer.Write([uint16]$sizes.Count)
        [uint32]$offset = 6 + 16 * $sizes.Count
        for ($entryIndex = 0; $entryIndex -lt $sizes.Count; $entryIndex++) {
            $dimensionByte = if ($sizes[$entryIndex] -eq 256) { 0 } else { $sizes[$entryIndex] }
            $writer.Write([byte]$dimensionByte)
            $writer.Write([byte]$dimensionByte)
            $writer.Write([byte]0)
            $writer.Write([byte]0)
            $writer.Write([uint16]1)
            $writer.Write([uint16]32)
            $writer.Write([uint32]$entries[$entryIndex].Length)
            $writer.Write([uint32]$offset)
            $offset += $entries[$entryIndex].Length
        }
        foreach ($entryBytes in $entries) { $writer.Write([byte[]]$entryBytes) }
        $writer.Flush()
        [System.IO.File]::WriteAllBytes((Join-Path $OutputDirectory 'veil.ico'), $iconStream.ToArray())
    } finally {
        $writer.Dispose()
        $iconStream.Dispose()
    }
} finally {
    $master.Dispose()
}
Write-Output 'Built editable SVG, 512px preview, and Windows ICO (16, 24, 32, 48, 64, 128, 256px).'
