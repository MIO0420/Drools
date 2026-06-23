# ============================================================
# 實驗三：租戶隔離正確性（併發壓力版）
#
# 改版重點：
#   A 公司 500 筆、B 公司 500 筆、C 公司 500 筆（共 1500 筆）
#   三家各自打包成一個批次請求，三個請求「同時併發」送出。
#
#   驗證：
#     (1) 三家公司在同時併發結算下，各走各的客製比例（正確性）
#     (2) 併發下租戶隔離不被污染（A 不含乙、B 不含甲）
#     (3) 併發吞吐：總牆鐘時間 ≈ 三家最大值（而非加總）→ 證明真併發
#
# 底薪 36000、workingDaysInMonth 30 → 時薪 150（36000/30/8）
# 8 小時扣薪基準 = 150 × 8 = 1200（100%）
#
# 扣薪比例對照（8H）：
#   假別         通用(C)   A客製    B客製
#   普通病假      50%      30%     10%
#   事假         100%     80%     50%
#   家庭照顧假    100%     50%     20%
#   育嬰假       100%     60%     30%
#   生理假       不扣      不扣     不扣
# ============================================================

# ── TLS 與連線數設定（併發必備）──────────────────────────────
# DefaultConnectionLimit 預設僅 2，會把對同一主機的 3 個請求限流成 2，
# 必須調高才能讓三家真正同時送出。
[System.Net.ServicePointManager]::SecurityProtocol    = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::DefaultConnectionLimit = 100

$calcUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$BASE           = 36000
$H8             = 1200          # 8H × 時薪150 = 100% 扣薪基準
$PER_COMPANY    = 500           # 每家公司送出的筆數
$companies      = @("A", "B", "C")
$leaveTypes     = @("普通病假", "事假", "家庭照顧假", "育嬰假", "生理假")

# ── 預期扣薪表（company → leaveType → 預期 leaveDeduction）──────
$expect = @{
    "A" = @{ "普通病假" = ($H8*0.3); "事假" = ($H8*0.8); "家庭照顧假" = ($H8*0.5); "育嬰假" = ($H8*0.6); "生理假" = 0 }
    "B" = @{ "普通病假" = ($H8*0.1); "事假" = ($H8*0.5); "家庭照顧假" = ($H8*0.2); "育嬰假" = ($H8*0.3); "生理假" = 0 }
    "C" = @{ "普通病假" = ($H8*0.5); "事假" = ($H8*1.0); "家庭照顧假" = ($H8*1.0); "育嬰假" = ($H8*1.0); "生理假" = 0 }
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

Write-Host "============================================================" -ForegroundColor White
Write-Host " 實驗三：租戶隔離正確性（併發壓力版）  底薪 $BASE  時薪 150" -ForegroundColor White
Write-Host (" A/B/C 各 {0} 筆，共 {1} 筆，三個請求同時併發送出" -f $PER_COMPANY, ($PER_COMPANY*3)) -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# ── 1. 為每家公司各組裝 500 筆批次資料 ───────────────────────
$payloads = @{}   # company → UTF8 bytes
$metaAll  = @{}   # company → ( employeeId → @{ leaveType; expected } )

foreach ($c in $companies) {
    $recs = New-Object System.Collections.Generic.List[object]
    $m    = @{}
    for ($i = 0; $i -lt $PER_COMPANY; $i++) {
        $lt  = $leaveTypes[$i % 5]                 # 五個假別輪替，各 100 筆
        $eid = "E3-{0}-{1:D4}" -f $c, $i
        $recs.Add(@{
            employeeId         = $eid
            baseSalary         = $BASE
            companyId          = $c
            workingDaysInMonth = 30
            tenureMonths       = 12
            seniorityMonths    = 12
            leaves             = @(@{ employeeId = $eid; leaveTypeName = $lt; leaveHours = 8 })
            overtimes          = @()
        })
        $m[$eid] = @{ leaveType = $lt; expected = $expect[$c][$lt] }
    }
    $json          = $recs | ConvertTo-Json -Depth 10
    $payloads[$c]  = [System.Text.Encoding]::UTF8.GetBytes($json)
    $metaAll[$c]   = $m
    Write-Host ("    已組裝 {0} 公司 {1} 筆（payload {2:N0} bytes）" -f $c, $PER_COMPANY, $payloads[$c].Length) -ForegroundColor DarkGray
}

# ── 2. 用 RunspacePool 真併發送出三個請求 ────────────────────
$worker = {
    param($url, $bytes)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $r = Invoke-WebRequest -Uri $url -Method Post -Body $bytes `
                -ContentType "application/json; charset=utf-8" -UseBasicParsing
        $sw.Stop()
        [pscustomobject]@{
            ok         = $true
            elapsedMs  = $sw.ElapsedMilliseconds
            serverMs   = $r.Headers["X-Execution-Time-Ms"]
            pureMs     = $r.Headers["X-Drools-Pure-Compute-Ms"]
            batchCount = $r.Headers["X-Batch-Count"]
            status     = [int]$r.StatusCode
            content    = $r.Content
        }
    } catch {
        $sw.Stop()
        [pscustomobject]@{ ok = $false; elapsedMs = $sw.ElapsedMilliseconds; error = $_.Exception.Message }
    }
}

$pool = [runspacefactory]::CreateRunspacePool(1, 3)
$pool.Open()

# 先建好三個 PowerShell instance（不執行），讓 BeginInvoke 盡量同時
$jobs = @()
foreach ($c in $companies) {
    $ps = [powershell]::Create()
    $ps.RunspacePool = $pool
    [void]$ps.AddScript($worker).AddArgument($calcUrl).AddArgument($payloads[$c])
    $jobs += [pscustomobject]@{ company = $c; ps = $ps; handle = $null }
}

Write-Host "`n三個請求同時送出中..." -ForegroundColor Yellow
$wall = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($j in $jobs) { $j.handle = $j.ps.BeginInvoke() }   # 全部非同步啟動

# 等全部完成並收集結果
$resp = @{}
foreach ($j in $jobs) {
    $out = $j.ps.EndInvoke($j.handle)
    $resp[$j.company] = $out[0]
    $j.ps.Dispose()
}
$wall.Stop()
$pool.Close(); $pool.Dispose()

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
if ($maxElapsed -gt 0) {
    $ratio = [math]::Round($sumElapsed / $wallMs, 2)
    Write-Host ("  併發加速比（加總/牆鐘） : {0}x  → 越接近 3 代表併發度越高" -f $ratio) -ForegroundColor Green
}
Write-Host ("  全體平均每筆            : {0:N3} ms / 筆（{1} 筆 / 牆鐘）" -f ($wallMs / ($PER_COMPANY*3)), ($PER_COMPANY*3))

# ── 4. 逐筆驗證正確性 + 隔離性 ───────────────────────────────
$okByCompany   = @{ "A" = 0; "B" = 0; "C" = 0 }
$failByCompany = @{ "A" = 0; "B" = 0; "C" = 0 }
$byKey         = @{}   # "公司|假別" → 實際回傳值（抽樣用）

foreach ($c in $companies) {
    $r = $resp[$c]
    if (-not $r.ok) {
        Check $false "$c 公司請求失敗：$($r.error)" "" ""
        $failByCompany[$c] += $PER_COMPANY
        continue
    }

    $arr = $r.content | ConvertFrom-Json
    Check ($arr.Count -eq $PER_COMPANY) "$c 公司回傳筆數應為 $PER_COMPANY" $arr.Count $PER_COMPANY

    foreach ($w in $arr) {
        $meta = $metaAll[$c][$w.employeeId]
        if ($null -eq $meta) {
            Check $false "$c 出現未知 employeeId：$($w.employeeId)" "" ""
            $failByCompany[$c]++; continue
        }
        if ($w.error) {
            Check $false "$($w.employeeId) 回傳錯誤：$($w.error)" "" ""
            $failByCompany[$c]++; continue
        }

        $got     = [decimal]$w.result.leaveDeduction
        $exp     = [decimal]$meta.expected
        $ruleStr = ($w.result.ruleDetails -join "")

        # (1) 扣薪比例正確
        $okAmount = ($got -eq $exp)
        if (-not $okAmount) {
            Check $false "$c $($meta.leaveType) 扣薪應為 $exp（$($w.employeeId)）" $got $exp
        } else { $script:pass++ }

        # (2) 租戶隔離
        $okIso = $true
        if ($c -eq "A" -and ($ruleStr -match "乙公司")) { Check $false "A 結果不應含乙公司規則（$($w.employeeId)）" "" ""; $okIso = $false }
        if ($c -eq "B" -and ($ruleStr -match "甲公司")) { Check $false "B 結果不應含甲公司規則（$($w.employeeId)）" "" ""; $okIso = $false }

        if ($okAmount -and $okIso) { $okByCompany[$c]++ } else { $failByCompany[$c]++ }

        $k = "{0}|{1}" -f $c, $meta.leaveType
        if (-not $byKey.ContainsKey($k)) { $byKey[$k] = $got }
    }
}

# ── 5. 彙總 ──────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host (" 實驗三併發測試：PASS {0}  |  FAIL {1}" -f $pass, $fail) -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

Write-Host "`n[ 各公司驗證通過數（金額正確且隔離成立）]" -ForegroundColor Cyan
Write-Host ("  {0,-8} {1,-10} {2,-10}" -f "公司", "通過", "失敗")
foreach ($c in $companies) {
    $color = if ($failByCompany[$c] -eq 0) { "Green" } else { "Red" }
    Write-Host ("  {0,-8} {1,-10} {2,-10}" -f $c, $okByCompany[$c], $failByCompany[$c]) -ForegroundColor $color
}

# ── 6. 三方扣薪對照（實際回傳抽樣）───────────────────────────
Write-Host "`n[ 三方扣薪對照（實際回傳抽樣，8H 時薪150）]" -ForegroundColor Cyan
Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10}" -f "假別", "A客製", "B客製", "C通用")
foreach ($lt in $leaveTypes) {
    Write-Host ("  {0,-12} {1,-10} {2,-10} {3,-10}" -f `
        $lt, $byKey["A|$lt"], $byKey["B|$lt"], $byKey["C|$lt"])
}