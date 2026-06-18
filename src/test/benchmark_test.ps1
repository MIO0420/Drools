# ============================================================
# 規則引擎效能測試腳本 - Drools vs If-Else 對比版
# ============================================================

$baseUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"

function Invoke-BenchmarkCall {
    param ([string]$Url, [string]$Body, [string]$Label)

    $timeNow = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId(
        (Get-Date), "Taipei Standard Time").ToString("yyyy-MM-dd HH:mm:ss")

    $headers = @{ "Content-Type" = "application/json"; "x-test-case" = $Label }

    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $response = Invoke-WebRequest -Uri $Url -Method POST -Headers $headers `
                    -Body $Body -TimeoutSec 30 -UseBasicParsing
        $sw.Stop()

        $execTime = $response.Headers["X-Execution-Time-Ms"] | Select-Object -First 1
        $totalMB  = $response.Headers["X-Memory-After-MB"]   | Select-Object -First 1

        return [PSCustomObject]@{
            Timestamp_CST  = $timeNow
            Label          = $Label
            ServerTime_ms  = if ($execTime) { [double]$execTime } else { 0 }
            ClientTime_ms  = [math]::Round($sw.Elapsed.TotalMilliseconds, 3)
            TotalMem_MB    = if ($totalMB)  { [double]$totalMB  } else { 0 }
            StatusCode     = $response.StatusCode
        }
    } catch {
        return [PSCustomObject]@{
            Timestamp_CST = $timeNow; Label = $Label
            ServerTime_ms = -1; ClientTime_ms = -1
            TotalMem_MB = 0; StatusCode = "ERROR"
        }
    }
}

# ── 測試資料定義 ──────────────────────────────────────────────
# Drools 版（英文假別）
$droolsCases = @{
    "MARRIAGE"    = @{ employeeId="E001"; baseSalary="40000"; leaveType="MARRIAGE";    leaveDays="3"; leaveHours="24"; usedDaysThisYear=0; seniorityMonths=24 }
    "PERSONAL"    = @{ employeeId="E001"; baseSalary="40000"; leaveType="PERSONAL";    leaveDays="2"; leaveHours="16"; usedDaysThisYear=0; seniorityMonths=24 }
    "SICK"        = @{ employeeId="E001"; baseSalary="40000"; leaveType="SICK";        leaveDays="5"; leaveHours="40"; usedDaysThisYear=0; seniorityMonths=24; hospitalized=$false }
    "ANNUAL"      = @{ employeeId="E001"; baseSalary="40000"; leaveType="ANNUAL";      leaveDays="3"; leaveHours="24"; usedDaysThisYear=2; seniorityMonths=24 }
    "BEREAVEMENT" = @{ employeeId="E001"; baseSalary="40000"; leaveType="BEREAVEMENT"; leaveDays="6"; leaveHours="48"; usedDaysThisYear=0; seniorityMonths=24; bereavementRelation="PARENT" }
    "PATERNITY"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="PATERNITY";   leaveDays="5"; leaveHours="40"; usedDaysThisYear=0; seniorityMonths=24 }
}

# Legacy 版（中文假別）
$legacyCases = @{
    "婚假"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="婚假";   leaveDays="3"; leaveHours="24"; usedDaysThisYear=0; tenureMonths=24 }
    "事假"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="事假";   leaveDays="2"; leaveHours="16"; usedDaysThisYear=0; tenureMonths=24 }
    "病假"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="病假";   leaveDays="5"; leaveHours="40"; usedDaysThisYear=0; tenureMonths=24 }
    "特休"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="特休";   leaveDays="3"; leaveHours="24"; usedDaysThisYear=2; tenureMonths=24; maxDaysPerYear=10 }
    "喪假"   = @{ employeeId="E001"; baseSalary="40000"; leaveType="喪假";   leaveDays="6"; leaveHours="48"; usedDaysThisYear=0; tenureMonths=24; bereavementRelation="父母" }
    "陪產假" = @{ employeeId="E001"; baseSalary="40000"; leaveType="陪產假"; leaveDays="5"; leaveHours="40"; usedDaysThisYear=0; tenureMonths=24 }
}

$allResults = @()

# ============================================================
# Step 0: 暖機（各打 5 次，不計入結果）
# ============================================================
Write-Host "`n========== [Warmup] 暖機中，請稍候... ==========" -ForegroundColor Yellow
foreach ($key in $droolsCases.Keys) {
    for ($i = 1; $i -le 5; $i++) {
        Invoke-BenchmarkCall -Url "$baseUrl/calculateleave" `
            -Body ($droolsCases[$key] | ConvertTo-Json) -Label "Warmup_Drools" | Out-Null
        Invoke-BenchmarkCall -Url "$baseUrl/calculateleavelegacy" `
            -Body ($legacyCases[($legacyCases.Keys | Select-Object -First 1)] | ConvertTo-Json) `
            -Label "Warmup_Legacy" | Out-Null
    }
}
Write-Host " 暖機完成！" -ForegroundColor Green

# ============================================================
# Step 1: 單一假別，各跑 30 次（Drools vs Legacy 對比）
# ============================================================
Write-Host "`n========== [Step 1] 單一假別 30 次對比 ==========" -ForegroundColor Cyan

$droolsKeys = @("MARRIAGE", "PERSONAL", "SICK", "ANNUAL", "BEREAVEMENT", "PATERNITY")
$legacyKeys = @("婚假",     "事假",     "病假", "特休",   "喪假",        "陪產假")

for ($k = 0; $k -lt $droolsKeys.Count; $k++) {
    $dk = $droolsKeys[$k]
    $lk = $legacyKeys[$k]
    Write-Host "`n  -- $dk vs $lk --" -ForegroundColor White

    for ($i = 1; $i -le 30; $i++) {
        # Drools
        $r1 = Invoke-BenchmarkCall -Url "$baseUrl/calculateleave" `
              -Body ($droolsCases[$dk] | ConvertTo-Json) `
              -Label "Step1_Drools_$dk"
        $allResults += $r1

        # Legacy
        $r2 = Invoke-BenchmarkCall -Url "$baseUrl/calculateleavelegacy" `
              -Body ($legacyCases[$lk] | ConvertTo-Json) `
              -Label "Step1_Legacy_$lk"
        $allResults += $r2

        if ($i % 10 -eq 0) {
            Write-Host "    Run $i/30 | Drools: $($r1.ServerTime_ms) ms | Legacy: $($r2.ServerTime_ms) ms"
        }
    }
}

# ============================================================
# Step 2: 批次壓力測試（100 次連續請求）
# ============================================================
Write-Host "`n========== [Step 2] 批次壓力 100 次 ==========" -ForegroundColor Cyan

$batchLeaveTypes_D = @("MARRIAGE","PERSONAL","SICK","ANNUAL","BEREAVEMENT","PATERNITY","MATERNITY","OFFICIAL")
$batchLeaveTypes_L = @("婚假","事假","病假","特休","喪假","陪產假","產假","公假")

for ($i = 1; $i -le 100; $i++) {
    $idx = ($i - 1) % $batchLeaveTypes_D.Count
    $dk  = $batchLeaveTypes_D[$idx]
    $lk  = $batchLeaveTypes_L[$idx]

    $bodyD = @{
        employeeId="EMP" + $i.ToString("D3")
        baseSalary="40000"; leaveType=$dk
        leaveDays="3"; leaveHours="24"
        usedDaysThisYear=0; seniorityMonths=24
        bereavementRelation="PARENT"; hospitalized=$false
    } | ConvertTo-Json

    $bodyL = @{
        employeeId="EMP" + $i.ToString("D3")
        baseSalary="40000"; leaveType=$lk
        leaveDays="3"; leaveHours="24"
        usedDaysThisYear=0; tenureMonths=24
        bereavementRelation="父母"; maxDaysPerYear=10
    } | ConvertTo-Json

    $r1 = Invoke-BenchmarkCall -Url "$baseUrl/calculateleave"        -Body $bodyD -Label "Step2_Drools_Batch"
    $r2 = Invoke-BenchmarkCall -Url "$baseUrl/calculateleavelegacy"  -Body $bodyL -Label "Step2_Legacy_Batch"
    $allResults += $r1
    $allResults += $r2

    if ($i % 20 -eq 0) {
        Write-Host "  已完成: $i/100 | Drools: $($r1.ServerTime_ms) ms | Legacy: $($r2.ServerTime_ms) ms"
    }
}

# ============================================================
# Step 3: 摘要統計
# ============================================================
Write-Host "`n========== [Step 3] 摘要統計 ==========" -ForegroundColor Green

$groups = $allResults | Where-Object { $_.ServerTime_ms -ge 0 } | Group-Object Label
foreach ($g in $groups | Sort-Object Name) {
    $times = $g.Group | ForEach-Object { $_.ServerTime_ms }
    $avg   = [math]::Round(($times | Measure-Object -Average).Average, 3)
    $min   = [math]::Round(($times | Measure-Object -Minimum).Minimum, 3)
    $max   = [math]::Round(($times | Measure-Object -Maximum).Maximum, 3)
    Write-Host ("  {0,-35} | avg={1,8} ms | min={2,8} ms | max={3,8} ms | n={4}" `
        -f $g.Name, $avg, $min, $max, $g.Count)
}

# ============================================================
# 輸出 CSV
# ============================================================
$csvPath = "$env:USERPROFILE\Desktop\benchmark_drools_vs_legacy_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$allResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
Write-Host "`n✅ 實驗完成！數據已存至桌面：$csvPath" -ForegroundColor Green
