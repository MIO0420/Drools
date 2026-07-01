# ============================================================
# 實驗三：租戶隔離正確性（併發 + 隨機化資料版）
#
# 改版重點：
#   A/B/C 各 500 筆（共 1500 筆），三個請求同時併發送出。
#   每一筆的「底薪、請假時數、假別、年資」皆隨機不同，更貼近真實資料。
#
#   扣薪公式（後端固定）：
#     時薪   = 底薪 ÷ 30 ÷ 8      （後端 dailySalary 寫死除以 30）
#     扣薪   = 時薪 × 請假時數 × 比例（比例固定在各公司規則庫）
#     最終以 setScale(2, HALF_UP) 取到小數兩位
#   → 故每筆可逐筆動態算出預期扣薪再比對（保留 0.01 容差）。
#
#   為避免浮點進位誤差：底薪取 240 的倍數（時薪剛好為整數）。
#   設固定亂數種子，結果可重現。
#
#   三層驗證：
#     (1) 扣薪金額正確（動態預期，容差 0.01）
#     (2) 租戶隔離（A 不含乙公司、B 不含甲公司）
#     (3) 確實走到各自規則（A 含甲公司客製 / B 含乙公司客製 / C 不含任何客製）
#
# 扣薪比例對照：
#   假別         通用(C)   A客製    B客製
#   普通病假      50%      30%     10%
#   事假         100%     80%     50%
#   家庭照顧假    100%     50%     20%
#   育嬰假       100%     60%     30%
#   生理假       不扣      不扣     不扣
# ============================================================

# ── TLS 與連線數設定（併發必備）──────────────────────────────
[System.Net.ServicePointManager]::SecurityProtocol       = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::DefaultConnectionLimit = 100

$calcUrl     = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$PER_COMPANY = 500
$companies   = @("A", "B", "C")
$leaveTypes  = @("普通病假", "事假", "家庭照顧假", "育嬰假", "生理假")

# 固定亂數種子 → 每次跑出同一組隨機資料（可重現）
Get-Random -SetSeed 20250101 | Out-Null

# ── 各公司各假別的扣薪「比例」（非固定金額，金額逐筆算）────────
$rate = @{
    "A" = @{ "普通病假" = 0.3; "事假" = 0.8; "家庭照顧假" = 0.5; "育嬰假" = 0.6; "生理假" = 0.0 }
    "B" = @{ "普通病假" = 0.1; "事假" = 0.5; "家庭照顧假" = 0.2; "育嬰假" = 0.3; "生理假" = 0.0 }
    "C" = @{ "普通病假" = 0.5; "事假" = 1.0; "家庭照顧假" = 1.0; "育嬰假" = 1.0; "生理假" = 0.0 }
}

$pass = 0; $fail = 0
function Check($cond, $msg, $got, $exp) {
    if ($cond) { $script:pass++ }
    else {
        $script:fail++
        $detail = if ($null -ne $got) { "（得到 $got，預期 $exp）" } else { "" }
        Write-Host "    [FAIL] $msg $detail" -ForegroundColor Red
    }
}

# 後端扣薪公式（PowerShell 端複刻）：時薪 = 底薪/30/8；扣薪 = 時薪 × 時數 × 比例
function Predict($baseSalary, $hours, $r) {
    $hourly = $baseSalary / 240.0            # = baseSalary/30/8（baseSalary 取 240 倍數 → 整數）
    $raw    = [double]$hourly * [double]$hours * [double]$r
    return [math]::Round($raw, 2, [System.MidpointRounding]::AwayFromZero)
}

Write-Host "============================================================" -ForegroundColor White
Write-Host " 實驗三：租戶隔離正確性（併發 + 隨機化資料版）" -ForegroundColor White
Write-Host (" A/B/C 各 {0} 筆，共 {1} 筆，每筆底薪/時數/假別/年資皆不同" -f $PER_COMPANY, ($PER_COMPANY*3)) -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# ── 1. 為每家公司各組裝 500 筆「隨機」批次資料 ───────────────
$payloads = @{}   # company → UTF8 bytes
$metaAll  = @{}   # company → ( employeeId → @{ leaveType; baseSalary; hours; expected } )
$minSal = [int]::MaxValue; $maxSal = 0; $minH = [int]::MaxValue; $maxH = 0

foreach ($c in $companies) {
    $recs = New-Object System.Collections.Generic.List[object]
    $m    = @{}
    for ($i = 0; $i -lt $PER_COMPANY; $i++) {
        $lt    = $leaveTypes[$i % 5]                          # 假別輪替，確保五種各約 100 筆
        $base  = (Get-Random -Minimum 100 -Maximum 376) * 240 # 24,000 ~ 90,000，且為 240 倍數
        $hours = Get-Random -Minimum 1 -Maximum 17            # 1 ~ 16 小時
        $tenure= Get-Random -Minimum 1 -Maximum 241           # 1 ~ 240 個月年資（增加真實性）
        $eid   = "E3-{0}-{1:D4}" -f $c, $i
        $exp   = Predict $base $hours $rate[$c][$lt]

        $recs.Add(@{
            employeeId         = $eid
            baseSalary         = $base
            companyId          = $c
            workingDaysInMonth = 30
            tenureMonths       = $tenure
            seniorityMonths    = $tenure
            leaves             = @(@{ employeeId = $eid; leaveTypeName = $lt; leaveHours = $hours })
            overtimes          = @()
        })
        $m[$eid] = @{ leaveType = $lt; baseSalary = $base; hours = $hours; expected = $exp }

        if ($base  -lt $minSal) { $minSal = $base };  if ($base  -gt $maxSal) { $maxSal = $base }
        if ($hours -lt $minH)   { $minH   = $hours }; if ($hours -gt $maxH)   { $maxH   = $hours }
    }
    $json         = $recs | ConvertTo-Json -Depth 10
    $payloads[$c] = [System.Text.Encoding]::UTF8.GetBytes($json)
    $metaAll[$c]  = $m
    Write-Host ("    已組裝 {0} 公司 {1} 筆（payload {2:N0} bytes）" -f $c, $PER_COMPANY, $payloads[$c].Length) -ForegroundColor DarkGray
}
Write-Host ("    資料多樣性：底薪 {0:N0}~{1:N0}　請假時數 {2}~{3} 小時" -f $minSal, $maxSal, $minH, $maxH) -ForegroundColor DarkGray

# ── 2. 用 RunspacePool 真併發送出三個請求 ────────────────────
$worker = {
    param($url, $bytes)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-WebRequest -Uri $url -Method Post -Body $bytes `
                -ContentType "application/json; charset=utf-8" -UseBasicParsing
        $sw.Stop()
        [pscustomobject]@{
            ok = $true; elapsedMs = $sw.ElapsedMilliseconds
            serverMs = $r.Headers["X-Execution-Time-Ms"]; pureMs = $r.Headers["X-Drools-Pure-Compute-Ms"]
            batchCount = $r.Headers["X-Batch-Count"]; status = [int]$r.StatusCode; content = $r.Content
        }
    } catch {
        $sw.Stop()
        [pscustomobject]@{ ok = $false; elapsedMs = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
    }
}

$pool = [runspacefactory]::CreateRunspacePool(1, 3)
$pool.Open()
$jobs = @()
foreach ($c in $companies) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($worker).AddArgument($calcUrl).AddArgument($payloads[$c])
    $jobs += [pscustomobject]@{ company = $c; ps = $ps; handle = $null }
}

Write-Host "`n三個請求同時送出中..." -ForegroundColor Yellow
$wall = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($j in $jobs) { $j.handle = $j.ps.BeginInvoke() }
$resp = @{}
foreach ($j in $jobs) { $out = $j.ps.EndInvoke($j.handle); $resp[$j.company] = $out[0]; $j.ps.Dispose() }
$wall.Stop(); $pool.Close(); $pool.Dispose()
$wallMs = $wall.ElapsedMilliseconds

# ── 3. 效能彙整 ──────────────────────────────────────────────
function HdrVal($v) { if ($v -is [array]) { $v[0] } else { $v } }
Write-Host "`n--- 併發效能 ---" -ForegroundColor Cyan
Write-Host ("  {0,-8} {1,-14} {2,-16} {3,-16} {4,-10}" -f "公司", "往返(ms)", "伺服器(ms)", "純引擎(ms)", "回傳筆數")
$sumElapsed = 0; $maxElapsed = 0
foreach ($c in $companies) {
    $r = $resp[$c]
    if ($r.ok) {
        $sumElapsed += $r.elapsedMs
        if ($r.elapsedMs -gt $maxElapsed) { $maxElapsed = $r.elapsedMs }
        Write-Host ("  {0,-8} {1,-14} {2,-16} {3,-16} {4,-10}" -f `
            $c, $r.elapsedMs, (HdrVal $r.serverMs), (HdrVal $r.pureMs), (HdrVal $r.batchCount))
    } else {
        Write-Host ("  {0,-8} 請求失敗：{1}" -f $c, $r.error) -ForegroundColor Red
    }
}
Write-Host ""
Write-Host ("  牆鐘總耗時（三家併發）  : {0} ms" -f $wallMs) -ForegroundColor Green
Write-Host ("  三家往返時間加總        : {0} ms" -f $sumElapsed)
Write-Host ("  三家往返最大值          : {0} ms" -f $maxElapsed)
if ($wallMs -gt 0) {
    Write-Host ("  併發加速比（加總/牆鐘） : {0}x  → 越接近 3 代表併發度越高" -f ([math]::Round($sumElapsed / $wallMs, 2))) -ForegroundColor Green
    Write-Host ("  全體平均每筆            : {0:N3} ms / 筆（{1} 筆 / 牆鐘）" -f ($wallMs / ($PER_COMPANY*3)), ($PER_COMPANY*3))
}

# ── 4. 逐筆驗證：金額（動態預期）+ 隔離 + 走對規則 ────────────
$okByCompany      = @{ "A" = 0; "B" = 0; "C" = 0 }
$failByCompany    = @{ "A" = 0; "B" = 0; "C" = 0 }
$routeOkByCompany = @{ "A" = 0; "B" = 0; "C" = 0 }
$detail           = @{ "A" = (New-Object System.Collections.Generic.List[object]); "B" = (New-Object System.Collections.Generic.List[object]); "C" = (New-Object System.Collections.Generic.List[object]) }

foreach ($c in $companies) {
    $r = $resp[$c]
    if (-not $r.ok) {
        Check $false "$c 公司請求失敗：$($r.error)" "" ""; $failByCompany[$c] += $PER_COMPANY; continue
    }
    $arr = $r.content | ConvertFrom-Json
    Check ($arr.Count -eq $PER_COMPANY) "$c 公司回傳筆數應為 $PER_COMPANY" $arr.Count $PER_COMPANY

    foreach ($w in $arr) {
        $meta = $metaAll[$c][$w.employeeId]
        if ($null -eq $meta) { Check $false "$c 未知 employeeId：$($w.employeeId)" "" ""; $failByCompany[$c]++; continue }
        if ($w.error)        { Check $false "$($w.employeeId) 回傳錯誤：$($w.error)" "" ""; $failByCompany[$c]++; continue }

        $got     = [decimal]$w.result.leaveDeduction
        $exp     = [decimal]$meta.expected
        $ruleStr = ($w.result.ruleDetails -join "")
        $lt      = $meta.leaveType

        # (1) 金額正確（動態預期，容差 0.01）
        $okAmount = ([math]::Abs([double]$got - [double]$exp) -le 0.01)
        if (-not $okAmount) {
            Check $false ("{0} {1} 底薪{2} {3}h 扣薪應為 {4}（{5}）" -f $c, $lt, $meta.baseSalary, $meta.hours, $exp, $w.employeeId) $got $exp
        } else { $script:pass++ }

        # (2) 租戶隔離（否定式）
        $okIso = $true
        if ($c -eq "A" -and ($ruleStr -match "乙公司")) { Check $false "A 不應含乙公司規則（$($w.employeeId)）" "" ""; $okIso = $false }
        if ($c -eq "B" -and ($ruleStr -match "甲公司")) { Check $false "B 不應含甲公司規則（$($w.employeeId)）" "" ""; $okIso = $false }

        # (3) 確實走到各自規則（肯定式，含生理假）
        $okRoute = $true
        if ($c -eq "A" -and ($ruleStr -notmatch "甲公司客製")) { Check $false "A $lt 應觸發甲公司客製規則（$($w.employeeId)）" "" ""; $okRoute = $false }
        if ($c -eq "B" -and ($ruleStr -notmatch "乙公司客製")) { Check $false "B $lt 應觸發乙公司客製規則（$($w.employeeId)）" "" ""; $okRoute = $false }
        if ($c -eq "C" -and (($ruleStr -match "甲公司客製") -or ($ruleStr -match "乙公司客製"))) { Check $false "C $lt 不應含任何公司客製標記（$($w.employeeId)）" "" ""; $okRoute = $false }
        if ($okRoute) { $routeOkByCompany[$c]++ }

        if ($okAmount -and $okIso -and $okRoute) { $okByCompany[$c]++ } else { $failByCompany[$c]++ }

        $detail[$c].Add([pscustomobject]@{ eid = $w.employeeId; lt = $lt; base = $meta.baseSalary; h = $meta.hours; exp = $exp; got = $got })
    }
}

# ── 5. 彙總 ──────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host (" 實驗三併發 + 隨機化測試：PASS {0}  |  FAIL {1}" -f $pass, $fail) -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Write-Host "`n[ 各公司驗證通過數（金額正確 + 隔離成立 + 走對規則）]" -ForegroundColor Cyan
Write-Host ("  {0,-8} {1,-10} {2,-10} {3,-12}" -f "公司", "通過", "失敗", "走對規則數")
foreach ($c in $companies) {
    $color = if ($failByCompany[$c] -eq 0) { "Green" } else { "Red" }
    Write-Host ("  {0,-8} {1,-10} {2,-10} {3,-12}" -f $c, $okByCompany[$c], $failByCompany[$c], $routeOkByCompany[$c]) -ForegroundColor $color
}

# ── 6. 多樣性統計（量化證明每筆資料不同）────────────────────
Write-Host "`n[ 測試資料多樣性統計（每家 500 筆）]" -ForegroundColor Cyan
Write-Host ("  {0,-6} {1,-14} {2,-12} {3,-18} {4,-14}" -f "公司", "不同底薪數", "不同時數數", "不同(底薪+時數+假別)", "最多重複組合")
foreach ($c in $companies) {
    $rows       = $detail[$c]
    $distBase   = ($rows | Select-Object -ExpandProperty base  -Unique).Count
    $distHours  = ($rows | Select-Object -ExpandProperty h     -Unique).Count
    $combos     = $rows | ForEach-Object { "{0}|{1}|{2}" -f $_.base, $_.h, $_.lt }
    $distCombo  = ($combos | Select-Object -Unique).Count
    $maxDup     = ($combos | Group-Object | Sort-Object Count -Descending | Select-Object -First 1).Count
    Write-Host ("  {0,-6} {1,-14} {2,-12} {3,-18} {4,-14}" -f $c, $distBase, $distHours, $distCombo, $maxDup)
}
Write-Host "  說明：employeeId 全數唯一；同一(底薪+時數+假別)組合最多重複次數越小，代表輸入越分散。" -ForegroundColor DarkGray

# ── 7. 隨機抽樣明細（每家隨機 10 筆，預期=實際逐筆對照）──────
Write-Host "`n[ 隨機抽樣 10 筆 / 家（輸入皆不同、預期=實際）]" -ForegroundColor Cyan
Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-8} {4,-12} {5,-12} {6}" -f "員工編號", "假別", "底薪", "時數", "預期扣薪", "實際扣薪", "符合")
foreach ($c in $companies) {
    $pick = $detail[$c] | Get-Random -Count ([math]::Min(10, $detail[$c].Count))
    foreach ($s in $pick) {
        $ok = if ([math]::Abs([double]$s.got - [double]$s.exp) -le 0.01) { "OK" } else { "X" }
        $color = if ($ok -eq "OK") { "Gray" } else { "Red" }
        Write-Host ("  {0,-12} {1,-12} {2,-10} {3,-8} {4,-12} {5,-12} {6}" -f $s.eid, $s.lt, $s.base, $s.h, $s.exp, $s.got, $ok) -ForegroundColor $color
    }
    Write-Host ""
}

# ── 7b. 完整覆蓋抽樣（每家公司 × 每假別 各 2 筆，共 30 筆）──────
$SAMPLE_PER = 2
Write-Host "`n[ 完整覆蓋抽樣：每家 × 每假別 各 $SAMPLE_PER 筆（按假別分組）]" -ForegroundColor Cyan
Write-Host ("  {0,-10} {1,-6} {2,-12} {3,-10} {4,-8} {5,-8} {6,-12} {7,-12} {8}" -f `
    "假別", "公司", "員工編號", "底薪", "時數", "比例", "預期扣薪", "實際扣薪", "符合")
foreach ($lt in $leaveTypes) {
    foreach ($c in $companies) {
        $pool = @($detail[$c] | Where-Object { $_.lt -eq $lt })
        if ($pool.Count -eq 0) {
            Write-Host ("  {0,-10} {1,-6} （此假別無資料）" -f $lt, $c) -ForegroundColor DarkYellow
            continue
        }
        $pick = $pool | Get-Random -Count ([math]::Min($SAMPLE_PER, $pool.Count))
        foreach ($s in $pick) {
            $pct = "{0:P0}" -f $rate[$c][$lt]
            $ok  = if ([math]::Abs([double]$s.got - [double]$s.exp) -le 0.01) { "OK" } else { "X" }
            $color = if ($ok -eq "OK") { "Gray" } else { "Red" }
            Write-Host ("  {0,-10} {1,-6} {2,-12} {3,-10} {4,-8} {5,-8} {6,-12} {7,-12} {8}" -f `
                $lt, $c, $s.eid, $s.base, $s.h, $pct, $s.exp, $s.got, $ok) -ForegroundColor $color
        }
    }
    Write-Host ""
}

# ── 7. 比例對照（參考值：底薪36000、8H 下的預期）──────────────
Write-Host "`n[ 三方扣薪比例對照（參考：底薪36000、8H、時薪150）]" -ForegroundColor Cyan
Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10}" -f "假別", "A客製", "B客製", "C通用")
foreach ($lt in $leaveTypes) {
    Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10}" -f `
        $lt, (Predict 36000 8 $rate["A"][$lt]), (Predict 36000 8 $rate["B"][$lt]), (Predict 36000 8 $rate["C"][$lt]))
}