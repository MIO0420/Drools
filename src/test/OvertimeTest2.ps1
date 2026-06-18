# ============================================================
# OvertimeBenchmark.ps1
# Drools vs Switch-Case (Legacy) 對比壓力測試
# 100 家公司 x 10 員工，兩個端點各打一輪
# ============================================================

param(
    [int]$TotalCompanies      = 100,
    [int]$EmployeesPerCompany = 10,
    [int]$Concurrency         = 20
)

$DROOLS_URL  = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculateovertime"
$LEGACY_URL  = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculateovertime/legacy"
$GC_URL      = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/gc"
$TIMESTAMP   = Get-Date -Format "yyyyMMdd_HHmmss"
$CSV_FILE    = "overtime_benchmark_$TIMESTAMP.csv"
$JSON_FILE   = "overtime_benchmark_summary_$TIMESTAMP.json"

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
# 產生單筆 Payload（與 OvertimeTest.ps1 完全相同）
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
# 執行一輪壓力測試（共用邏輯）
# ============================================================
function Invoke-OvertimeRound {
    param(
        [string]$RoundName,
        [string]$TargetUrl,
        [System.Collections.Generic.List[hashtable]]$AllMeta,
        [int]$Concurrency
    )

    Write-Host "`n$("─" * 60)"
    Write-Host "🔄 開始測試：$RoundName"
    Write-Host "   端點：$TargetUrl"
    Write-Host "$("─" * 60)"

    $scriptBlock = {
        param($Url, $BodyJson, $Label, $EmployeeId, $CompanyId, $OvertimeType, $OvertimeHours, $MonthlyHours, $RoundName)

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
                Round         = $RoundName
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
                Round         = $RoundName
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

    $wallStart = [System.Diagnostics.Stopwatch]::StartNew()
    $results   = [System.Collections.Generic.List[PSCustomObject]]::new()
    $batches   = [math]::Ceiling($AllMeta.Count / $Concurrency)

    for ($b = 0; $b -lt $batches; $b++) {
        $start = $b * $Concurrency
        $end   = [math]::Min($start + $Concurrency - 1, $AllMeta.Count - 1)
        $batch = $AllMeta[$start..$end]

        $batchJobs = foreach ($meta in $batch) {
            Start-Job -ScriptBlock $scriptBlock -ArgumentList `
                $TargetUrl,
                $meta.Json,
                $meta.Label,
                $meta.EmployeeId,
                $meta.CompanyId,
                $meta.OvertimeType,
                $meta.OvertimeHours,
                $meta.MonthlyHours,
                $RoundName
        }

        $batchJobs | Wait-Job | Out-Null
        foreach ($job in $batchJobs) {
            $output = Receive-Job -Job $job
            if ($output) { $results.Add($output) }
            Remove-Job -Job $job
        }

        $done = [math]::Min($end + 1, $AllMeta.Count)
        Write-Host "   進度：$done / $($AllMeta.Count)"
    }

    $wallStart.Stop()
    return @{
        Results     = $results
        WallSeconds = $wallStart.Elapsed.TotalSeconds
    }
}

# ============================================================
# 統計計算（共用）
# ============================================================
function Get-Percentile([double[]]$arr, [double]$p) {
    if ($arr.Count -eq 0) { return 0 }
    $idx = [math]::Min([math]::Floor($arr.Count * $p), $arr.Count - 1)
    return $arr[$idx]
}

function Get-Stats {
    param($ResultList, [double]$WallSeconds)

    $success  = @($ResultList | Where-Object { $_.Status -eq 200 })
    $failed   = @($ResultList | Where-Object { $_.Status -ne 200 })
    $violated = @($success    | Where-Object { $_.Violated -eq $true })
    $latArr   = @($success    | ForEach-Object { $_.ElapsedMs } | Sort-Object)
    $total    = $ResultList.Count

    return [ordered]@{
        Total       = $total
        Success     = $success.Count
        Failed      = $failed.Count
        Violated    = $violated.Count
        WallSeconds = [math]::Round($WallSeconds, 3)
        TPS         = [math]::Round($total / [math]::Max($WallSeconds, 0.001), 1)
        LatMin      = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Minimum).Minimum, 1) } else { 0 }
        LatMax      = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Maximum).Maximum, 1) } else { 0 }
        LatMean     = if ($latArr.Count -gt 0) { [math]::Round(($latArr | Measure-Object -Average).Average,  1) } else { 0 }
        LatMedian   = Get-Percentile $latArr 0.50
        LatP90      = Get-Percentile $latArr 0.90
        LatP95      = Get-Percentile $latArr 0.95
        LatP99      = Get-Percentile $latArr 0.99
        SuccessRows = $success
        FailedRows  = $failed
    }
}

# ============================================================
# 主流程
# ============================================================

Write-Host ("=" * 60)
Write-Host "⚡ Drools vs Switch-Case 對比壓力測試"
Write-Host "   公司數：$TotalCompanies  每公司員工：$EmployeesPerCompany"
Write-Host "   總請求：$($TotalCompanies * $EmployeesPerCompany)（每輪）"
Write-Host "   並發數：$Concurrency"
Write-Host "   開始時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
Write-Host ("=" * 60)

# ── 產生所有任務 meta（兩輪共用相同 Payload）────────────────
$companyIds = Get-CompanyIds $TotalCompanies
$allMeta    = [System.Collections.Generic.List[hashtable]]::new()

foreach ($cid in $companyIds) {
    for ($i = 1; $i -le $EmployeesPerCompany; $i++) {
        $meta = Build-PayloadJson $cid $i
        $meta["Label"] = "BENCH-${cid}-EMP$($i.ToString('000'))"
        $allMeta.Add($meta)
    }
}

$allMeta = $allMeta | Sort-Object { Get-Random }

# ── 測試前記憶體快照 ──────────────────────────────────────
Write-Host "`n📊 測試前 Server 記憶體快照..."
$memBefore = Get-ServerMemory
Write-Host "   $memBefore"

# ── Round 1：Drools ───────────────────────────────────────
$droolsRound = Invoke-OvertimeRound -RoundName "Drools" -TargetUrl $DROOLS_URL `
               -AllMeta $allMeta -Concurrency $Concurrency
$memMid = Get-ServerMemory
Write-Host "`n📊 Drools 測試後記憶體：$memMid"

# ── Round 2：Switch-Case (Legacy) ────────────────────────
$legacyRound = Invoke-OvertimeRound -RoundName "Switch-Case" -TargetUrl $LEGACY_URL `
               -AllMeta $allMeta -Concurrency $Concurrency
$memAfter = Get-ServerMemory
Write-Host "`n📊 Switch-Case 測試後記憶體：$memAfter"

# ── 統計 ─────────────────────────────────────────────────
$drStats = Get-Stats -ResultList $droolsRound.Results  -WallSeconds $droolsRound.WallSeconds
$scStats = Get-Stats -ResultList $legacyRound.Results  -WallSeconds $legacyRound.WallSeconds

# ============================================================
# 輸出報告
# ============================================================

Write-Host "`n$("=" * 60)"
Write-Host "📋 對比測試結果總覽"
Write-Host "$("=" * 60)"

$colW = 18
Write-Host ("  " + "指標".PadRight(20) + "Drools".PadLeft($colW) + "Switch-Case".PadLeft($colW))
Write-Host ("  " + "─" * 56)

function Fmt-Row($label, $drVal, $scVal) {
    Write-Host ("  " + $label.PadRight(20) + "$drVal".PadLeft($colW) + "$scVal".PadLeft($colW))
}

Fmt-Row "總請求數"        $drStats.Total        $scStats.Total
Fmt-Row "成功 (HTTP 200)" $drStats.Success       $scStats.Success
Fmt-Row "失敗"            $drStats.Failed        $scStats.Failed
Fmt-Row "違規筆數"        $drStats.Violated      $scStats.Violated
Fmt-Row "總耗時 (秒)"     $drStats.WallSeconds   $scStats.WallSeconds
Fmt-Row "平均 TPS"        $drStats.TPS           $scStats.TPS

Write-Host "`n⏱️  延遲統計 (ms)"
Write-Host ("  " + "指標".PadRight(20) + "Drools".PadLeft($colW) + "Switch-Case".PadLeft($colW))
Write-Host ("  " + "─" * 56)
Fmt-Row "Min"    $drStats.LatMin    $scStats.LatMin
Fmt-Row "Max"    $drStats.LatMax    $scStats.LatMax
Fmt-Row "Mean"   $drStats.LatMean   $scStats.LatMean
Fmt-Row "Median" $drStats.LatMedian $scStats.LatMedian
Fmt-Row "P90"    $drStats.LatP90    $scStats.LatP90
Fmt-Row "P95"    $drStats.LatP95    $scStats.LatP95
Fmt-Row "P99"    $drStats.LatP99    $scStats.LatP99

# ── 速度比較 ─────────────────────────────────────────────
$meanRatio = if ($scStats.LatMean -gt 0) { [math]::Round($drStats.LatMean / $scStats.LatMean, 2) } else { 0 }
$p99Ratio  = if ($scStats.LatP99  -gt 0) { [math]::Round($drStats.LatP99  / $scStats.LatP99,  2) } else { 0 }
$tpsRatio  = if ($drStats.TPS     -gt 0) { [math]::Round($scStats.TPS     / $drStats.TPS,     2) } else { 0 }

Write-Host "`n🏆 效能比較（Switch-Case 相對 Drools）"
Write-Host "   Mean 延遲比  : Drools 是 Switch-Case 的 ${meanRatio}x"
Write-Host "   P99  延遲比  : Drools 是 Switch-Case 的 ${p99Ratio}x"
Write-Host "   TPS  比      : Switch-Case 是 Drools 的 ${tpsRatio}x"

# ── 特殊公司規則命中確認 ──────────────────────────────────
Write-Host "`n🏢 特殊公司規則命中確認"
foreach ($sid in $SPECIAL_COMPANIES) {
    foreach ($roundData in @(
        @{ Name="Drools";       Rows=$droolsRound.Results },
        @{ Name="Switch-Case";  Rows=$legacyRound.Results }
    )) {
        $compRows    = @($roundData.Rows | Where-Object { $_.CompanyId -eq $sid })
        $restDayRows = @($compRows       | Where-Object { $_.OvertimeType -eq "REST_DAY" })
        $hitRows     = @($restDayRows    | Where-Object { $_.AppliedRule -like "*$sid*" })
        $avgLat      = if ($compRows.Count -gt 0) {
            [math]::Round(($compRows | ForEach-Object { $_.ElapsedMs } | Measure-Object -Average).Average, 1)
        } else { 0 }
        Write-Host "  [$($roundData.Name)] 公司 ${sid}："
        Write-Host "    REST_DAY 請求數   : $($restDayRows.Count)"
        Write-Host "    專屬規則命中數    : $($hitRows.Count)"
        Write-Host "    平均延遲          : $avgLat ms"
    }
}

# ── 各加班類型統計 ────────────────────────────────────────
Write-Host "`n📊 各加班類型統計（Drools / Switch-Case）"
Write-Host ("  " + "類型".PadRight(22) + "請求(D/S)".PadLeft(12) + "違規(D/S)".PadLeft(12) + "均延遲D(ms)".PadLeft(13) + "均延遲S(ms)".PadLeft(13))
Write-Host ("  " + "─" * 72)

foreach ($ot in $OVERTIME_TYPES) {
    $drRows  = @($drStats.SuccessRows | Where-Object { $_.OvertimeType -eq $ot })
    $scRows  = @($scStats.SuccessRows | Where-Object { $_.OvertimeType -eq $ot })
    $drVio   = @($drRows | Where-Object { $_.Violated -eq $true })
    $scVio   = @($scRows | Where-Object { $_.Violated -eq $true })
    $drAvg   = if ($drRows.Count -gt 0) { [math]::Round(($drRows | ForEach-Object { $_.ElapsedMs } | Measure-Object -Average).Average, 1) } else { 0 }
    $scAvg   = if ($scRows.Count -gt 0) { [math]::Round(($scRows | ForEach-Object { $_.ElapsedMs } | Measure-Object -Average).Average, 1) } else { 0 }
    Write-Host ("  " + $ot.PadRight(22) + "$($drRows.Count)/$($scRows.Count)".PadLeft(12) + "$($drVio.Count)/$($scVio.Count)".PadLeft(12) + $drAvg.ToString().PadLeft(13) + $scAvg.ToString().PadLeft(13))
}

# ── 結果一致性檢查 ────────────────────────────────────────
Write-Host "`n🔍 結果一致性檢查（violated 欄位）"
$drMap = @{}
foreach ($r in $droolsRound.Results) { $drMap[$r.Label] = $r }
$mismatch = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($sc in $legacyRound.Results) {
    $dr = $drMap[$sc.Label]
    if ($dr -and $dr.Status -eq 200 -and $sc.Status -eq 200) {
        if ($dr.Violated -ne $sc.Violated) {
            $mismatch.Add([PSCustomObject]@{
                Label        = $sc.Label
                OvertimeType = $sc.OvertimeType
                Hours        = $sc.OvertimeHours
                DR_Violated  = $dr.Violated
                SC_Violated  = $sc.Violated
                DR_Rule      = $dr.AppliedRule
                SC_Rule      = $sc.AppliedRule
            })
        }
    }
}

if ($mismatch.Count -eq 0) {
    Write-Host "  ✅ 全部 $($droolsRound.Results.Count) 筆結果一致，violated 欄位完全吻合"
} else {
    Write-Host "  ❌ 發現 $($mismatch.Count) 筆不一致："
    $mismatch | Select-Object -First 10 | ForEach-Object {
        Write-Host "    [$($_.OvertimeType) $($_.Hours)H] $($_.Label)"
        Write-Host "      Drools: violated=$($_.DR_Violated)  rule=$($_.DR_Rule)"
        Write-Host "      Switch: violated=$($_.SC_Violated)  rule=$($_.SC_Rule)"
    }
}

Write-Host "`n💾 Server 記憶體變化"
Write-Host "  測試前        : $memBefore"
Write-Host "  Drools 後     : $memMid"
Write-Host "  Switch-Case 後: $memAfter"

if ($drStats.Failed -gt 0 -or $scStats.Failed -gt 0) {
    Write-Host "`n❌ 失敗請求（前 10 筆）"
    $allFailed = @($drStats.FailedRows) + @($scStats.FailedRows)
    $allFailed | Select-Object -First 10 | ForEach-Object {
        Write-Host "  [$($_.Round)][$($_.Status)] $($_.EmployeeId) | $($_.OvertimeType) | $($_.Error)"
    }
}

# ============================================================
# 輸出 CSV（兩輪合併）
# ============================================================
$allResults = @($droolsRound.Results) + @($legacyRound.Results)
$allResults | Export-Csv -Path $CSV_FILE -NoTypeInformation -Encoding UTF8
Write-Host "`n✅ CSV 已儲存至：$CSV_FILE"

# ============================================================
# 輸出 JSON 摘要
# ============================================================
[ordered]@{
    testTime   = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    drools     = [ordered]@{
        total       = $drStats.Total
        success     = $drStats.Success
        failed      = $drStats.Failed
        violated    = $drStats.Violated
        wallSeconds = $drStats.WallSeconds
        tps         = $drStats.TPS
        latency     = [ordered]@{
            min    = $drStats.LatMin
            max    = $drStats.LatMax
            mean   = $drStats.LatMean
            median = $drStats.LatMedian
            p90    = $drStats.LatP90
            p95    = $drStats.LatP95
            p99    = $drStats.LatP99
        }
    }
    switchCase = [ordered]@{
        total       = $scStats.Total
        success     = $scStats.Success
        failed      = $scStats.Failed
        violated    = $scStats.Violated
        wallSeconds = $scStats.WallSeconds
        tps         = $scStats.TPS
        latency     = [ordered]@{
            min    = $scStats.LatMin
            max    = $scStats.LatMax
            mean   = $scStats.LatMean
            median = $scStats.LatMedian
            p90    = $scStats.LatP90
            p95    = $scStats.LatP95
            p99    = $scStats.LatP99
        }
    }
    comparison = [ordered]@{
        meanRatio     = $meanRatio
        p99Ratio      = $p99Ratio
        tpsRatio      = $tpsRatio
        mismatchCount = $mismatch.Count
    }
    memory     = [ordered]@{
        before     = $memBefore
        afterDrools= $memMid
        afterSwitch= $memAfter
    }
} | ConvertTo-Json -Depth 6 | Out-File -FilePath $JSON_FILE -Encoding UTF8

Write-Host "✅ JSON 摘要已儲存至：$JSON_FILE"
Write-Host ("=" * 60)
