# 低 / 中 / 高 三級距 — 交叉複雜度執行效能敏感度實驗
# 同一套 273 條規則 (公司25)，用不同員工觸發不同複雜度的程式碼路徑
# 重點：畫出「交叉複雜度 → 執行時間」曲線，比較 Drools 與硬編碼的增長斜率
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

# ============================================================
#  低交叉：STAFF、無部門、低年資、無加班、單純一張事假
#  → 硬編碼大量交叉 if 不成立，走簡單路徑
# ============================================================
function BuildLowCross($n) {
    $list = New-Object System.Collections.ArrayList
    $bases = @(30000,35000,40000,45000,50000)
    for ($i = 1; $i -le $n; $i++) {
        $id   = "L{0:D4}" -f $i
        $base = $bases[$i % $bases.Count]
        $emp = @{
            employeeId="$id"; baseSalary=$base; companyId="25"; workingDaysInMonth=30
            tenureMonths=6; seniorityMonths=6
            position="STAFF"; department=""
            leaves=@( @{ employeeId="$id"; leaveTypeName="事假"; leaveHours=8 } )
            overtimes=@()
            attendances=@()
        }
        [void]$list.Add($emp)
    }
    return $list.ToArray()
}

# ============================================================
#  中交叉：有職級(MANAGER) + 中年資、單一加班、無部門交叉、無全勤
#  → 觸發職級津貼 + 年資 + 單一加班，但不到全維度疊加
# ============================================================
function BuildMidCross($n) {
    $list = New-Object System.Collections.ArrayList
    $bases   = @(55000,60000,65000,70000,75000)
    $seniors = @(36,42,48,54,60)
    for ($i = 1; $i -le $n; $i++) {
        $id   = "M{0:D4}" -f $i
        $base = $bases[$i % $bases.Count]
        $sen  = $seniors[$i % $seniors.Count]
        $emp = @{
            employeeId="$id"; baseSalary=$base; companyId="25"; workingDaysInMonth=30
            tenureMonths=$sen; seniorityMonths=$sen
            position="MANAGER"; department=""        # 有職級但無部門 → 部分交叉
            leaves=@( @{ employeeId="$id"; leaveTypeName="事假"; leaveHours=8 } )
            overtimes=@( @{ employeeId="$id"; overtimeType="WEEKDAY"; overtimeHours=3 } )
            attendances=@()
        }
        [void]$list.Add($emp)
    }
    return $list.ToArray()
}

# ============================================================
#  高交叉：EXECUTIVE/DIRECTOR/MANAGER + RD/IT/SALES + 高年資
#          + 全勤 + 多張加班單
#  → 觸發 getCustomAllowances(208)、calcSeniorityBonusDirect(54) 等
# ============================================================
function BuildHighCross($n) {
    $list = New-Object System.Collections.ArrayList
    $posPool  = @("EXECUTIVE","DIRECTOR","MANAGER")
    $deptPool = @("RD","IT","SALES")
    $bases   = @(80000,90000,100000,110000,120000)
    $seniors = @(120,130,140,150,160)
    for ($i = 1; $i -le $n; $i++) {
        $id   = "H{0:D4}" -f $i
        $pos  = $posPool[$i % $posPool.Count]
        $dept = $deptPool[$i % $deptPool.Count]
        $base = $bases[$i % $bases.Count]
        $sen  = $seniors[$i % $seniors.Count]
        $emp = @{
            employeeId="$id"; baseSalary=$base; companyId="25"; workingDaysInMonth=30
            tenureMonths=$sen; seniorityMonths=$sen
            position="$pos"; department="$dept"
            leaves=@( @{ employeeId="$id"; leaveTypeName="普通病假"; leaveHours=8 } )
            overtimes=@(
                @{ employeeId="$id"; overtimeType="WEEKDAY";          overtimeHours=3 },
                @{ employeeId="$id"; overtimeType="REST_DAY";         overtimeHours=4 },
                @{ employeeId="$id"; overtimeType="NATIONAL_HOLIDAY"; overtimeHours=2 }
            )
            attendances=@( @{ employeeId="$id"; hasFullAttendance=$true; lateCount=0; earlyLeaveCount=0 } )
        }
        [void]$list.Add($emp)
    }
    return $list.ToArray()
}

# ── 送出並讀對等 header ──
function PostMeasure($url, $arr) {
    $body  = ($arr | ConvertTo-Json -Depth 10)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $sw    = [System.Diagnostics.Stopwatch]::StartNew()
    $resp  = Invoke-WebRequest -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -UseBasicParsing
    $sw.Stop()

    $droolsPure = $null
    if ($resp.Headers['X-Drools-Pure-Compute-Ms']) { $droolsPure = [double]($resp.Headers['X-Drools-Pure-Compute-Ms'] | Select-Object -First 1) }
    $legacyPure = $null
    if ($resp.Headers['X-Legacy-Pure-Compute-Ms']) { $legacyPure = [double]($resp.Headers['X-Legacy-Pure-Compute-Ms'] | Select-Object -First 1) }

    return @{ endToEnd=$sw.ElapsedMilliseconds; droolsPure=$droolsPure; legacyPure=$legacyPure }
}

function TrimAvg($arr) {
    $arr = $arr | Where-Object { $_ -ne $null }
    if ($arr.Count -ge 3) {
        $sorted = $arr | Sort-Object
        return [math]::Round((($sorted[1..($sorted.Count-2)]) | Measure-Object -Average).Average, 2)
    }
    if ($arr.Count -eq 0) { return 0 }
    return [math]::Round(($arr | Measure-Object -Average).Average, 2)
}

# ── 跑一組員工 ──
function RunGroup($label, $emps) {
    Write-Host "`n──────── $label (員工數 $($emps.Count)) ────────" -ForegroundColor Cyan

    Write-Host "  [暖機] 2 回合..." -ForegroundColor DarkYellow
    for ($w=1; $w -le 2; $w++) {
        $null = PostMeasure $droolsUrl $emps
        $null = PostMeasure $legacyUrl $emps
        Start-Sleep -Milliseconds 500
    }

    $dPure=@(); $lPure=@()
    for ($r=1; $r -le 5; $r++) {
        $d = PostMeasure $droolsUrl $emps
        $l = PostMeasure $legacyUrl $emps
        $dPure += $d.droolsPure
        $lPure += $l.legacyPure
        Write-Host ("    回合 {0}: Drools純 {1,6}ms / 硬編碼純 {2,6}ms" -f $r, $d.droolsPure, $l.legacyPure) -ForegroundColor Gray
        Start-Sleep -Milliseconds 400
    }

    $dAvg = TrimAvg $dPure
    $lAvg = TrimAvg $lPure
    Write-Host ("  → Drools {0}ms / 硬編碼 {1}ms" -f $dAvg, $lAvg) -ForegroundColor Yellow
    return @{ drools=$dAvg; legacy=$lAvg }
}

# ============================================================
#  主實驗
# ============================================================
$N = 500   # 每組員工數（相同，控制變數）；抖動大可再調到 1000

Write-Host "============================================================" -ForegroundColor White
Write-Host " 交叉複雜度執行效能敏感度 — 低/中/高 三級距" -ForegroundColor White
Write-Host " 同一套規則(公司25)，員工數固定 $N，比較增長斜率" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

$lowEmps  = BuildLowCross  $N
$midEmps  = BuildMidCross  $N
$highEmps = BuildHighCross $N

$low  = RunGroup "低交叉 (STAFF/無部門/低年資/無加班)"        $lowEmps
$mid  = RunGroup "中交叉 (MANAGER/中年資/單一加班)"          $midEmps
$high = RunGroup "高交叉 (高階+部門+高年資+全勤+多加班)"      $highEmps

# ── 結果表 ──
function Pct($base, $val) {
    if ($base -le 0) { return 0 }
    return [math]::Round(($val - $base) / $base * 100, 1)
}

$dMidInc  = Pct $low.drools $mid.drools
$dHighInc = Pct $low.drools $high.drools
$lMidInc  = Pct $low.legacy $mid.legacy
$lHighInc = Pct $low.legacy $high.legacy

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 實驗結果 — 交叉複雜度 vs 執行時間" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("                 低交叉     中交叉     高交叉")
Write-Host ("  -----------------------------------------------------")
Write-Host ("  Drools 純運算   {0,6}ms   {1,6}ms   {2,6}ms" -f $low.drools, $mid.drools, $high.drools)
Write-Host ("    (相對低交叉)    基準      +{0}%     +{1}%" -f $dMidInc, $dHighInc)
Write-Host ("  硬編碼 純運算   {0,6}ms   {1,6}ms   {2,6}ms" -f $low.legacy, $mid.legacy, $high.legacy)
Write-Host ("    (相對低交叉)    基準      +{0}%     +{1}%" -f $lMidInc, $lHighInc)
Write-Host ("  -----------------------------------------------------")
Write-Host ""
Write-Host "  ★ 解讀：比較「低→高」的總增幅斜率" -ForegroundColor Yellow
Write-Host ("     Drools 低→高 增幅: +{0}%" -f $dHighInc) -ForegroundColor Gray
Write-Host ("     硬編碼 低→高 增幅: +{0}%" -f $lHighInc) -ForegroundColor Gray
if ($lHighInc -gt $dHighInc) {
    $ratio = if ($dHighInc -ne 0) { [math]::Round($lHighInc / $dHighInc, 1) } else { "∞" }
    Write-Host ("     → 硬編碼增幅是 Drools 的 {0} 倍，對交叉複雜度更敏感" -f $ratio) -ForegroundColor Green
}
Write-Host ""
Write-Host "  ★ 三點可畫成「交叉複雜度 vs 執行時間」折線圖：" -ForegroundColor Yellow
Write-Host "     X軸=低/中/高, Y軸=純運算ms, 兩條線比較斜率陡峭度" -ForegroundColor Gray
Write-Host "  ★ 絕對時間硬編碼仍較快(Rete固定成本)，論點為增長率(斜率)" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Green

# ── 匯出 CSV 方便畫圖 ──
$csv = @(
    [PSCustomObject]@{ 複雜度="低交叉"; Drools=$low.drools;  硬編碼=$low.legacy  }
    [PSCustomObject]@{ 複雜度="中交叉"; Drools=$mid.drools;  硬編碼=$mid.legacy  }
    [PSCustomObject]@{ 複雜度="高交叉"; Drools=$high.drools; 硬編碼=$high.legacy }
)
$csv | Export-Csv -Path "cross_complexity_curve.csv" -NoTypeInformation -Encoding UTF8
Write-Host "曲線資料已匯出: cross_complexity_curve.csv" -ForegroundColor DarkGray