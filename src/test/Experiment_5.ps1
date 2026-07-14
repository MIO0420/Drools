# ============================================================
#  實驗五：多租戶併發壓力測試（每家 500 員工，併發 100→1000 家，每次 +100）
#  公司池：5家客製(91/92/25/94/95) + 通用id填充，湊足不重複 N 家
#  每個 companyId 各自建一個 KieContainer → 驗證記憶體隨租戶數疊加
#  ★ 全自動：無需按 Enter；組間自動等待讓記憶體釋放
#  ★ 一次測兩個架構：drools(規則引擎) 與 legacy(硬編碼)
#  ★ 全程 log 會寫入 .log 檔；每組記錄【開始~結束時間】、總耗時、平均請求耗時
#  ★ 記憶體峰值請對照每組「開始~結束時間」到 Azure App Insights 查
# ============================================================
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

# ===== 設定 =====
$EMP_PER_CO   = 500                                   # 每家公司員工數
$CONCURRENCY  = @(4..9 | ForEach-Object { $_ * 10 }) + @(1..10 | ForEach-Object { $_ * 100 }) # 40,50..90,100,200..1000（共16組）
$MAX_PARALLEL = 50        # 每組實際「同時執行」的請求上限；設 0 = 等於公司數(完全併發，慎用)
$GROUP_WAIT   = 600       # 組間等待秒數（讓記憶體釋放）
$ARCH_WAIT    = 600       # 架構切換等待秒數
$REQ_TIMEOUT  = 600       # 單請求逾時秒數
$ARCHS        = @("drools","legacy")   # 想只測一個架構就改成 @("drools") 或 @("legacy")

# ===== 全程 Log（寫入檔案）=====
$stamp   = Get-Date -Format yyyyMMdd_HHmmss
$logFile = "實驗五_log_$stamp.txt"
Start-Transcript -Path $logFile -Append | Out-Null
Write-Host ("Log 檔：{0}" -f $logFile) -ForegroundColor Cyan

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

# 產生一家公司 500 員工批次
function BuildCompanyBatch($cid, $emp, $seed) {
  Get-Random -SetSeed $seed | Out-Null
  $positions=@("EXECUTIVE","DIRECTOR","MANAGER","STAFF","INTERN")
  $depts=@("RD","IT","SALES","OPS","FINANCE","CUSTOMER")
  $arr=@()
  for ($i=1;$i -le $emp;$i++){
    $pos=$positions[(Get-Random -Maximum 5)]; $dept=$depts[(Get-Random -Maximum 6)]
    $arr += [ordered]@{
      employeeId=("C{0}E{1:D3}" -f $cid,$i); companyId="$cid"
      baseSalary=((Get-Random -Minimum 125 -Maximum 792)*240)
      workingDaysInMonth=30; tenureMonths=(Get-Random -Minimum 1 -Maximum 241); seniorityMonths=(Get-Random -Minimum 1 -Maximum 241)
      position=$pos; department=$dept; identity="REGULAR"
      overtimes=@(@{overtimeType="WEEKDAY";overtimeHours=8})
      performances=@(@{employeeId=("C{0}E{1:D3}" -f $cid,$i);companyId="$cid";score=(Get-Random -Minimum 70 -Maximum 136);grade="S";confirmed=$true})
    }
  }
  return (@($arr) | ConvertTo-Json -Depth 12)
}

# 平行送 N 個請求（Runspace）；maxParallel 控制同時執行上限
function RunConcurrent($url, $bodies, $maxParallel, $timeoutSec) {
  $cap = if ($maxParallel -le 0) { $bodies.Count } else { [math]::Min($maxParallel, $bodies.Count) }
  $pool = [runspacefactory]::CreateRunspacePool(1, [math]::Max(1,$cap))
  $pool.Open()
  $jobs=@()
  foreach ($b in $bodies) {
    $ps=[powershell]::Create(); $ps.RunspacePool=$pool
    [void]$ps.AddScript({
      param($u,$body,$toSec)
      $sw=[System.Diagnostics.Stopwatch]::StartNew()
      try {
        $bytes=[Text.Encoding]::UTF8.GetBytes($body)
        $null=Invoke-RestMethod -Uri $u -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec $toSec
        $sw.Stop(); return @{ ok=$true; ms=$sw.Elapsed.TotalMilliseconds }
      } catch { $sw.Stop(); return @{ ok=$false; ms=$sw.Elapsed.TotalMilliseconds; err=$_.Exception.Message } }
    }).AddArgument($url).AddArgument($b).AddArgument($timeoutSec)
    $jobs += @{ ps=$ps; handle=$ps.BeginInvoke() }
  }
  $results=@()
  foreach ($j in $jobs) { $results += $j.ps.EndInvoke($j.handle); $j.ps.Dispose() }
  $pool.Close(); $pool.Dispose()
  return $results
}

$runStart   = Get-Date
$allSummary = @()

foreach ($TARGET in $ARCHS) {
  $url = if ($TARGET -eq "drools") { $droolsUrl } else { $legacyUrl }

  Write-Host ""
  Write-Host "============================================================" -ForegroundColor White
  Write-Host (" 實驗五 併發壓力測試 — 架構: {0}" -f $TARGET.ToUpper()) -ForegroundColor White
  Write-Host (" 每家 {0} 員工，併發 {1} 家；5客製+通用填充" -f $EMP_PER_CO, ($CONCURRENCY -join "/")) -ForegroundColor White
  Write-Host (" 同時執行上限 MAX_PARALLEL = {0}" -f $(if($MAX_PARALLEL -le 0){"完全併發(=公司數)"}else{$MAX_PARALLEL})) -ForegroundColor White
  Write-Host "============================================================" -ForegroundColor White

  $summary=@()
  foreach ($N in $CONCURRENCY) {
    $picked = PickCompanies $N
    Write-Host ""
    Write-Host (">>> 【{0} 家併發】公司範圍: {1} ... {2}（共{3}家）" -f $N, $picked[0], $picked[-1], $picked.Count) -ForegroundColor Magenta

    # 預建 body（此段不列入計時；大 N 會較久，顯示進度）
    Write-Host ("    組建 {0} 家 x {1} 員工的請求資料中..." -f $N, $EMP_PER_CO) -ForegroundColor DarkGray
    $bodies=@(); $k=0
    foreach ($cid in $picked) {
      $k++
      $bodies += (BuildCompanyBatch $cid $EMP_PER_CO (7000+$k))
      if ($k % 100 -eq 0) { Write-Host ("      已組建 {0}/{1} 家" -f $k, $N) -ForegroundColor DarkGray }
    }

    $startTime=Get-Date
    Write-Host ("    [開始] {0:yyyy-MM-dd HH:mm:ss.fff}" -f $startTime) -ForegroundColor Cyan
    $sw=[System.Diagnostics.Stopwatch]::StartNew()
    $res = RunConcurrent $url $bodies $MAX_PARALLEL $REQ_TIMEOUT
    $sw.Stop()
    $endTime=Get-Date

    $ok=($res|Where-Object{$_.ok}).Count
    $fail=($res|Where-Object{-not $_.ok}).Count
    $maxMs=($res|ForEach-Object{$_.ms}|Measure-Object -Maximum).Maximum
    $avgMs=($res|ForEach-Object{$_.ms}|Measure-Object -Average).Average

    Write-Host ("    [結束] {0:yyyy-MM-dd HH:mm:ss.fff}" -f $endTime) -ForegroundColor Cyan
    Write-Host ("    總耗時 = {0:N0} ms" -f $sw.Elapsed.TotalMilliseconds) -ForegroundColor Green
    Write-Host ("    成功 {0} / 失敗 {1}" -f $ok,$fail) -ForegroundColor $(if($fail-eq 0){"Green"}else{"Red"})
    Write-Host ("    單請求 最慢 {0:N0}ms / 平均 {1:N0}ms" -f $maxMs,$avgMs) -ForegroundColor DarkGray
    if ($fail -gt 0) {
      $errs=($res|Where-Object{-not $_.ok}|ForEach-Object{$_.err}|Select-Object -Unique) -join " | "
      Write-Host ("    失敗原因: {0}" -f $errs) -ForegroundColor Red
    }

    $summary += [pscustomobject]@{
      架構=$TARGET; 併發公司數=$N; 同時上限=$(if($MAX_PARALLEL -le 0){$N}else{$MAX_PARALLEL}); 總員工=($N*$EMP_PER_CO)
      總耗時ms=[math]::Round($sw.Elapsed.TotalMilliseconds,0); 成功=$ok; 失敗=$fail
      最慢請求ms=[math]::Round($maxMs,0); 平均請求ms=[math]::Round($avgMs,0)
      開始=$startTime.ToString("yyyy-MM-dd HH:mm:ss"); 結束=$endTime.ToString("yyyy-MM-dd HH:mm:ss")
    }

    # 釋放本組 body 記憶體
    $bodies=$null; [System.GC]::Collect()

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
  $allSummary += $summary

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
Write-Host ""
Write-Host "================ 合併對照表（DROOLS vs LEGACY）================" -ForegroundColor Green
$allSummary | Format-Table -AutoSize

$csv="實驗五_對照_$stamp.csv"
$allSummary | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host ("已存合併 CSV: {0}" -f $csv) -ForegroundColor Cyan
Write-Host ("整體測試區間：{0:yyyy-MM-dd HH:mm:ss} ~ {1:yyyy-MM-dd HH:mm:ss}（約 {2:N1} 分鐘）" -f $runStart,$runEnd,($runEnd-$runStart).TotalMinutes) -ForegroundColor Cyan
Write-Host ""
Write-Host "★ 用每組【開始~結束】時間到 Azure 查 Instance Count + Memory working set 峰值" -ForegroundColor Yellow

Stop-Transcript | Out-Null