# ============================================================
#  實驗四 效能測試:規則引擎 vs 硬編碼,L1~L5,每批 500 筆
#  產出 Q1(穩態效能) + Q3(冷啟動成本)
#  互動式:每個冷啟動測試前會提示你 Restart Function App
# ============================================================
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"

$BATCH = 500      # 每批員工數
$WARM  = 5        # 穩態取樣發數(每發 500 筆)

# 級別 → companyId
$levels = @(
  @{ lv="L1"; cid="91"; rules=26 }
  @{ lv="L2"; cid="92"; rules=63 }
  @{ lv="L3"; cid="25"; rules=273 }
  @{ lv="L4"; cid="94"; rules=479 }
  @{ lv="L5"; cid="95"; rules=754 }
)

# 產生 500 筆批次(同一級用同樣資料,確保公平)
function BuildBatch($cid, $n) {
  Get-Random -SetSeed 42 | Out-Null
  $positions=@("EXECUTIVE","DIRECTOR","MANAGER","STAFF","INTERN")
  $depts=@("RD","IT","SALES","OPS","FINANCE","CUSTOMER")
  $arr=@()
  for ($i=1;$i -le $n;$i++){
    $pos=$positions[(Get-Random -Maximum 5)]; $dept=$depts[(Get-Random -Maximum 6)]
    $e=[ordered]@{
      employeeId=("E{0:D4}" -f $i); companyId=$cid; baseSalary=((Get-Random -Minimum 125 -Maximum 792)*240)
      workingDaysInMonth=30; tenureMonths=(Get-Random -Minimum 1 -Maximum 241); seniorityMonths=(Get-Random -Minimum 1 -Maximum 241)
      position=$pos; department=$dept; identity="REGULAR"
      overtimes=@(@{overtimeType="WEEKDAY";overtimeHours=8})
      performances=@(@{employeeId=("E{0:D4}" -f $i);companyId=$cid;score=(Get-Random -Minimum 70 -Maximum 136);grade="S";confirmed=$true})
    }
    $arr+=$e
  }
  return (@($arr) | ConvertTo-Json -Depth 12)
}

# 送一發,回傳耗時(ms);失敗回 -1
function TimedPost($url, $body) {
  $bytes=[Text.Encoding]::UTF8.GetBytes($body)
  $sw=[System.Diagnostics.Stopwatch]::StartNew()
  try {
    $null = Invoke-RestMethod -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec 300
    $sw.Stop(); return $sw.Elapsed.TotalMilliseconds
  } catch { $sw.Stop(); return -1 }
}

# 測一個端點(冷啟動 + 穩態)
function MeasureEndpoint($name, $url, $body) {
  Write-Host ""
  Write-Host ("  >>> 請先【Restart Function App】,等它完全啟動(約30~60秒),然後按 Enter 開始測 {0}" -f $name) -ForegroundColor Yellow
  Read-Host "      準備好按 Enter"
  # 冷啟動:第一發
  Write-Host ("      [冷啟動] 送第一批 {0} 筆..." -f $BATCH) -ForegroundColor DarkGray
  $cold = TimedPost $url $body
  if ($cold -lt 0) { Write-Host "      ✗ 冷啟動失敗(可能 OOM/timeout)" -ForegroundColor Red; return @{ cold=-1; warm=-1; runs=@() } }
  Write-Host ("      [冷啟動] = {0:N1} ms" -f $cold) -ForegroundColor Cyan
  # 穩態:連打 WARM 發
  $runs=@()
  for ($k=1;$k -le $WARM;$k++){
    $t=TimedPost $url $body
    $runs+=$t
    Write-Host ("      [穩態 {0}/{1}] = {2:N1} ms" -f $k,$WARM,$t) -ForegroundColor DarkGray
  }
  $avg=($runs | Measure-Object -Average).Average
  return @{ cold=$cold; warm=$avg; runs=$runs }
}

$results=@()
Write-Host "============================================================" -ForegroundColor White
Write-Host " 實驗四 效能測試:規則引擎 vs 硬編碼(每批 $BATCH 筆,穩態取 $WARM 發)" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

foreach ($L in $levels) {
  Write-Host ""
  Write-Host ("━━━━━━ {0} (cid={1}, {2}條規則) ━━━━━━" -f $L.lv,$L.cid,$L.rules) -ForegroundColor Magenta
  $body = BuildBatch $L.cid $BATCH

  # 規則引擎
  $d = MeasureEndpoint ("規則引擎 "+$L.lv) $droolsUrl $body
  # 硬編碼
  $h = MeasureEndpoint ("硬編碼 "+$L.lv) $legacyUrl $body

  $results += [pscustomobject]@{
    級別=$L.lv; 規則數=$L.rules
    規則引擎_冷啟動ms=[math]::Round($d.cold,1); 規則引擎_穩態ms=[math]::Round($d.warm,1)
    硬編碼_冷啟動ms=[math]::Round($h.cold,1);   硬編碼_穩態ms=[math]::Round($h.warm,1)
    穩態倍數=if($h.warm -gt 0){[math]::Round($d.warm/$h.warm,1)}else{0}
  }
}

Write-Host ""
Write-Host "════════════════════ 彙整結果 ════════════════════" -ForegroundColor Green
$results | Format-Table -AutoSize

$csv="效能結果_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
$results | Export-Csv -Path $csv -NoTypeInformation -Encoding UTF8
Write-Host ("已存 CSV:{0}" -f $csv) -ForegroundColor Cyan
Write-Host ""
Write-Host "[Q1 穩態效能] 看「規則引擎_穩態ms vs 硬編碼_穩態ms」隨規則數的成長" -ForegroundColor DarkGray
Write-Host "[Q3 冷啟動]   看「規則引擎_冷啟動ms」相對穩態高多少(KieContainer 編譯成本)" -ForegroundColor DarkGray