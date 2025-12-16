$ffmpeg = "C:\Users\MarieLexisDad\ffmpeg-8.0.1-essentials_build\bin\ffmpeg.exe"
$ffprobe = "C:\Users\MarieLexisDad\ffmpeg-8.0.1-essentials_build\bin\ffprobe.exe"
$assetsPath = "C:\Users\MarieLexisDad\repos\trpec-promo-videos\assets"

Set-Location $assetsPath

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "TRPEC Video Assembly Fix (CROP - No Black Bars)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

# Step 1: Verify source files
Write-Host "`n=== Step 1: Verify Source Files ===" -ForegroundColor Cyan
$files = @("clip1_new.mp4", "clip2_new.mp4", "video1_original_backup.mp4")
foreach ($f in $files) {
    if (Test-Path $f) {
        $size = [math]::Round((Get-Item $f).Length / 1MB, 2)
        Write-Host "  [OK] $f ($size MB)" -ForegroundColor Green
    } else {
        Write-Host "  [MISSING] $f" -ForegroundColor Red
        exit 1
    }
}

# Step 2: Re-encode clips - CROP to 16:9 (no black bars)
# Source is 1440x1440 (1:1), target is 1920x1080 (16:9)
# Crop height to 810 (1440 * 9/16 = 810), then scale to 1920x1080
Write-Host "`n=== Step 2: Re-encode Clips (CROP to 16:9 - No Black Bars) ===" -ForegroundColor Cyan

Write-Host "  Processing clip1_new.mp4 -> clip1_fixed.mp4..."
$null = & $ffmpeg -y -i "clip1_new.mp4" -f lavfi -i "anullsrc=channel_layout=mono:sample_rate=48000" -vf "crop=1440:810:0:(ih-810)/2,scale=1920:1080,fps=30" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 128k -shortest -map 0:v -map 1:a "clip1_fixed.mp4" 2>&1
if (Test-Path "clip1_fixed.mp4") { Write-Host "  [OK] clip1_fixed.mp4 created (cropped to 16:9)" -ForegroundColor Green }

Write-Host "  Processing clip2_new.mp4 -> clip2_fixed.mp4..."
$null = & $ffmpeg -y -i "clip2_new.mp4" -f lavfi -i "anullsrc=channel_layout=mono:sample_rate=48000" -vf "crop=1440:810:0:(ih-810)/2,scale=1920:1080,fps=30" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 128k -shortest -map 0:v -map 1:a "clip2_fixed.mp4" 2>&1
if (Test-Path "clip2_fixed.mp4") { Write-Host "  [OK] clip2_fixed.mp4 created (cropped to 16:9)" -ForegroundColor Green }

# Step 3: Extract parts from original
Write-Host "`n=== Step 3: Extract Parts from Original ===" -ForegroundColor Cyan

Write-Host "  Extracting part1 (0:00-0:21)..."
$null = & $ffmpeg -y -i "video1_original_backup.mp4" -t 21 -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 128k "part1.mp4" 2>&1
if (Test-Path "part1.mp4") { Write-Host "  [OK] part1.mp4 created" -ForegroundColor Green }

Write-Host "  Extracting part4 (0:31-end)..."
$null = & $ffmpeg -y -i "video1_original_backup.mp4" -ss 31 -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 128k "part4.mp4" 2>&1
if (Test-Path "part4.mp4") { Write-Host "  [OK] part4.mp4 created" -ForegroundColor Green }

# Step 4: Verify specs
Write-Host "`n=== Step 4: Verify All Parts Have Matching Specs ===" -ForegroundColor Cyan
$partsToCheck = @("part1.mp4", "clip1_fixed.mp4", "clip2_fixed.mp4", "part4.mp4")
foreach ($f in $partsToCheck) {
    $info = & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height,r_frame_rate -of csv=p=0 $f 2>&1
    Write-Host "  $f : $info" -ForegroundColor White
}

# Step 5: Concatenate
Write-Host "`n=== Step 5: Concatenate All Parts ===" -ForegroundColor Cyan

@"
file 'part1.mp4'
file 'clip1_fixed.mp4'
file 'clip2_fixed.mp4'
file 'part4.mp4'
"@ | Out-File -Encoding ascii "concat_list.txt"

Write-Host "  Concatenating (full re-encode for compatibility)..."
$null = & $ffmpeg -y -f concat -safe 0 -i "concat_list.txt" -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 128k "video1_final.mp4" 2>&1
if (Test-Path "video1_final.mp4") { Write-Host "  [OK] video1_final.mp4 created" -ForegroundColor Green }

# Step 6: Debug frames
Write-Host "`n=== Step 6: Extract Debug Frames ===" -ForegroundColor Cyan

$null = & $ffmpeg -y -ss 23 -i "video1_final.mp4" -frames:v 1 "debug_frame_23s.jpg" 2>&1
if (Test-Path "debug_frame_23s.jpg") { Write-Host "  [OK] debug_frame_23s.jpg (should show students - NO BLACK BARS)" -ForegroundColor Green }

$null = & $ffmpeg -y -ss 28 -i "video1_final.mp4" -frames:v 1 "debug_frame_28s.jpg" 2>&1
if (Test-Path "debug_frame_28s.jpg") { Write-Host "  [OK] debug_frame_28s.jpg (should show administrators - NO BLACK BARS)" -ForegroundColor Green }

# Final info
$finalDuration = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "video1_final.mp4" 2>&1
$finalSize = [math]::Round((Get-Item "video1_final.mp4").Length / 1MB, 2)

Write-Host "`n========================================" -ForegroundColor Yellow
Write-Host "ASSEMBLY COMPLETE (NO BLACK BARS)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Final video: video1_final.mp4"
Write-Host "  Duration: $finalDuration seconds"
Write-Host "  Size: $finalSize MB"
Write-Host ""
Write-Host "  Debug frames saved for verification:"
Write-Host "    - debug_frame_23s.jpg (students clip)"
Write-Host "    - debug_frame_28s.jpg (administrators clip)"
