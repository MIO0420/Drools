# ============================================================
#  實驗四 · 問題三：冷啟動 / 編譯成本量測（無暖機版）
#  Drools(規則引擎) vs Legacy(硬編碼)，逐級別 L1–L5
#
#  ★ 與舊版最大差異：完全「沒有暖機、沒有預打第一發」。
#    計時的第一發之前不會有任何請求，確保量到的是真正的冷啟動
#    （KieContainer 把 DRL 編譯成 Rete 的時間）。
#
#  ★ 另加「熱度自動偵測」：若第一發跟穩態差不多，代表這其實是熱的
#    （多半是忘了重啟 FA），腳本會紅字警告並「不寫入」，請重啟後重量。
#
#  原理：
#    冷啟動(首發) = 平台啟動 + 執行期暖身 +（Drools 才有）DRL 編譯
#    穩態         = 純執行
#    冷啟動開銷   = 冷 − 穩態
#    規則引擎純編譯成本 = 同級別 (Drools 冷啟動開銷 − Legacy 冷啟動開銷)
#
#  【務必】每量一次 (級別 × 架構)，量測前都要先「重啟 Function App」，
#         並等它完全停止；重啟後「先打誰、誰才是平台冷」，
#         所以 drools 與 legacy 要各自重啟後單獨量，不能同一次連打。
#
#  用法（每行前先重啟 FA；保險起見每組跑 2–3 次取中位數）：
#    ./實驗四_問題三_冷啟動量測.ps1 -Level L1 -CompanyId 91 -Arch drools
#    ./實驗四_問題三_冷啟動量測.ps1 -Level L1 -CompanyId 91 -Arch legacy
#    ... L2/L3/L4/L5 依此類推（companyId 換成該級別的值）
#
#  全部量完後產生彙總（每級別中位數 + 規則引擎編譯成本）：
#    ./實驗四_問題三_冷啟動量測.ps1 -Summary
#
#  參數：
#    -NoConfirm   略過「已重啟了嗎」的確認（用於自動化）
#    -WarmRuns N  穩態取樣發數（預設 5）
# ============================================================

param(
  [string]$Level     = "L1",
  [string]$CompanyId = "91",
  [ValidateSet("drools","legacy")][string]$Arch = "drools",
  [int]$WarmRuns     = 5,
  [string]$OutCsv    = "q3_coldstart.csv",
  [switch]$NoConfirm,
  [switch]$Summary
)

$base      = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net"
$droolsUrl = "$base/api/calculatesalary"
$legacyUrl = "$base/api/checksalary/legacy"

function Median($nums) {
  $s = @($nums | Sort-Object)
  $n = $s.Count
  if ($n -eq 0) { return $null }
  if ($n % 2) { return $s[[int](($n - 1) / 2)] }
  return (($s[$n / 2 - 1] + $s[$n / 2]) / 2)
}

# ---------- 彙總模式 ----------
if ($Summary) {
  if (-not (Test-Path $OutCsv)) { Write-Host "找不到 $OutCsv，請先量測。" -ForegroundColor Red; return }
  $rows = Import-Csv $OutCsv
  Write-Host "============================================================" -ForegroundColor White
  Write-Host " 冷啟動彙總（每組取中位數，單位 ms）" -ForegroundColor White
  Write-Host "============================================================" -ForegroundColor White
  Write-Host ("{0,-6}{1,14}{2,14}{3,18}" -f "級別","Drools開銷","Legacy開銷","規則引擎編譯成本") -ForegroundColor Cyan
  $levels = $rows.級別 | Select-Object -Unique | Sort-Object
  foreach ($lv in $levels) {
    $dr = Median (($rows | Where-Object { $_.級別 -eq $lv -and $_.架構 -eq "drools" }).冷啟動開銷ms | ForEach-Object { [double]$_ })
    $lg = Median (($rows | Where-Object { $_.級別 -eq $lv -and $_.架構 -eq "legacy" }).冷啟動開銷ms | ForEach-Object { [double]$_ })
    $drTxt = if ($null -ne $dr) { "{0:N0}" -f $dr } else { "—" }
    $lgTxt = if ($null -ne $lg) { "{0:N0}" -f $lg } else { "—" }
    $cmp   = if (($null -ne $dr) -and ($null -ne $lg)) { "{0:N0}" -f ($dr - $lg) } else { "—" }
    Write-Host ("{0,-6}{1,14}{2,14}{3,18}" -f $lv,$drTxt,$lgTxt,$cmp)
  }
  Write-Host ""
  Write-Host " 『規則引擎編譯成本』= Drools開銷 − Legacy開銷，即 DRL 編譯成 Rete 的額外時間。" -ForegroundColor DarkGray
  return
}

# ---------- 量測模式 ----------
$url = if ($Arch -eq "drools") { $droolsUrl } else { $legacyUrl }

# 量測前確認：確保剛剛已重啟 FA（這是最容易出錯、導致量到熱的地方）
if (-not $NoConfirm) {
  Write-Host ""
  Write-Host " ⚠ 冷啟動量測前提：剛剛已『重啟 Function App』並等它完全停止？" -ForegroundColor Yellow
  Write-Host "    這一發之前絕不能有任何請求（含暖機、含瀏覽器開過頁面）。" -ForegroundColor Yellow
  $ans = Read-Host "    已重啟請按 Enter 繼續；未重啟請輸入 n 中止"
  if ($ans -match '^[nN]') { Write-Host " 已中止。請重啟 FA 後再跑。" -ForegroundColor Red; return }
}

# 代表性請求：冷啟動會編譯全部規則，單筆即可觸發
function Build($cid) {
  $e = [ordered]@{
    employeeId="R001"; companyId=$cid; baseSalary=60000
    workingDaysInMonth=30; tenureMonths=36; seniorityMonths=36
    position="STAFF"; department="RD"; identity="REGULAR"
    overtimes=@(@{ overtimeType="WEEKDAY"; overtimeHours=8 })
    performances=@(@{ employeeId="R001"; companyId=$cid; score=100; grade="A+"; confirmed=$true })
  }
  return (,@($e) | ConvertTo-Json -Depth 12)
}

function Post($url, $body) {
  $bytes = [Text.Encoding]::UTF8.GetBytes($body)
  try {
    $null = Invoke-RestMethod -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec 180
    return $true
  } catch { return $false }
}

$body = Build $CompanyId

Write-Host "============================================================" -ForegroundColor White
Write-Host (" 冷啟動量測 | 級別 {0} | 架構 {1} | companyId {2}" -f $Level,$Arch,$CompanyId) -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# ★ 第一發 = 冷啟動（前面沒有任何暖機！）
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$ok = Post $url $body
$sw.Stop()
$cold = $sw.Elapsed.TotalMilliseconds
if (-not $ok) {
  Write-Host " ✗ 冷啟動請求失敗（可能逾時，服務尚未就緒或重啟未完成）。" -ForegroundColor Red
  return
}
Write-Host (" 冷啟動（首發）　：{0,10:N0} ms" -f $cold) -ForegroundColor Cyan

# 穩態：連打取平均（這些才是熱的）
Start-Sleep -Milliseconds 500
$warmList = @()
for ($i = 1; $i -le $WarmRuns; $i++) {
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $null = Post $url $body
  $sw.Stop()
  $warmList += $sw.Elapsed.TotalMilliseconds
}
$warm     = ($warmList | Measure-Object -Average).Average
$overhead = $cold - $warm
Write-Host (" 穩態平均（{0} 發）：{1,10:N0} ms" -f $WarmRuns,$warm) -ForegroundColor Green
Write-Host (" 冷啟動開銷（冷−穩態）：{0,6:N0} ms" -f $overhead) -ForegroundColor Magenta

# ★ 熱度自動偵測：冷啟動應明顯高於穩態；若差距太小，多半是忘了重啟（量到熱的）
$looksHot = ($overhead -lt 150) -or ($cold -lt $warm * 1.25)
if ($looksHot) {
  Write-Host ""
  Write-Host " ============================================================" -ForegroundColor Red
  Write-Host " ⚠ 警告：這一發『不像冷啟動』（冷 ≈ 穩態）。" -ForegroundColor Red
  Write-Host "    最可能原因：量測前沒有重啟 Function App，或這發之前已被請求暖過。" -ForegroundColor Red
  Write-Host "    → 請『重啟 FA』後重跑本次量測。本次結果為避免污染，已『不寫入』CSV。" -ForegroundColor Red
  Write-Host " ============================================================" -ForegroundColor Red
  return
}

# 累加寫入 CSV（僅在通過熱度偵測時）
$row = [pscustomobject]@{
  時間         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
  級別         = $Level
  架構         = $Arch
  companyId    = $CompanyId
  冷啟動ms     = [math]::Round($cold)
  穩態ms       = [math]::Round($warm)
  冷啟動開銷ms = [math]::Round($overhead)
}
$row | Export-Csv -Path $OutCsv -Append -NoTypeInformation -Encoding UTF8
Write-Host (" → 已累加寫入 {0}" -f $OutCsv) -ForegroundColor DarkGray
Write-Host ""
Write-Host " 下一步：重啟 FA，換另一架構或下一級別再跑；全部完成後用 -Summary 產生彙總。" -ForegroundColor DarkGray