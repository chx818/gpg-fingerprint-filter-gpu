# ==================== 用户配置区 ====================
$ALGO = "p512"
$PATTERN = "x{12}"
$TIME_WINDOW = 31536000
$OUTPUT_DIR = ".\batch_keys"
$LOG_FILE = ".\batch_miner.log"
# ===================================================

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $SCRIPT_DIR

$EXE = Join-Path $SCRIPT_DIR "gpg-fingerprint-filter-gpu.exe"
$SCRATCH_DIR = Join-Path $SCRIPT_DIR "_miner_scratch"

# 自动清理可能残留的后台孤儿挖掘进程
Get-Process -Name "gpg-fingerprint-filter-gpu" -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Host ">> 发现残留的后台挖掘进程 (PID: $($_.Id))，正在清理以释放算力..." -ForegroundColor Yellow
    try { Stop-Process -Id $_.Id -Force } catch {}
}

# 自动寻找系统 GnuPG 中的 gpg.exe
$GPG_EXE = "gpg"
if (-not (Get-Command "gpg" -ErrorAction SilentlyContinue)) {
    if (Test-Path "C:\Program Files\GnuPG\bin\gpg.exe") {
        $GPG_EXE = "C:\Program Files\GnuPG\bin\gpg.exe"
    } elseif (Test-Path "C:\Program Files (x86)\GnuPG\bin\gpg.exe") {
        $GPG_EXE = "C:\Program Files (x86)\GnuPG\bin\gpg.exe"
    }
}

if (-not (Test-Path $OUTPUT_DIR)) { New-Item -ItemType Directory -Path $OUTPUT_DIR -Force | Out-Null }
if (-not (Test-Path $SCRATCH_DIR)) { New-Item -ItemType Directory -Path $SCRATCH_DIR -Force | Out-Null }

$TOTAL_HITS = 0
$START_TIME = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$global:currentProc = $null

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ">> 自动化 PGP 靓号挂机挖掘启动 (Windows 版)" -ForegroundColor Green
Write-Host ">> 算法: $ALGO | 目标模式: $PATTERN"
Write-Host ">> 结果存储: $OUTPUT_DIR"
Write-Host ">> 退出请按 Ctrl+C"
Write-Host "==================================================" -ForegroundColor Cyan

try {
    while ($true) {
        Remove-Item -Path "$SCRATCH_DIR\*" -Force -ErrorAction SilentlyContinue
        $RUN_START = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()

        $pinfo = New-Object System.Diagnostics.ProcessStartInfo
        $pinfo.FileName = $EXE
        $pinfo.WorkingDirectory = $SCRIPT_DIR
        $pinfo.Arguments = "-a `"$ALGO`" -t $TIME_WINDOW `"$PATTERN`" `"$SCRATCH_DIR`""
        $pinfo.RedirectStandardOutput = $true
        $pinfo.RedirectStandardError = $true
        $pinfo.UseShellExecute = $false
        $pinfo.CreateNoWindow = $true

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $pinfo
        $proc.Start() | Out-Null
        $global:currentProc = $proc

        $sr = $proc.StandardOutput
        $charBuf = New-Object System.Text.StringBuilder

        while (-not $proc.HasExited -or -not $sr.EndOfStream) {
            $charInt = $sr.Read()
            if ($charInt -eq -1) { break }
            $ch = [char]$charInt

            if ($ch -eq "`r" -or $ch -eq "`n") {
                $line = $charBuf.ToString()
                $charBuf.Clear() | Out-Null
                if ($line -match "Speed:\s+([0-9\.]+)\s+hashes") {
                    $speed = $Matches[1]
                    Write-Host -NoNewline ("`r>> 当前 GPU 哈希速度: {0} hashes/sec        " -f $speed)
                }
            } else {
                $charBuf.Append($ch) | Out-Null
            }
        }
        $proc.WaitForExit()
        $global:currentProc = $null
        Write-Host ""

        $found = Get-ChildItem -Path $SCRATCH_DIR -Filter "*.gpg" -File | Select-Object -First 1

        if ($found) {
            $TOTAL_HITS++
            $RUN_END = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
            $ELAPSED = $RUN_END - $RUN_START

            $fpr = ""
            try {
                $listPackets = & $GPG_EXE --list-packets $found.FullName 2>$null
                foreach ($l in $listPackets) {
                    if ($l -match "keyid:\s+([0-9A-Fa-f]+)") {
                        $fpr = $Matches[1]
                        break
                    }
                }
            } catch {
                $fpr = ""
            }

            if (-not $fpr) {
                $fpr = "HIT_" + (Get-Date -Format "yyyyMMdd_HHmmss")
            }

            $targetName = Join-Path $OUTPUT_DIR "${ALGO}_${fpr}.gpg"
            Move-Item -Path $found.FullName -Destination $targetName -Force

            $min = [math]::Floor($ELAPSED / 60)
            $sec = $ELAPSED % 60
            $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

            Write-Host "[HIT #$TOTAL_HITS] [$ts] (耗时: ${min}分${sec}秒) -> KeyID: $fpr" -ForegroundColor Green
            " [HIT #$TOTAL_HITS] [$ts] (耗时: ${min}分${sec}秒) KeyID: $fpr -> $targetName" | Out-File -Append -FilePath $LOG_FILE
        } else {
            Start-Sleep -Seconds 2
        }
    }
} finally {
    # 确保退出时强行杀死子进程，杜绝后台残留
    if ($global:currentProc -and -not $global:currentProc.HasExited) {
        try {
            $global:currentProc.Kill()
            $global:currentProc.WaitForExit(1000)
        } catch {}
    }

    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Yellow
    Write-Host ">> 收到终止信号，挂机任务结束。"
    $TOTAL_TIME = [System.DateTimeOffset]::UtcNow.ToUnixTimeSeconds() - $START_TIME
    $h = [math]::Floor($TOTAL_TIME / 3600)
    $m = [math]::Floor(($TOTAL_TIME % 3600) / 60)
    $s = $TOTAL_TIME % 60
    Write-Host ">> 累计挂机时长: ${h}小时${m}分 ${s}秒"
    Write-Host ">> 成功收获靓号: $TOTAL_HITS 个"
    Write-Host ">> 结果保存在: $((Resolve-Path $OUTPUT_DIR).Path)"
    Write-Host "==================================================" -ForegroundColor Yellow
    Remove-Item -Recurse -Force $SCRATCH_DIR -ErrorAction SilentlyContinue
}
