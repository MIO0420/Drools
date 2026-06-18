# LeaveTest_10Companies.ps1
# 測試 10 間公司 × 10 位員工，比對 Drools vs Legacy 結果
# 效能測量：冷啟動（Round 1）+ 熱執行（Round 2、3）分開呈現

$baseUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"

$companies = @(
    "COMPANY_A","COMPANY_B","COMPANY_C",
    "COMPANY_D","COMPANY_E","COMPANY_F",
    "COMPANY_G","COMPANY_H","COMPANY_I","COMPANY_J"
)

$leaveScenarios = @(
    @{ leaveTypeName="MARRIAGE";    leaveDays=5;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=8;  baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="MARRIAGE";    leaveDays=5;  usedDaysThisYear=6;  hospitalized=$false; leaveHours=8;  baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="PERSONAL";    leaveDays=3;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=24; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="PERSONAL";    leaveDays=3;  usedDaysThisYear=13; hospitalized=$false; leaveHours=24; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="SICK";        leaveDays=2;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=16; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="ANNUAL";      leaveDays=3;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=24; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="FAMILY_CARE"; leaveDays=2;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=16; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="FAMILY_CARE"; leaveDays=3;  usedDaysThisYear=6;  hospitalized=$false; leaveHours=24; baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="BIRTHDAY";    leaveDays=1;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=8;  baseSalary=50000; seniorityMonths=36 },
    @{ leaveTypeName="PATERNITY";   leaveDays=5;  usedDaysThisYear=0;  hospitalized=$false; leaveHours=40; baseSalary=50000; seniorityMonths=36 }
)

# ── 建立請求資料 ─────────────────────────────────────────────
$allRequests = @()
$empIndex = 1

foreach ($company in $companies) {
    for ($i = 0; $i -lt 10; $i++) {
        $scenario = $leaveScenarios[$i]
        $empId = "E{0:D3}" -f $empIndex
        $allRequests += @{
            employeeId       = $empId
            companyId        = $company
            seniorityMonths  = $scenario.seniorityMonths
            position         = "STAFF"
            baseSalary       = $scenario.baseSalary
            leaveTypeName    = $scenario.leaveTypeName
            leaveDays        = $scenario.leaveDays
            leaveHours       = $scenario.leaveHours
            usedDaysThisYear = $scenario.usedDaysThisYear
            hospitalized     = $scenario.hospitalized
        }
        $empIndex++
    }
}

$body = $allRequests | ConvertTo-Json -Depth 5

# ════════════════════════════════════════════════════════════
# 效能測量：3 輪
#   Round 1 = 冷啟動（含 KieContainer 初始化，計入測試）
#   Round 2 = 熱執行第一次
#   Round 3 = 熱執行第二次
# ════════════════════════════════════════════════════════════
Write-Host "`n⏱️  效能測量（3 輪）" -ForegroundColor Cyan
Write-Host ("─" * 60)

$droolsRounds = @()
$legacyRounds = @()

for ($round = 1; $round -le 3; $round++) {

    $label = if ($round -eq 1) { "冷啟動" } else { "熱執行 #$($round - 1)" }

    # Drools
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-RestMethod -Uri "$baseUrl/calculateleave/batch" `
        -Method POST -Body $body -ContentType "application/json"
    $sw.Stop()
    $dMs = $sw.ElapsedMilliseconds
    $droolsRounds += $dMs

    # Legacy
    $sw2 = [System.Diagnostics.Stopwatch]::StartNew()
    $legacyResp = Invoke-RestMethod -Uri "$baseUrl/calculateleavelegacy/batch" `
        -Method POST -Body $body -ContentType "application/json"
    $sw2.Stop()
    $lMs = $sw2.ElapsedMilliseconds
    $legacyRounds += $lMs

    # 只有第 1 輪保留結果做正確性比對
    if ($round -eq 1) {
        $droolsResp = $resp
    }

    $diff = if ($lMs -gt 0) { [math]::Round((($dMs - $lMs) / $lMs) * 100, 1) } else { 0 }
    $icon = if ($round -eq 1) { "🧊" } else { "🔥" }
    Write-Host ("  $icon Round {0} [{1,-8}]  Drools: {2,6} ms  |  Legacy: {3,6} ms  |  差距: {4,7}%" -f `
        $round, $label, $dMs, $lMs, $diff)
}

# 熱執行平均
$droolsHotAvg = [math]::Round(($droolsRounds[1] + $droolsRounds[2]) / 2, 0)
$legacyHotAvg = [math]::Round(($legacyRounds[1] + $legacyRounds[2]) / 2, 0)
$hotDiff      = if ($legacyHotAvg -gt 0) { [math]::Round((($droolsHotAvg - $legacyHotAvg) / $legacyHotAvg) * 100, 1) } else { 0 }

Write-Host ("─" * 60)
Write-Host ("  📊 熱執行平均          Drools: {0,6} ms  |  Legacy: {1,6} ms  |  差距: {2,7}%" -f `
    $droolsHotAvg, $legacyHotAvg, $hotDiff)
Write-Host ("─" * 60)

# ── 正確性比對（使用 Round 1 的結果）────────────────────────
Write-Host "`n📤 正確性比對（100 筆，使用 Round 1 結果）" -ForegroundColor Yellow
Write-Host ("=" * 100)
Write-Host ("{0,-6} {1,-12} {2,-14} {3,-8} {4,-8} {5,-8} {6,-8} {7,-5}" -f `
    "EmpID","Company","LeaveType","D-App","L-App","D-Rem","L-Rem","Match")
Write-Host ("=" * 100)

$matchCount    = 0
$mismatchCount = 0
$mismatchList  = @()

for ($i = 0; $i -lt $allRequests.Count; $i++) {
    $req    = $allRequests[$i]
    $drools = $droolsResp[$i]
    $legacy = $legacyResp[$i]

    $appMatch = ($drools.approved      -eq $legacy.approved)
    $remMatch = ($drools.remainingDays -eq $legacy.remainingDays)
    $isMatch  = $appMatch -and $remMatch

    $matchIcon = if ($isMatch) { "✅" } else { "❌" }

    if ($isMatch) { $matchCount++ }
    else {
        $mismatchCount++
        $mismatchList += @{
            empId     = $req.employeeId
            company   = $req.companyId
            leaveType = $req.leaveTypeName
            dApp      = $drools.approved
            lApp      = $legacy.approved
            dRem      = $drools.remainingDays
            lRem      = $legacy.remainingDays
        }
    }

    Write-Host ("{0,-6} {1,-12} {2,-14} {3,-8} {4,-8} {5,-8} {6,-8} {7,-5}" -f `
        $req.employeeId, $req.companyId, $req.leaveTypeName,
        $drools.approved, $legacy.approved,
        $drools.remainingDays, $legacy.remainingDays,
        $matchIcon)
}

# ── 測試總結 ─────────────────────────────────────────────────
Write-Host ("=" * 100)
Write-Host "`n📈 測試總結" -ForegroundColor Green
Write-Host "  總筆數      : $($allRequests.Count)"
Write-Host "  ✅ 一致     : $matchCount"
Write-Host "  ❌ 不一致   : $mismatchCount"
Write-Host ""
Write-Host "⏱️  效能總覽" -ForegroundColor Cyan
Write-Host ("  {0,-20} {1,10} {2,10}" -f "項目", "Drools", "Legacy")
Write-Host ("  " + "─" * 42)
Write-Host ("  {0,-20} {1,9} ms {2,9} ms" -f "🧊 冷啟動 (R1)",   $droolsRounds[0], $legacyRounds[0])
Write-Host ("  {0,-20} {1,9} ms {2,9} ms" -f "🔥 熱執行 (R2)",   $droolsRounds[1], $legacyRounds[1])
Write-Host ("  {0,-20} {1,9} ms {2,9} ms" -f "🔥 熱執行 (R3)",   $droolsRounds[2], $legacyRounds[2])
Write-Host ("  {0,-20} {1,9} ms {2,9} ms" -f "📊 熱執行平均",    $droolsHotAvg,    $legacyHotAvg)

# ── 不一致明細 ────────────────────────────────────────────────
if ($mismatchCount -gt 0) {
    Write-Host "`n⚠️  不一致明細：" -ForegroundColor Red
    Write-Host ("{0,-6} {1,-12} {2,-14} {3,-8} {4,-8} {5,-8} {6,-8}" -f `
        "EmpID","Company","LeaveType","D-App","L-App","D-Rem","L-Rem")
    Write-Host ("-" * 80)
    $mismatchList | ForEach-Object {
        Write-Host ("{0,-6} {1,-12} {2,-14} {3,-8} {4,-8} {5,-8} {6,-8}" -f `
            $_.empId, $_.company, $_.leaveType,
            $_.dApp, $_.lApp, $_.dRem, $_.lRem)
    }
}
