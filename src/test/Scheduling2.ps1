# ============================================================
# test-scheduling-realtime-only.ps1
# 僅跑 PHASE 1｜100 筆逐筆測試（X-Mode: realtime）
# 無冷卻等待，直接送出
# 所有時間戳記均為 UTC+8
# ============================================================

$apiUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checkscheduling"

# ── UTC+8 時間工具 ────────────────────────────────────────────
function Get-Utc8Time {
    param([string]$fmt = "yyyy-MM-dd HH:mm:ss.fff")
    return [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
        [System.DateTime]::UtcNow, "Taipei Standard Time"
    ).ToString($fmt)
}

$runId   = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
               [System.DateTime]::UtcNow, "Taipei Standard Time"
           ).ToString("yyyyMMdd-HHmmss")

$logFile = "scheduling-realtime-$runId.log"
$csvFile = "scheduling-realtime-$runId.csv"

# ============================================================
# 工具函式：寫 log
# ============================================================
function Write-Log {
    param([string]$msg, [string]$color = "White")
    $line = "[$(Get-Utc8Time)] [UTC+8] $msg"
    Write-Host $line -ForegroundColor $color
    $line | Out-File -FilePath $logFile -Append -Encoding UTF8
}

# ============================================================
# 工具函式：產生員工測試資料（Set A）
# ============================================================
function New-EmployeeData {
    param([int]$i, [string]$set = "A")

    $workTimeTypes = @("GENERAL","TWO_WEEK_FLEXIBLE","FOUR_WEEK_FLEXIBLE","EIGHT_WEEK_FLEXIBLE")

    if ($set -eq "A") {
        return @{
            workTimeType                     = $workTimeTypes[($i - 1) % 4]
            dailyWorkHours                   = 8 + ($i % 5)
            weeklyWorkHours                  = 38 + ($i % 14)
            biweeklyWorkHours                = 72 + ($i % 20)
            fourWeekWorkHours                = 144 + ($i % 30)
            eightWeekWorkHours               = 300 + ($i % 30)
            consecutiveWorkDays              = 4 + ($i % 10)
            restDaysPerWeek                  = $i % 3
            mandatoryDaysOffBiweekly         = $i % 3
            totalDaysOffFourWeeks            = 4 + ($i % 6)
            dailyTotalHours                  = 9 + ($i % 5)
            monthlyOvertimeHours             = ($i * 7) % 61
            quarterlyOvertimeHours           = ($i * 19) % 151
            laborCouncilAgreed               = ($i % 2 -eq 1)
            compensatoryLeaveExpired         = ($i % 11 -eq 0)
            compensatoryLeaveHours           = ($i % 6)
            shiftChangeRestHours             = 6 + ($i % 8)
            continuousWorkHours              = 3 + ($i % 5)
            breakMinutes                     = 10 + ($i % 31)
            mandatoryDayOffPerWeek           = (-not ($i % 7  -eq 0))
            restDayPerWeek                   = (-not ($i % 11 -eq 0))
            mandatoryDayOffScheduledAsWork   = ($i % 17 -eq 0)
            legalExceptionForMandatoryDayOff = ($i % 23 -eq 0)
            nationalHolidayScheduledAsWork   = ($i % 19 -eq 0)
            nationalHolidayAdjustAgreed      = ($i % 29 -eq 0)
            annualLeaveDeniedByEmployer      = ($i % 31 -eq 0)
            annualLeaveAdjustmentAgreed      = ($i % 37 -eq 0)
        }
    } else {
        $j = $i + 100
        return @{
            workTimeType                     = $workTimeTypes[($i - 1) % 4]
            dailyWorkHours                   = 6 + ($j % 3)
            weeklyWorkHours                  = 32 + ($j % 9)
            biweeklyWorkHours                = 60 + ($j % 16)
            fourWeekWorkHours                = 120 + ($j % 25)
            eightWeekWorkHours               = 260 + ($j % 35)
            consecutiveWorkDays              = 2 + ($j % 8)
            restDaysPerWeek                  = 1 + ($j % 2)
            mandatoryDaysOffBiweekly         = 1 + ($j % 2)
            totalDaysOffFourWeeks            = 6 + ($j % 4)
            dailyTotalHours                  = 10 + ($j % 4)
            monthlyOvertimeHours             = 30 + ($j * 3) % 50
            quarterlyOvertimeHours           = 80 + ($j * 5) % 90
            laborCouncilAgreed               = ($j % 3 -eq 0)
            compensatoryLeaveExpired         = ($j % 7 -eq 0)
            compensatoryLeaveHours           = ($j % 8)
            shiftChangeRestHours             = 8 + ($j % 6)
            continuousWorkHours              = 4 + ($j % 4)
            breakMinutes                     = 20 + ($j % 25)
            mandatoryDayOffPerWeek           = (-not ($j % 9  -eq 0))
            restDayPerWeek                   = (-not ($j % 13 -eq 0))
            mandatoryDayOffScheduledAsWork   = ($j % 11 -eq 0)
            legalExceptionForMandatoryDayOff = ($j % 17 -eq 0)
            nationalHolidayScheduledAsWork   = ($j % 13 -eq 0)
            nationalHolidayAdjustAgreed      = ($j % 19 -eq 0)
            annualLeaveDeniedByEmployer      = ($j % 23 -eq 0)
            annualLeaveAdjustmentAgreed      = ($j % 29 -eq 0)
        }
    }
}

# ============================================================
# 工具函式：送出單筆請求
# ============================================================
function Invoke-SchedulingCheck {
    param([int]$seq, [string]$phase, [hashtable]$employee)

    $body      = $employee | ConvertTo-Json -Depth 5
    $execTime  = Get-Utc8Time
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $response = Invoke-RestMethod -Method POST -Uri $apiUrl `
            -ContentType "application/json" `
            -Headers @{ "X-Mode" = "realtime" } `
            -Body $body
        $stopwatch.Stop()

        return @{
            Seq              = $seq
            Phase            = $phase
            ExecTime         = $execTime
            EmployeeId       = "EMP-{0:D3}" -f $seq
            WorkType         = $employee.workTimeType
            DailyHours       = $employee.dailyWorkHours
            WeeklyHours      = $employee.weeklyWorkHours
            ConsecDays       = $employee.consecutiveWorkDays
            MonthlyOT        = $employee.monthlyOvertimeHours
            Violated         = $response.violated
            ViolatedRules    = $response.violatedRules
            ViolatedMessages = $response.violatedMessages
            Warnings         = $response.warnings
            Notes            = $response.notes
            ElapsedMs        = $stopwatch.ElapsedMilliseconds
            IsError          = $false
        }
    } catch {
        $stopwatch.Stop()
        return @{
            Seq              = $seq
            Phase            = $phase
            ExecTime         = $execTime
            EmployeeId       = "EMP-{0:D3}" -f $seq
            WorkType         = $employee.workTimeType
            DailyHours       = $employee.dailyWorkHours
            WeeklyHours      = $employee.weeklyWorkHours
            ConsecDays       = $employee.consecutiveWorkDays
            MonthlyOT        = $employee.monthlyOvertimeHours
            Violated         = $false
            ViolatedRules    = @("ERROR")
            ViolatedMessages = @($_.Exception.Message)
            Warnings         = @()
            Notes            = @()
            ElapsedMs        = $stopwatch.ElapsedMilliseconds
            IsError          = $true
        }
    }
}

# ============================================================
# 工具函式：將結果寫入 log + csv
# ============================================================
function Write-Result {
    param([hashtable]$r)

    if ($r.IsError) {
        $color = "Magenta"; $status = "ERROR"
    } elseif ($r.Violated) {
        $color = "Red";     $status = "違規"
    } else {
        $color = "Green";   $status = "合規"
    }

    $ruleCount = if ($r.ViolatedRules) { $r.ViolatedRules.Count } else { 0 }

    $screenLine = "[{0}][UTC+8][{1}][#{2:D3}] {3} | {4,-22} | 日{5}H 週{6}H 連{7}天 MonthOT:{8}H | [{9}] 違規:{10}條 | {11}ms" -f `
        $r.ExecTime, $r.Phase, $r.Seq, $r.EmployeeId, $r.WorkType, `
        $r.DailyHours, $r.WeeklyHours, $r.ConsecDays, $r.MonthlyOT, `
        $status, $ruleCount, $r.ElapsedMs

    Write-Host $screenLine -ForegroundColor $color
    $screenLine | Out-File -FilePath $logFile -Append -Encoding UTF8

    if ($ruleCount -gt 0) {
        for ($idx = 0; $idx -lt $ruleCount; $idx++) {
            $ruleLine = "         └ 違規[{0}] {1}" -f ($idx + 1), $r.ViolatedRules[$idx]
            $ruleLine | Out-File -FilePath $logFile -Append -Encoding UTF8
        }
    }

    if ($r.Warnings -and $r.Warnings.Count -gt 0) {
        "         └ 警告：$($r.Warnings -join ' / ')" | Out-File -FilePath $logFile -Append -Encoding UTF8
    }
    "         └ 耗時：$($r.ElapsedMs)ms" | Out-File -FilePath $logFile -Append -Encoding UTF8

    $rulesJoined = if ($r.ViolatedRules) { ($r.ViolatedRules -join " | ") -replace ",","，" } else { "" }
    $msgsJoined  = if ($r.ViolatedMessages) { ($r.ViolatedMessages -join " | ") -replace ",","，" } else { "" }

    "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9},{10},{11},{12},{13}" -f `
        $r.Phase, $r.Seq, $r.ExecTime, $r.EmployeeId, $r.WorkType, `
        $r.DailyHours, $r.WeeklyHours, $r.ConsecDays, $r.MonthlyOT, `
        $r.Violated, $ruleCount, $rulesJoined, $msgsJoined, $r.ElapsedMs `
        | Out-File -FilePath $csvFile -Append -Encoding UTF8
}

# ============================================================
# 初始化 Log / CSV
# ============================================================
$initTime = Get-Utc8Time
@"
============================================================
排班合規測試（僅 PHASE 1） | RunID：$runId
開始時間：$initTime (UTC+8)
流程：PHASE 1 逐筆 100 筆（無冷卻，Function 已暖機）
API：$apiUrl
============================================================
"@ | Out-File -FilePath $logFile -Encoding UTF8

"階段,序號,送出時間(UTC+8),員工ID,工時制度,每日工時,每週工時,連續天數,月加班時數,violated,違規條數,violatedRules,violatedMessages,耗時ms" `
    | Out-File -FilePath $csvFile -Encoding UTF8

Write-Host "============================================================" -ForegroundColor White
Write-Host "  排班合規測試（僅 PHASE 1）| RunID：$runId" -ForegroundColor White
Write-Host "  開始時間：$initTime (UTC+8)" -ForegroundColor White
Write-Host "  Log：$logFile" -ForegroundColor White
Write-Host "  CSV：$csvFile" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# ============================================================
# PHASE 1｜100 筆逐筆測試（Set A，一次一筆，X-Mode: realtime）
# ============================================================
$p1StartTime = Get-Utc8Time
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  PHASE 1｜100 筆逐筆測試（X-Mode: realtime）" -ForegroundColor Cyan
Write-Host "  送出時間：$p1StartTime (UTC+8)" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Log "PHASE 1 開始 | 送出時間：$p1StartTime (UTC+8)" "Cyan"
"[PHASE 1 - 100 筆逐筆測試 | Set A | X-Mode: realtime | 開始：$p1StartTime UTC+8]" | Out-File -FilePath $logFile -Append -Encoding UTF8

$p1Violated = 0; $p1Compliant = 0; $p1Error = 0; $p1TotalMs = 0
$p1Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

for ($i = 1; $i -le 100; $i++) {
    $emp = New-EmployeeData -i $i -set "A"
    $r   = Invoke-SchedulingCheck -seq $i -phase "PHASE1" -employee $emp
    Write-Result $r

    $p1TotalMs += $r.ElapsedMs
    if     ($r.IsError)  { $p1Error++ }
    elseif ($r.Violated) { $p1Violated++ }
    else                 { $p1Compliant++ }

    Write-Progress `
        -Activity "PHASE 1｜逐筆測試（Set A）" `
        -Status   "進度：$i/100 | 違規：$p1Violated | 合規：$p1Compliant | 錯誤：$p1Error | $(Get-Utc8Time 'HH:mm:ss') UTC+8" `
        -PercentComplete $i
}

$p1Stopwatch.Stop()
Write-Progress -Activity "PHASE 1｜逐筆測試（Set A）" -Completed
$p1EndTime    = Get-Utc8Time
$p1AvgPerItem = [math]::Round($p1TotalMs / 100, 1)

Write-Log "PHASE 1 完成 | 結束：$p1EndTime (UTC+8) | 違規:$p1Violated | 合規:$p1Compliant | 錯誤:$p1Error | 總耗時:$($p1Stopwatch.ElapsedMilliseconds)ms | 平均:${p1AvgPerItem}ms" "Cyan"
Write-Host ""

# ============================================================
# 最終統計摘要
# ============================================================
$endTime = Get-Utc8Time

$summary = @"

============================================================
  測試完成總摘要 | RunID：$runId
============================================================
  開始時間    : $initTime (UTC+8)
  結束時間    : $endTime (UTC+8)

  [PHASE 1] 100 筆逐筆測試（Set A，X-Mode: realtime）
    送出開始    : $p1StartTime (UTC+8)
    送出結束    : $p1EndTime (UTC+8)
    違規筆數    : $p1Violated / 100
    合規筆數    : $p1Compliant / 100
    錯誤筆數    : $p1Error / 100
    總耗時      : $($p1Stopwatch.ElapsedMilliseconds) ms（含 100 次 HTTP 往返）
    平均每筆    : ${p1AvgPerItem} ms

  輸出檔案
    Log  : $logFile
    CSV  : $csvFile
============================================================
"@

Write-Host $summary -ForegroundColor Cyan
$summary | Out-File -FilePath $logFile -Append -Encoding UTF8
