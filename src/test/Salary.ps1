# =================================================================
# 薪資計算規則引擎測試腳本 - 對齊 Excel 詹姆士案例 $40,961
# 連續 10 筆請求，觀察冷啟動暖機效果 + 第 1 筆印出計算明細
# 修正：全部統一使用 leaveTypeName（配合 @JsonAlias 相容 leaveType）
# =================================================================

chcp 65001 | Out-Null
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
# $Url = "http://localhost:7071/api/calculatesalary"
$Url = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"

$TestData = @{
    companyId            = "CMP001"
    employeeId           = "7"
    position             = "業務部"
    identity             = "詹姆士"
    tenureMonths         = 12
    baseSalary           = 36000.0
    absentDays           = 0.0
    laborInsuredSalary   = 0
    healthInsuredSalary  = 0
    pensionSalary        = 0
    voluntaryPensionRate = 0.0
    workingDaysInMonth   = 22

    leaves = @(
        # 5/5  曠職 8H → $1,200
        @{ leaveTypeName = "曠職";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/6  事假 8H → $1,200
        @{ leaveTypeName = "事假";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/7  曠職 8H → $1,200
        @{ leaveTypeName = "曠職";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/8  普通病假 3H (50%) → $225
        @{ leaveTypeName = "普通病假"; leaveHours = 3.0;    leaveDays = 0.375;    deductionRate = 0.5; affectFullAttendance = $true  },
        # 5/9  事假 0.3H (18分) → $45
        @{ leaveTypeName = "事假";    leaveHours = 0.3;    leaveDays = 0.0375;   deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/9  普通病假 0.4167H (25分) (50%) → $31
        @{ leaveTypeName = "普通病假"; leaveHours = 0.4167; leaveDays = 0.05209;  deductionRate = 0.5; affectFullAttendance = $true  },
        # 5/13 事假 2H → $300
        @{ leaveTypeName = "事假";    leaveHours = 2.0;    leaveDays = 0.25;     deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/18 事假 0.1667H (10分) → $25
        @{ leaveTypeName = "事假";    leaveHours = 0.1667; leaveDays = 0.02084;  deductionRate = 1.0; affectFullAttendance = $true  },
        # 5/23 事假 1H → $150
        @{ leaveTypeName = "事假";    leaveHours = 1.0;    leaveDays = 0.125;    deductionRate = 1.0; affectFullAttendance = $true  },
        # 給薪假（不扣薪）
        @{ leaveTypeName = "特休";    leaveHours = 15.0;   leaveDays = 1.875;    deductionRate = 0.0; affectFullAttendance = $false },
        @{ leaveTypeName = "產檢假";  leaveHours = 5.0;    leaveDays = 0.625;    deductionRate = 0.0; affectFullAttendance = $false },
        @{ leaveTypeName = "公假";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 0.0; affectFullAttendance = $false },
        @{ leaveTypeName = "補休";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 0.0; affectFullAttendance = $false },
        @{ leaveTypeName = "喪假";    leaveHours = 8.0;    leaveDays = 1.0;      deductionRate = 0.0; affectFullAttendance = $false }
    )

    overtimes = @(
        # 5/16 平日加班 3.25H → $716
        @{ overtimeType = "WEEKDAY";           overtimeHours = 3.25  },
        # 5/23 平日加班 3.25H → $716
        @{ overtimeType = "WEEKDAY";           overtimeHours = 3.25  },
        # 5/24 休息日加班 2.5H（做1給4）→ $1,002
        @{ overtimeType = "REST_DAY";          overtimeHours = 2.5   },
        # 5/18 例假日加班 12H（做1給8 + 超過8H×2）→ $2,400
        @{ overtimeType = "STATUTORY_HOLIDAY"; overtimeHours = 12.0  },
        # 5/25 例假日加班 4H（做1給8）→ $1,200
        @{ overtimeType = "STATUTORY_HOLIDAY"; overtimeHours = 4.0   },
        # 5/30 國定假日加班 1H（補發日薪）→ $1,200
        @{ overtimeType = "NATIONAL_HOLIDAY";  overtimeHours = 1.0   },
        # 5/31 國定假日加班 12H（日薪 + 階梯）→ $2,103
        @{ overtimeType = "NATIONAL_HOLIDAY";  overtimeHours = 12.0  }
    )
}

$TestBody  = $TestData | ConvertTo-Json -Depth 10 -Compress
$TotalRuns = 10
$Results   = @()

Write-Host "`n>>> 開始連續 $TotalRuns 筆請求，觀察冷啟動暖機效果..." -ForegroundColor Cyan
Write-Host "=================================================================" -ForegroundColor DarkGray

for ($i = 1; $i -le $TotalRuns; $i++) {

    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    try {
        $ResponseObj = Invoke-WebRequest -Uri $Url -Method Post -Body $TestBody `
            -ContentType "application/json; charset=utf-8" -ErrorAction Stop -TimeoutSec 30
        $stopwatch.Stop()

        $Content = $ResponseObj.Content | ConvertFrom-Json
        $ms      = $stopwatch.Elapsed.TotalMilliseconds
        $Results += $ms

        $rowColor = if ($i -eq 1) { "Yellow" } else { "White" }
        $tag      = if ($i -eq 1) { " <- 冷啟動" } else { "" }

        Write-Host ("  [{0:D2}]  耗時: {1,8:F2} ms  |  HTTP {2}  |  實領: {3}{4}" -f `
            $i, $ms, $ResponseObj.StatusCode, $Content.finalSalary, $tag) -ForegroundColor $rowColor

        # ── 只在第 1 筆印出完整計算明細 ──────────────────────────────
        if ($i -eq 1) {
            Write-Host ""
            Write-Host "  +--- 金額摘要 -------------------------------------------------" -ForegroundColor Cyan
            Write-Host ("  |  底薪:              {0,10}" -f $Content.baseSalary)                              -ForegroundColor White
            Write-Host ("  |  請假扣薪:         -{0,10}  (目標: -4,376)" -f $Content.leaveDeduction)          -ForegroundColor Red
            Write-Host ("  |  加班費:           +{0,10}  (目標: +9,337)" -f $Content.overtimeBonus)           -ForegroundColor Green
            Write-Host ("  |  實領薪資:          {0,10}  (目標: 40,961)" -f $Content.finalSalary)             -ForegroundColor Yellow
            Write-Host "  +--- 規則觸發明細 --------------------------------------------" -ForegroundColor Cyan
            if ($Content.ruleDetails -and $Content.ruleDetails.Count -gt 0) {
                $idx = 1
                foreach ($detail in $Content.ruleDetails) {
                    Write-Host ("  |  {0,2}. {1}" -f $idx, $detail) -ForegroundColor Gray
                    $idx++
                }
            } else {
                Write-Host "  |  [!] ruleDetails 為空，請確認 DRL 有呼叫 addRuleDetail()" -ForegroundColor Yellow
            }
            Write-Host "  +------------------------------------------------------------" -ForegroundColor Cyan
            Write-Host ""
        }

    } catch {
        $stopwatch.Stop()
        $Results += -1
        Write-Host ("  [{0:D2}]  [X] 請求失敗: {1}" -f $i, $_.Exception.Message) -ForegroundColor Red
    } finally {
        if ($stopwatch.IsRunning) { $stopwatch.Stop() }
    }
}

# =================================================================
# 統計摘要
# =================================================================
$ValidResults = $Results | Where-Object { $_ -ge 0 }

if ($ValidResults.Count -gt 0) {

    $First  = $ValidResults[0]
    $Warmup = if ($ValidResults.Count -gt 1) {
        $ValidResults | Select-Object -Skip 1 | Measure-Object -Average -Minimum -Maximum
    } else { $null }

    Write-Host "`n=================================================================" -ForegroundColor DarkGray
    Write-Host "  [統計] 摘要（共 $($ValidResults.Count) 筆成功）"                  -ForegroundColor Cyan
    Write-Host "=================================================================" -ForegroundColor DarkGray
    Write-Host ("  第 1 筆（冷啟動）:  {0,8:F2} ms" -f $First)                     -ForegroundColor Yellow

    if ($Warmup) {
        Write-Host ("  第 2~{0} 筆 平均:   {1,8:F2} ms" -f $TotalRuns, $Warmup.Average) -ForegroundColor Green
        Write-Host ("  第 2~{0} 筆 最快:   {1,8:F2} ms" -f $TotalRuns, $Warmup.Minimum) -ForegroundColor Green
        Write-Host ("  第 2~{0} 筆 最慢:   {1,8:F2} ms" -f $TotalRuns, $Warmup.Maximum) -ForegroundColor Green

        $diff = $First - $Warmup.Average
        $pct  = if ($Warmup.Average -gt 0) { ($diff / $First * 100) } else { 0 }
        Write-Host ("  冷啟動比熱均值慢:  {0,8:F2} ms  ({1:F1}%)" -f $diff, $pct)  -ForegroundColor Magenta
    }

    Write-Host "=================================================================" -ForegroundColor DarkGray
}

Write-Host ""
