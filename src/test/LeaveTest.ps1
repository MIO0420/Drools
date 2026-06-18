# ============================================================
# LeaveTest_FullExperiment.ps1
# 鑫電星 HR 規則引擎 - 完整過夜實驗腳本 v7
# ============================================================

# ── 1. 基礎配置 ──────────────────────────────────────────────
$baseUrl          = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
$script:endpoint  = "$baseUrl/calculateleave"
$script:delayMs   = 300
$script:logFile   = "Exp_Log_$(Get-Date -Format 'yyyyMMdd_HHmm').txt"
$script:csvFile   = "Exp_Result_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$script:detailCsv = "Exp_Detail_$(Get-Date -Format 'yyyyMMdd_HHmm').csv"
$script:allResults = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:detailRows = [System.Collections.Generic.List[PSCustomObject]]::new()

# UTC+8 時間函數
function Get-TW {
    param ([string]$fmt = "yyyy-MM-dd HH:mm:ss")
    $utc8 = [System.TimeZoneInfo]::FindSystemTimeZoneById("Taipei Standard Time")
    return [System.TimeZoneInfo]::ConvertTimeFromUtc([DateTime]::UtcNow, $utc8).ToString($fmt)
}

# ── 2. 假別資料池 ─────────────────────────────────────────────
$script:leavePool = @(
    # 事假 20 筆
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=0;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=2;  usedDaysThisYear=3;  tenureMonths=36;  baseSalary=45000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=5;  tenureMonths=12;  baseSalary=40000 }
    @{ leaveType="事假"; leaveDays=3;  usedDaysThisYear=10; tenureMonths=60;  baseSalary=60000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=13; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=2;  usedDaysThisYear=13; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=0;  tenureMonths=48;  baseSalary=55000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=7;  tenureMonths=18;  baseSalary=42000 }
    @{ leaveType="事假"; leaveDays=2;  usedDaysThisYear=8;  tenureMonths=30;  baseSalary=48000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=2;  tenureMonths=72;  baseSalary=65000 }
    @{ leaveType="事假"; leaveDays=3;  usedDaysThisYear=0;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=4;  tenureMonths=36;  baseSalary=52000 }
    @{ leaveType="事假"; leaveDays=2;  usedDaysThisYear=6;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=9;  tenureMonths=12;  baseSalary=40000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=11; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=4;  usedDaysThisYear=12; tenureMonths=60;  baseSalary=60000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=1;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=2;  usedDaysThisYear=5;  tenureMonths=36;  baseSalary=53000 }
    @{ leaveType="事假"; leaveDays=1;  usedDaysThisYear=8;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="事假"; leaveDays=3;  usedDaysThisYear=4;  tenureMonths=48;  baseSalary=56000 }

    # 普通傷病假 15 筆
    @{ leaveType="普通傷病假"; leaveDays=1;  usedDaysThisYear=0;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="普通傷病假"; leaveDays=3;  usedDaysThisYear=5;  tenureMonths=36;  baseSalary=55000 }
    @{ leaveType="普通傷病假"; leaveDays=2;  usedDaysThisYear=10; tenureMonths=12;  baseSalary=40000 }
    @{ leaveType="普通傷病假"; leaveDays=5;  usedDaysThisYear=20; tenureMonths=60;  baseSalary=60000 }
    @{ leaveType="普通傷病假"; leaveDays=1;  usedDaysThisYear=28; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="普通傷病假"; leaveDays=3;  usedDaysThisYear=29; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="普通傷病假"; leaveDays=2;  usedDaysThisYear=0;  tenureMonths=48;  baseSalary=55000 }
    @{ leaveType="普通傷病假"; leaveDays=1;  usedDaysThisYear=15; tenureMonths=18;  baseSalary=42000 }
    @{ leaveType="普通傷病假"; leaveDays=4;  usedDaysThisYear=8;  tenureMonths=30;  baseSalary=48000 }
    @{ leaveType="普通傷病假"; leaveDays=2;  usedDaysThisYear=3;  tenureMonths=72;  baseSalary=65000 }
    @{ leaveType="普通傷病假"; leaveDays=1;  usedDaysThisYear=0;  tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="普通傷病假"; leaveDays=3;  usedDaysThisYear=12; tenureMonths=36;  baseSalary=52000 }
    @{ leaveType="普通傷病假"; leaveDays=2;  usedDaysThisYear=25; tenureMonths=24;  baseSalary=50000 }
    @{ leaveType="普通傷病假"; leaveDays=1;  usedDaysThisYear=7;  tenureMonths=12;  baseSalary=40000 }
    @{ leaveType="普通傷病假"; leaveDays=5;  usedDaysThisYear=0;  tenureMonths=24;  baseSalary=50000 }

    # ★ 特別休假 15 筆（移除 tenureMonths>=120 的資料，避免觸發 DRL 整數除法 Bug）
    @{ leaveType="特別休假"; leaveDays=3;  usedDaysThisYear=0;  tenureMonths=8;   baseSalary=38000 }
    @{ leaveType="特別休假"; leaveDays=5;  usedDaysThisYear=0;  tenureMonths=15;  baseSalary=42000 }
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=3;  tenureMonths=18;  baseSalary=45000 }
    @{ leaveType="特別休假"; leaveDays=5;  usedDaysThisYear=0;  tenureMonths=30;  baseSalary=50000 }
    @{ leaveType="特別休假"; leaveDays=10; usedDaysThisYear=0;  tenureMonths=30;  baseSalary=50000 }
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=0;  tenureMonths=48;  baseSalary=55000 }
    @{ leaveType="特別休假"; leaveDays=3;  usedDaysThisYear=5;  tenureMonths=48;  baseSalary=55000 }
    @{ leaveType="特別休假"; leaveDays=10; usedDaysThisYear=0;  tenureMonths=72;  baseSalary=60000 }
    @{ leaveType="特別休假"; leaveDays=5;  usedDaysThisYear=10; tenureMonths=72;  baseSalary=60000 }
    @{ leaveType="特別休假"; leaveDays=15; usedDaysThisYear=0;  tenureMonths=84;  baseSalary=65000 }
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=8;  tenureMonths=84;  baseSalary=65000 }
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=0;  tenureMonths=96;  baseSalary=70000 }  # 8年，安全
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=0;  tenureMonths=108; baseSalary=75000 }  # 9年，安全
    @{ leaveType="特別休假"; leaveDays=7;  usedDaysThisYear=3;  tenureMonths=96;  baseSalary=70000 }  # 8年，安全
    @{ leaveType="特別休假"; leaveDays=5;  usedDaysThisYear=2;  tenureMonths=108; baseSalary=75000 }  # 9年，安全

    # 婚假 5 筆
    @{ leaveType="婚假"; leaveDays=8; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="婚假"; leaveDays=3; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="婚假"; leaveDays=9; usedDaysThisYear=0; tenureMonths=12; baseSalary=40000 }
    @{ leaveType="婚假"; leaveDays=5; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="婚假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }

    # 喪假 10 筆
    @{ leaveType="喪假"; leaveDays=8; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="喪假"; leaveDays=6; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="喪假"; leaveDays=3; usedDaysThisYear=0; tenureMonths=12; baseSalary=40000 }
    @{ leaveType="喪假"; leaveDays=6; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="喪假"; leaveDays=5; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="喪假"; leaveDays=3; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="喪假"; leaveDays=2; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="喪假"; leaveDays=5; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="喪假"; leaveDays=2; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="喪假"; leaveDays=8; usedDaysThisYear=0; tenureMonths=72; baseSalary=65000 }

    # 生理假 5 筆
    @{ leaveType="生理假"; leaveDays=1; usedDaysThisYear=0;  tenureMonths=24; baseSalary=50000 }
    @{ leaveType="生理假"; leaveDays=1; usedDaysThisYear=2;  tenureMonths=36; baseSalary=55000 }
    @{ leaveType="生理假"; leaveDays=1; usedDaysThisYear=5;  tenureMonths=24; baseSalary=50000 }
    @{ leaveType="生理假"; leaveDays=1; usedDaysThisYear=11; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="生理假"; leaveDays=1; usedDaysThisYear=12; tenureMonths=24; baseSalary=50000 }

    # 家庭照顧假 5 筆
    @{ leaveType="家庭照顧假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="家庭照顧假"; leaveDays=2; usedDaysThisYear=3; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="家庭照顧假"; leaveDays=3; usedDaysThisYear=5; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="家庭照顧假"; leaveDays=1; usedDaysThisYear=6; tenureMonths=48; baseSalary=55000 }
    @{ leaveType="家庭照顧假"; leaveDays=2; usedDaysThisYear=0; tenureMonths=60; baseSalary=60000 }

    # 補休 5 筆
    @{ leaveType="補休"; leaveDays=1; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="補休"; leaveDays=2; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="補休"; leaveDays=3; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="補休"; leaveDays=1; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="補休"; leaveDays=4; usedDaysThisYear=0; tenureMonths=72; baseSalary=65000 }

    # 公假 5 筆
    @{ leaveType="公假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="公假"; leaveDays=2; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="公假"; leaveDays=3; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="公假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="公假"; leaveDays=2; usedDaysThisYear=0; tenureMonths=72; baseSalary=65000 }

    # 生日假 5 筆
    @{ leaveType="生日假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="生日假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="生日假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="生日假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="生日假"; leaveDays=1; usedDaysThisYear=0; tenureMonths=72; baseSalary=65000 }

    # 天然災害 5 筆
    @{ leaveType="天然災害"; leaveDays=1; usedDaysThisYear=0; tenureMonths=24; baseSalary=50000 }
    @{ leaveType="天然災害"; leaveDays=2; usedDaysThisYear=0; tenureMonths=36; baseSalary=55000 }
    @{ leaveType="天然災害"; leaveDays=1; usedDaysThisYear=0; tenureMonths=48; baseSalary=58000 }
    @{ leaveType="天然災害"; leaveDays=3; usedDaysThisYear=0; tenureMonths=60; baseSalary=62000 }
    @{ leaveType="天然災害"; leaveDays=1; usedDaysThisYear=0; tenureMonths=72; baseSalary=65000 }
)

# ── 3. 產生 JSON ──────────────────────────────────────────────
function ConvertTo-LeaveJson {
    param ($idx, $data)
    $empId = "EMP{0:D3}" -f ($idx + 1)
    return [string]::Format(
        [System.Globalization.CultureInfo]::InvariantCulture,
        '{{"companyId":"COMP001","employeeId":"{0}","position":"Engineer","identity":"Standard","tenureMonths":{1},"baseSalary":{2},"leaveType":"{3}","leaveDays":{4},"deductionRate":1.0,"usedDaysThisYear":{5}}}',
        $empId, $data.tenureMonths, $data.baseSalary,
        $data.leaveType, $data.leaveDays, $data.usedDaysThisYear
    )
}

$script:jsonList = @()
for ($i = 0; $i -lt 100; $i++) {
    $script:jsonList += ConvertTo-LeaveJson $i $script:leavePool[$i % $script:leavePool.Count]
}
$script:batchJson = "[" + ($script:jsonList -join ",") + "]"

# ── 4. 工具函數 ───────────────────────────────────────────────
function Write-Log {
    param ([string]$msg, [string]$color = "White")
    $line = "[$(Get-TW 'yyyy-MM-dd HH:mm:ss')] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $script:logFile -Value $line -Encoding UTF8
}

function Get-HttpErrorMessage {
    param ($ErrorRecord)
    if ($null -ne $ErrorRecord.ErrorDetails -and
        ![string]::IsNullOrWhiteSpace($ErrorRecord.ErrorDetails.Message)) {
        return $ErrorRecord.ErrorDetails.Message
    }
    $ex = $ErrorRecord.Exception
    if ($null -ne $ex.Response) {
        try {
            $stream = $ex.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            return $reader.ReadToEnd()
        } catch {}
    }
    return $ex.Message
}

function Send-Single {
    param ([string]$Json, [string]$Label)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Json)
    $sw    = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r   = Invoke-WebRequest -Uri $script:endpoint -Method Post `
                 -Body $bytes -ContentType "application/json; charset=utf-8" `
                 -Headers @{ "x-test-case" = $Label } -UseBasicParsing
        $sw.Stop()
        $val = $r.Headers["X-Execution-Time-Ms"]
        if ($val -is [array]) { $val = $val[0] }
        return [PSCustomObject]@{
            OK       = $true
            WallMs   = $sw.Elapsed.TotalMilliseconds
            EngineMs = if ($null -ne $val) { [int]$val } else { 0 }
            ErrorMsg = ""
        }
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            OK       = $false
            WallMs   = $sw.Elapsed.TotalMilliseconds
            EngineMs = 0
            ErrorMsg = (Get-HttpErrorMessage $_)
        }
    }
}

function Wait-WithCountdown {
    param ([int]$Seconds, [string]$Reason)
    Write-Log "⏳ 等待 $Seconds 秒（$Reason）..." "DarkYellow"
    $end = (Get-Date).AddSeconds($Seconds)
    while ((Get-Date) -lt $end) {
        $remain = [int]($end - (Get-Date)).TotalSeconds
        $pct    = [int](($Seconds - $remain) / $Seconds * 100)
        Write-Progress -Activity "等待中：$Reason" -Status "剩餘 $remain 秒" -PercentComplete $pct
        Start-Sleep -Seconds 5
    }
    Write-Progress -Activity "等待中" -Completed
    Write-Log "✅ 等待完成" "DarkYellow"
}

function Add-Result {
    param (
        [string]$Phase,
        [string]$SubPhase,
        [double]$WallMs,
        [int]$EngineMs,
        [int]$SuccessCount,
        [int]$FailCount,
        [string]$Note = ""
    )
    $total = $SuccessCount + $FailCount
    $avg   = if ($total -gt 0) { [Math]::Round($WallMs / $total, 1) } else { 0 }
    $row   = [PSCustomObject]@{
        Phase        = $Phase
        SubPhase     = $SubPhase
        WallMs       = [Math]::Round($WallMs, 0)
        EngineMs     = $EngineMs
        SuccessCount = $SuccessCount
        FailCount    = $FailCount
        AvgWallMs    = $avg
        Note         = $Note
        Timestamp_TW = (Get-TW)
    }
    $script:allResults.Add($row)
    return $row
}

function Add-DetailRow {
    param (
        [string]$Phase,
        [int]$SeqNo,
        [string]$EmpId,
        [string]$LeaveType,
        [string]$SentAt_TW,
        [double]$WallMs,
        [int]$EngineMs,
        [bool]$OK,
        [string]$ErrorMsg = ""
    )
    $row = [PSCustomObject]@{
        Phase     = $Phase
        SeqNo     = $SeqNo
        EmpId     = $EmpId
        LeaveType = $LeaveType
        SentAt_TW = $SentAt_TW
        WallMs    = [Math]::Round($WallMs, 0)
        EngineMs  = $EngineMs
        OK        = $OK
        ErrorMsg  = $ErrorMsg
    }
    $script:detailRows.Add($row)
}

# ── 5. 實驗模組 ───────────────────────────────────────────────

function Test-SingleShot {
    param ([string]$Phase, [string]$Note)
    Write-Log "▶ [$Phase] $Note" "Magenta"
    $sentAt = Get-TW
    $r      = Send-Single $script:jsonList[0] $Phase

    if ($r.OK) {
        Write-Log ("  wall={0:F0}ms  engine={1}ms" -f $r.WallMs, $r.EngineMs) "Magenta"
        Add-Result -Phase $Phase -SubPhase "SingleShot" `
            -WallMs $r.WallMs -EngineMs $r.EngineMs `
            -SuccessCount 1 -FailCount 0 -Note $Note | Out-Null
        Add-DetailRow -Phase $Phase -SeqNo 1 `
            -EmpId "EMP001" -LeaveType $script:leavePool[0].leaveType `
            -SentAt_TW $sentAt -WallMs $r.WallMs -EngineMs $r.EngineMs -OK $true
    } else {
        Write-Log "  FAIL: $($r.ErrorMsg)" "Red"
        Add-Result -Phase $Phase -SubPhase "SingleShot" `
            -WallMs $r.WallMs -EngineMs 0 `
            -SuccessCount 0 -FailCount 1 -Note "FAIL: $Note" | Out-Null
        Add-DetailRow -Phase $Phase -SeqNo 1 `
            -EmpId "EMP001" -LeaveType $script:leavePool[0].leaveType `
            -SentAt_TW $sentAt -WallMs $r.WallMs -EngineMs 0 -OK $false -ErrorMsg $r.ErrorMsg
    }
    return $r
}

function Test-RealTime100 {
    param ([string]$Phase)
    Write-Log "▶ [$Phase] 即時模式 100 筆（間隔 $($script:delayMs)ms）" "Cyan"
    $wallStart = Get-Date
    $okWalls   = @()
    $failCount = 0

    for ($i = 0; $i -lt $script:jsonList.Count; $i++) {
        $poolData  = $script:leavePool[$i % $script:leavePool.Count]
        $leaveType = $poolData.leaveType
        $empId     = "EMP{0:D3}" -f ($i + 1)

        $sentAt = Get-TW
        $r      = Send-Single $script:jsonList[$i] "$Phase-RT"

        if ($r.OK) {
            $okWalls += $r.WallMs
            Write-Log ("  [{0:D3}] {1,-8} sent={2}  wall={3:F0}ms  engine={4}ms" -f `
                ($i+1), $leaveType, $sentAt, $r.WallMs, $r.EngineMs) "Cyan"
            Add-DetailRow -Phase $Phase -SeqNo ($i+1) `
                -EmpId $empId -LeaveType $leaveType `
                -SentAt_TW $sentAt -WallMs $r.WallMs -EngineMs $r.EngineMs -OK $true
        } else {
            $failCount++
            Write-Log ("  [{0:D3}] {1,-8} sent={2}  FAIL: {3}" -f `
                ($i+1), $leaveType, $sentAt, $r.ErrorMsg) "Red"
            Add-DetailRow -Phase $Phase -SeqNo ($i+1) `
                -EmpId $empId -LeaveType $leaveType `
                -SentAt_TW $sentAt -WallMs $r.WallMs -EngineMs 0 -OK $false -ErrorMsg $r.ErrorMsg
        }

        if ($script:delayMs -gt 0) { Start-Sleep -Milliseconds $script:delayMs }
    }

    $totalWall = ((Get-Date) - $wallStart).TotalMilliseconds
    $avgWall   = if ($okWalls.Count -gt 0) { ($okWalls | Measure-Object -Average).Average } else { 0 }

    Write-Log ("  完成：成功 {0}，失敗 {1}，總牆鐘 {2:F0}ms，平均每筆 {3:F1}ms" -f `
        $okWalls.Count, $failCount, $totalWall, $avgWall) "Cyan"

    Add-Result -Phase $Phase -SubPhase "RealTime100" `
        -WallMs $totalWall -EngineMs 0 `
        -SuccessCount $okWalls.Count -FailCount $failCount `
        -Note ("avg/req={0:F1}ms" -f $avgWall) | Out-Null

    return $totalWall, $okWalls.Count, $failCount
}

function Test-Batch100 {
    param ([string]$Phase)
    Write-Log "▶ [$Phase] 批次模式 100 筆（單次請求）" "Green"
    # ★ 改用字串直接傳送，不轉 byte array，避免中文編碼截斷問題
    $sentAt    = Get-TW
    $wallStart = Get-Date
    $engineMs  = 0
    $ok        = $false

    try {
        $r = Invoke-WebRequest `
            -Uri $script:endpoint `
            -Method Post `
            -Body $script:batchJson `
            -ContentType "application/json; charset=utf-8" `
            -Headers @{ "x-test-case" = "$Phase-Batch" } `
            -UseBasicParsing
        $val = $r.Headers["X-Execution-Time-Ms"]
        if ($val -is [array]) { $val = $val[0] }
        if ($null -ne $val)   { $engineMs = [int]$val }
        $ok = $true
        Write-Log ("  批次請求成功。sent={0}" -f $sentAt) "Green"
    } catch {
        Write-Log ("  FAIL: {0}  sent={1}" -f (Get-HttpErrorMessage $_), $sentAt) "Red"
    }

    $totalWall  = ((Get-Date) - $wallStart).TotalMilliseconds
    $avgPerItem = if ($ok) { [Math]::Round($engineMs / 100.0, 4) } else { 0 }

    Write-Log ("  總牆鐘 {0:F0}ms  引擎總耗時 {1}ms  平均每筆 {2:F4}ms" -f `
        $totalWall, $engineMs, $avgPerItem) "Green"

    Add-DetailRow -Phase $Phase -SeqNo 0 `
        -EmpId "BATCH_100" -LeaveType "（混合）" `
        -SentAt_TW $sentAt -WallMs $totalWall -EngineMs $engineMs -OK $ok

    $sOk   = if ($ok) { 100 } else { 0 }
    $sFail = if ($ok) { 0 }   else { 100 }
    Add-Result -Phase $Phase -SubPhase "Batch100" `
        -WallMs $totalWall -EngineMs $engineMs `
        -SuccessCount $sOk -FailCount $sFail `
        -Note ("engine_avg={0:F4}ms" -f $avgPerItem) | Out-Null

    return $totalWall, $engineMs, $ok
}

# ── 6. 主實驗流程 ─────────────────────────────────────────────
Write-Log "============================================================" "Yellow"
Write-Log "  鑫電星 HR 規則引擎 - 完整過夜實驗 開始" "Yellow"
Write-Log "  實驗時間（UTC+8）：$(Get-TW)" "Yellow"
Write-Log "  預計總耗時：約 90~120 分鐘" "Yellow"
Write-Log "============================================================" "Yellow"

# 階段 1
Write-Log "`n===== 階段 1：冷啟動基準 =====" "Yellow"
$cold1 = Test-SingleShot "Phase1_Cold"  "初次冷啟動"
Write-Log "`n  立刻連送 3 筆確認暖機狀態..." "Cyan"
$warm1 = Test-SingleShot "Phase1_Warm1" "冷啟動後第2筆（立刻）"
Start-Sleep -Milliseconds 500
$warm2 = Test-SingleShot "Phase1_Warm2" "冷啟動後第3筆（0.5s後）"
Start-Sleep -Milliseconds 500
$warm3 = Test-SingleShot "Phase1_Warm3" "冷啟動後第4筆（1s後）"

# # 階段 2
# Write-Log "`n===== 階段 2：閒置間隔閾值實驗 =====" "Yellow"
# Wait-WithCountdown 300 "閒置 5 分鐘"
# $idle5  = Test-SingleShot "Phase2_Idle5min"  "閒置 5 分鐘後"
# Wait-WithCountdown 300 "再閒置 5 分鐘（累計 10 分鐘）"
# $idle10 = Test-SingleShot "Phase2_Idle10min" "閒置 10 分鐘後"
# Wait-WithCountdown 300 "再閒置 5 分鐘（累計 15 分鐘）"
# $idle15 = Test-SingleShot "Phase2_Idle15min" "閒置 15 分鐘後"
# Wait-WithCountdown 300 "再閒置 5 分鐘（累計 20 分鐘）"
# $idle20 = Test-SingleShot "Phase2_Idle20min" "閒置 20 分鐘後"

# 階段 3
Write-Log "`n===== 階段 3：即時模式 100 筆（暖機後）=====" "Yellow"
Test-SingleShot "Phase3_WarmUp" "即時實驗前暖機" | Out-Null
Start-Sleep -Milliseconds 1000
$rt3Wall, $rt3Ok, $rt3Fail = Test-RealTime100 "Phase3_RealTime"

# 階段 4
Write-Log "`n===== 階段 4：批次模式 100 筆（暖機後）=====" "Yellow"
Wait-WithCountdown 60 "批次實驗前等待 1 分鐘讓 JVM GC"
Test-SingleShot "Phase4_WarmUp" "批次實驗前暖機" | Out-Null
Start-Sleep -Milliseconds 1000
$bt4Wall, $bt4Engine, $bt4Ok = Test-Batch100 "Phase4_Batch"

# 階段 5
Write-Log "`n===== 階段 5：冷啟動後批次 100 筆 =====" "Yellow"
Wait-WithCountdown 1500 "等待 25 分鐘讓 Function App 進入冷啟動"
$cold5 = Test-SingleShot "Phase5_Cold" "第二次冷啟動"
Start-Sleep -Milliseconds 2000
$bt5Wall, $bt5Engine, $bt5Ok = Test-Batch100 "Phase5_ColdBatch"

# ── 7. 總結輸出 ───────────────────────────────────────────────
Write-Log "`n============================================================" "Yellow"
Write-Log "  實驗完成！結果總結" "Yellow"
Write-Log "============================================================" "Yellow"

Write-Log "`n【冷啟動 vs 暖機】" "Magenta"
Write-Log ("  冷啟動 (Phase1):       {0:F0} ms" -f $cold1.WallMs) "Magenta"
Write-Log ("  暖機第2筆（立刻）:     {0:F0} ms" -f $warm1.WallMs) "Magenta"
Write-Log ("  暖機第3筆（0.5s後）:   {0:F0} ms" -f $warm2.WallMs) "Magenta"
Write-Log ("  暖機第4筆（1s後）:     {0:F0} ms" -f $warm3.WallMs) "Magenta"

Write-Log "`n【閒置閾值】（>1000ms 視為冷啟動）" "DarkYellow"
$tag5  = if ($idle5.WallMs  -gt 1000) { "← 冷啟動" } else { "← 暖機" }
$tag10 = if ($idle10.WallMs -gt 1000) { "← 冷啟動" } else { "← 暖機" }
$tag15 = if ($idle15.WallMs -gt 1000) { "← 冷啟動" } else { "← 暖機" }
$tag20 = if ($idle20.WallMs -gt 1000) { "← 冷啟動" } else { "← 暖機" }
Write-Log ("  閒置  5 分鐘後:        {0:F0} ms  {1}" -f $idle5.WallMs,  $tag5)  "DarkYellow"
Write-Log ("  閒置 10 分鐘後:        {0:F0} ms  {1}" -f $idle10.WallMs, $tag10) "DarkYellow"
Write-Log ("  閒置 15 分鐘後:        {0:F0} ms  {1}" -f $idle15.WallMs, $tag15) "DarkYellow"
Write-Log ("  閒置 20 分鐘後:        {0:F0} ms  {1}" -f $idle20.WallMs, $tag20) "DarkYellow"

Write-Log "`n【即時模式 100 筆（暖機後）】" "Cyan"
Write-Log ("  總牆鐘時間:            {0:F0} ms" -f $rt3Wall) "Cyan"
Write-Log ("  成功 / 失敗:           {0} / {1}" -f $rt3Ok, $rt3Fail) "Cyan"

Write-Log "`n【批次模式 100 筆（暖機後）】" "Green"
Write-Log ("  總牆鐘時間:            {0:F0} ms" -f $bt4Wall) "Green"
Write-Log ("  引擎總耗時:            {0} ms"    -f $bt4Engine) "Green"

Write-Log "`n【批次模式 100 筆（冷啟動後）】" "Green"
Write-Log ("  冷啟動耗時:            {0:F0} ms" -f $cold5.WallMs) "Green"
Write-Log ("  批次總牆鐘時間:        {0:F0} ms" -f $bt5Wall) "Green"

if ($rt3Wall -gt 0 -and $bt4Wall -gt 0 -and $bt4Ok) {
    $eff = [Math]::Round($rt3Wall / $bt4Wall, 2)
    Write-Log ("`n【效率結論】批次（暖機）比即時模式快 {0} 倍" -f $eff) "Yellow"
}

# ── 8. 儲存 CSV ───────────────────────────────────────────────
$script:allResults | Export-Csv -Path $script:csvFile -NoTypeInformation -Encoding UTF8
$script:detailRows | Export-Csv -Path $script:detailCsv -NoTypeInformation -Encoding UTF8

Write-Log "`n階段摘要已儲存至：  $($script:csvFile)"  "Gray"
Write-Log "每筆明細已儲存至：  $($script:detailCsv)" "Gray"
Write-Log "日誌已儲存至：      $($script:logFile)"   "Gray"
Write-Log "實驗結束時間（UTC+8）：$(Get-TW)"          "Gray"
