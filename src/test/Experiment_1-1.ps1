# ============================================================
#  低 / 中 / 高 三級距 — 交叉複雜度「送出一次要多久」實驗
#  同一套 273 條規則 (公司25)，員工數固定，比較 Drools 與硬編碼
#
#  ★ 量測目標：送出一次資料的『往返時間』(client end-to-end)
#    = 從 client 送出這批員工 → 收到回應 為止的實際等待時間
#    （包含網路來回 + 伺服器處理；這才是實際打一發 API 要等多久）
#
#  ★ 往返再拆解（參考用）：
#    - 伺服器：X-Execution-Time-Ms（整支函式在伺服器內耗時）
#    - 網路  ：往返 − 伺服器（來回傳輸 + 排隊）
#
#  ★ 冷啟動：先打一發把 KieContainer / RULE_CACHE 暖起來，
#    暖機後才計時，往返時間即不含冷啟動。
# ============================================================
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

# ============================================================
#  低交叉：STAFF、無部門、低年資、無加班、單純一張事假
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
#  中交叉：MANAGER + 中年資、單一加班、無部門交叉、無全勤
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
#  高交叉：高階 + 部門 + 高年資 + 全勤 + 多張加班單
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

# ── 送出並量『往返時間』(client end-to-end) ──
#    Stopwatch 包住整個 Invoke-WebRequest：送出 → 收到回應 的實際等待
function PostMeasure($url, $arr) {
    $body  = ($arr | ConvertTo-Json -Depth 10)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)

    $sw   = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-WebRequest -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -UseBasicParsing
    $sw.Stop()

    # 伺服器內耗時（拆解往返用，非主角）
    $execMs = $null
    if ($resp.Headers['X-Execution-Time-Ms']) { $execMs = [double]($resp.Headers['X-Execution-Time-Ms'] | Select-Object -First 1) }

    return @{ roundTrip=[double]$sw.ElapsedMilliseconds; serverMs=$execMs }
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

# ── 跑一組員工：量『送出一次的往返時間』──
function RunGroup($label, $emps) {
    Write-Host "`n──────── $label (員工數 $($emps.Count)) ────────" -ForegroundColor Cyan

    Write-Host "  [暖機] 2 回合（穩定 JIT / 連線）..." -ForegroundColor DarkYellow
    for ($w=1; $w -le 2; $w++) {
        $null = PostMeasure $droolsUrl $emps
        $null = PostMeasure $legacyUrl $emps
        Start-Sleep -Milliseconds 500
    }

    $dRT=@(); $dSrv=@(); $lRT=@(); $lSrv=@()
    for ($r=1; $r -le 5; $r++) {
        $d = PostMeasure $droolsUrl $emps
        $l = PostMeasure $legacyUrl $emps
        $dRT += $d.roundTrip ; $dSrv += $d.serverMs
        $lRT += $l.roundTrip ; $lSrv += $l.serverMs
        Write-Host ("    回合 {0}: Drools 往返 {1,6}ms (伺服器{2,4}/網路{3,4})  |  硬編碼 往返 {4,6}ms (伺服器{5,4}/網路{6,4})" -f `
            $r, $d.roundTrip, $d.serverMs, ($d.roundTrip - $d.serverMs), `
            $l.roundTrip, $l.serverMs, ($l.roundTrip - $l.serverMs)) -ForegroundColor Gray
        Start-Sleep -Milliseconds 400
    }

    $res = @{
        droolsRT  = TrimAvg $dRT ; droolsSrv = TrimAvg $dSrv
        legacyRT  = TrimAvg $lRT ; legacySrv = TrimAvg $lSrv
    }
    $res.droolsNet = [math]::Round($res.droolsRT - $res.droolsSrv, 2)
    $res.legacyNet = [math]::Round($res.legacyRT - $res.legacySrv, 2)
    Write-Host ("  → Drools 往返 {0}ms (伺服器{1}/網路{2})  |  硬編碼 往返 {3}ms (伺服器{4}/網路{5})" -f `
        $res.droolsRT, $res.droolsSrv, $res.droolsNet, $res.legacyRT, $res.legacySrv, $res.legacyNet) -ForegroundColor Yellow
    return $res
}

# ============================================================
#  主實驗
# ============================================================
$N = 500   # 每組員工數（相同，控制變數）

Write-Host "============================================================" -ForegroundColor White
Write-Host " 交叉複雜度 — 送出一次資料的往返時間（client end-to-end）" -ForegroundColor White
Write-Host " 同一套規則(公司25)，員工數固定 $N" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

$lowEmps  = BuildLowCross  $N
$midEmps  = BuildMidCross  $N
$highEmps = BuildHighCross $N

# ── 全域暖機：先把 KieContainer / RULE_CACHE 建好（吸收冷啟動）──
Write-Host "`n[暖機] 先打一發把 Drools KieContainer / Legacy RULE_CACHE 就緒..." -ForegroundColor DarkGray
$primeEmp = BuildLowCross 1
$null = PostMeasure $droolsUrl $primeEmp
$null = PostMeasure $legacyUrl $primeEmp
Start-Sleep -Milliseconds 500
Write-Host "[暖機] 完成，開始計時（以下往返時間皆不含冷啟動）" -ForegroundColor DarkGray

$expSw = [System.Diagnostics.Stopwatch]::StartNew()

$low  = RunGroup "低交叉 (STAFF/無部門/低年資/無加班)"        $lowEmps
$mid  = RunGroup "中交叉 (MANAGER/中年資/單一加班)"          $midEmps
$high = RunGroup "高交叉 (高階+部門+高年資+全勤+多加班)"      $highEmps

$expSw.Stop()
$experimentMs = [double]$expSw.ElapsedMilliseconds

# ── 結果表 ──
function Pct($base, $val) {
    if ($base -le 0) { return 0 }
    return [math]::Round(($val - $base) / $base * 100, 1)
}

# 往返(RT) 增長幅度
$dMidRT  = Pct $low.droolsRT $mid.droolsRT ; $dHighRT = Pct $low.droolsRT $high.droolsRT
$lMidRT  = Pct $low.legacyRT $mid.legacyRT ; $lHighRT = Pct $low.legacyRT $high.legacyRT
# 伺服器(Srv) 增長幅度
$dMidSrv = Pct $low.droolsSrv $mid.droolsSrv ; $dHighSrv = Pct $low.droolsSrv $high.droolsSrv
$lMidSrv = Pct $low.legacySrv $mid.legacySrv ; $lHighSrv = Pct $low.legacySrv $high.legacySrv

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 實驗結果 — 送出一次資料要多久（往返時間 ms）" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host ("                       低交叉     中交叉     高交叉")
Write-Host ("  -----------------------------------------------------------")
Write-Host ("  Drools 往返          {0,6}ms   {1,6}ms   {2,6}ms" -f $low.droolsRT, $mid.droolsRT, $high.droolsRT)
Write-Host ("    (往返 相對低交叉)    基準      +{0}%     +{1}%" -f $dMidRT, $dHighRT)
Write-Host ("    ├ 伺服器           {0,6}ms   {1,6}ms   {2,6}ms" -f $low.droolsSrv, $mid.droolsSrv, $high.droolsSrv)
Write-Host ("    │ (伺服器 相對低交叉) 基準     +{0}%     +{1}%" -f $dMidSrv, $dHighSrv)
Write-Host ("    └ 網路             {0,6}ms   {1,6}ms   {2,6}ms" -f $low.droolsNet, $mid.droolsNet, $high.droolsNet)
Write-Host ("  -----------------------------------------------------------")
Write-Host ("  硬編碼 往返          {0,6}ms   {1,6}ms   {2,6}ms" -f $low.legacyRT, $mid.legacyRT, $high.legacyRT)
Write-Host ("    (往返 相對低交叉)    基準      +{0}%     +{1}%" -f $lMidRT, $lHighRT)
Write-Host ("    ├ 伺服器           {0,6}ms   {1,6}ms   {2,6}ms" -f $low.legacySrv, $mid.legacySrv, $high.legacySrv)
Write-Host ("    │ (伺服器 相對低交叉) 基準     +{0}%     +{1}%" -f $lMidSrv, $lHighSrv)
Write-Host ("    └ 網路             {0,6}ms   {1,6}ms   {2,6}ms" -f $low.legacyNet, $mid.legacyNet, $high.legacyNet)
Write-Host ("  -----------------------------------------------------------")
Write-Host ""
Write-Host "  ★ 低→高 增長幅度（兩種都算）：" -ForegroundColor Yellow
Write-Host ("     往返  ：Drools +{0}%  /  硬編碼 +{1}%" -f $dHighRT,  $lHighRT)  -ForegroundColor Gray
Write-Host ("     伺服器：Drools +{0}%  /  硬編碼 +{1}%" -f $dHighSrv, $lHighSrv) -ForegroundColor Gray
Write-Host "  ★ 伺服器％＝架構本身對交叉複雜度的敏感度（乾淨）；" -ForegroundColor Gray
Write-Host "     往返％含固定網路延遲，增幅會被稀釋變小" -ForegroundColor Gray
Write-Host "============================================================" -ForegroundColor Green

Write-Host "`n============================================================" -ForegroundColor Cyan
Write-Host " 實驗總時間（暖機後量測，已不含冷啟動）" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ("  實驗時間  {0,10:N0} ms  ({1,7:N2} s)" -f $experimentMs, ($experimentMs/1000)) -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# ── 匯出 CSV（往返 + 拆解 + 兩種增長幅度）──
$csv = @(
    [PSCustomObject]@{ 複雜度="低交叉"; Drools往返=$low.droolsRT;  Drools伺服器=$low.droolsSrv;  Drools網路=$low.droolsNet;  硬編碼往返=$low.legacyRT;  硬編碼伺服器=$low.legacySrv;  硬編碼網路=$low.legacyNet;  Drools往返增幅=0; Drools伺服器增幅=0; 硬編碼往返增幅=0; 硬編碼伺服器增幅=0 }
    [PSCustomObject]@{ 複雜度="中交叉"; Drools往返=$mid.droolsRT;  Drools伺服器=$mid.droolsSrv;  Drools網路=$mid.droolsNet;  硬編碼往返=$mid.legacyRT;  硬編碼伺服器=$mid.legacySrv;  硬編碼網路=$mid.legacyNet;  Drools往返增幅=$dMidRT;  Drools伺服器增幅=$dMidSrv;  硬編碼往返增幅=$lMidRT;  硬編碼伺服器增幅=$lMidSrv }
    [PSCustomObject]@{ 複雜度="高交叉"; Drools往返=$high.droolsRT; Drools伺服器=$high.droolsSrv; Drools網路=$high.droolsNet; 硬編碼往返=$high.legacyRT; 硬編碼伺服器=$high.legacySrv; 硬編碼網路=$high.legacyNet; Drools往返增幅=$dHighRT; Drools伺服器增幅=$dHighSrv; 硬編碼往返增幅=$lHighRT; 硬編碼伺服器增幅=$lHighSrv }
)
$csv | Export-Csv -Path "cross_complexity_curve.csv" -NoTypeInformation -Encoding UTF8
Write-Host "曲線資料已匯出: cross_complexity_curve.csv" -ForegroundColor DarkGray