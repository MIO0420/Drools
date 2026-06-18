# ============================================================
# OvertimeTest.ps1
# 加班規則壓力測試 - 100 家公司 x 10 員工
# ============================================================

param(
    [int]$TotalCompanies      = 100,
    [int]$EmployeesPerCompany = 10,
    [int]$Concurrency         = 20
)

$BASE_URL  = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculateovertime"
$GC_URL    = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/gc"
$TIMESTAMP = Get-Date -Format "yyyyMMdd_HHmmss"
$CSV_FILE  = "overtime_test_$TIMESTAMP.csv"
$JSON_FILE = "overtime_test_summary_$TIMESTAMP.json"

$SPECIAL_COMPANIES = @("76014406", "12345678")
$OVERTIME_TYPES    = @("WEEKDAY", "REST_DAY", "NATIONAL_HOLIDAY", "REGULAR_DAY_OFF")

# ============================================================
# 產生 100 家公司 ID
# ============================================================
function Get-CompanyIds([int]$n) {
    $ids  = [System.Collections.Generic.List[string]]::new()
    $used = [System.Collections.Generic.HashSet[string]]::new()
    $ids.Add("76014406"); $used.Add("76014406") | Out-Null
    $ids.Add("12345678"); $used.Add("12345678") | Out-Null
    $rng = [System.Random]::new()
    while ($ids.Count -lt $n) {
        $cid = $rng.Next(10000000, 99999999).ToString()
        if ($used.Add($cid)) { $ids.Add($cid) }
    }
    return $ids
}

# ============================================================
# 產生單筆 Payload（回傳 JSON 字串）
# ============================================================
function Build-PayloadJson([string]$CompanyId, [int]$EmpIndex) {
    $rng          = [System.Random]::new()
    $overtimeType = $OVERTIME_TYPES[$rng.Next(0, $OVERTIME_TYPES.Count)]

    $hours = switch ($overtimeType) {
        "REST_DAY" { [math]::Round($rng.NextDouble() * 11 + 1, 1) }
        "WEEKDAY"  { [math]::Round($rng.NextDouble() * 3  + 1, 1) }
        default    { [math]::Round($rng.NextDouble() * 7  + 1, 1) }
    }

    $monthlyHours = [math]::Round($rng.NextDouble() * 50 + 10, 1)
    $empId        = "${CompanyId}_EMP$($EmpIndex.ToString('000'))"

    $payload = [ordered]@{
        employeeId             = $empId
        companyId              = $CompanyId
        overtimeType           = $overtimeType
        overtimeHours          = $hours
        monthlyOvertimeHours   = $monthlyHours
        quarterlyOvertimeHours = [math]::Round($monthlyHours * 3, 1)
        laborCouncilAgreed     = ($rng.Next(0, 2) -eq 1)
        consecutiveWorkDays    = $rng.Next(1, 8)
        restDaysPerWeek        = $rng.Next(1, 3)
        isChildWorker          = ($rng.NextDouble() -lt 0.02)
        isPregnantOrNursing    = ($rng.NextDouble() -lt 0.05)
        dailyWorkHours         = 8
        weeklyWorkHours        = 40
        disasterException      = ($rng.NextDouble() -lt 0.10)
        compensatoryTimeOff    = ($rng.NextDouble() -lt 0.30)
        compensatoryExpired    = $false
    }

    return @{
        Json         = ($payload | ConvertTo-Json -Depth 3 -Compress)
        EmployeeId   = $empId
        CompanyId    = $CompanyId
        OvertimeType = $overtimeType
        OvertimeHours= $hours
        MonthlyHours = $monthlyHours
    }
}

# ============================================================
# 取得 Server 記憶體快照
# ============================================================
function Get-ServerMemory {
    try {
        $resp = Invoke-RestMethod -Uri $GC_URL -Method GET -TimeoutSec 10
        return ($resp | ConvertTo-Json -Compress)
    } catch {
        return "{`"error`":`"$($_.Exception.Message)`"}"
    }
}

# ============================================================
# 主流程
# ============================================================

Write-Host ("=" * 60)
Write-Host "🚀 加班規則壓力測試"
Write-Host "   公司數：$TotalCompanies  每公司員工：$EmployeesPerCompany"
Write-Host "   總請求：$($TotalCompanies * $EmployeesPerCompany)"
Write-Host "   並發數：$Concurrency"
Write-Host "   開始時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ("=" * 60)

# 產生所有任務 meta
$companyIds = Get-CompanyIds $TotalCompanies
$allMeta    = [System.Collections.Generic.List[hashtable]]::new()

foreach ($cid in $companyIds) {
    for ($i = 1; $i -le $EmployeesPerCompany; $i++) {
        $meta = Build-PayloadJson $cid $i
        $meta["Label"] = "PERF-${cid}-EMP$($i.ToString('000'))"
        $allMeta.Add($meta)
    }
}

# 打亂順序
$allMeta = $allMeta | Sort-Object { Get-Random }

# ── 測試前記憶體快照 ──────────────────────────────────────
Write-Host "`n📊 測試前 Server 記憶體快照..."
$memBefore = Get-ServerMemory
Write-Host "   $memBefore"

# ── 並發發送（使用 Start-Job）────────────────────────────
Write-Host "`n⏳ 發送 $($allMeta.Count) 筆請求中...`n"

$wallStart   = [System.Diagnostics.Stopwatch]::StartNew()
$allJobs     = [System.Collections.Generic.List[object]]::new()
$jobMetaMap  = @{}   # job.Id → meta

$scriptBlock = {
    param($Url, $BodyJson, $Label, $EmployeeId, $CompanyId, $OvertimeType, $OvertimeHours, $MonthlyHours)

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod `
            -Uri         $Url `
            -Method      POST `
            -Body        $BodyJson `
            -ContentType "application/json" `
            -Headers     @{ "x-test-case" = $Label } `
            -TimeoutSec  30
        $sw.Stop()
        return [PSCustomObject]@{
            Label         = $Label
            CompanyId     = $CompanyId
            EmployeeId    = $EmployeeId
            OvertimeType  = $OvertimeType
            OvertimeHours = $OvertimeHours
            MonthlyHours  = $MonthlyHours
            Status        = 200
            ElapsedMs     = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            Violated      = $resp.violated
            AppliedRule   = "$($resp.appliedRule)"
            Warnings      = (($resp.warnings) -join " | ")
            Notes         = (($resp.notes)    -join " | ")
            Error         = ""
        }
    } catch {
        $sw.Stop()
        return [PSCustomObject]@{
            Label         = $Label
            CompanyId     = $CompanyId
            EmployeeId    = $EmployeeId
            OvertimeType  = $OvertimeType
            OvertimeHours = $OvertimeHours
            MonthlyHours  = $MonthlyHours
            Status        = -1
            ElapsedMs     = [math]::Round($sw.Elapsed.TotalMilliseconds, 2)
            Violated      = $null
            AppliedRule   = ""
            Warnings      = ""
            Notes         = ""
            Error         = $_.Exception.Message
        }
    }
}

# 批次送出，每批 $Concurrency 筆
$batches = [math]::Ceiling($allMeta.Count / $Concurrency)
$results = [System.Collections.Generic.List[PSCustomObject]]::new()

for ($b = 0; $b -lt $batches; $b++) {
    $start = $b * $Concurrency
    $end   = [math]::Min($start + $Concurrency - 1, $allMeta.Count - 1)
    $batch = $allMeta[$start..$end]

    $batchJobs = foreach ($meta in $batch) {
        Start-Job -ScriptBlock $scriptBlock -ArgumentList `
            $BASE_URL,
            $meta.Json,
            $meta.Label,
            $meta.EmployeeId,
            $meta.CompanyId,
            $meta.OvertimeType,
            $meta.OvertimeHours,
            $meta.MonthlyHours
    }

    # 等待這批全部完成
    $batchJobs | Wait-Job | Out-Null

    foreach ($job in $batchJobs) {
        $output = Receive-Job -Job $job
        if ($output) { $results.Add($output) }
        Remove-Job -Job $job
    }

    $done = [math]::Min($end + 1, $allMeta.Count)
    Write-Host "   進度：$done / $($allMeta.Count)"
}

$wallStart.Stop()
$wallElapsed = $wallStart.Elapsed.TotalSeconds

# ── 測試後記憶體快照 ──────────────────────────────────────
Write-Host "`n📊 測試後 Server 記憶體快照..."
$memAfter = Get-ServerMemory
Write-Host "   $memAfter"

# ============================================================
# 統計分析
# ============================================================

$resultList = $results | Sort-Object Label
$success    = @($resultList | Where-Object { $_.Status -eq 200 })
$failed     = @($resultList | Where-Object { $_.Status -ne 200 })
$violated   = @($success    | Where-Object { $_.Violated -eq $true })
$latArr     = @($success    | ForEach-Object { $_.ElapsedMs } | Sort-Object)
$total      = $resultList.Count

function Get-Percentile([double[]]$arr, [double]$p) {
    if ($arr.Count -eq 0) { return 0 }
    $idx = [math]::Min([math]::Floor($arr.Count * $p), $arr.Count - 1)
    return $arr[$idx]
}

$latMean = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Average).Average, 1) } else { 0 }
$latMin  = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Minimum).Minimum, 1) } else { 0 }
$latMax  = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Maximum).Maximum, 1) } else { 0 }
$latMed  = Get-Percentile $latArr 0.50
$latP90  = Get-Percentile $latArr 0.90
$latP95  = Get-Percentile $latArr 0.95
$latP99  = Get-Percentile $latArr 0.99
$tps     = [math]::Round($total / $wallElapsed, 1)

# ============================================================
# 輸出報告
# ============================================================

Write-Host "`n$("=" * 60)"
Write-Host "📋 測試結果總覽"
Write-Host "$("=" * 60)"
Write-Host "  總請求數       : $total"
Write-Host "  成功 (HTTP 200): $($success.Count)  ($([math]::Round($success.Count / [math]::Max($total,1) * 100, 1))%)"
Write-Host "  失敗           : $($failed.Count)  ($([math]::Round($failed.Count  / [math]::Max($total,1) * 100, 1))%)"
Write-Host "  違規筆數       : $($violated.Count)  ($([math]::Round($violated.Count / [math]::Max($success.Count,1) * 100, 1))% of success)"
Write-Host "  總耗時 (wall)  : $([math]::Round($wallElapsed, 2)) 秒"
Write-Host "  平均 TPS       : $tps req/s"

Write-Host "`n⏱️  延遲統計 (ms)"
Write-Host "  Min    : $latMin"
Write-Host "  Max    : $latMax"
Write-Host "  Mean   : $latMean"
Write-Host "  Median : $latMed"
Write-Host "  P90    : $latP90"
Write-Host "  P95    : $latP95"
Write-Host "  P99    : $latP99"

Write-Host "`n🏢 特殊公司規則命中確認"
foreach ($sid in $SPECIAL_COMPANIES) {
    $compRows    = @($resultList | Where-Object { $_.CompanyId -eq $sid })
    $restDayRows = @($compRows   | Where-Object { $_.OvertimeType -eq "REST_DAY" })
    $hitRows     = @($restDayRows| Where-Object { $_.AppliedRule -like "*$sid*" })
    $avgLat      = if ($compRows.Count -gt 0) {
        [math]::Round(($compRows | ForEach-Object { $_.ElapsedMs } | Measure-Object -Average).Average, 1)
    } else { 0 }
    Write-Host "  公司 ${sid}："
    Write-Host "    REST_DAY 請求數   : $($restDayRows.Count)"
    Write-Host "    專屬規則命中數    : $($hitRows.Count)"
    Write-Host "    平均延遲          : $avgLat ms"
}

Write-Host "`n📊 各加班類型統計"
Write-Host ("  " + "類型".PadRight(22) + "請求".PadLeft(6) + "違規".PadLeft(6) + "違規率".PadLeft(8) + "平均延遲(ms)".PadLeft(14))
Write-Host ("  " + "-" * 58)
foreach ($ot in $OVERTIME_TYPES) {
    $otRows  = @($success | Where-Object { $_.OvertimeType -eq $ot })
    $otVio   = @($otRows  | Where-Object { $_.Violated -eq $true })
    $otAvg   = if ($otRows.Count -gt 0) {
        [math]::Round(($otRows | ForEach-Object { $_.ElapsedMs } | Measure-Object -Average).Average, 1)
    } else { 0 }
    $vioRate = if ($otRows.Count -gt 0) { [math]::Round($otVio.Count / $otRows.Count * 100, 1) } else { 0 }
    Write-Host ("  " + $ot.PadRight(22) + $otRows.Count.ToString().PadLeft(6) + $otVio.Count.ToString().PadLeft(6) + "$vioRate%".PadLeft(8) + $otAvg.ToString().PadLeft(14))
}

Write-Host "`n💾 Server 記憶體變化"
Write-Host "  測試前: $memBefore"
Write-Host "  測試後: $memAfter"

if ($failed.Count -gt 0) {
    Write-Host "`n❌ 失敗請求（前 10 筆）"
    $failed | Select-Object -First 10 | ForEach-Object {
        Write-Host "  [$($_.Status)] $($_.EmployeeId) | $($_.OvertimeType) | $($_.Error)"
    }
}

# ============================================================
# 輸出 CSV
# ============================================================

$resultList | Export-Csv -Path $CSV_FILE -NoTypeInformation -Encoding UTF8
Write-Host "`n✅ CSV 已儲存至：$CSV_FILE"

# ============================================================
# 輸出 JSON 摘要
# ============================================================

[ordered]@{
    testTime     = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    total        = $total
    success      = $success.Count
    failed       = $failed.Count
    violated     = $violated.Count
    wallSeconds  = [math]::Round($wallElapsed, 3)
    tps          = $tps
    latency      = [ordered]@{
        min    = $latMin
        max    = $latMax
        mean   = $latMean
        median = $latMed
        p90    = $latP90
        p95    = $latP95
        p99    = $latP99
    }
    memoryBefore = $memBefore
    memoryAfter  = $memAfter
} | ConvertTo-Json -Depth 5 | Out-File -FilePath $JSON_FILE -Encoding UTF8

Write-Host "✅ JSON 摘要已儲存至：$JSON_FILE"
Write-Host ("=" * 60)
