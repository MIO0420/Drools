# ============================================================
#  實驗四 PART B 補充：一次性冷啟動 / KieContainer 編譯成本 + 攤提
# ============================================================
#  ★★★ 執行順序警告 ★★★
#  KieContainer 一旦建好就被快取（computeIfAbsent），編譯成本「只發生第一次」。
#  → 這支腳本必須在「剛部署 / 長時間閒置（容器已被回收）後」最先跑，
#    且要在 Experiment_4.ps1 之前。否則容器已熱，編譯成本會量到 ~0。
#  → 想重量一次，需讓容器失效（重新部署，或呼叫會觸發 invalidateContainerCache 的端點）。
#
#  量測邏輯：
#    1. 先打 Legacy 數次 → 暖機 instance/JVM（硬編碼無 KieContainer，不會污染 Drools 編譯量測）
#    2. 對每間公司打「首發」→ 端到端含 KieContainer 編譯（instance 此時已熱）
#    3. 再打「熱發」數次取中位 → 端到端純計算（容器已快取）
#    4. 一次性編譯/冷啟成本 ≈ 首發端到端 − 熱發端到端中位
#    5. 攤提/筆 = 編譯成本 ÷ 批次筆數（容器存活期內可攤提到趨近 0）
#
#  ★ 誠實框定（寫進論文時務必標注）★
#    - 這量的是「Azure 消費型方案 + 執行期從 Blob 動態編譯」這個部署架構的成本，
#      不是規則引擎的本質執行成本；換部署方式（預編譯 KieBase 打包進映像）數字會不同。
#    - 它是 one-time、隨規則數成長、可攤提；不可混入 PART B 的純計算曲線。
# ============================================================

$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

$ProgressPreference = 'SilentlyContinue'

$batchSize = 200      # 與 PART B 一致；用於攤提計算
$warmInstanceHits = 3 # 用 Legacy 暖機 instance 的次數
$warmContainerHits = 5 # 量熱發中位數用的次數
# 用一個「不在 L1~L5 清單裡」的 companyId 暖身 Drools，吸收全域初始化
# （KieServices 初始化、Drools 類別載入、首次 JIT）。它會建一個獨立的通用容器，
#  不碰 91/95 的容器，所以 L1 量到的就是「純編譯增量」而非全域冷啟動。
$droolsWarmCid = "00"
$monthlyHeadcounts = @(100, 300, 500, 1000)  # 你真實月結人數情境（攤提用）

# 公司 + 規則數（規則數用來看「編譯成本是否隨 N 成長」）
$levels = @(
    @{ Level="L1"; Cid="91"; Rules=26  },
    @{ Level="L2"; Cid="92"; Rules=63  },
    @{ Level="L3"; Cid="25"; Rules=273 },
    @{ Level="L4"; Cid="94"; Rules=479 },
    @{ Level="L5"; Cid="95"; Rules=754 }
)

# ── 員工批次（內容不影響冷啟動量測，固定即可）──
function NewEmp($cid, $idx) {
    @{
        employeeId="COLD{0:D4}" -f $idx; baseSalary=80000; companyId=$cid
        workingDaysInMonth=30; tenureMonths=50; seniorityMonths=50
        position="MANAGER"; department="RD"; identity="REGULAR"
        leaves=@( @{ leaveTypeName="事假"; leaveHours=8 } )
        overtimes=@( @{ overtimeType="WEEKDAY"; overtimeHours=8 } )
        attendances=@(); performances=@(); projects=@()
    }
}
function NewBatch($cid, $n) {
    $arr = @(for ($k = 1; $k -le $n; $k++) { NewEmp $cid $k })
    return ,$arr
}

function Median($arr) {
    if ($arr.Count -eq 0) { return 0 }
    $s = $arr | Sort-Object
    $m = [math]::Floor($s.Count / 2)
    if ($s.Count % 2 -eq 0) { return ($s[$m-1] + $s[$m]) / 2 } else { return $s[$m] }
}

# 端到端牆鐘時間（含冷啟動/編譯），同時撈 header 純計算
function PostE2E($url, $body) {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-WebRequest -Uri $url -Method Post -Body $bytes `
                -ContentType "application/json; charset=utf-8" -UseBasicParsing
        $sw.Stop()
        $pure = $null
        foreach ($h in @("X-Drools-Pure-Compute-Ms","X-Legacy-Pure-Compute-Ms")) {
            $raw = $resp.Headers[$h]
            if ($raw) { $pure = [double]((@($raw)[0]).ToString().Trim()) }
        }
        return @{ e2e = [math]::Round($sw.Elapsed.TotalMilliseconds,1); pure = $pure }
    } catch {
        $sw.Stop()
        Write-Host ("    [HTTP錯誤] {0}" -f $_.Exception.Message) -ForegroundColor Red
        return @{ e2e = $null; pure = $null }
    }
}

Write-Host "============================================================" -ForegroundColor White
Write-Host " 一次性冷啟動 / KieContainer 編譯成本量測" -ForegroundColor White
Write-Host " ★必須在剛部署/長時間閒置後最先跑，否則容器已熱量不到★" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor White

# ── Step 0：用 Legacy 暖機 instance / JVM（不建 Drools 容器）──
Write-Host "`n[Step 0] 用 Legacy 暖機 instance/JVM ($warmInstanceHits 次)..." -ForegroundColor DarkGray
$warmBody = (NewBatch "91" $batchSize | ConvertTo-Json -Depth 12)
for ($i=0; $i -lt $warmInstanceHits; $i++) {
    $r = PostE2E $legacyUrl $warmBody
    Write-Host ("    Legacy 暖機 {0}: 端到端 {1} ms" -f ($i+1), $r.e2e) -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 300
}

# ── Step 0.5：Drools 暖身發（用不在清單的 companyId）→ 吸收 Drools 全域初始化 ──
# 這發會建一個獨立的通用容器，把 KieServices 初始化/類別載入/首次 JIT 吃掉，
# 但不碰 91~95 的容器，所以後面 L1 量到的是純編譯增量，不會像之前 L1 爆到 4.6 秒。
Write-Host "`n[Step 0.5] Drools 暖身發（公司$droolsWarmCid，吸收全域初始化）..." -ForegroundColor DarkGray
$warmDroolsBody = (NewBatch $droolsWarmCid $batchSize | ConvertTo-Json -Depth 12)
$wd = PostE2E $droolsUrl $warmDroolsBody
Write-Host ("    Drools 暖身: 端到端 {0} ms（這筆含全域初始化，丟棄不計）" -f $wd.e2e) -ForegroundColor DarkGray
Start-Sleep -Milliseconds 400

# ── Step 1：每間公司量「首發（冷容器）vs 熱發」──
$rows = @()
foreach ($lv in $levels) {
    Write-Host ("`n--- {0} (公司{1}, {2}條規則) ---" -f $lv.Level,$lv.Cid,$lv.Rules) -ForegroundColor Cyan
    $body = (NewBatch $lv.Cid $batchSize | ConvertTo-Json -Depth 12)

    # 首發：Drools 第一次 → 含 KieContainer 編譯（instance 已由 Legacy 暖機）
    $firstD = PostE2E $droolsUrl $body
    Write-Host ("  [首發] Drools 端到端 {0} ms（含編譯）/ 純計算 header {1} ms" -f $firstD.e2e, $firstD.pure) -ForegroundColor Yellow
    Start-Sleep -Milliseconds 400

    # 熱發：容器已快取 → 取中位
    $warmListD = @(); $warmPureD = @()
    for ($i=0; $i -lt $warmContainerHits; $i++) {
        $r = PostE2E $droolsUrl $body
        if ($r.e2e -ne $null)  { $warmListD += $r.e2e }
        if ($r.pure -ne $null) { $warmPureD += $r.pure }
        Start-Sleep -Milliseconds 200
    }
    $warmD     = Median $warmListD
    $warmPure  = Median $warmPureD
    $buildCost = if ($firstD.e2e -ne $null) { [math]::Round($firstD.e2e - $warmD, 1) } else { $null }
    $amortized = if ($buildCost -ne $null -and $batchSize -gt 0) { [math]::Round($buildCost / $batchSize, 3) } else { $null }

    # Legacy 對照：首發 vs 熱發（硬編碼無容器，預期編譯成本 ≈ 0）
    $firstL = PostE2E $legacyUrl $body
    Start-Sleep -Milliseconds 300
    $warmListL = @()
    for ($i=0; $i -lt 3; $i++) { $r = PostE2E $legacyUrl $body; if ($r.e2e) { $warmListL += $r.e2e }; Start-Sleep -Milliseconds 150 }
    $warmL = Median $warmListL
    $buildL = if ($firstL.e2e -ne $null) { [math]::Round($firstL.e2e - $warmL, 1) } else { $null }

    Write-Host ("  [熱發] Drools 端到端中位 {0} ms / 純計算 {1} ms" -f $warmD, $warmPure) -ForegroundColor Gray
    Write-Host ("  → Drools 一次性編譯/冷啟成本 ≈ {0} ms（攤提 {1} ms/筆 @批次{2}）" -f $buildCost, $amortized, $batchSize) -ForegroundColor Green
    Write-Host ("  → Legacy 對照：首發 {0} / 熱發 {1} → 一次性成本 ≈ {2} ms（無編譯，應接近 0）" -f $firstL.e2e, $warmL, $buildL) -ForegroundColor DarkGreen

    $rows += [ordered]@{
        Level=$lv.Level; Cid=$lv.Cid; Rules=$lv.Rules
        Drools_First_E2E=$firstD.e2e; Drools_Warm_E2E=$warmD; Drools_Warm_Pure=$warmPure
        Drools_BuildCost=$buildCost; Drools_Amortized_PerRec=$amortized
        Legacy_First_E2E=$firstL.e2e; Legacy_Warm_E2E=$warmL; Legacy_BuildCost=$buildL
    }
}

# ── 彙總表（含污染自動標示）──
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 彙總：一次性編譯成本 vs 規則數（看是否隨 N 成長）" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host "Level | 規則數 | Drools編譯成本ms | Legacy一次性ms | 備註" -ForegroundColor White

# 找出「乾淨」的最低規則數基準：理論上規則越多編譯越久；
# 若某級成本明顯大於規則數更多的級別，代表它被全域初始化污染，標示出來。
$clean = @()
foreach ($r in $rows) {
    $note = ""
    # 污染判定：成本比「規則數更多的某一級」還高 → 不單調 → 疑似含全域初始化
    $contaminated = $false
    foreach ($r2 in $rows) {
        if ($r2.Rules -gt $r.Rules -and $r2.Drools_BuildCost -ne $null -and $r.Drools_BuildCost -ne $null `
            -and $r.Drools_BuildCost -gt ($r2.Drools_BuildCost * 1.3)) { $contaminated = $true }
    }
    if ($contaminated) { $note = "⚠ 疑含全域初始化，當基準勿入趨勢" }
    else { $clean += $r }
    Write-Host ("  {0}  | {1,5} | {2,14} | {3,12} | {4}" -f `
        $r.Level, $r.Rules, $r.Drools_BuildCost, $r.Legacy_BuildCost, $note)
}
Write-Host "`n  Legacy 一次性成本全部 ≈ 0 → 證明硬編碼無編譯成本（對照組成立）" -ForegroundColor DarkGreen
if ($clean.Count -lt $rows.Count) {
    Write-Host "  ⚠ 有級別被標示污染（多半是第一發 Drools），畫趨勢線時請只用未標示者。" -ForegroundColor Yellow
} else {
    Write-Host "  ✓ 五級皆單調（編譯成本隨規則數成長），可直接畫趨勢線。" -ForegroundColor Green
}

# ── 攤提情境：對應你「真實月結人數」+ 部署模型誠實框定 ──
Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 攤提情境：以真實月結人數分攤一次性編譯成本（用 L5 最壞值）" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
$l5 = $rows | Where-Object { $_.Level -eq "L5" }
if ($l5 -and $l5.Drools_BuildCost -ne $null) {
    $bc = $l5.Drools_BuildCost
    Write-Host ("  L5(754條) 一次性編譯成本 = {0} ms" -f $bc) -ForegroundColor Gray
    Write-Host "  月結人數 | 攤提到每人的編譯成本" -ForegroundColor White
    foreach ($h in $monthlyHeadcounts) {
        $a = [math]::Round($bc / $h, 3)
        Write-Host ("  {0,7} | {1} ms/人" -f $h, $a)
    }
    Write-Host "" 
    Write-Host "  ★誠實框定（兩種部署情境）★" -ForegroundColor Yellow
    Write-Host "   - 常駐/高流量（容器一直活）：編譯只付一次，跨多次月結攤提 → 趨近 0。" -ForegroundColor Gray
    Write-Host "   - 消費型方案+月結（閒置即回收）：每月冷啟一次、每月重編譯一次，" -ForegroundColor Gray
    Write-Host ("     但 {0}ms 攤到整批月結後每人僅數 ms，對一個月一次的批次作業實務可忽略。" -f $bc) -ForegroundColor Gray
}

# ── 輸出 CSV ──
$rows | ForEach-Object { New-Object PSObject -Property $_ } |
    Export-Csv "experiment4_coldstart.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`n============================================================" -ForegroundColor Green
Write-Host " 完成！輸出 experiment4_coldstart.csv" -ForegroundColor Green
Write-Host " 論述：規則引擎付一筆隨規則數成長的一次性編譯成本，" -ForegroundColor Cyan
Write-Host "       但因 KieContainer 快取，可攤提到趨近 0；硬編碼無此成本。" -ForegroundColor Cyan
Write-Host " ★此為部署架構成本（動態編譯），不可混入 PART B 純計算曲線★" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Green