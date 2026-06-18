chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$url = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checktime"

Write-Host "`n[TARGET] $url`n" -ForegroundColor Magenta

# =================================================================
# 工具函式
# =================================================================
function Invoke-TimeCheck {
    param(
        [string]   $TestName,
        [string]   $Expect,
        [object[]] $Bodies
    )

    $safeBodies = $Bodies | ForEach-Object {
        $item = $_
        $item.leaveApplications    = [object[]]@($item.leaveApplications    | Where-Object { $_ -ne $null })
        $item.overtimeApplications = [object[]]@($item.overtimeApplications | Where-Object { $_ -ne $null })
        $item
    }

    $json = $safeBodies | ConvertTo-Json -Depth 6 -Compress
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $resList = Invoke-RestMethod -Uri $url -Method Post `
                   -Body $json `
                   -ContentType "application/json; charset=utf-8" `
                   -ErrorAction Stop `
                   -TimeoutSec 120

        $sw.Stop()
        $ms      = [math]::Round($sw.Elapsed.TotalMilliseconds)
        $perItem = if ($Bodies.Count -gt 0) { [math]::Round($ms / $Bodies.Count, 2) } else { 0 }

        Write-Host ("+-- [PASS] {0}" -f $TestName) -ForegroundColor Green
        Write-Host ("    總耗時   : {0} ms" -f $ms)                                          -ForegroundColor Cyan
        Write-Host ("    每筆平均 : {0} ms／筆" -f $perItem)                                 -ForegroundColor Cyan
        Write-Host ("    送出     : {0} 筆  收到 : {1} 筆" -f $Bodies.Count, $resList.Count) -ForegroundColor White
        Write-Host ("    expect   : {0}" -f $Expect)                                         -ForegroundColor DarkGray

        return @{ Result = $resList; Ms = $ms; PerItem = $perItem }

    } catch {
        $sw.Stop()
        $ms = [math]::Round($sw.Elapsed.TotalMilliseconds)
        Write-Host ("+-- [FAIL] {0}  ({1} ms)" -f $TestName, $ms) -ForegroundColor Red
        Write-Host ("    error : {0}" -f $_.Exception.Message) -ForegroundColor Red

        if ($_.Exception.Response) {
            try {
                $stream = $_.Exception.Response.GetResponseStream()
                $reader = New-Object System.IO.StreamReader($stream)
                Write-Host ("    body  : {0}" -f $reader.ReadToEnd()) -ForegroundColor DarkRed
            } catch {}
        }
        return $null
    }
}

function Show-Result($res) {
    Write-Host ("    ---- {0}  {1} ----" -f $res.employeeCode, $res.scheduleDate) -ForegroundColor DarkCyan
    Write-Host ("      status            : {0}" -f $res.status)           -ForegroundColor Yellow
    Write-Host ("      totalWorkH        : {0}  |  overtimeH : {1}" -f $res.totalWorkHours, $res.overtimeHours) -ForegroundColor White
    $lateColor  = if ($res.lateMinutes         -gt 0) { "Red" } else { "Green" }
    $earlyColor = if ($res.earlyLeaveMinutes   -gt 0) { "Red" } else { "Green" }
    $earrColor  = if ($res.earlyArrivalMinutes -gt 0) { "Yellow" } else { "Green" }
    Write-Host ("      lateMin           : {0}" -f $res.lateMinutes)           -ForegroundColor $lateColor
    Write-Host ("      earlyLeaveMin     : {0}" -f $res.earlyLeaveMinutes)     -ForegroundColor $earlyColor
    Write-Host ("      earlyArrivalMin   : {0}" -f $res.earlyArrivalMinutes)   -ForegroundColor $earrColor
    Write-Host ("      effectiveIn       : {0}" -f $res.effectiveClockIn)      -ForegroundColor Cyan
    Write-Host ("      effectiveOut      : {0}" -f $res.effectiveClockOut)     -ForegroundColor Cyan
    if ($res.violations -and $res.violations.Count -gt 0) {
        Write-Host "      violations:" -ForegroundColor Red
        $res.violations | ForEach-Object { Write-Host "        - $_" -ForegroundColor Red }
    }
    if ($res.notes -and $res.notes.Count -gt 0) {
        Write-Host "      notes:" -ForegroundColor Gray
        $res.notes | ForEach-Object { Write-Host "        - $_" -ForegroundColor Gray }
    }
}

$pass = 0
$fail = 0
$perfLog = New-Object System.Collections.ArrayList

# =================================================================
# SECTION 1：功能驗證（3筆，原有，不動）
# =================================================================
Write-Host "=== SECTION 1：功能驗證（3筆）===" -ForegroundColor Magenta

$functionalCases = @(
    @{
        employeeCode         = "EMP010"
        scheduleStartTime    = "2026-05-12T09:00:00"
        scheduleEndTime      = "2026-05-12T18:00:00"
        clockInTime          = "2026-05-12T10:55:00"
        clockOutTime         = "2026-05-12T18:00:00"
        toleranceMinutes     = 5
        leaveApplications    = [object[]]@(
            @{ leaveStart="2026-05-12T10:00:00"; leaveEnd="2026-05-12T11:00:00"; leaveType="事假"; paid=$false }
        )
        overtimeApplications = [object[]]@()
    },
    @{
        employeeCode         = "EMP011"
        scheduleStartTime    = "2026-05-12T09:00:00"
        scheduleEndTime      = "2026-05-12T18:00:00"
        clockInTime          = "2026-05-12T10:55:00"
        clockOutTime         = "2026-05-12T18:00:00"
        toleranceMinutes     = 5
        leaveApplications    = [object[]]@(
            @{ leaveStart="2026-05-12T09:00:00"; leaveEnd="2026-05-12T11:00:00"; leaveType="事假"; paid=$false }
        )
        overtimeApplications = [object[]]@()
    },
    @{
        employeeCode         = "EMP012"
        scheduleStartTime    = "2026-05-12T09:00:00"
        scheduleEndTime      = "2026-05-12T18:00:00"
        clockInTime          = "2026-05-12T11:30:00"
        clockOutTime         = "2026-05-12T18:00:00"
        toleranceMinutes     = 5
        leaveApplications    = [object[]]@(
            @{ leaveStart="2026-05-12T10:00:00"; leaveEnd="2026-05-12T11:00:00"; leaveType="事假"; paid=$false }
        )
        overtimeApplications = [object[]]@()
    }
)

$s1Ret = Invoke-TimeCheck `
    -TestName "TEST-A/B/C 三筆功能驗證" `
    -Expect   "EMP010=LATE/60分 | EMP011=NORMAL/0分 | EMP012=LATE/60分+請假1H" `
    -Bodies   $functionalCases

if ($null -ne $s1Ret) {
    $pass++
    [void]$perfLog.Add([PSCustomObject]@{ 測試名稱="功能驗證3筆"; 筆數=3; 總耗時_ms=$s1Ret.Ms; 每筆平均_ms=$s1Ret.PerItem })
    foreach ($res in $s1Ret.Result) { Show-Result $res }
} else { $fail++ }

Write-Host ""

# =================================================================
# SECTION 2：批次壓力測試（原有，不動）
# =================================================================
Write-Host "=== SECTION 2：批次壓力測試（10人 × 5月工作日，20種情境輪替）===" -ForegroundColor Magenta

$employees = @("EMP001","EMP002","EMP003","EMP004","EMP005",
               "EMP006","EMP007","EMP008","EMP009","EMP010")

$workDays = @()
$d = [datetime]"2026-05-01"
while ($d.Month -eq 5) {
    if ($d.DayOfWeek -ne "Saturday" -and $d.DayOfWeek -ne "Sunday") { $workDays += $d }
    $d = $d.AddDays(1)
}
Write-Host ("    2026-05 工作日：{0} 天" -f $workDays.Count) -ForegroundColor DarkGray

$scenarios    = 0..19
$batchBodies  = New-Object System.Collections.ArrayList

foreach ($emp in $employees) {
    $empNum      = [int]($emp -replace "EMP","")
    $scenarioIdx = ($empNum - 1) % $scenarios.Count
    $dayIndex    = 0

    foreach ($day in $workDays) {
        $dateStr  = $day.ToString("yyyy-MM-dd")
        $scenario = $scenarios[($scenarioIdx + $dayIndex) % $scenarios.Count]
        $dayIndex++

        $clockIn=$null; $clockOut=$null; $punchCorrIn=$null; $punchCorrOut=$null
        $leaveList = New-Object System.Collections.ArrayList
        $otList    = New-Object System.Collections.ArrayList
        $lunchOut=$null; $lunchIn=$null

        switch ($scenario) {
            0  { $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T18:00:00" }
            1  { $clockIn="${dateStr}T09:30:00"; $clockOut="${dateStr}T18:00:00" }
            2  { $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T17:15:00" }
            3  { $clockIn="${dateStr}T09:20:00"; $clockOut="${dateStr}T17:30:00" }
            4  {
                $clockIn="${dateStr}T10:58:00"; $clockOut="${dateStr}T18:00:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T09:00:00"; leaveEnd="${dateStr}T11:00:00"; leaveType="病假"; paid=$true })
            }
            5  {
                $clockIn="${dateStr}T12:00:00"; $clockOut="${dateStr}T18:00:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T09:00:00"; leaveEnd="${dateStr}T11:00:00"; leaveType="事假"; paid=$false })
            }
            6  {
                $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T17:02:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T17:00:00"; leaveEnd="${dateStr}T18:00:00"; leaveType="特休"; paid=$true })
            }
            7  {
                $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T19:00:00"
                [void]$otList.Add(@{ overtimeStart="${dateStr}T18:00:00"; overtimeEnd="${dateStr}T19:00:00"; overtimeType="WEEKDAY" })
            }
            8  {
                $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T20:00:00"
                [void]$otList.Add(@{ overtimeStart="${dateStr}T18:00:00"; overtimeEnd="${dateStr}T20:00:00"; overtimeType="WEEKDAY" })
            }
            9  { $clockIn=$null; $clockOut=$null }
            10 {
                $clockIn="${dateStr}T09:30:00"; $clockOut="${dateStr}T18:30:00"
                [void]$otList.Add(@{ overtimeStart="${dateStr}T18:00:00"; overtimeEnd="${dateStr}T18:30:00"; overtimeType="WEEKDAY" })
            }
            11 { $punchCorrIn="${dateStr}T09:05:00"; $punchCorrOut="${dateStr}T18:00:00" }
            12 { $clockIn="${dateStr}T09:05:00"; $clockOut="${dateStr}T18:00:00" }
            13 { $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T17:55:00" }
            14 {
                $clockIn="${dateStr}T13:00:00"; $clockOut="${dateStr}T18:00:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T09:00:00"; leaveEnd="${dateStr}T13:00:00"; leaveType="事假"; paid=$false })
            }
            15 {
                $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T13:00:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T13:00:00"; leaveEnd="${dateStr}T18:00:00"; leaveType="事假"; paid=$false })
            }
            16 { $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T18:00:00"; $lunchOut="${dateStr}T12:00:00"; $lunchIn="${dateStr}T13:00:00" }
            17 {
                $clockIn="${dateStr}T10:00:00"; $clockOut="${dateStr}T18:00:00"
                [void]$leaveList.Add(@{ leaveStart="${dateStr}T09:00:00"; leaveEnd="${dateStr}T09:30:00"; leaveType="病假"; paid=$true })
            }
            18 {
                $clockIn="${dateStr}T09:00:00"; $clockOut="${dateStr}T21:00:00"
                [void]$otList.Add(@{ overtimeStart="${dateStr}T18:00:00"; overtimeEnd="${dateStr}T21:00:00"; overtimeType="HOLIDAY" })
            }
            19 {
                $clockIn="${dateStr}T09:15:00"; $clockOut="${dateStr}T19:00:00"
                [void]$otList.Add(@{ overtimeStart="${dateStr}T18:00:00"; overtimeEnd="${dateStr}T19:00:00"; overtimeType="WEEKDAY" })
            }
        }

        $fact = @{
            employeeCode         = $emp
            scheduleStartTime    = "${dateStr}T09:00:00"
            scheduleEndTime      = "${dateStr}T18:00:00"
            toleranceMinutes     = 5
            leaveApplications    = $leaveList
            overtimeApplications = $otList
        }
        if ($null -ne $clockIn)      { $fact["clockInTime"]        = $clockIn }
        if ($null -ne $clockOut)     { $fact["clockOutTime"]       = $clockOut }
        if ($null -ne $punchCorrIn)  { $fact["punchCorrectionIn"]  = $punchCorrIn }
        if ($null -ne $punchCorrOut) { $fact["punchCorrectionOut"] = $punchCorrOut }
        if ($null -ne $lunchOut)     { $fact["lunchOutTime"]       = $lunchOut }
        if ($null -ne $lunchIn)      { $fact["lunchInTime"]        = $lunchIn }

        [void]$batchBodies.Add($fact)
    }
}

Write-Host ("    產生測試資料：{0} 筆，準備送出..." -f $batchBodies.Count) -ForegroundColor DarkGray

$s2Ret = Invoke-TimeCheck `
    -TestName ("批次 {0} 筆（10人×{1}天，20種情境輪替）" -f $batchBodies.Count, $workDays.Count) `
    -Expect   "正常/遲到/早退/請假/曠職/補卡/加班/午休/容錯邊界 全覆蓋" `
    -Bodies   $batchBodies

if ($null -ne $s2Ret) {
    $pass++
    $s2Result = $s2Ret.Result
    [void]$perfLog.Add([PSCustomObject]@{
        測試名稱    = ("批次{0}筆" -f $batchBodies.Count)
        筆數        = $batchBodies.Count
        總耗時_ms   = $s2Ret.Ms
        每筆平均_ms = $s2Ret.PerItem
    })

    $totalLate      = ($s2Result | Where-Object { $_.lateMinutes       -gt 0 }).Count
    $totalEarly     = ($s2Result | Where-Object { $_.earlyLeaveMinutes -gt 0 }).Count
    $totalOvertime  = ($s2Result | Where-Object { $_.overtimeHours     -gt 0 }).Count
    $totalNormal    = ($s2Result | Where-Object { $_.status -eq "NORMAL" }).Count
    $totalAbsent    = ($s2Result | Where-Object { $_.totalWorkHours    -eq 0 }).Count
    $totalWorkHours = ($s2Result | Measure-Object -Property totalWorkHours -Sum).Sum

    Write-Host ""
    Write-Host "    [批次統計摘要]" -ForegroundColor Magenta
    Write-Host ("      送出筆數     : {0}" -f $batchBodies.Count)                     -ForegroundColor White
    Write-Host ("      收到筆數     : {0}" -f $s2Result.Count)                        -ForegroundColor White
    Write-Host ("      正常出勤     : {0}" -f $totalNormal)                           -ForegroundColor Green
    Write-Host ("      遲到筆數     : {0}" -f $totalLate)                             -ForegroundColor Red
    Write-Host ("      早退筆數     : {0}" -f $totalEarly)                            -ForegroundColor Red
    Write-Host ("      有加班筆數   : {0}" -f $totalOvertime)                         -ForegroundColor Yellow
    Write-Host ("      工時為0筆數  : {0}（曠職/無打卡）" -f $totalAbsent)            -ForegroundColor DarkYellow
    Write-Host ("      總工時合計   : {0} 小時" -f [math]::Round($totalWorkHours, 2)) -ForegroundColor Cyan

    Write-Host ""
    Write-Host "    [各員工月工時]" -ForegroundColor Magenta
    foreach ($emp in $employees) {
        $empRows  = $s2Result | Where-Object { $_.employeeCode -eq $emp }
        $empHours = ($empRows | Measure-Object -Property totalWorkHours -Sum).Sum
        $empOT    = ($empRows | Measure-Object -Property overtimeHours  -Sum).Sum
        $empLate  = ($empRows | Where-Object { $_.lateMinutes       -gt 0 }).Count
        $empEarly = ($empRows | Where-Object { $_.earlyLeaveMinutes -gt 0 }).Count
        $empAbs   = ($empRows | Where-Object { $_.totalWorkHours    -eq 0 }).Count
        Write-Host ("      {0}  工時:{1}H  加班:{2}H  遲到:{3}天  早退:{4}天  曠職:{5}天" -f `
            $emp, [math]::Round($empHours,2), [math]::Round($empOT,2),
            $empLate, $empEarly, $empAbs) -ForegroundColor White
    }

    $csvPath = Join-Path $PSScriptRoot "TimeCheck_Detail_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $csvRows = $s2Result | ForEach-Object {
        $res = $_
        $ds = if ($res.scheduleDate) { try { ([datetime]$res.scheduleDate).ToString("yyyy-MM-dd") } catch { $res.scheduleDate } } else { "" }
        [PSCustomObject]@{
            員工代號     = $res.employeeCode;  日期         = $ds
            狀態         = $res.status;        有效上班時間 = $res.effectiveClockIn
            有效下班時間 = $res.effectiveClockOut
            實際工時_H   = [math]::Round($res.totalWorkHours, 2)
            加班時數_H   = [math]::Round($res.overtimeHours,  2)
            遲到分鐘     = $res.lateMinutes;   早退分鐘     = $res.earlyLeaveMinutes
            早到分鐘     = $res.earlyArrivalMinutes          # ✅ 新增欄位
            午休分鐘     = $res.lunchBreakMinutes
            違規事項     = ($res.violations -join " | ");    備註 = ($res.notes -join " | ")
        }
    }
    $csvRows = $csvRows | Sort-Object 員工代號, 日期
    $csvRows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-Host ""
    Write-Host ("    [CSV 輸出]  {0}" -f $csvPath) -ForegroundColor Green
    Write-Host ("    共 {0} 筆明細" -f $csvRows.Count) -ForegroundColor Green

} else { $fail++ }

Write-Host ""

# =================================================================
# ✅ SECTION 3：新功能驗證（早到 + 月累計遲到豁免）
# =================================================================
Write-Host "=== SECTION 3：新功能驗證（早到判斷 + 月累計遲到豁免）===" -ForegroundColor Magenta

$section3Cases = @(

    # ── 早到測試 ──────────────────────────────────────────────

    @{
        # T1：08:20 打卡，容許提早 30 分（08:30 才算最早準時）
        # 08:20 < 08:30 → 早到 40 分 → EARLY_ARRIVAL
        employeeCode                  = "T1_早到40分"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T08:20:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 30
        allowedMonthlyLateMinutes     = 0
        monthlyAccumulatedLateMinutes = 0
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T2：08:35 打卡，容許提早 30 分（08:30 才算最早準時）
        # 08:35 在 08:30~09:00 之間 → 準時 → NORMAL
        employeeCode                  = "T2_早到但在容許區間"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T08:35:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 30
        allowedMonthlyLateMinutes     = 0
        monthlyAccumulatedLateMinutes = 0
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T3：earlyArrivalToleranceMinutes = 0（功能關閉）
        # 08:00 打卡 → 不啟用早到判斷 → NORMAL（有效上班仍為打卡時間）
        employeeCode                  = "T3_早到功能關閉"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T08:00:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 0
        allowedMonthlyLateMinutes     = 0
        monthlyAccumulatedLateMinutes = 0
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    # ── 月累計遲到豁免測試 ────────────────────────────────────

    @{
        # T4：遲到 20 分，累計已用 30 分，上限 60 分
        # 30 + 20 = 50 <= 60 → 豁免 → NORMAL
        employeeCode                  = "T4_月累計豁免通過"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T09:20:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 0
        allowedMonthlyLateMinutes     = 60
        monthlyAccumulatedLateMinutes = 30
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T5：遲到 20 分，累計已用 50 分，上限 60 分
        # 50 + 20 = 70 > 60 → 不豁免 → LATE
        employeeCode                  = "T5_月累計超限不豁免"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T09:20:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 0
        allowedMonthlyLateMinutes     = 60
        monthlyAccumulatedLateMinutes = 50
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T6：allowedMonthlyLateMinutes = 0（功能關閉）
        # 遲到 15 分 → 不啟用豁免 → LATE
        employeeCode                  = "T6_月累計功能關閉"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T09:15:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 0
        allowedMonthlyLateMinutes     = 0
        monthlyAccumulatedLateMinutes = 0
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T7：遲到 60 分，累計已用 0 分，上限 60 分
        # 0 + 60 = 60 <= 60 → 剛好用完，豁免 → NORMAL
        employeeCode                  = "T7_月累計剛好用完"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T10:00:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 0
        allowedMonthlyLateMinutes     = 60
        monthlyAccumulatedLateMinutes = 0
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    },

    @{
        # T8：早到 + 月累計豁免同時啟用
        # 08:20 打卡（早到40分）+ 遲到功能不觸發 → EARLY_ARRIVAL
        employeeCode                  = "T8_早到且豁免同時啟用"
        scheduleStartTime             = "2026-05-12T09:00:00"
        scheduleEndTime               = "2026-05-12T18:00:00"
        clockInTime                   = "2026-05-12T08:20:00"
        clockOutTime                  = "2026-05-12T18:00:00"
        toleranceMinutes              = 5
        earlyArrivalToleranceMinutes  = 30
        allowedMonthlyLateMinutes     = 60
        monthlyAccumulatedLateMinutes = 10
        leaveApplications             = [object[]]@()
        overtimeApplications          = [object[]]@()
    }
)

$s3Ret = Invoke-TimeCheck `
    -TestName "SECTION 3：早到 + 月累計豁免（8筆）" `
    -Expect   "T1=EARLY_ARRIVAL | T2=NORMAL | T3=NORMAL | T4=NORMAL(豁免) | T5=LATE | T6=LATE | T7=NORMAL(豁免) | T8=EARLY_ARRIVAL" `
    -Bodies   $section3Cases

if ($null -ne $s3Ret) {
    $pass++
    [void]$perfLog.Add([PSCustomObject]@{
        測試名稱    = "新功能驗證8筆"
        筆數        = 8
        總耗時_ms   = $s3Ret.Ms
        每筆平均_ms = $s3Ret.PerItem
    })

    Write-Host ""
    Write-Host "    [逐筆結果]" -ForegroundColor Magenta

    # 預期對照表
    $expects = @{
        "T1_早到40分"           = @{ status="EARLY_ARRIVAL"; earlyArrivalMin=40 }
        "T2_早到但在容許區間"   = @{ status="NORMAL";        earlyArrivalMin=0  }
        "T3_早到功能關閉"       = @{ status="NORMAL";        earlyArrivalMin=0  }
        "T4_月累計豁免通過"     = @{ status="NORMAL";        lateMin=0          }
        "T5_月累計超限不豁免"   = @{ status="LATE";          lateMin=15         }
        "T6_月累計功能關閉"     = @{ status="LATE";          lateMin=10         }
        "T7_月累計剛好用完"     = @{ status="NORMAL";        lateMin=0          }
        "T8_早到且豁免同時啟用" = @{ status="EARLY_ARRIVAL"; earlyArrivalMin=40 }
    }

    foreach ($res in $s3Ret.Result) {
        Show-Result $res

        # 自動驗證
# 找到這段（約第 508~512 行）並替換
$exp = $expects[$res.employeeCode]
if ($null -ne $exp) {
    $statusOk    = ($res.status -eq $exp.status)
    $icon        = if ($statusOk) { "✅" } else { "❌" }
    $verifyColor = if ($statusOk) { "Green" } else { "Red" }   # ✅ 先算好顏色
    Write-Host ("      {0} 預期 status={1}  實際 status={2}" -f `
        $icon, $exp.status, $res.status) `
        -ForegroundColor $verifyColor                           # ✅ 再傳入變數
}

        Write-Host ""
    }

} else { $fail++ }

Write-Host ""

# =================================================================
# 效能總表
# =================================================================
Write-Host "=== 效能統計 ===" -ForegroundColor Magenta
Write-Host ("{0,-30} {1,8} {2,12} {3,12}" -f "測試名稱","筆數","總耗時(ms)","每筆平均(ms)") -ForegroundColor DarkCyan
Write-Host ("-" * 66) -ForegroundColor DarkGray
foreach ($p in $perfLog) {
    Write-Host ("{0,-30} {1,8} {2,12} {3,12}" -f `
        $p.測試名稱, $p.筆數, $p.總耗時_ms, $p.每筆平均_ms) -ForegroundColor White
}
Write-Host ("-" * 66) -ForegroundColor DarkGray

Write-Host ""

# =================================================================
# 總結
# =================================================================
Write-Host "=================================================================" -ForegroundColor DarkGray
$color = if ($fail -eq 0) { "Green" } else { "Red" }
Write-Host ("  PASS {0}  /  FAIL {1}  /  TOTAL {2}" -f $pass, $fail, ($pass + $fail)) -ForegroundColor $color
Write-Host "=================================================================" -ForegroundColor DarkGray
