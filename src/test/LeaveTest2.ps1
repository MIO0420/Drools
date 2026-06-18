# ============================================================
#  鑫電星 HR 規則引擎 - 冷啟動間隔探測實驗 v2
#  目標：找出「第一筆冷啟動後，間隔多久第二筆也會冷啟動」的臨界點
#  實驗設計：
#    每輪 = 呼叫 /api/gc → 等待 5 分鐘冷卻 → Shot1（觸發冷啟動）
#          → 等待 N 分鐘 → Shot2（觀察是否冷啟動）
#    間隔序列：5, 10, 15, 20, 25, 30 分鐘（共 6 輪）
#  預計總耗時：
#    固定冷卻：6 輪 × 5 分鐘 = 30 分鐘
#    間隔等待：5+10+15+20+25+30 = 105 分鐘
#    合計：約 135 分鐘（2.25 小時）
# ============================================================

# ===== 設定區 =====
$endpoint        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculateleave"
$gcEndpoint      = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/gc"
$coldWaitSec     = 300           # GC 後固定冷卻等待（秒）= 5 分鐘
$coldThreshMs    = 500           # engine time 超過此值視為「冷啟動」（ms）
$outputDir       = "C:\Users\PT\Desktop\code\Graduate\src\test"

# 間隔序列（分鐘）→ 轉換為秒
$intervalMinutes = @(5, 10, 15, 20, 25, 30)
$intervalSeconds = $intervalMinutes | ForEach-Object { $_ * 60 }

# ===== 時間工具 =====
$twZone = [System.TimeZoneInfo]::FindSystemTimeZoneById("Taipei Standard Time")
function Get-TW {
    [System.TimeZoneInfo]::ConvertTimeFromUtc(
        (Get-Date).ToUniversalTime(), $twZone
    ).ToString("yyyy-MM-dd HH:mm:ss")
}

# ===== 日誌工具 =====
function Write-Log {
    param([string]$msg, [string]$color = "White")
    $line = "[$(Get-TW)] $msg"
    Write-Host $line -ForegroundColor $color
    Add-Content -Path $logFile -Value $line
}

# ===== 檔案初始化 =====
$timestamp = (Get-Date).ToString("yyyyMMdd_HHmmss")
$logFile   = Join-Path $outputDir "ColdInterval_Log_$timestamp.txt"
$csvFile   = Join-Path $outputDir "ColdInterval_Result_$timestamp.csv"

# CSV 標頭
"Round,IntervalMin,Shot,SentAt_TW,WallMs,EngineMs,IsCold,Note" |
    Out-File -FilePath $csvFile -Encoding UTF8

# ===== 測試 Payload =====
$payload = @{
    companyId        = "C001"
    employeeId       = "E999"
    position         = "Engineer"
    identity         = "fullTime"
    tenureMonths     = 24
    baseSalary       = 50000
    leaveType        = "事假"
    leaveDays        = 1
    deductionRate    = 0
    usedDaysThisYear = 0
} | ConvertTo-Json -Compress

# ===== 單筆請求函式 =====
function Invoke-Single {
    param([string]$label)

    $sentAt   = Get-TW
    $sw       = [System.Diagnostics.Stopwatch]::StartNew()
    $engineMs = -1
    $wallMs   = -1
    $isCold   = $false
    $note     = "OK"

    try {
        $resp = Invoke-WebRequest `
            -Uri         $endpoint `
            -Method      Post `
            -Body        $payload `
            -ContentType "application/json; charset=utf-8" `
            -Headers     @{ "x-test-case" = $label } `
            -UseBasicParsing

        $sw.Stop()
        $wallMs   = $sw.ElapsedMilliseconds
        $engineMs = [int]($resp.Headers["X-Execution-Time-Ms"] | Select-Object -First 1)
        $isCold   = ($engineMs -gt $coldThreshMs)

    } catch {
        $sw.Stop()
        $wallMs = $sw.ElapsedMilliseconds
        $note   = "FAIL: $($_.Exception.Message -replace ',', ' ')"
        $isCold = $false
    }

    return [PSCustomObject]@{
        SentAt   = $sentAt
        WallMs   = $wallMs
        EngineMs = $engineMs
        IsCold   = $isCold
        Note     = $note
    }
}

# ===== 呼叫 GC 端點函式 =====
function Invoke-GC {
    Write-Log "🗑️  呼叫 /api/gc 強制釋放記憶體..." "DarkYellow"
    try {
        $resp = Invoke-WebRequest `
            -Uri             $gcEndpoint `
            -Method          Get `
            -UseBasicParsing
        Write-Log "   GC 完成，狀態碼：$($resp.StatusCode)" "DarkYellow"
    } catch {
        Write-Log "   GC 呼叫失敗：$($_.Exception.Message)" "Red"
    }
}

# ===== 倒數等待函式 =====
function Wait-WithCountdown {
    param([int]$seconds, [string]$reason)
    Write-Log "⏳ 等待 $seconds 秒（$reason）..."
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        $left = [int]($end - (Get-Date)).TotalSeconds
        Write-Progress -Activity "等待中" -Status $reason -SecondsRemaining $left
        Start-Sleep -Seconds 1
    }
    Write-Progress -Activity "等待中" -Completed
    Write-Log "✅ 等待完成" "Green"
}

# ===== 主程式 =====
$totalEstMin = ($coldWaitSec / 60 * $intervalMinutes.Count) + ($intervalMinutes | Measure-Object -Sum).Sum

Write-Log "============================================================" "Cyan"
Write-Log "  鑫電星 HR 規則引擎 - 冷啟動間隔探測實驗 v2 開始" "Cyan"
Write-Log "  實驗時間（UTC+8）：$(Get-TW)" "Cyan"
Write-Log "  間隔序列：$($intervalMinutes -join ', ') 分鐘" "Cyan"
Write-Log "  每輪流程：/api/gc → 等待 $($coldWaitSec/60) 分鐘冷卻 → Shot1 → 等待 N 分鐘 → Shot2" "Cyan"
Write-Log "  冷啟動判定閾值：engine > $coldThreshMs ms" "Cyan"
Write-Log "  預計總耗時：約 $totalEstMin 分鐘（$([math]::Round($totalEstMin/60,2)) 小時）" "Cyan"
Write-Log "============================================================" "Cyan"

$roundNum = 0

foreach ($intervalSec in $intervalSeconds) {
    $intervalMin = $intervalSec / 60
    $roundNum++

    Write-Log "" "White"
    Write-Log "===== Round $roundNum / $($intervalSeconds.Count)：間隔 $intervalMin 分鐘（${intervalSec}s）=====" "Yellow"

    # ── 1. 呼叫 GC 釋放記憶體 ──
    Invoke-GC

    # ── 2. 等待 5 分鐘讓引擎冷卻（確保 Shot1 是冷啟動）──
    Wait-WithCountdown -seconds $coldWaitSec `
        -reason "GC 後等待引擎冷卻（Round $roundNum / $($intervalSeconds.Count)）"

    # ── 3. Shot1：觸發冷啟動 ──
    Write-Log "▶ [Round${roundNum}] Shot1 送出（預期冷啟動）..." "Cyan"
    $shot1 = Invoke-Single -label "Round${roundNum}_Shot1_Gap${intervalMin}min"

    $mark1 = if ($shot1.IsCold) { "🥶 冷啟動（符合預期）" } else { "⚠️ 未冷啟動（異常！請確認 GC 是否有效）" }
    $col1  = if ($shot1.IsCold) { "Magenta" }               else { "Red" }
    Write-Log ("  Shot1  wall={0}ms  engine={1}ms  {2}  {3}" -f `
        $shot1.WallMs, $shot1.EngineMs, $mark1, $shot1.Note) $col1

    # Shot1 若未冷啟動，記錄警告但仍繼續實驗
    if (-not $shot1.IsCold) {
        Write-Log "  ⚠️  Shot1 未達冷啟動閾值，本輪 Shot2 結果僅供參考！" "Red"
    }

    # CSV 寫入 Shot1
    "$roundNum,$intervalMin,1,$($shot1.SentAt),$($shot1.WallMs),$($shot1.EngineMs),$($shot1.IsCold),$($shot1.Note)" |
        Add-Content -Path $csvFile -Encoding UTF8

    # ── 4. 等待 N 分鐘 ──
    Wait-WithCountdown -seconds $intervalSec `
        -reason "等待間隔 $intervalMin 分鐘後送 Shot2（Round $roundNum）"

    # ── 5. Shot2：觀察是否再次冷啟動 ──
    Write-Log "▶ [Round${roundNum}] Shot2 送出（間隔 ${intervalMin} 分鐘後）..." "Cyan"
    $shot2 = Invoke-Single -label "Round${roundNum}_Shot2_Gap${intervalMin}min"

    $mark2 = if ($shot2.IsCold) { "🥶 冷啟動！" } else { "✅ 暖機" }
    $col2  = if ($shot2.IsCold) { "Red" }          else { "Green" }
    Write-Log ("  Shot2  wall={0}ms  engine={1}ms  {2}  {3}" -f `
        $shot2.WallMs, $shot2.EngineMs, $mark2, $shot2.Note) $col2

    # CSV 寫入 Shot2
    "$roundNum,$intervalMin,2,$($shot2.SentAt),$($shot2.WallMs),$($shot2.EngineMs),$($shot2.IsCold),$($shot2.Note)" |
        Add-Content -Path $csvFile -Encoding UTF8

    # ── 6. 本輪小結 ──
    $roundConclusion = if ($shot2.IsCold) { "❌ 第二筆冷啟動" } else { "✅ 第二筆暖機" }
    $roundColor      = if ($shot2.IsCold) { "Red" }             else { "Green" }
    Write-Log ("  ── 本輪結論：間隔 {0} 分鐘 → {1}" -f $intervalMin, $roundConclusion) $roundColor
}

# ===== 最終報告 =====
Write-Log "" "White"
Write-Log "============================================================" "Cyan"
Write-Log "  實驗完成！最終結果摘要" "Cyan"
Write-Log "  完成時間（UTC+8）：$(Get-TW)" "Cyan"
Write-Log "============================================================" "Cyan"

$results      = Import-Csv $csvFile
$shot2Results = $results | Where-Object { $_.Shot -eq "2" }

Write-Log "" "White"
Write-Log ("  {0,-12} {1,-20} {2}" -f "間隔(min)", "第二筆 engine(ms)", "是否冷啟動") "White"
Write-Log ("  {0,-12} {1,-20} {2}" -f "---------", "----------------", "----------") "White"

$firstColdMin = $null
$prevMin      = $null

foreach ($row in $shot2Results) {
    $mark = if ($row.IsCold -eq "True") { "🥶 YES" } else { "✅ NO " }
    $col  = if ($row.IsCold -eq "True") { "Red" }    else { "Green" }
    Write-Log ("  {0,-12} {1,-20} {2}" -f $row.IntervalMin, $row.EngineMs, $mark) $col

    if ($row.IsCold -eq "True" -and $null -eq $firstColdMin) {
        $firstColdMin = [int]$row.IntervalMin
    } elseif ($row.IsCold -ne "True") {
        $prevMin = [int]$row.IntervalMin
    }
}

Write-Log "" "White"
if ($null -ne $firstColdMin) {
    if ($null -ne $prevMin) {
        Write-Log "  🎯 冷啟動閾值：間隔介於 ${prevMin} 分鐘 ~ ${firstColdMin} 分鐘之間" "Yellow"
    } else {
        Write-Log "  🎯 冷啟動閾值：間隔 ${firstColdMin} 分鐘時即出現冷啟動（含更短間隔未測試）" "Yellow"
    }
    Write-Log "     → 第二筆在間隔 $firstColdMin 分鐘時首次出現冷啟動" "Yellow"
} else {
    Write-Log "  🎯 在所有測試間隔（最長 30 分鐘）內，第二筆均未觸發冷啟動" "Yellow"
}

Write-Log "" "White"
Write-Log "  📄 詳細結果 CSV：$csvFile" "Cyan"
Write-Log "  📄 完整日誌：$logFile"     "Cyan"
Write-Log "============================================================" "Cyan"
