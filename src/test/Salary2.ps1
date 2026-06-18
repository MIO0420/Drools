# =================================================================
# 鑫電星 HR 規則引擎 - 單筆 vs 批次薪資計算效能比較實驗
# 目標：比較單筆循序送出 vs 10筆並行送出的處理時間差異
# 每位員工資料不同，觸發不同規則路徑，並印出觸發規則明細
# =================================================================

# ===== 設定區 =====
$endpoint  = "http://localhost:7071/api/calculatesalary"
$outputDir = "C:\Users\PT\Desktop\code\Graduate\src\test"

# ===== 時間工具：台灣時間（UTC+8）=====
$twZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Taipei Standard Time")
function Get-TW {
    [System.TimeZoneInfo]::ConvertTimeFromUtc(
        (Get-Date).ToUniversalTime(), $twZone
    ).ToString("yyyy-MM-dd HH:mm:ss")
}

# ===== 日誌工具 =====
function Write-Log {
    param([string]$msg, [string]$color = "White")
    $line = "[$(Get-TW)] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $logFile -Value $line
}

# ===== 檔案初始化 =====
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile   = Join-Path $outputDir "SalaryBatch_Log_$timestamp.txt"
$csvFile   = Join-Path $outputDir "SalaryBatch_Result_$timestamp.csv"

# CSV 標頭
# Mode        = Sequential（單筆）或 Parallel（批次）
# EmployeeId  = 員工代碼
# WallMs      = 客戶端感知耗時
# EngineMs    = 伺服器端規則引擎耗時（X-Execution-Time-Ms）
# RulesHit    = 觸發的規則清單（從回應 Body 的 ruleDetails 欄位取得）
# FinalSalary = 計算結果薪資
"Mode,EmployeeId,WallMs,EngineMs,FinalSalary,RulesHit" |
    Out-File -FilePath $csvFile -Encoding UTF8


# ===== 10 位員工測試資料 =====
# 每位員工底薪、假別、加班均不同，確保觸發不同規則路徑
$employees = @(

    # E001：事假 8H，無加班 -> 觸發 Leave Deduction - 事假
    @{
        employeeId           = "E001"
        baseSalary           = 36000.0
        tenureMonths         = 12
        workingDaysInMonth   = 22
        laborInsuredSalary   = 36000
        healthInsuredSalary  = 36000
        pensionSalary        = 36000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "事假"; leaveHours = 8.0; leaveDays = 1.0;
               deductionRate = 1.0; affectFullAttendance = $true }
        )
        overtimes = @()
    },

    # E002：普通病假 4H + 平日加班 2H -> 觸發病假規則 + Weekday OT 0~2H
    @{
        employeeId           = "E002"
        baseSalary           = 40000.0
        tenureMonths         = 24
        workingDaysInMonth   = 22
        laborInsuredSalary   = 40000
        healthInsuredSalary  = 40000
        pensionSalary        = 40000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "普通病假"; leaveHours = 4.0; leaveDays = 0.5;
               deductionRate = 0.5; affectFullAttendance = $true }
        )
        overtimes = @(
            @{ overtimeType = "WEEKDAY"; overtimeHours = 2.0 }
        )
    },

    # E003：婚假 3天，無加班 -> 觸發 Marriage Leave - Approved
    @{
        employeeId           = "E003"
        baseSalary           = 45000.0
        tenureMonths         = 36
        workingDaysInMonth   = 22
        laborInsuredSalary   = 45000
        healthInsuredSalary  = 45000
        pensionSalary        = 45000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "婚假"; leaveHours = 24.0; leaveDays = 3.0;
               deductionRate = 0.0; affectFullAttendance = $false }
        )
        overtimes = @()
    },

    # E004：曠職 8H，無加班 -> 觸發 Leave Deduction - 曠職
    @{
        employeeId           = "E004"
        baseSalary           = 38000.0
        tenureMonths         = 6
        workingDaysInMonth   = 22
        laborInsuredSalary   = 38000
        healthInsuredSalary  = 38000
        pensionSalary        = 38000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "曠職"; leaveHours = 8.0; leaveDays = 1.0;
               deductionRate = 1.0; affectFullAttendance = $true }
        )
        overtimes = @()
    },

    # E005：無請假，平日加班 4H -> 觸發 Weekday OT >2H（分段計算 x1.34 + x1.67）
    @{
        employeeId           = "E005"
        baseSalary           = 50000.0
        tenureMonths         = 48
        workingDaysInMonth   = 22
        laborInsuredSalary   = 50000
        healthInsuredSalary  = 50000
        pensionSalary        = 50000
        voluntaryPensionRate = 0.06
        leaves    = @()
        overtimes = @(
            @{ overtimeType = "WEEKDAY"; overtimeHours = 4.0 }
        )
    },

    # E006：事假 4H + 普通病假 4H -> 觸發兩條請假扣薪規則
    @{
        employeeId           = "E006"
        baseSalary           = 32000.0
        tenureMonths         = 18
        workingDaysInMonth   = 22
        laborInsuredSalary   = 32000
        healthInsuredSalary  = 32000
        pensionSalary        = 32000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "事假";     leaveHours = 4.0; leaveDays = 0.5;
               deductionRate = 1.0; affectFullAttendance = $true },
            @{ leaveType = "普通病假"; leaveHours = 4.0; leaveDays = 0.5;
               deductionRate = 0.5; affectFullAttendance = $true }
        )
        overtimes = @()
    },

    # E007：無請假，休息日加班 8H -> 觸發 Rest Day OT（最低保障 4H）
    @{
        employeeId           = "E007"
        baseSalary           = 55000.0
        tenureMonths         = 60
        workingDaysInMonth   = 22
        laborInsuredSalary   = 55000
        healthInsuredSalary  = 55000
        pensionSalary        = 55000
        voluntaryPensionRate = 0.06
        leaves    = @()
        overtimes = @(
            @{ overtimeType = "REST_DAY"; overtimeHours = 8.0 }
        )
    },

    # E008：家庭照顧假 8H -> 觸發 Leave Deduction - 家庭照顧假
    @{
        employeeId           = "E008"
        baseSalary           = 42000.0
        tenureMonths         = 30
        workingDaysInMonth   = 22
        laborInsuredSalary   = 42000
        healthInsuredSalary  = 42000
        pensionSalary        = 42000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "家庭照顧假"; leaveHours = 8.0; leaveDays = 1.0;
               deductionRate = 1.0; affectFullAttendance = $true }
        )
        overtimes = @()
    },

    # E009：住院病假 16H -> 觸發 Leave Deduction - 住院病假
    @{
        employeeId           = "E009"
        baseSalary           = 36000.0
        tenureMonths         = 9
        workingDaysInMonth   = 22
        laborInsuredSalary   = 36000
        healthInsuredSalary  = 36000
        pensionSalary        = 36000
        voluntaryPensionRate = 0.0
        leaves = @(
            @{ leaveType = "住院病假"; leaveHours = 16.0; leaveDays = 2.0;
               deductionRate = 1.0; affectFullAttendance = $true }
        )
        overtimes = @()
    },

    # E010：無請假，國定假日加班 8H -> 觸發 Holiday OT
    @{
        employeeId           = "E010"
        baseSalary           = 60000.0
        tenureMonths         = 72
        workingDaysInMonth   = 22
        laborInsuredSalary   = 60000
        healthInsuredSalary  = 60000
        pensionSalary        = 60000
        voluntaryPensionRate = 0.06
        leaves    = @()
        overtimes = @(
            @{ overtimeType = "HOLIDAY"; overtimeHours = 8.0 }
        )
    }
)


# ===== 核心函式：送出單筆薪資計算請求 =====
# 回傳：PSCustomObject { EmployeeId, WallMs, EngineMs, FinalSalary, RulesHit }
function Invoke-SalaryRequest {
    param(
        [hashtable]$employee,   # 員工資料
        [string]$mode           # "Sequential" 或 "Parallel"
    )

    $payload = $employee | ConvertTo-Json -Depth 5 -Compress

    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $resp = Invoke-WebRequest `
            -Uri         $endpoint `
            -Method      Post `
            -Body        $payload `
            -ContentType "application/json; charset=utf-8" `
            -Headers     @{ "x-test-case" = "$mode-$($employee.employeeId)" } `
            -UseBasicParsing

        $sw.Stop()
        $wallMs   = $sw.ElapsedMilliseconds
        $engineMs = [int]($resp.Headers["X-Execution-Time-Ms"] | Select-Object -First 1)

        # 從回應 Body 取得規則觸發明細（ruleDetails 欄位）
        $body        = $resp.Content | ConvertFrom-Json
        $finalSalary = $body.finalSalary
        $rulesHit    = ($body.ruleDetails -join " | ")   # 多條規則用 | 分隔

        return [PSCustomObject]@{
            EmployeeId  = $employee.employeeId
            WallMs      = $wallMs
            EngineMs    = $engineMs
            FinalSalary = $finalSalary
            RulesHit    = $rulesHit
            Success     = $true
        }

    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            EmployeeId  = $employee.employeeId
            WallMs      = $sw.ElapsedMilliseconds
            EngineMs    = -1
            FinalSalary = 0
            RulesHit    = "FAIL: $($_.Exception.Message)"
            Success     = $false
        }
    }
}


# =================================================================
# 實驗一：單筆循序模式（Sequential）
# 逐一送出，等待回應後才送下一筆
# =================================================================
Write-Log "============================================================" "Cyan"
Write-Log "  實驗一：單筆循序模式（Sequential）開始" "Cyan"
Write-Log "============================================================" "Cyan"

$seqResults = @()
$seqTotalSw = [System.Diagnostics.Stopwatch]::StartNew()

foreach ($emp in $employees) {
    Write-Log "  送出 $($emp.employeeId)..." "White"
    $r = Invoke-SalaryRequest -employee $emp -mode "Sequential"

    # 印出觸發規則明細
    Write-Log "  $($r.EmployeeId)  wall=$($r.WallMs)ms  engine=$($r.EngineMs)ms  salary=$($r.FinalSalary)" "Green"
    Write-Log "    觸發規則：$($r.RulesHit)" "Yellow"

    # 寫入 CSV
    "Sequential,$($r.EmployeeId),$($r.WallMs),$($r.EngineMs),$($r.FinalSalary),$($r.RulesHit)" |
        Add-Content -Path $csvFile -Encoding UTF8

    $seqResults += $r
}

$seqTotalSw.Stop()
$seqTotalMs  = $seqTotalSw.ElapsedMilliseconds
$seqAvgMs    = [math]::Round(($seqResults | Measure-Object WallMs -Average).Average, 1)
$seqMaxMs    = ($seqResults | Measure-Object WallMs -Maximum).Maximum
$seqMinMs    = ($seqResults | Measure-Object WallMs -Minimum).Minimum

Write-Log "  單筆循序完成：總耗時=$($seqTotalMs)ms  平均=$($seqAvgMs)ms  最快=$($seqMinMs)ms  最慢=$($seqMaxMs)ms" "Cyan"


# =================================================================
# 實驗二：批次並行模式（Parallel）
# 10 筆同時送出，使用 PowerShell Job 並行執行
# =================================================================
Write-Log "" "White"
Write-Log "============================================================" "Cyan"
Write-Log "  實驗二：批次並行模式（Parallel）開始" "Cyan"
Write-Log "============================================================" "Cyan"

$parTotalSw = [System.Diagnostics.Stopwatch]::StartNew()

# 建立 10 個 Background Job，同時送出請求
$jobs = $employees | ForEach-Object {
    $emp = $_
    Start-Job -ScriptBlock {
        param($emp, $endpoint)

        $payload  = $emp | ConvertTo-Json -Depth 5 -Compress
        $sw       = [System.Diagnostics.Stopwatch]::StartNew()

        try {
            $resp = Invoke-WebRequest `
                -Uri         $endpoint `
                -Method      Post `
                -Body        $payload `
                -ContentType "application/json; charset=utf-8" `
                -Headers     @{ "x-test-case" = "Parallel-$($emp.employeeId)" } `
                -UseBasicParsing

            $sw.Stop()
            $body     = $resp.Content | ConvertFrom-Json
            return [PSCustomObject]@{
                EmployeeId  = $emp.employeeId
                WallMs      = $sw.ElapsedMilliseconds
                EngineMs    = [int]($resp.Headers["X-Execution-Time-Ms"] | Select-Object -First 1)
                FinalSalary = $body.finalSalary
                RulesHit    = ($body.ruleDetails -join " | ")
                Success     = $true
            }
        } catch {
            $sw.Stop()
            return [PSCustomObject]@{
                EmployeeId  = $emp.employeeId
                WallMs      = $sw.ElapsedMilliseconds
                EngineMs    = -1
                FinalSalary = 0
                RulesHit    = "FAIL: $($_.Exception.Message)"
                Success     = $false
            }
        }
    } -ArgumentList $emp, $endpoint
}

# 等待所有 Job 完成並收集結果
$parResults = $jobs | Wait-Job | Receive-Job
$jobs | Remove-Job

$parTotalSw.Stop()
$parTotalMs = $parTotalSw.ElapsedMilliseconds

# 印出並行結果
foreach ($r in $parResults) {
    Write-Log "  $($r.EmployeeId)  wall=$($r.WallMs)ms  engine=$($r.EngineMs)ms  salary=$($r.FinalSalary)" "Green"
    Write-Log "    觸發規則：$($r.RulesHit)" "Yellow"

    "Parallel,$($r.EmployeeId),$($r.WallMs),$($r.EngineMs),$($r.FinalSalary),$($r.RulesHit)" |
        Add-Content -Path $csvFile -Encoding UTF8
}

$parAvgMs = [math]::Round(($parResults | Measure-Object WallMs -Average).Average, 1)
$parMaxMs = ($parResults | Measure-Object WallMs -Maximum).Maximum
$parMinMs = ($parResults | Measure-Object WallMs -Minimum).Minimum

Write-Log "  批次並行完成：總耗時=$($parTotalMs)ms  平均=$($parAvgMs)ms  最快=$($parMinMs)ms  最慢=$($parMaxMs)ms" "Cyan"


# =================================================================
# 最終比較報告
# =================================================================
Write-Log "" "White"
Write-Log "============================================================" "Cyan"
Write-Log "  最終比較報告" "Cyan"
Write-Log "============================================================" "Cyan"
Write-Log ("  {0,-20} {1,-15} {2,-15} {3,-15} {4}" -f "模式", "總耗時(ms)", "平均(ms)", "最快(ms)", "最慢(ms)") "White"
Write-Log ("  {0,-20} {1,-15} {2,-15} {3,-15} {4}" -f "----", "----------", "--------", "--------", "--------") "White"
Write-Log ("  {0,-20} {1,-15} {2,-15} {3,-15} {4}" -f "Sequential（單筆）", $seqTotalMs, $seqAvgMs, $seqMinMs, $seqMaxMs) "Green"
Write-Log ("  {0,-20} {1,-15} {2,-15} {3,-15} {4}" -f "Parallel（批次）",   $parTotalMs, $parAvgMs, $parMinMs, $parMaxMs) "Yellow"

$speedup = [math]::Round($seqTotalMs / $parTotalMs, 2)
Write-Log "" "White"
Write-Log "  批次並行比單筆循序快 $speedup 倍" "Cyan"
Write-Log "  詳細結果 CSV：$csvFile" "Cyan"
Write-Log "  完整日誌：$logFile" "Cyan"
Write-Log "============================================================" "Cyan"
