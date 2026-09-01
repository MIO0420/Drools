# ============================================================
#  實驗五：多租戶併發壓力測試（每家 500 員工，併發 40→1000 家）
#  公司池：5家客製(91/92/25/94/95) + 通用id填充，湊足不重複 N 家
#  每個 companyId 各自建一個 KieContainer → 驗證記憶體隨租戶數疊加
#  ★ 全自動：無需按 Enter；組間自動等待讓記憶體釋放
#  ★ 一次測兩個架構：drools(規則引擎) 與 legacy(硬編碼)
#  ★ 所有結果集中在「一份 Excel」：摘要 / 明細 / 執行紀錄 三個工作表
#  ★ 每組跑完就即時存檔一次（覆寫同一份），中斷也保得住已完成的組
#  ★ 記憶體峰值請對照每組「開始~結束時間」到 Azure App Insights 查
#  ★ 本版：所有 += 陣列累加改為 System.Collections.Generic.List（大 N 效能優化）
# ============================================================
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

# ===== 設定 =====
$EMP_PER_CO   = 500                                   # 每家公司員工數
$CONCURRENCY  = @(4..9 | ForEach-Object { $_ * 10 }) + @(1..10 | ForEach-Object { $_ * 100 }) + @(2..10 | ForEach-Object { $_ * 1000 }) # 40,50..90, 100,200..1000, 2000,3000..10000（共25組）
$MAX_PARALLEL = 10000        # 每組實際「同時執行」的請求上限；設 0 = 等於公司數(完全併發，慎用)
$GROUP_WAIT   = 600       # 組間等待秒數（讓記憶體釋放）
$ARCH_WAIT    = 600       # 架構切換等待秒數
$REQ_TIMEOUT  = 600       # 單請求逾時秒數
$ARCHS        = @("drools","legacy")   # 想只測一個架構就改成 @("drools") 或 @("legacy")

$stamp = Get-Date -Format yyyyMMdd_HHmmss
$xlsx  = "實驗五_$stamp.xlsx"

# ===== 準備 Excel 輸出能力（裝不起來就退回多 CSV，不讓你白跑）=====
$UseExcel = $true
try {
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocol]::Tls12
  if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    Write-Host "首次使用：安裝 ImportExcel 模組中（只需一次）..." -ForegroundColor Yellow
    Install-Module ImportExcel -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
  }
  Import-Module ImportExcel -ErrorAction Stop
  Write-Host ("輸出檔（單一 Excel）：{0}" -f $xlsx) -ForegroundColor Cyan
} catch {
  $UseExcel = $false
  Write-Host ("無法使用 ImportExcel，改用 CSV 多檔輸出：{0}" -f $_.Exception.Message) -ForegroundColor Red
}

# ===== 統一存檔：把三份資料寫進同一份 xlsx（每組呼叫一次，覆寫）=====
function Save-All($summary, $detail, $logLines) {
  # ★ 用管線正規化成陣列：避免 @() 直接套在 List[object] 上（PS7 會丟 Argument types do not match）
  $sumArr = @($summary | ForEach-Object { $_ })
  $detArr = @($detail  | ForEach-Object { $_ })
  try {
    if ($UseExcel) {
      Remove-Item $xlsx -ErrorAction SilentlyContinue
      $sumArr | Export-Excel -Path $xlsx -WorksheetName '摘要' -AutoSize -FreezeTopRow -BoldTopRow
      if ($detArr.Count -gt 0) {
        $detArr | Export-Excel -Path $xlsx -WorksheetName '明細' -AutoSize -FreezeTopRow -BoldTopRow
      }
      @($logLines | ForEach-Object { [pscustomobject]@{ 執行紀錄 = $_ } }) |
        Export-Excel -Path $xlsx -WorksheetName '執行紀錄' -AutoSize
    } else {
      $sumArr | Export-Csv "實驗五_對照_$stamp.csv" -NoTypeInformation -Encoding UTF8
      $detArr | Export-Csv "實驗五_明細_$stamp.csv" -NoTypeInformation -Encoding UTF8
      $logLines | Out-File   "實驗五_log_$stamp.txt"  -Encoding UTF8
    }
  } catch {
    Write-Host ("    ⚠ 存檔失敗（資料仍在記憶體，下一組會再存）：{0}" -f $_.Exception.Message) -ForegroundColor Red
  }
}

# ===== 執行紀錄（同時印到畫面 + 收進 Log 工作表；倒數不收進去，避免洗版）=====
$logLines = New-Object System.Collections.Generic.List[string]
function Log([string]$msg, [string]$color = "Gray") {
  Write-Host $msg -ForegroundColor $color
  $logLines.Add(("{0}  {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $msg))
}

# ===== 公司池（自動擴充到能產生最大 N 家不重複 ID）=====
$MAX_CO  = ($CONCURRENCY | Measure-Object -Maximum).Maximum
$custom  = @("91","92","25","94","95")                                     # 客製5家
$generic = @(1..($MAX_CO + $custom.Count + 50) | Where-Object { $custom -notcontains "$_" } | ForEach-Object { "$_" })  # 通用池(夠填到 MAX_CO)

# 組成 N 家不重複：先放5家客製，再用通用id填到N
function PickCompanies($n) {
  $picked = @()
  $picked += $custom[0..([math]::Min($custom.Count,$n)-1)]
  $need = $n - $picked.Count
  if ($need -gt 0) { $picked += $generic[0..($need-1)] }
  return $picked[0..($n-1)]
}

# 百分位數（線性內插）
function Percentile($values, $p) {
  $s = @($values | Sort-Object)
  if ($s.Count -eq 0) { return 0 }
  if ($s.Count -eq 1) { return $s[0] }
  $rank = ($p/100.0) * ($s.Count - 1)
  $lo = [math]::Floor($rank); $hi = [math]::Ceiling($rank)
  if ($lo -eq $hi) { return $s[[int]$lo] }
  $frac = $rank - $lo
  return $s[[int]$lo] + ($s[[int]$hi] - $s[[int]$lo]) * $frac
}

# 產生一家公司 500 員工批次
function BuildCompanyBatch($cid, $emp, $seed) {
  Get-Random -SetSeed $seed | Out-Null
  $positions=@("EXECUTIVE","DIRECTOR","MANAGER","STAFF","INTERN")
  $depts=@("RD","IT","SALES","OPS","FINANCE","CUSTOMER")
  $arr = New-Object System.Collections.Generic.List[object]
  for ($i=1;$i -le $emp;$i++){
    $pos=$positions[(Get-Random -Maximum 5)]; $dept=$depts[(Get-Random -Maximum 6)]
    $arr.Add([ordered]@{
      employeeId=("C{0}E{1:D3}" -f $cid,$i); companyId="$cid"
      baseSalary=((Get-Random -Minimum 125 -Maximum 792)*240)
      workingDaysInMonth=30; tenureMonths=(Get-Random -Minimum 1 -Maximum 241); seniorityMonths=(Get-Random -Minimum 1 -Maximum 241)
      position=$pos; department=$dept; identity="REGULAR"
      overtimes=@(@{overtimeType="WEEKDAY";overtimeHours=8})
      performances=@(@{employeeId=("C{0}E{1:D3}" -f $cid,$i);companyId="$cid";score=(Get-Random -Minimum 70 -Maximum 136);grade="S";confirmed=$true})
    })
  }
  return ($arr.ToArray() | ConvertTo-Json -Depth 12)
}

# 平行送 N 個請求（Runspace）；maxParallel 控制同時執行上限
# 每筆回傳：seq(送出序號,從1起)、cid、ok、ms、err
function RunConcurrent($url, $items, $maxParallel, $timeoutSec) {
  $cap = if ($maxParallel -le 0) { $items.Count } else { [math]::Min($maxParallel, $items.Count) }
  $pool = [runspacefactory]::CreateRunspacePool(1, [math]::Max(1,$cap))
  $pool.Open()
  $jobs = New-Object System.Collections.Generic.List[object]
  $seq=0
  foreach ($it in $items) {
    $seq++
    $ps=[powershell]::Create(); $ps.RunspacePool=$pool
    [void]$ps.AddScript({
      param($u,$body,$toSec,$seqNo,$cid)
      $sw=[System.Diagnostics.Stopwatch]::StartNew()
      try {
        $bytes=[Text.Encoding]::UTF8.GetBytes($body)
        $null=Invoke-RestMethod -Uri $u -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec $toSec
        $sw.Stop(); return @{ seq=$seqNo; cid=$cid; ok=$true;  ms=$sw.Elapsed.TotalMilliseconds }
      } catch { $sw.Stop(); return @{ seq=$seqNo; cid=$cid; ok=$false; ms=$sw.Elapsed.TotalMilliseconds; err=$_.Exception.Message } }
    }).AddArgument($url).AddArgument($it.body).AddArgument($timeoutSec).AddArgument($seq).AddArgument($it.cid)
    $jobs.Add(@{ ps=$ps; handle=$ps.BeginInvoke() })
  }
  $results = New-Object System.Collections.Generic.List[object]
  foreach ($j in $jobs) {
    foreach ($out in $j.ps.EndInvoke($j.handle)) { $results.Add($out) }
    $j.ps.Dispose()
  }
  $pool.Close(); $pool.Dispose()
  return $results
}

$runStart   = Get-Date
$allSummary = New-Object System.Collections.Generic.List[object]
$allDetail  = New-Object System.Collections.Generic.List[object]

Log ("實驗五 開始，輸出：{0}（模式：{1}）" -f $(if($UseExcel){$xlsx}else{"CSV 多檔"}), $(if($UseExcel){"單一Excel"}else{"CSV"})) "Cyan"

foreach ($TARGET in $ARCHS) {
  $url = if ($TARGET -eq "drools") { $droolsUrl } else { $legacyUrl }

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor White
  Log (" 架構: {0} — 每家 {1} 員工，併發 {2} 家；同時上限 {3}" -f $TARGET.ToUpper(), $EMP_PER_CO, ($CONCURRENCY -join "/"), $(if($MAX_PARALLEL -le 0){"完全併發"}else{$MAX_PARALLEL})) "White"
  Write-Host "============================================================" -ForegroundColor White

  $summary = New-Object System.Collections.Generic.List[object]
  foreach ($N in $CONCURRENCY) {
    $picked = PickCompanies $N
    Write-Host ""
    Log (">>> 【{0} 家併發 / {1}】公司範圍 {2}...{3}（共{4}家）" -f $N, $TARGET, $picked[0], $picked[-1], $picked.Count) "Magenta"

    # 預建 body（此段不列入計時；大 N 會較久，顯示進度）
    Write-Host ("    組建 {0} 家 x {1} 員工的請求資料中..." -f $N, $EMP_PER_CO) -ForegroundColor DarkGray
    $items = New-Object System.Collections.Generic.List[object]
    $k=0
    foreach ($cid in $picked) {
      $k++
      $items.Add(@{ cid=$cid; body=(BuildCompanyBatch $cid $EMP_PER_CO (7000+$k)) })
      if ($k % 100 -eq 0) { Write-Host ("      已組建 {0}/{1} 家" -f $k, $N) -ForegroundColor DarkGray }
    }

    $startTime=Get-Date
    Write-Host ("    [開始] {0:yyyy-MM-dd HH:mm:ss.fff}" -f $startTime) -ForegroundColor Cyan
    $sw=[System.Diagnostics.Stopwatch]::StartNew()
    $res = RunConcurrent $url $items $MAX_PARALLEL $REQ_TIMEOUT
    $sw.Stop()
    $endTime=Get-Date

    $ok=($res|Where-Object{$_.ok}).Count
    $fail=($res|Where-Object{-not $_.ok}).Count
    $msList=@($res|ForEach-Object{$_.ms})
    $maxMs=($msList|Measure-Object -Maximum).Maximum
    $minMs=($msList|Measure-Object -Minimum).Minimum
    $avgMs=($msList|Measure-Object -Average).Average
    $p50=Percentile $msList 50
    $p95=Percentile $msList 95

    Log ("    [{0}家] 開始 {1:HH:mm:ss} 結束 {2:HH:mm:ss}｜總耗時 {3:N0}ms｜成功 {4}/失敗 {5}｜單筆 最快{6:N0}/平均{7:N0}/中位{8:N0}/p95{9:N0}/最慢{10:N0}ms" -f `
        $N,$startTime,$endTime,$sw.Elapsed.TotalMilliseconds,$ok,$fail,$minMs,$avgMs,$p50,$p95,$maxMs) $(if($fail -eq 0){"Green"}else{"Red"})
    if ($fail -gt 0) {
      $errs=($res|Where-Object{-not $_.ok}|ForEach-Object{$_.err}|Select-Object -Unique) -join " | "
      Log ("    失敗原因: {0}" -f $errs) "Red"
    }

    # 每筆明細（依送出序號排序；波段：前 MAX_PARALLEL 筆視為第一波=冷）
    $firstWave = if ($MAX_PARALLEL -le 0) { $N } else { $MAX_PARALLEL }
    foreach ($r in ($res | Sort-Object { $_.seq })) {
      $allDetail.Add([pscustomobject]@{
        架構=$TARGET; 併發公司數=$N; 送出序號=$r.seq; companyId=$r.cid
        波段=$(if($r.seq -le $firstWave){"冷(第一波)"}else{"熱(穩態)"})
        ok=$r.ok; ms=[math]::Round($r.ms,0); err=$(if($r.ok){""}else{$r.err})
        組開始=$startTime.ToString("yyyy-MM-dd HH:mm:ss")
      })
    }

    $row = [pscustomobject]@{
      架構=$TARGET; 併發公司數=$N; 同時上限=$(if($MAX_PARALLEL -le 0){$N}else{$MAX_PARALLEL}); 總員工=($N*$EMP_PER_CO)
      總耗時ms=[int][math]::Round($sw.Elapsed.TotalMilliseconds,0); 成功=$ok; 失敗=$fail
      最快請求ms=[int][math]::Round($minMs,0); 平均請求ms=[int][math]::Round($avgMs,0)
      中位請求ms=[int][math]::Round($p50,0); p95請求ms=[int][math]::Round($p95,0); 最慢請求ms=[int][math]::Round($maxMs,0)
      開始=$startTime.ToString("yyyy-MM-dd HH:mm:ss"); 結束=$endTime.ToString("yyyy-MM-dd HH:mm:ss")
    }
    $summary.Add($row)
    $allSummary.Add($row)

    # ★ 每組跑完即時存檔（覆寫同一份）
    Save-All $allSummary $allDetail $logLines
    Write-Host ("    ✓ 已即時寫入 {0}" -f $(if($UseExcel){$xlsx}else{"CSV"})) -ForegroundColor DarkGreen

    # 釋放本組記憶體
    $items=$null; $res=$null; [System.GC]::Collect()

    # 組間等待讓記憶體釋放（最後一組不等）
    if ($N -ne $CONCURRENCY[-1]) {
      Write-Host ("    組間等待 {0} 秒讓記憶體釋放..." -f $GROUP_WAIT) -ForegroundColor DarkYellow
      for ($s=$GROUP_WAIT; $s -gt 0; $s-=30) {
        Write-Host ("       剩餘 {0} 秒..." -f $s) -ForegroundColor DarkGray
        Start-Sleep -Seconds ([math]::Min(30,$s))
      }
      Write-Host "    等待結束，開始下一組" -ForegroundColor DarkYellow
    }
  }

  Write-Host ""
  Write-Host "================ 小結（$($TARGET.ToUpper())）================" -ForegroundColor Green
  $summary | Format-Table -AutoSize

  # 架構之間也等待讓記憶體釋放（最後一個架構不等）
  if ($TARGET -ne $ARCHS[-1]) {
    Write-Host ("`n架構切換：等待 {0} 秒讓記憶體釋放，再測下一個架構..." -f $ARCH_WAIT) -ForegroundColor DarkYellow
    for ($s=$ARCH_WAIT; $s -gt 0; $s-=30) {
      Write-Host ("   剩餘 {0} 秒..." -f $s) -ForegroundColor DarkGray
      Start-Sleep -Seconds ([math]::Min(30,$s))
    }
    Write-Host "架構切換等待結束" -ForegroundColor DarkYellow
  }
}

$runEnd = Get-Date
Log ("整體測試區間：{0:yyyy-MM-dd HH:mm:ss} ~ {1:yyyy-MM-dd HH:mm:ss}（約 {2:N1} 分鐘）" -f $runStart,$runEnd,($runEnd-$runStart).TotalMinutes) "Cyan"
Save-All $allSummary $allDetail $logLines   # 最終再存一次（把最後的 log 寫進去）

Write-Host ""
Write-Host "================ 合併對照表（DROOLS vs LEGACY）================" -ForegroundColor Green
$allSummary | Format-Table -AutoSize
if ($UseExcel) {
  Write-Host ("★ 全部結果都在一份檔：{0}（摘要 / 明細 / 執行紀錄 三個工作表）" -f $xlsx) -ForegroundColor Cyan
} else {
  Write-Host "★ 未能使用 Excel，已退回輸出：實驗五_對照_*.csv、實驗五_明細_*.csv、實驗五_log_*.txt" -ForegroundColor Yellow
}
Write-Host "★ 用每組【開始~結束】時間到 Azure 查 Instance Count + Memory working set 峰值" -ForegroundColor Yellow
Write-Host "★ 明細工作表的『波段』欄可直接做冷/熱分離分析" -ForegroundColor Yellow