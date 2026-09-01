# # # =========================================================
# # # experiment_all.ps1 — 完整一條龍 + 500 筆批次雙層比對
# # #   NL -> JSON -> 存DRL -> 查DRL轉Java -> build -> 部署 -> 查詢 -> 比對
# # #
# # # 本輪重點：公司 10 客製（事假半扣 0.5；平日加班前2H×2、超過×4），
# # #   一次送出 500 筆隨機員工資料，雙層驗證：
# # #     第一層：DRL 端點 ↔ 硬編碼 Java 端點（逐筆數值一致）
# # #     第二層：DRL 計算結果 ↔ 公司應有值（逐筆套用公司客製規則）
# # #
# # # 用法：
# # #   ./experiment_all.ps1                 # 完整跑（含部署 + 比對）
# # #   ./experiment_all.ps1 -SkipDeploy     # 跑到編譯關卡，不部署不比對
# # #   ./experiment_all.ps1 -NoReset        # 不清空 DRL
# # #   ./experiment_all.ps1 -OnlyCompare    # 跳過 0-6，直接跑 500 筆比對（規則已部署時用）
# # # =========================================================

# # param(
# #     [string]$ProjectRoot = "C:\Users\PT\Desktop\code\Graduate",
# #     [string]$CompanyId   = "10",
# #     [int]$MaxFix         = 3,
# #     [int]$N              = 500,        # 一次送出的員工筆數
# #     [switch]$NoReset,
# #     [switch]$SkipDeploy,
# #     [switch]$OnlyCompare              # 規則已部署，只想重跑 500 筆比對
# # )

# # $BaseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # $ParseRuleUrl   = "$BaseUrl/ai/parse-rule"
# # $UpdateRulesUrl = "$BaseUrl/updaterules"
# # $ResetRulesUrl  = "$BaseUrl/resetrules"
# # $GenJavaUrl     = "$BaseUrl/ai/generate-java"
# # $DrlCalcUrl     = "$BaseUrl/calculatesalary"
# # $LegacyUrl      = "$BaseUrl/checksalary/legacy"
# # $QueryUrl       = "$BaseUrl/rules/Salary/Company_${CompanyId}_Salary.drl"

# # [System.Net.ServicePointManager]::SecurityProtocol       = [System.Net.SecurityProtocolType]::Tls12
# # [System.Net.ServicePointManager]::DefaultConnectionLimit = 100

# # # ── 公司 10 的自然語言規則 ──
# # $Prompts = @(
# #     "公司10的員工平日有加班時數的話，加班費前兩小時2倍、超過兩小時4倍。"
# #     "公司10的員工請事假，只扣一半薪水（扣薪比率0.5），這跟一般公司全額扣薪不同。"
# # )

# # # 比對時忽略的非數值/易變欄位
# # $IgnoreKeys = @('appliedRule','ruleDetails','notes','warnings','executionTimeMs','timestamp','computeTime','message','employeeId')

# # # ── 公司客製比率（用於第二層「公司應有值」預測）──
# # $LEAVE_RATE = 0.5    # 公司10事假半扣（通用為 1.0 全扣）
# # $OT_R1      = 2.0    # 平日加班前 2 小時倍率（公司）
# # $OT_R2      = 4.0    # 平日加班超過 2 小時倍率（公司）

# # # ── 共用：POST hashtable / 純 JSON ──
# # function Invoke-ApiJson {
# #     param([string]$Url, [hashtable]$Payload, [int]$TimeoutSec = 180)
# #     $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 8 -Compress))
# #     Invoke-Raw $Url $bytes $TimeoutSec
# # }
# # function Invoke-PostJson {
# #     param([string]$Url, [string]$JsonBody, [int]$TimeoutSec = 120)
# #     $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
# #     Invoke-Raw $Url $bytes $TimeoutSec
# # }
# # function Invoke-Raw {
# #     param([string]$Url, [byte[]]$Bytes, [int]$TimeoutSec)
# #     try {
# #         $resp = Invoke-WebRequest -Uri $Url -Method POST -Body $Bytes `
# #             -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec -ErrorAction Stop
# #         return @{ Ok=$true; Json=($resp.Content | ConvertFrom-Json) }
# #     } catch {
# #         $b = $null
# #         if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $b = $_.ErrorDetails.Message }
# #         elseif ($_.Exception.Response) { try { $b = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {} }
# #         return @{ Ok=$false; Error=$_.Exception.Message; Body=$b }
# #     }
# # }
# # function Norm($o) {
# #     if ($o -is [System.Management.Automation.PSCustomObject]) {
# #         $h = [ordered]@{}
# #         foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) {
# #             if ($IgnoreKeys -contains $p.Name) { continue }
# #             $h[$p.Name] = Norm $p.Value
# #         }
# #         return $h
# #     } elseif (($o -is [System.Collections.IEnumerable]) -and ($o -isnot [string])) {
# #         return @($o | ForEach-Object { Norm $_ })
# #     } else {
# #         $d = 0.0
# #         if ($null -ne $o -and [double]::TryParse([string]$o, [ref]$d)) { return ('{0:N2}' -f $d) }
# #         return [string]$o
# #     }
# # }
# # function Get-Diffs($a, $b, $path) {
# #     $diffs = @()
# #     if (($a -is [System.Collections.IDictionary]) -and ($b -is [System.Collections.IDictionary])) {
# #         $keys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
# #         foreach ($k in $keys) {
# #             $av = if ($a.Contains($k)) { $a[$k] } else { '<缺>' }
# #             $bv = if ($b.Contains($k)) { $b[$k] } else { '<缺>' }
# #             $p  = if ($path) { "$path.$k" } else { "$k" }
# #             $diffs += Get-Diffs $av $bv $p
# #         }
# #     } elseif (($a -is [array]) -and ($b -is [array])) {
# #         if ($a.Count -ne $b.Count) { $diffs += "$path[長度] DRL=$($a.Count) Java=$($b.Count)" }
# #         $n = [Math]::Min($a.Count, $b.Count)
# #         for ($i=0; $i -lt $n; $i++) { $diffs += Get-Diffs $a[$i] $b[$i] "$path[$i]" }
# #     } else {
# #         if ("$a" -ne "$b") { $diffs += "${path}: DRL=$a  Java=$b" }
# #     }
# #     return $diffs
# # }

# # # ── 公司應有值預測（時薪 = 底薪/30/8；底薪取 240 倍數 → 時薪整數，精確）──
# # function Predict-Leave($base, $h) {
# #     if ($h -le 0) { return [double]0 }
# #     return [math]::Round([double]($base/240.0) * $h * $LEAVE_RATE, 2, [System.MidpointRounding]::AwayFromZero)
# # }
# # function Predict-Ot($base, $h) {
# #     if ($h -le 0) { return [double]0 }
# #     $hourly = $base/240.0
# #     $units  = ([math]::Min($h,2) * $OT_R1) + ([math]::Max($h-2,0) * $OT_R2)
# #     return [math]::Round([double]$hourly * $units, 2, [System.MidpointRounding]::AwayFromZero)
# # }

# # # =====================================================================
# # # Step 0-6：一條龍（NL→DRL→Java→部署）。-OnlyCompare 時整段跳過。
# # # =====================================================================
# # if (-not $OnlyCompare) {

# #     if (-not (Test-Path (Join-Path $ProjectRoot "pom.xml"))) {
# #         $probe = (Get-Location).Path
# #         while ($probe -and -not (Test-Path (Join-Path $probe "pom.xml"))) {
# #             $parent = Split-Path $probe -Parent
# #             if ($parent -eq $probe) { $probe = $null; break }
# #             $probe = $parent
# #         }
# #         if ($probe) { $ProjectRoot = $probe } else { Write-Host "找不到 pom.xml，請用 -ProjectRoot 指定" -ForegroundColor Red; exit 1 }
# #     }
# #     $ProjectRoot    = (Resolve-Path $ProjectRoot).Path
# #     $SalaryRulesDir = Join-Path $ProjectRoot "src\main\java\com\function\function\SalaryRules"
# #     $JavaPath       = Join-Path $SalaryRulesDir "Company${CompanyId}Rule.java"
# #     New-Item -ItemType Directory -Force -Path $SalaryRulesDir | Out-Null
# #     Write-Host "專案根目錄: $ProjectRoot" -ForegroundColor DarkCyan
# #     Write-Host "目標公司  : $CompanyId  ->  $JavaPath`n" -ForegroundColor DarkCyan

# #     # ── Step 0：重置 ──
# #     if (-not $NoReset) {
# #         Write-Host "[0] 重置公司 $CompanyId ... " -NoNewline
# #         $rr = Invoke-ApiJson -Url $ResetRulesUrl -Payload @{ ruleSet="salary"; companyId="$CompanyId" }
# #         if ($rr.Ok) { Write-Host "DRL 已清空" -ForegroundColor Green -NoNewline } else { Write-Host "重置失敗(可能未部署ResetRules): $($rr.Error) $($rr.Body)" -ForegroundColor Yellow -NoNewline }
# #         if (Test-Path $JavaPath) { Remove-Item $JavaPath -Force; Write-Host "；已刪舊 Java" -ForegroundColor Green } else { Write-Host "" }
# #     } else { Write-Host "[0] -NoReset：保留 DRL" -ForegroundColor DarkYellow }

# #     # ── Step 1+2：NL -> JSON -> 存 DRL ──
# #     $ruleCount = 0
# #     for ($i=0; $i -lt $Prompts.Count; $i++) {
# #         Write-Host "`n[1] parse-rule ($($i+1)/$($Prompts.Count)) ... " -NoNewline
# #         $pr = Invoke-ApiJson -Url $ParseRuleUrl -Payload @{ text=$Prompts[$i]; ruleSet="salary"; companyId="$CompanyId" }
# #         if (-not $pr.Ok) { Write-Host "失敗: $($pr.Error) $($pr.Body)" -ForegroundColor Red; continue }
# #         $rules = if ($pr.Json -is [array]) { $pr.Json } else { @($pr.Json) }
# #         Write-Host "$($rules.Count) 條規則" -ForegroundColor Green
# #         foreach ($rule in $rules) {
# #             $cleanConditions = @()
# #             if ($rule.conditions) {
# #                 foreach ($cond in $rule.conditions) {
# #                     if (($cond.value -is [System.Management.Automation.PSCustomObject]) -or ($cond.operator -eq "+")) { continue }
# #                     $clean = @{}
# #                     if ($cond.field)           { $clean.field    = $cond.field }
# #                     if ($cond.operator)        { $clean.operator = $cond.operator }
# #                     if ($null -ne $cond.value) { $clean.value    = $cond.value }
# #                     if ($clean.field -and $clean.operator) { $cleanConditions += $clean }
# #                 }
# #             }
# #             $up = @{
# #                 ruleSet="salary"; companyId="$CompanyId"
# #                 ruleName = if ($rule.ruleName) { $rule.ruleName } else { "rule_$i" }
# #                 author="pipeline"; version=1
# #                 priority = if ($rule.priority) { [int]$rule.priority } else { 8 }
# #             }
# #             if ($cleanConditions.Count -gt 0) { $up.conditions     = $cleanConditions }
# #             if ($rule.action)                 { $up.action          = $rule.action }
# #             if ($rule.actionNote)             { $up.actionNote      = $rule.actionNote }
# #             if ($rule.actionWarning)          { $up.actionWarning   = $rule.actionWarning }
# #             if ($rule.activationGroup)        { $up.activationGroup = $rule.activationGroup }
# #             Write-Host "    [2] updaterules: $($up.ruleName) ... " -NoNewline
# #             $ur = Invoke-ApiJson -Url $UpdateRulesUrl -Payload $up
# #             if ($ur.Ok) { Write-Host "OK" -ForegroundColor Green; $ruleCount++ } else { Write-Host "失敗: $($ur.Error) $($ur.Body)" -ForegroundColor Red }
# #         }
# #     }
# #     if ($ruleCount -eq 0) { Write-Host "`n沒有任何規則寫入，結束。" -ForegroundColor Red; exit 1 }
# #     Write-Host "`n已寫入 $ruleCount 條規則" -ForegroundColor Green
# #     Start-Sleep -Seconds 2

# #     # ── Step 3：查 DRL -> AI 轉 Java ──
# #     Write-Host "`n[3] generate-java ... " -NoNewline
# #     $gj = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId" }
# #     if (-not $gj.Ok -or -not $gj.Json.javaCode) { Write-Host "失敗: $($gj.Error) $($gj.Body)" -ForegroundColor Red; exit 1 }
# #     $gj.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8
# #     Write-Host "OK（DRL $($gj.Json.sourceDrlChars) 字元）" -ForegroundColor Green

# #     # ── Step 4：本地編譯關卡 + AI 修復 ──
# #     function Invoke-MvnCompile {
# #         Push-Location $ProjectRoot
# #         $out = & mvn -q compile 2>&1 | Out-String
# #         $ok  = ($LASTEXITCODE -eq 0)
# #         Pop-Location
# #         return @{ Ok=$ok; Out=$out }
# #     }
# #     $attempt = 0
# #     while ($true) {
# #         Write-Host "`n[4] mvn compile (第 $($attempt+1) 次) ..." -ForegroundColor Cyan
# #         $c = Invoke-MvnCompile
# #         if ($c.Ok) { Write-Host "編譯通過 OK" -ForegroundColor Green; break }
# #         Write-Host "編譯失敗" -ForegroundColor Red
# #         if ($attempt -ge $MaxFix) {
# #             Write-Host (($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -First 20) -join "`n")
# #             exit 1
# #         }
# #         $attempt++
# #         $errLines = ($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" }) -join "`n"
# #         Write-Host "  -> 請 AI 修 ..." -ForegroundColor Yellow
# #         $cur = Get-Content $JavaPath -Raw
# #         $fix = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; previousCode=$cur; compileError=$errLines }
# #         if ($fix.Ok -and $fix.Json.javaCode) { $fix.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8; Write-Host "     已套用修正" -ForegroundColor DarkGreen }
# #         else { Write-Host "     AI 修復失敗: $($fix.Error) $($fix.Body)" -ForegroundColor Red }
# #     }

# #     if ($SkipDeploy) { Write-Host "`n-SkipDeploy：已編譯通過，未部署。" -ForegroundColor Yellow; exit 0 }

# #     # ── Step 5：部署 ──
# #     Write-Host "`n[5] mvn clean package azure-functions:deploy ..." -ForegroundColor Cyan
# #     Push-Location $ProjectRoot
# #     $start = Get-Date
# #     & mvn clean package azure-functions:deploy
# #     $ok = ($LASTEXITCODE -eq 0)
# #     Pop-Location
# #     if (-not $ok) { Write-Host "部署失敗 (exit=$LASTEXITCODE)" -ForegroundColor Red; exit 1 }
# #     Write-Host ("部署成功（{0} 分）。" -f [math]::Round(((Get-Date)-$start).TotalMinutes,1)) -ForegroundColor Green
# #     Write-Host "等冷啟動 30 秒 ..." -ForegroundColor DarkGray
# #     Start-Sleep -Seconds 30

# #     # ── Step 6：查詢規則 ──
# #     Write-Host "`n==================== [查詢規則] ====================" -ForegroundColor Cyan
# #     try {
# #         $drlResp = Invoke-WebRequest -Uri $QueryUrl -Method GET -TimeoutSec 60 -ErrorAction Stop
# #         Write-Host $drlResp.Content
# #     } catch { Write-Host "查詢 DRL 失敗：$($_.Exception.Message)" -ForegroundColor Yellow }

# # } else {
# #     Write-Host "[OnlyCompare] 跳過 Step 0-6，直接跑 $N 筆比對。" -ForegroundColor DarkYellow
# # }

# # # =====================================================================
# # # Step 7：隨機 500 筆，一次送出，雙層比對（DRL↔Java、DRL↔公司應有值）
# # # =====================================================================
# # Write-Host "`n==================== [500 筆雙層比對] ====================" -ForegroundColor Cyan

# # # ── 7-1 產生 N 筆隨機員工（companyId=10）──
# # Get-Random -SetSeed 20250201 | Out-Null
# # $records = New-Object System.Collections.Generic.List[object]
# # $expect  = @{}                  # employeeId -> @{ base; otH; lvH; leave; ot; final }
# # $nOt=0; $nLv=0; $nBoth=0; $nNone=0
# # for ($i=0; $i -lt $N; $i++) {
# #     $base  = (Get-Random -Minimum 100 -Maximum 376) * 240      # 24,000~90,000，240 倍數
# #     $hasOt = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶平日加班
# #     $hasLv = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶事假
# #     $otH   = if ($hasOt) { Get-Random -Minimum 1 -Maximum 17 } else { 0 }   # 1~16h
# #     $lvH   = if ($hasLv) { Get-Random -Minimum 1 -Maximum 17 } else { 0 }
# #     $eid   = "C10-{0:D4}" -f $i

# #     $rec = @{ companyId="10"; employeeId=$eid; baseSalary=$base; tenureMonths=(Get-Random -Minimum 1 -Maximum 241) }
# #     if ($hasOt) { $rec.overtimes = @(@{ overtimeType="WEEKDAY"; overtimeHours=$otH }) }
# #     if ($hasLv) { $rec.leaves    = @(@{ leaveTypeName="事假"; leaveHours=$lvH; leaveDays=1 }) }
# #     $records.Add($rec)

# #     $el = Predict-Leave $base $lvH
# #     $eo = Predict-Ot    $base $otH
# #     $expect[$eid] = @{ base=$base; otH=$otH; lvH=$lvH; leave=$el; ot=$eo; final=[math]::Round([double]$base - $el + $eo, 2) }

# #     if     ($hasOt -and $hasLv) { $nBoth++ }
# #     elseif ($hasOt)             { $nOt++ }
# #     elseif ($hasLv)             { $nLv++ }
# #     else                        { $nNone++ }
# # }
# # Write-Host ("已產生 {0} 筆：純加班 {1}｜純事假 {2}｜加班+事假 {3}｜無扣項 {4}" -f $N,$nOt,$nLv,$nBoth,$nNone) -ForegroundColor DarkGray

# # # ── 7-2 一次送出（兩端點各一個批次陣列）──
# # function Post-Batch($url, $recs, $timeout=300) {
# #     $json  = $recs | ConvertTo-Json -Depth 10
# #     $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
# #     $sw = [System.Diagnostics.Stopwatch]::StartNew()
# #     $resp = Invoke-WebRequest -Uri $url -Method POST -Body $bytes `
# #             -ContentType "application/json; charset=utf-8" -TimeoutSec $timeout -UseBasicParsing
# #     $sw.Stop()
# #     $sv = $resp.Headers["X-Execution-Time-Ms"]; if ($sv -is [array]) { $sv = $sv[0] }
# #     return @{ items=($resp.Content | ConvertFrom-Json); ms=$sw.ElapsedMilliseconds; server=$sv }
# # }

# # Write-Host "`n送出 DRL 端點（$N 筆）... " -NoNewline
# # $drl = Post-Batch $DrlCalcUrl $records
# # Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $drl.ms, $drl.server, $drl.items.Count) -ForegroundColor Green
# # Write-Host "送出 Java 端點（$N 筆）... " -NoNewline
# # $jav = Post-Batch $LegacyUrl $records
# # Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $jav.ms, $jav.server, $jav.items.Count) -ForegroundColor Green

# # # ── 7-3 以 employeeId 對映 ──
# # $drlMap=@{}; foreach ($w in $drl.items) { $drlMap[$w.employeeId]=$w }
# # $javMap=@{}; foreach ($w in $jav.items) { $javMap[$w.employeeId]=$w }

# # # ── 7-4 雙層逐筆比對 ──
# # $L1pass=0; $L1fail=0     # 第一層：DRL ↔ Java
# # $L2pass=0; $L2fail=0     # 第二層：DRL ↔ 公司應有值
# # $L1fails=New-Object System.Collections.Generic.List[string]
# # $L2fails=New-Object System.Collections.Generic.List[string]
# # $sample =New-Object System.Collections.Generic.List[object]

# # foreach ($eid in $expect.Keys) {
# #     $ex=$expect[$eid]; $dw=$drlMap[$eid]; $jw=$javMap[$eid]
# #     if ($null -eq $dw -or $null -eq $jw) { $L1fail++; $L2fail++; $L1fails.Add("$eid 缺回傳（DRL=$([bool]$dw) Java=$([bool]$jw)）"); continue }
# #     if ($dw.error -or $jw.error)         { $L1fail++; $L2fail++; $L1fails.Add("$eid 回傳錯誤 DRL=$($dw.error) Java=$($jw.error)"); continue }
# #     $dr=$dw.result; $jr=$jw.result

# #     # 第一層：DRL ↔ Java（整包數值比對，忽略易變欄位）
# #     $diffs = Get-Diffs (Norm $dr) (Norm $jr) ""
# #     if (-not $diffs -or $diffs.Count -eq 0) { $L1pass++ }
# #     else { $L1fail++; $L1fails.Add("$eid ($($diffs.Count) 處)： " + ($diffs -join " ; ")) }

# #     # 第二層：DRL ↔ 公司應有值（事假半扣、加班2/4倍、實領）
# #     $okL = [math]::Abs([double]$dr.leaveDeduction - [double]$ex.leave) -le 0.01
# #     $okO = [math]::Abs([double]$dr.overtimeBonus  - [double]$ex.ot)    -le 0.01
# #     $okF = [math]::Abs([double]$dr.finalSalary    - [double]$ex.final) -le 0.01
# #     if ($okL -and $okO -and $okF) { $L2pass++ }
# #     else {
# #         $L2fail++
# #         $L2fails.Add(("{0} 底薪{1} 事假{2}h 加班{3}h | 事假扣 DRL={4}/應{5} 加班 DRL={6}/應{7} 實領 DRL={8}/應{9}" -f `
# #             $eid,$ex.base,$ex.lvH,$ex.otH,$dr.leaveDeduction,$ex.leave,$dr.overtimeBonus,$ex.ot,$dr.finalSalary,$ex.final))
# #     }

# #     if ($sample.Count -lt 12) {
# #         $sample.Add([pscustomobject]@{ eid=$eid; base=$ex.base; lvH=$ex.lvH; otH=$ex.otH;
# #             leaveD=$dr.leaveDeduction; leaveE=$ex.leave; otD=$dr.overtimeBonus; otE=$ex.ot; finD=$dr.finalSalary; finE=$ex.final })
# #     }
# # }

# # # ── 7-5 彙總 ──
# # $total=$expect.Count
# # $r1 = if ($total) { [math]::Round($L1pass*100.0/$total,1) } else { 0 }
# # $r2 = if ($total) { [math]::Round($L2pass*100.0/$total,1) } else { 0 }

# # Write-Host "`n==================== 結果 ====================" -ForegroundColor Cyan
# # $c1 = if ($L1fail -eq 0) { "Green" } else { "Red" }
# # $c2 = if ($L2fail -eq 0) { "Green" } else { "Red" }
# # Write-Host ("第一層 DRL ↔ Java        ：{0}/{1} = {2}%" -f $L1pass,$total,$r1) -ForegroundColor $c1
# # Write-Host ("第二層 DRL ↔ 公司應有值  ：{0}/{1} = {2}%" -f $L2pass,$total,$r2) -ForegroundColor $c2

# # Write-Host "`n--- 效能（兩端點各一次批次）---" -ForegroundColor Cyan
# # Write-Host ("  DRL 端點 ：往返 {0} ms，伺服器 {1} ms" -f $drl.ms,$drl.server)
# # Write-Host ("  Java 端點：往返 {0} ms，伺服器 {1} ms" -f $jav.ms,$jav.server)

# # if ($L1fail -gt 0) {
# #     Write-Host "`n[第一層不一致，前 10 筆]" -ForegroundColor Red
# #     $L1fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
# # }
# # if ($L2fail -gt 0) {
# #     Write-Host "`n[第二層與公司應有值不符，前 10 筆]" -ForegroundColor Red
# #     $L2fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
# # }

# # # ── 7-6 抽樣明細（前 12 筆）──
# # Write-Host "`n[ 抽樣明細（前 12 筆，DRL 值 = 公司應有值）]" -ForegroundColor Cyan
# # Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20}" -f "員工","底薪","事假h","加班h","事假扣(DRL/應)","加班費(DRL/應)","實領(DRL/應)")
# # foreach ($s in $sample) {
# #     Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20}" -f `
# #         $s.eid,$s.base,$s.lvH,$s.otH,("$($s.leaveD)/$($s.leaveE)"),("$($s.otD)/$($s.otE)"),("$($s.finD)/$($s.finE)"))
# # }

# # Write-Host "`n★ 雙層全綠 => 自然語言轉出的 DRL 規則，計算結果與硬編碼 Java 完全一致，" -ForegroundColor Magenta
# # Write-Host "   且皆套用公司10客製（事假半扣、加班2/4倍），語義與執行層均正確。" -ForegroundColor Magenta

# # =========================================================
# # experiment_all.ps1 — 完整一條龍 + 500 筆批次雙層比對
# #   NL -> parse-rule(JSON) -> 存DRL(Blob) ；並把「JSON規則」直接轉Java(不經DRL) -> build -> 部署 -> 比對
# #
# #   ★流程變更（實驗二）：
# #     舊：新增規則 -> Blob儲存 -> generate-java 用 companyId 去查Blob的DRL -> 轉Java
# #     新：AI解析(parse-rule)的 JSON 規則，直接送 generate-java 的 rules 模式 -> 轉Java（完全不經 DRL）。
# #         左路徑（updaterules 仍寫 Blob -> 規則引擎動態載入 -> 測試輸入）維持不變。
# #     需搭配後端 AiExplainFunction.java 的 generate-java 新增 rules 模式（見同目錄改好的檔）。
# #
# # 本輪重點：公司 10 客製（事假半扣 0.5；平日加班前2H×2、超過×4），
# #   一次送出 500 筆隨機員工資料，雙層驗證：
# #     第一層：DRL 端點 ↔ 硬編碼 Java 端點（逐筆數值一致）
# #     第二層：DRL 計算結果 ↔ 公司應有值（逐筆套用公司客製規則）
# #
# # 用法：
# #   ./experiment_all.ps1                 # 完整跑（含部署 + 比對）
# #   ./experiment_all.ps1 -SkipDeploy     # 跑到編譯關卡，不部署不比對
# #   ./experiment_all.ps1 -NoReset        # 不清空 DRL
# #   ./experiment_all.ps1 -OnlyCompare    # 跳過 0-6，直接跑 500 筆比對（規則已部署時用）
# # =========================================================

# param(
#     [string]$ProjectRoot = "C:\Users\PT\Desktop\code\Graduate",
#     [string]$CompanyId   = "10",
#     [int]$MaxFix         = 3,
#     [int]$N              = 500,        # 一次送出的員工筆數
#     [switch]$NoReset,
#     [switch]$SkipDeploy,
#     [switch]$OnlyCompare              # 規則已部署，只想重跑 500 筆比對
# )

# $BaseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# $ParseRuleUrl   = "$BaseUrl/ai/parse-rule"
# $UpdateRulesUrl = "$BaseUrl/updaterules"
# $ResetRulesUrl  = "$BaseUrl/resetrules"
# $GenJavaUrl     = "$BaseUrl/ai/generate-java"
# $DrlCalcUrl     = "$BaseUrl/calculatesalary"
# $LegacyUrl      = "$BaseUrl/checksalary/legacy"
# $QueryUrl       = "$BaseUrl/rules/Salary/Company_${CompanyId}_Salary.drl"

# [System.Net.ServicePointManager]::SecurityProtocol       = [System.Net.SecurityProtocolType]::Tls12
# [System.Net.ServicePointManager]::DefaultConnectionLimit = 100

# # ── 公司 10 的自然語言規則 ──
# $Prompts = @(
#     "公司10的員工平日有加班時數的話，加班費前兩小時2倍、超過兩小時4倍。"
#     "公司10的員工請事假，只扣一半薪水（扣薪比率0.5），這跟一般公司全額扣薪不同。"
# )

# # 比對時忽略的非數值/易變欄位
# $IgnoreKeys = @('appliedRule','ruleDetails','notes','warnings','executionTimeMs','timestamp','computeTime','message','employeeId')

# # ── 公司客製比率（用於第二層「公司應有值」預測）──
# $LEAVE_RATE = 0.5    # 公司10事假半扣（通用為 1.0 全扣）
# $OT_R1      = 2.0    # 平日加班前 2 小時倍率（公司）
# $OT_R2      = 4.0    # 平日加班超過 2 小時倍率（公司）

# # ── 共用：POST hashtable / 純 JSON ──
# function Invoke-ApiJson {
#     param([string]$Url, [hashtable]$Payload, [int]$TimeoutSec = 180)
#     $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 8 -Compress))
#     Invoke-Raw $Url $bytes $TimeoutSec
# }
# function Invoke-PostJson {
#     param([string]$Url, [string]$JsonBody, [int]$TimeoutSec = 120)
#     $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
#     Invoke-Raw $Url $bytes $TimeoutSec
# }
# function Invoke-Raw {
#     param([string]$Url, [byte[]]$Bytes, [int]$TimeoutSec)
#     try {
#         $resp = Invoke-WebRequest -Uri $Url -Method POST -Body $Bytes `
#             -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec -ErrorAction Stop
#         return @{ Ok=$true; Json=($resp.Content | ConvertFrom-Json) }
#     } catch {
#         $b = $null
#         if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $b = $_.ErrorDetails.Message }
#         elseif ($_.Exception.Response) { try { $b = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {} }
#         return @{ Ok=$false; Error=$_.Exception.Message; Body=$b }
#     }
# }
# function Norm($o) {
#     if ($o -is [System.Management.Automation.PSCustomObject]) {
#         $h = [ordered]@{}
#         foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) {
#             if ($IgnoreKeys -contains $p.Name) { continue }
#             $h[$p.Name] = Norm $p.Value
#         }
#         return $h
#     } elseif (($o -is [System.Collections.IEnumerable]) -and ($o -isnot [string])) {
#         return @($o | ForEach-Object { Norm $_ })
#     } else {
#         $d = 0.0
#         if ($null -ne $o -and [double]::TryParse([string]$o, [ref]$d)) { return ('{0:N2}' -f $d) }
#         return [string]$o
#     }
# }
# function Get-Diffs($a, $b, $path) {
#     $diffs = @()
#     if (($a -is [System.Collections.IDictionary]) -and ($b -is [System.Collections.IDictionary])) {
#         $keys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
#         foreach ($k in $keys) {
#             $av = if ($a.Contains($k)) { $a[$k] } else { '<缺>' }
#             $bv = if ($b.Contains($k)) { $b[$k] } else { '<缺>' }
#             $p  = if ($path) { "$path.$k" } else { "$k" }
#             $diffs += Get-Diffs $av $bv $p
#         }
#     } elseif (($a -is [array]) -and ($b -is [array])) {
#         if ($a.Count -ne $b.Count) { $diffs += "$path[長度] DRL=$($a.Count) Java=$($b.Count)" }
#         $n = [Math]::Min($a.Count, $b.Count)
#         for ($i=0; $i -lt $n; $i++) { $diffs += Get-Diffs $a[$i] $b[$i] "$path[$i]" }
#     } else {
#         if ("$a" -ne "$b") { $diffs += "${path}: DRL=$a  Java=$b" }
#     }
#     return $diffs
# }

# # ── 公司應有值預測（時薪 = 底薪/30/8；底薪取 240 倍數 → 時薪整數，精確）──
# function Predict-Leave($base, $h) {
#     if ($h -le 0) { return [double]0 }
#     return [math]::Round([double]($base/240.0) * $h * $LEAVE_RATE, 2, [System.MidpointRounding]::AwayFromZero)
# }
# function Predict-Ot($base, $h) {
#     if ($h -le 0) { return [double]0 }
#     $hourly = $base/240.0
#     $units  = ([math]::Min($h,2) * $OT_R1) + ([math]::Max($h-2,0) * $OT_R2)
#     return [math]::Round([double]$hourly * $units, 2, [System.MidpointRounding]::AwayFromZero)
# }

# # =====================================================================
# # Step 0-6：一條龍（NL→解析→存DRL；解析結果直接→Java→部署）。-OnlyCompare 時整段跳過。
# # =====================================================================
# if (-not $OnlyCompare) {

#     if (-not (Test-Path (Join-Path $ProjectRoot "pom.xml"))) {
#         $probe = (Get-Location).Path
#         while ($probe -and -not (Test-Path (Join-Path $probe "pom.xml"))) {
#             $parent = Split-Path $probe -Parent
#             if ($parent -eq $probe) { $probe = $null; break }
#             $probe = $parent
#         }
#         if ($probe) { $ProjectRoot = $probe } else { Write-Host "找不到 pom.xml，請用 -ProjectRoot 指定" -ForegroundColor Red; exit 1 }
#     }
#     $ProjectRoot    = (Resolve-Path $ProjectRoot).Path
#     $SalaryRulesDir = Join-Path $ProjectRoot "src\main\java\com\function\function\SalaryRules"
#     $JavaPath       = Join-Path $SalaryRulesDir "Company${CompanyId}Rule.java"
#     New-Item -ItemType Directory -Force -Path $SalaryRulesDir | Out-Null
#     Write-Host "專案根目錄: $ProjectRoot" -ForegroundColor DarkCyan
#     Write-Host "目標公司  : $CompanyId  ->  $JavaPath`n" -ForegroundColor DarkCyan

#     # ── Step 0：重置 ──
#     if (-not $NoReset) {
#         Write-Host "[0] 重置公司 $CompanyId ... " -NoNewline
#         $rr = Invoke-ApiJson -Url $ResetRulesUrl -Payload @{ ruleSet="salary"; companyId="$CompanyId" }
#         if ($rr.Ok) { Write-Host "DRL 已清空" -ForegroundColor Green -NoNewline } else { Write-Host "重置失敗(可能未部署ResetRules): $($rr.Error) $($rr.Body)" -ForegroundColor Yellow -NoNewline }
#         if (Test-Path $JavaPath) { Remove-Item $JavaPath -Force; Write-Host "；已刪舊 Java" -ForegroundColor Green } else { Write-Host "" }
#     } else { Write-Host "[0] -NoReset：保留 DRL" -ForegroundColor DarkYellow }

#     # ── Step 1+2：NL -> JSON -> 存 DRL（Blob）；同時收集「AI 解析結果」，供直接轉 Java 用 ──
#     $ruleCount = 0
#     $parsedRules = New-Object System.Collections.Generic.List[object]   # ★收集 parse-rule 解析出的規則（$up），稍後以 JSON 直接轉 Java（不經 DRL）
#     for ($i=0; $i -lt $Prompts.Count; $i++) {
#         Write-Host "`n[1] parse-rule ($($i+1)/$($Prompts.Count)) ... " -NoNewline
#         $pr = Invoke-ApiJson -Url $ParseRuleUrl -Payload @{ text=$Prompts[$i]; ruleSet="salary"; companyId="$CompanyId" }
#         if (-not $pr.Ok) { Write-Host "失敗: $($pr.Error) $($pr.Body)" -ForegroundColor Red; continue }
#         $rules = if ($pr.Json -is [array]) { $pr.Json } else { @($pr.Json) }
#         Write-Host "$($rules.Count) 條規則" -ForegroundColor Green
#         foreach ($rule in $rules) {
#             $cleanConditions = @()
#             if ($rule.conditions) {
#                 foreach ($cond in $rule.conditions) {
#                     if (($cond.value -is [System.Management.Automation.PSCustomObject]) -or ($cond.operator -eq "+")) { continue }
#                     $clean = @{}
#                     if ($cond.field)           { $clean.field    = $cond.field }
#                     if ($cond.operator)        { $clean.operator = $cond.operator }
#                     if ($null -ne $cond.value) { $clean.value    = $cond.value }
#                     if ($clean.field -and $clean.operator) { $cleanConditions += $clean }
#                 }
#             }
#             $up = @{
#                 ruleSet="salary"; companyId="$CompanyId"
#                 ruleName = if ($rule.ruleName) { $rule.ruleName } else { "rule_$i" }
#                 author="pipeline"; version=1
#                 priority = if ($rule.priority) { [int]$rule.priority } else { 8 }
#             }
#             if ($cleanConditions.Count -gt 0) { $up.conditions     = $cleanConditions }
#             if ($rule.action)                 { $up.action          = $rule.action }
#             if ($rule.actionNote)             { $up.actionNote      = $rule.actionNote }
#             if ($rule.actionWarning)          { $up.actionWarning   = $rule.actionWarning }
#             if ($rule.activationGroup)        { $up.activationGroup = $rule.activationGroup }

#             # ★收集這條規則（parse-rule 的結構），稍後整包 JSON 送去直接轉 Java
#             $parsedRules.Add($up)

#             Write-Host "    [2] updaterules: $($up.ruleName) ... " -NoNewline
#             $ur = Invoke-ApiJson -Url $UpdateRulesUrl -Payload $up
#             if ($ur.Ok) { Write-Host "OK" -ForegroundColor Green; $ruleCount++ }
#             else        { Write-Host "失敗: $($ur.Error) $($ur.Body)" -ForegroundColor Red }
#         }
#     }
#     if ($ruleCount -eq 0) { Write-Host "`n沒有任何規則寫入，結束。" -ForegroundColor Red; exit 1 }
#     Write-Host "`n已寫入 $ruleCount 條規則" -ForegroundColor Green

#     # ── Step 3：★parse-rule 的 JSON 規則 → 直接轉 Java（不經 DRL；後端 rules 模式）──
#     Write-Host "`n[3] generate-java（JSON 規則直轉，不經 DRL）... " -NoNewline
#     $gj = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; rules=$parsedRules }
#     if (-not $gj.Ok -or -not $gj.Json.javaCode) { Write-Host "失敗: $($gj.Error) $($gj.Body)" -ForegroundColor Red; exit 1 }
#     $gj.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8
#     Write-Host ("OK（模式 {0}｜來源 {1} 條 JSON 規則）" -f $gj.Json.sourceMode, $parsedRules.Count) -ForegroundColor Green

#     # ── Step 4：本地編譯關卡 + AI 修復 ──
#     function Invoke-MvnCompile {
#         Push-Location $ProjectRoot
#         $out = & mvn -q compile 2>&1 | Out-String
#         $ok  = ($LASTEXITCODE -eq 0)
#         Pop-Location
#         return @{ Ok=$ok; Out=$out }
#     }
#     $attempt = 0
#     while ($true) {
#         Write-Host "`n[4] mvn compile (第 $($attempt+1) 次) ..." -ForegroundColor Cyan
#         $c = Invoke-MvnCompile
#         if ($c.Ok) { Write-Host "編譯通過 OK" -ForegroundColor Green; break }
#         Write-Host "編譯失敗" -ForegroundColor Red
#         if ($attempt -ge $MaxFix) {
#             Write-Host (($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -First 20) -join "`n")
#             exit 1
#         }
#         $attempt++
#         $errLines = ($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" }) -join "`n"
#         Write-Host "  -> 請 AI 修 ..." -ForegroundColor Yellow
#         $cur = Get-Content $JavaPath -Raw
#         # 修復模式：後端走 previousCode + compileError 分支，不需再帶 DRL
#         $fix = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; previousCode=$cur; compileError=$errLines }
#         if ($fix.Ok -and $fix.Json.javaCode) { $fix.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8; Write-Host "     已套用修正" -ForegroundColor DarkGreen }
#         else { Write-Host "     AI 修復失敗: $($fix.Error) $($fix.Body)" -ForegroundColor Red }
#     }

#     if ($SkipDeploy) { Write-Host "`n-SkipDeploy：已編譯通過，未部署。" -ForegroundColor Yellow; exit 0 }

#     # ── Step 5：部署 ──
#     Write-Host "`n[5] mvn clean package azure-functions:deploy ..." -ForegroundColor Cyan
#     Push-Location $ProjectRoot
#     $start = Get-Date
#     & mvn clean package azure-functions:deploy
#     $ok = ($LASTEXITCODE -eq 0)
#     Pop-Location
#     if (-not $ok) { Write-Host "部署失敗 (exit=$LASTEXITCODE)" -ForegroundColor Red; exit 1 }
#     Write-Host ("部署成功（{0} 分）。" -f [math]::Round(((Get-Date)-$start).TotalMinutes,1)) -ForegroundColor Green
#     Write-Host "等冷啟動 30 秒 ..." -ForegroundColor DarkGray
#     Start-Sleep -Seconds 30

#     # ── Step 6：查詢規則 ──
#     Write-Host "`n==================== [查詢規則] ====================" -ForegroundColor Cyan
#     try {
#         $drlResp = Invoke-WebRequest -Uri $QueryUrl -Method GET -TimeoutSec 60 -ErrorAction Stop
#         Write-Host $drlResp.Content
#     } catch { Write-Host "查詢 DRL 失敗：$($_.Exception.Message)" -ForegroundColor Yellow }

# } else {
#     Write-Host "[OnlyCompare] 跳過 Step 0-6，直接跑 $N 筆比對。" -ForegroundColor DarkYellow
# }

# # =====================================================================
# # Step 7：隨機 500 筆，一次送出，雙層比對（DRL↔Java、DRL↔公司應有值）
# # =====================================================================
# Write-Host "`n==================== [500 筆雙層比對] ====================" -ForegroundColor Cyan

# # ── 7-1 產生 N 筆隨機員工（companyId=10）──
# Get-Random -SetSeed 20250201 | Out-Null
# $records = New-Object System.Collections.Generic.List[object]
# $expect  = @{}                  # employeeId -> @{ base; otH; lvH; leave; ot; final }
# $nOt=0; $nLv=0; $nBoth=0; $nNone=0
# for ($i=0; $i -lt $N; $i++) {
#     $base  = (Get-Random -Minimum 100 -Maximum 376) * 240      # 24,000~90,000，240 倍數
#     $hasOt = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶平日加班
#     $hasLv = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶事假
#     $otH   = if ($hasOt) { Get-Random -Minimum 1 -Maximum 17 } else { 0 }   # 1~16h
#     $lvH   = if ($hasLv) { Get-Random -Minimum 1 -Maximum 17 } else { 0 }
#     $eid   = "C10-{0:D4}" -f $i

#     $rec = @{ companyId="10"; employeeId=$eid; baseSalary=$base; tenureMonths=(Get-Random -Minimum 1 -Maximum 241) }
#     if ($hasOt) { $rec.overtimes = @(@{ overtimeType="WEEKDAY"; overtimeHours=$otH }) }
#     if ($hasLv) { $rec.leaves    = @(@{ leaveTypeName="事假"; leaveHours=$lvH; leaveDays=1 }) }
#     $records.Add($rec)

#     $el = Predict-Leave $base $lvH
#     $eo = Predict-Ot    $base $otH
#     $expect[$eid] = @{ base=$base; otH=$otH; lvH=$lvH; leave=$el; ot=$eo; final=[math]::Round([double]$base - $el + $eo, 2) }

#     if     ($hasOt -and $hasLv) { $nBoth++ }
#     elseif ($hasOt)             { $nOt++ }
#     elseif ($hasLv)             { $nLv++ }
#     else                        { $nNone++ }
# }
# Write-Host ("已產生 {0} 筆：純加班 {1}｜純事假 {2}｜加班+事假 {3}｜無扣項 {4}" -f $N,$nOt,$nLv,$nBoth,$nNone) -ForegroundColor DarkGray

# # ── 7-2 一次送出（兩端點各一個批次陣列）──
# function Post-Batch($url, $recs, $timeout=300) {
#     $json  = $recs | ConvertTo-Json -Depth 10
#     $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
#     $sw = [System.Diagnostics.Stopwatch]::StartNew()
#     $resp = Invoke-WebRequest -Uri $url -Method POST -Body $bytes `
#             -ContentType "application/json; charset=utf-8" -TimeoutSec $timeout -UseBasicParsing
#     $sw.Stop()
#     $sv = $resp.Headers["X-Execution-Time-Ms"]; if ($sv -is [array]) { $sv = $sv[0] }
#     return @{ items=($resp.Content | ConvertFrom-Json); ms=$sw.ElapsedMilliseconds; server=$sv }
# }

# Write-Host "`n送出 DRL 端點（$N 筆）... " -NoNewline
# $drl = Post-Batch $DrlCalcUrl $records
# Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $drl.ms, $drl.server, $drl.items.Count) -ForegroundColor Green
# Write-Host "送出 Java 端點（$N 筆）... " -NoNewline
# $jav = Post-Batch $LegacyUrl $records
# Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $jav.ms, $jav.server, $jav.items.Count) -ForegroundColor Green

# # ── 7-3 以 employeeId 對映 ──
# $drlMap=@{}; foreach ($w in $drl.items) { $drlMap[$w.employeeId]=$w }
# $javMap=@{}; foreach ($w in $jav.items) { $javMap[$w.employeeId]=$w }

# # ── 7-4 雙層逐筆比對 ──
# $L1pass=0; $L1fail=0     # 第一層：DRL ↔ Java
# $L2pass=0; $L2fail=0     # 第二層：DRL ↔ 公司應有值
# $L1fails=New-Object System.Collections.Generic.List[string]
# $L2fails=New-Object System.Collections.Generic.List[string]
# $sample =New-Object System.Collections.Generic.List[object]

# foreach ($eid in $expect.Keys) {
#     $ex=$expect[$eid]; $dw=$drlMap[$eid]; $jw=$javMap[$eid]
#     if ($null -eq $dw -or $null -eq $jw) { $L1fail++; $L2fail++; $L1fails.Add("$eid 缺回傳（DRL=$([bool]$dw) Java=$([bool]$jw)）"); continue }
#     if ($dw.error -or $jw.error)         { $L1fail++; $L2fail++; $L1fails.Add("$eid 回傳錯誤 DRL=$($dw.error) Java=$($jw.error)"); continue }
#     $dr=$dw.result; $jr=$jw.result

#     # 第一層：DRL ↔ Java（整包數值比對，忽略易變欄位）
#     $diffs = Get-Diffs (Norm $dr) (Norm $jr) ""
#     if (-not $diffs -or $diffs.Count -eq 0) { $L1pass++ }
#     else { $L1fail++; $L1fails.Add("$eid ($($diffs.Count) 處)： " + ($diffs -join " ; ")) }

#     # 第二層：DRL ↔ 公司應有值（事假半扣、加班2/4倍、實領）
#     $okL = [math]::Abs([double]$dr.leaveDeduction - [double]$ex.leave) -le 0.01
#     $okO = [math]::Abs([double]$dr.overtimeBonus  - [double]$ex.ot)    -le 0.01
#     $okF = [math]::Abs([double]$dr.finalSalary    - [double]$ex.final) -le 0.01
#     if ($okL -and $okO -and $okF) { $L2pass++ }
#     else {
#         $L2fail++
#         $L2fails.Add(("{0} 底薪{1} 事假{2}h 加班{3}h | 事假扣 DRL={4}/應{5} 加班 DRL={6}/應{7} 實領 DRL={8}/應{9}" -f `
#             $eid,$ex.base,$ex.lvH,$ex.otH,$dr.leaveDeduction,$ex.leave,$dr.overtimeBonus,$ex.ot,$dr.finalSalary,$ex.final))
#     }

#     if ($sample.Count -lt 12) {
#         $sample.Add([pscustomobject]@{ eid=$eid; base=$ex.base; lvH=$ex.lvH; otH=$ex.otH;
#             leaveD=$dr.leaveDeduction; leaveE=$ex.leave; otD=$dr.overtimeBonus; otE=$ex.ot; finD=$dr.finalSalary; finE=$ex.final })
#     }
# }

# # ── 7-5 彙總 ──
# $total=$expect.Count
# $r1 = if ($total) { [math]::Round($L1pass*100.0/$total,1) } else { 0 }
# $r2 = if ($total) { [math]::Round($L2pass*100.0/$total,1) } else { 0 }

# Write-Host "`n==================== 結果 ====================" -ForegroundColor Cyan
# $c1 = if ($L1fail -eq 0) { "Green" } else { "Red" }
# $c2 = if ($L2fail -eq 0) { "Green" } else { "Red" }
# Write-Host ("第一層 DRL ↔ Java        ：{0}/{1} = {2}%" -f $L1pass,$total,$r1) -ForegroundColor $c1
# Write-Host ("第二層 DRL ↔ 公司應有值  ：{0}/{1} = {2}%" -f $L2pass,$total,$r2) -ForegroundColor $c2

# Write-Host "`n--- 效能（兩端點各一次批次）---" -ForegroundColor Cyan
# Write-Host ("  DRL 端點 ：往返 {0} ms，伺服器 {1} ms" -f $drl.ms,$drl.server)
# Write-Host ("  Java 端點：往返 {0} ms，伺服器 {1} ms" -f $jav.ms,$jav.server)

# if ($L1fail -gt 0) {
#     Write-Host "`n[第一層不一致，前 10 筆]" -ForegroundColor Red
#     $L1fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
# }
# if ($L2fail -gt 0) {
#     Write-Host "`n[第二層與公司應有值不符，前 10 筆]" -ForegroundColor Red
#     $L2fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
# }

# # ── 7-6 抽樣明細（前 12 筆）──
# Write-Host "`n[ 抽樣明細（前 12 筆，DRL 值 = 公司應有值）]" -ForegroundColor Cyan
# Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20}" -f "員工","底薪","事假h","加班h","事假扣(DRL/應)","加班費(DRL/應)","實領(DRL/應)")
# foreach ($s in $sample) {
#     Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20}" -f `
#         $s.eid,$s.base,$s.lvH,$s.otH,("$($s.leaveD)/$($s.leaveE)"),("$($s.otD)/$($s.otE)"),("$($s.finD)/$($s.finE)"))
# }

# Write-Host "`n★ 雙層全綠 => 自然語言轉出的 DRL 規則，計算結果與硬編碼 Java 完全一致，" -ForegroundColor Magenta
# Write-Host "   且皆套用公司10客製（事假半扣、加班2/4倍），語義與執行層均正確。" -ForegroundColor Magenta

# =========================================================
# experiment_traps_F_L1.ps1 — 陷阱情境版（沿用 experiment_all 結構）
#   NL -> parse-rule(JSON) -> 存DRL(Blob)；JSON規則直接轉Java(不經DRL) -> build -> 部署 -> 500筆雙層比對
#
#   ★本輪為「函式表達力上限」陷阱驗證，公司 10：
#     情境 F（事假分段）：前兩天(16h)扣全額、之後扣一半 —— calcLeaveDeduction 只吃單一比率
#     情境 L1（三階費率）：前2h×2、3~4h×3、超過4h×4     —— calcWeekdayOvertimeByRate 只吃兩階
#     兩者不同模組（請假 / 加班），不衝突，同一次即可驗。
#
#   預期結果（這是重點，不是全綠）：
#     第一層 DRL ↔ Java        ：100%（兩端共用同一函式，錯得一樣）
#     第二層 DRL ↔ 公司應有值  ：破 —— 事假>16h 或 加班>2h 時，DRL 值 ≠ 分段/三階正確值
#   → 證明：問題在「目標函式沒有分段/階數參數」，不是 AI 看不懂語言。
#
# 用法：
#   ./experiment_traps_F_L1.ps1                 # 完整跑（含部署 + 比對）
#   ./experiment_traps_F_L1.ps1 -SkipDeploy     # 跑到編譯關卡，不部署不比對
#   ./experiment_traps_F_L1.ps1 -NoReset        # 不清空 DRL
#   ./experiment_traps_F_L1.ps1 -OnlyCompare    # 跳過 0-6，直接跑 500 筆比對（規則已部署時用）
# =========================================================

param(
    [string]$ProjectRoot = "C:\Users\PT\Desktop\code\Graduate",
    [string]$CompanyId   = "10",
    [int]$MaxFix         = 3,
    [int]$N              = 500,        # 一次送出的員工筆數
    [switch]$NoReset,
    [switch]$SkipDeploy,
    [switch]$OnlyCompare              # 規則已部署，只想重跑 500 筆比對
)

$BaseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
$ParseRuleUrl   = "$BaseUrl/ai/parse-rule"
$UpdateRulesUrl = "$BaseUrl/updaterules"
$ResetRulesUrl  = "$BaseUrl/resetrules"
$GenJavaUrl     = "$BaseUrl/ai/generate-java"
$DrlCalcUrl     = "$BaseUrl/calculatesalary"
$LegacyUrl      = "$BaseUrl/checksalary/legacy"
$QueryUrl       = "$BaseUrl/rules/Salary/Company_${CompanyId}_Salary.drl"

[System.Net.ServicePointManager]::SecurityProtocol       = [System.Net.SecurityProtocolType]::Tls12
[System.Net.ServicePointManager]::DefaultConnectionLimit = 100

# ── 公司 10 的自然語言規則（★兩句陷阱：事假分段 + 加班三階）──
$Prompts = @(
    "公司10的員工請事假，前兩天扣全額、之後扣一半。"
    "公司10的員工平日加班，前兩小時2倍、第三到第四小時3倍、超過四小時4倍。"
)

# 比對時忽略的非數值/易變欄位
$IgnoreKeys = @('appliedRule','ruleDetails','notes','warnings','executionTimeMs','timestamp','computeTime','message','employeeId')

# ── 公司客製「正確」比率（用於第二層「公司應有值」預測）──
#   情境 F 事假分段：前兩天=16小時(1天8h) 扣全額，之後扣一半
$LV_SPLIT_H = 16       # 兩天分界（小時）
$LV_R1      = 1.0      # 前兩天：全額扣
$LV_R2      = 0.5      # 之後：半額扣
#   情境 L1 加班三階：前2h×2、2~4h×3、超過4h×4
$OT_S1 = 2 ; $OT_R1 = 2.0    # 第一階分界 / 倍率
$OT_S2 = 4 ; $OT_R2 = 3.0    # 第二階分界 / 倍率
             $OT_R3 = 4.0    # 第三階倍率（超過 $OT_S2）

# ── 共用：POST hashtable / 純 JSON ──
function Invoke-ApiJson {
    param([string]$Url, [hashtable]$Payload, [int]$TimeoutSec = 180)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($Payload | ConvertTo-Json -Depth 8 -Compress))
    Invoke-Raw $Url $bytes $TimeoutSec
}
function Invoke-PostJson {
    param([string]$Url, [string]$JsonBody, [int]$TimeoutSec = 120)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($JsonBody)
    Invoke-Raw $Url $bytes $TimeoutSec
}
function Invoke-Raw {
    param([string]$Url, [byte[]]$Bytes, [int]$TimeoutSec)
    try {
        $resp = Invoke-WebRequest -Uri $Url -Method POST -Body $Bytes `
            -ContentType "application/json; charset=utf-8" -TimeoutSec $TimeoutSec -ErrorAction Stop
        return @{ Ok=$true; Json=($resp.Content | ConvertFrom-Json) }
    } catch {
        $b = $null
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) { $b = $_.ErrorDetails.Message }
        elseif ($_.Exception.Response) { try { $b = (New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())).ReadToEnd() } catch {} }
        return @{ Ok=$false; Error=$_.Exception.Message; Body=$b }
    }
}
function Norm($o) {
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in ($o.PSObject.Properties | Sort-Object Name)) {
            if ($IgnoreKeys -contains $p.Name) { continue }
            $h[$p.Name] = Norm $p.Value
        }
        return $h
    } elseif (($o -is [System.Collections.IEnumerable]) -and ($o -isnot [string])) {
        return @($o | ForEach-Object { Norm $_ })
    } else {
        $d = 0.0
        if ($null -ne $o -and [double]::TryParse([string]$o, [ref]$d)) { return ('{0:N2}' -f $d) }
        return [string]$o
    }
}
function Get-Diffs($a, $b, $path) {
    $diffs = @()
    if (($a -is [System.Collections.IDictionary]) -and ($b -is [System.Collections.IDictionary])) {
        $keys = @($a.Keys) + @($b.Keys) | Sort-Object -Unique
        foreach ($k in $keys) {
            $av = if ($a.Contains($k)) { $a[$k] } else { '<缺>' }
            $bv = if ($b.Contains($k)) { $b[$k] } else { '<缺>' }
            $p  = if ($path) { "$path.$k" } else { "$k" }
            $diffs += Get-Diffs $av $bv $p
        }
    } elseif (($a -is [array]) -and ($b -is [array])) {
        if ($a.Count -ne $b.Count) { $diffs += "$path[長度] DRL=$($a.Count) Java=$($b.Count)" }
        $n = [Math]::Min($a.Count, $b.Count)
        for ($i=0; $i -lt $n; $i++) { $diffs += Get-Diffs $a[$i] $b[$i] "$path[$i]" }
    } else {
        if ("$a" -ne "$b") { $diffs += "${path}: DRL=$a  Java=$b" }
    }
    return $diffs
}

# ── 公司應有值預測（時薪 = 底薪/240；底薪取 240 倍數 → 時薪整數，精確）──
#   ★情境 F：事假分段扣薪（前16h×1.0、之後×0.5）
function Predict-Leave($base, $h) {
    if ($h -le 0) { return [double]0 }
    $hourly = $base/240.0
    $units  = ([math]::Min($h,$LV_SPLIT_H) * $LV_R1) + ([math]::Max($h-$LV_SPLIT_H,0) * $LV_R2)
    return [math]::Round([double]$hourly * $units, 2, [System.MidpointRounding]::AwayFromZero)
}
#   ★情境 L1：加班三階（前2h×2、2~4h×3、超過4h×4）
function Predict-Ot($base, $h) {
    if ($h -le 0) { return [double]0 }
    $hourly = $base/240.0
    $t1 = [math]::Min($h,$OT_S1) * $OT_R1
    $t2 = [math]::Max([math]::Min($h,$OT_S2) - $OT_S1, 0) * $OT_R2
    $t3 = [math]::Max($h - $OT_S2, 0) * $OT_R3
    $units = $t1 + $t2 + $t3
    return [math]::Round([double]$hourly * $units, 2, [System.MidpointRounding]::AwayFromZero)
}

# =====================================================================
# Step 0-6：一條龍（NL→解析→存DRL；解析結果直接→Java→部署）。-OnlyCompare 時整段跳過。
# =====================================================================
if (-not $OnlyCompare) {

    if (-not (Test-Path (Join-Path $ProjectRoot "pom.xml"))) {
        $probe = (Get-Location).Path
        while ($probe -and -not (Test-Path (Join-Path $probe "pom.xml"))) {
            $parent = Split-Path $probe -Parent
            if ($parent -eq $probe) { $probe = $null; break }
            $probe = $parent
        }
        if ($probe) { $ProjectRoot = $probe } else { Write-Host "找不到 pom.xml，請用 -ProjectRoot 指定" -ForegroundColor Red; exit 1 }
    }
    $ProjectRoot    = (Resolve-Path $ProjectRoot).Path
    $SalaryRulesDir = Join-Path $ProjectRoot "src\main\java\com\function\function\SalaryRules"
    $JavaPath       = Join-Path $SalaryRulesDir "Company${CompanyId}Rule.java"
    New-Item -ItemType Directory -Force -Path $SalaryRulesDir | Out-Null
    Write-Host "專案根目錄: $ProjectRoot" -ForegroundColor DarkCyan
    Write-Host "目標公司  : $CompanyId  ->  $JavaPath" -ForegroundColor DarkCyan
    Write-Host "本輪為陷阱情境：事假分段(16h) + 加班三階(2/4h)，預期第二層會破。`n" -ForegroundColor DarkYellow

    # ── Step 0：重置 ──
    if (-not $NoReset) {
        Write-Host "[0] 重置公司 $CompanyId ... " -NoNewline
        $rr = Invoke-ApiJson -Url $ResetRulesUrl -Payload @{ ruleSet="salary"; companyId="$CompanyId" }
        if ($rr.Ok) { Write-Host "DRL 已清空" -ForegroundColor Green -NoNewline } else { Write-Host "重置失敗(可能未部署ResetRules): $($rr.Error) $($rr.Body)" -ForegroundColor Yellow -NoNewline }
        if (Test-Path $JavaPath) { Remove-Item $JavaPath -Force; Write-Host "；已刪舊 Java" -ForegroundColor Green } else { Write-Host "" }
    } else { Write-Host "[0] -NoReset：保留 DRL" -ForegroundColor DarkYellow }

    # ── Step 1+2：NL -> JSON -> 存 DRL（Blob）；同時收集「AI 解析結果」，供直接轉 Java 用 ──
    $ruleCount = 0
    $parsedRules = New-Object System.Collections.Generic.List[object]
    for ($i=0; $i -lt $Prompts.Count; $i++) {
        Write-Host "`n[1] parse-rule ($($i+1)/$($Prompts.Count)) ... " -NoNewline
        $pr = Invoke-ApiJson -Url $ParseRuleUrl -Payload @{ text=$Prompts[$i]; ruleSet="salary"; companyId="$CompanyId" }
        if (-not $pr.Ok) { Write-Host "失敗: $($pr.Error) $($pr.Body)" -ForegroundColor Red; continue }
        $rules = if ($pr.Json -is [array]) { $pr.Json } else { @($pr.Json) }
        Write-Host "$($rules.Count) 條規則" -ForegroundColor Green
        foreach ($rule in $rules) {
            $cleanConditions = @()
            if ($rule.conditions) {
                foreach ($cond in $rule.conditions) {
                    if (($cond.value -is [System.Management.Automation.PSCustomObject]) -or ($cond.operator -eq "+")) { continue }
                    $clean = @{}
                    if ($cond.field)           { $clean.field    = $cond.field }
                    if ($cond.operator)        { $clean.operator = $cond.operator }
                    if ($null -ne $cond.value) { $clean.value    = $cond.value }
                    if ($clean.field -and $clean.operator) { $cleanConditions += $clean }
                }
            }
            $up = @{
                ruleSet="salary"; companyId="$CompanyId"
                ruleName = if ($rule.ruleName) { $rule.ruleName } else { "rule_$i" }
                author="pipeline"; version=1
                priority = if ($rule.priority) { [int]$rule.priority } else { 8 }
            }
            if ($cleanConditions.Count -gt 0) { $up.conditions     = $cleanConditions }
            if ($rule.action)                 { $up.action          = $rule.action }
            if ($rule.actionNote)             { $up.actionNote      = $rule.actionNote }
            if ($rule.actionWarning)          { $up.actionWarning   = $rule.actionWarning }
            if ($rule.activationGroup)        { $up.activationGroup = $rule.activationGroup }

            $parsedRules.Add($up)

            Write-Host "    [2] updaterules: $($up.ruleName) ... " -NoNewline
            $ur = Invoke-ApiJson -Url $UpdateRulesUrl -Payload $up
            if ($ur.Ok) { Write-Host "OK" -ForegroundColor Green; $ruleCount++ }
            else        { Write-Host "失敗: $($ur.Error) $($ur.Body)" -ForegroundColor Red }
        }
    }
    if ($ruleCount -eq 0) { Write-Host "`n沒有任何規則寫入，結束。" -ForegroundColor Red; exit 1 }
    Write-Host "`n已寫入 $ruleCount 條規則" -ForegroundColor Green

    # ── Step 3：★parse-rule 的 JSON 規則 → 直接轉 Java（不經 DRL；後端 rules 模式）──
    Write-Host "`n[3] generate-java（JSON 規則直轉，不經 DRL）... " -NoNewline
    $gj = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; rules=$parsedRules }
    if (-not $gj.Ok -or -not $gj.Json.javaCode) { Write-Host "失敗: $($gj.Error) $($gj.Body)" -ForegroundColor Red; exit 1 }
    $gj.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8
    Write-Host ("OK（模式 {0}｜來源 {1} 條 JSON 規則）" -f $gj.Json.sourceMode, $parsedRules.Count) -ForegroundColor Green

    # ── Step 4：本地編譯關卡 + AI 修復 ──
    function Invoke-MvnCompile {
        Push-Location $ProjectRoot
        $out = & mvn -q compile 2>&1 | Out-String
        $ok  = ($LASTEXITCODE -eq 0)
        Pop-Location
        return @{ Ok=$ok; Out=$out }
    }
    $attempt = 0
    while ($true) {
        Write-Host "`n[4] mvn compile (第 $($attempt+1) 次) ..." -ForegroundColor Cyan
        $c = Invoke-MvnCompile
        if ($c.Ok) { Write-Host "編譯通過 OK" -ForegroundColor Green; break }
        Write-Host "編譯失敗" -ForegroundColor Red
        if ($attempt -ge $MaxFix) {
            Write-Host (($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -First 20) -join "`n")
            exit 1
        }
        $attempt++
        $errLines = ($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" }) -join "`n"
        Write-Host "  -> 請 AI 修 ..." -ForegroundColor Yellow
        $cur = Get-Content $JavaPath -Raw
        $fix = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; previousCode=$cur; compileError=$errLines }
        if ($fix.Ok -and $fix.Json.javaCode) { $fix.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8; Write-Host "     已套用修正" -ForegroundColor DarkGreen }
        else { Write-Host "     AI 修復失敗: $($fix.Error) $($fix.Body)" -ForegroundColor Red }
    }

    if ($SkipDeploy) { Write-Host "`n-SkipDeploy：已編譯通過，未部署。" -ForegroundColor Yellow; exit 0 }

    # ── Step 5：部署 ──
    Write-Host "`n[5] mvn clean package azure-functions:deploy ..." -ForegroundColor Cyan
    Push-Location $ProjectRoot
    $start = Get-Date
    & mvn clean package azure-functions:deploy
    $ok = ($LASTEXITCODE -eq 0)
    Pop-Location
    if (-not $ok) { Write-Host "部署失敗 (exit=$LASTEXITCODE)" -ForegroundColor Red; exit 1 }
    Write-Host ("部署成功（{0} 分）。" -f [math]::Round(((Get-Date)-$start).TotalMinutes,1)) -ForegroundColor Green
    Write-Host "等冷啟動 30 秒 ..." -ForegroundColor DarkGray
    Start-Sleep -Seconds 30

    # ── Step 6：查詢規則（順便數規則條數，防殘留）──
    Write-Host "`n==================== [查詢規則] ====================" -ForegroundColor Cyan
    try {
        $drlResp = Invoke-WebRequest -Uri $QueryUrl -Method GET -TimeoutSec 60 -ErrorAction Stop
        Write-Host $drlResp.Content
        $drlN = ([regex]::Matches($drlResp.Content, '(?m)rule\s+"([^"]+)"')).Count
        if ($drlN -gt $parsedRules.Count) {
            Write-Host ("`n[⚠ 殘留] DRL 有 {0} 條，本次只寫入 {1} 條 → 疑似殘留舊規則，第一層若不一致以此為疑。" -f $drlN, $parsedRules.Count) -ForegroundColor Red
        } else {
            Write-Host ("`n[殘留偵測] DRL {0} 條，與本次寫入一致，無殘留。" -f $drlN) -ForegroundColor DarkGray
        }
    } catch { Write-Host "查詢 DRL 失敗：$($_.Exception.Message)" -ForegroundColor Yellow }

} else {
    Write-Host "[OnlyCompare] 跳過 Step 0-6，直接跑 $N 筆比對。" -ForegroundColor DarkYellow
}

# =====================================================================
# Step 7：隨機 500 筆，一次送出，雙層比對（DRL↔Java、DRL↔公司應有值）
# =====================================================================
Write-Host "`n==================== [500 筆雙層比對（陷阱）] ====================" -ForegroundColor Cyan

# ── 7-1 產生 N 筆隨機員工（companyId=10）──
#   ★事假時數放大到 1~32h，好讓「超過兩天(16h)」的分段陷阱會被觸發
Get-Random -SetSeed 20250201 | Out-Null
$records = New-Object System.Collections.Generic.List[object]
$expect  = @{}
$nOt=0; $nLv=0; $nBoth=0; $nNone=0
for ($i=0; $i -lt $N; $i++) {
    $base  = (Get-Random -Minimum 100 -Maximum 376) * 240      # 24,000~90,000，240 倍數
    $hasOt = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶平日加班
    $hasLv = (Get-Random -Minimum 0 -Maximum 100) -lt 60       # 60% 帶事假
    $otH   = if ($hasOt) { Get-Random -Minimum 1 -Maximum 17 } else { 0 }   # 1~16h（跨 2h、4h 兩道分界）
    $lvH   = if ($hasLv) { Get-Random -Minimum 1 -Maximum 33 } else { 0 }   # 1~32h（跨 16h＝兩天分界）
    $eid   = "C10-{0:D4}" -f $i

    $rec = @{ companyId="10"; employeeId=$eid; baseSalary=$base; tenureMonths=(Get-Random -Minimum 1 -Maximum 241) }
    if ($hasOt) { $rec.overtimes = @(@{ overtimeType="WEEKDAY"; overtimeHours=$otH }) }
    if ($hasLv) { $rec.leaves    = @(@{ leaveTypeName="事假"; leaveHours=$lvH; leaveDays=[math]::Ceiling($lvH/8.0) }) }
    $records.Add($rec)

    $el = Predict-Leave $base $lvH
    $eo = Predict-Ot    $base $otH
    $expect[$eid] = @{ base=$base; otH=$otH; lvH=$lvH; leave=$el; ot=$eo; final=[math]::Round([double]$base - $el + $eo, 2) }

    if     ($hasOt -and $hasLv) { $nBoth++ }
    elseif ($hasOt)             { $nOt++ }
    elseif ($hasLv)             { $nLv++ }
    else                        { $nNone++ }
}
Write-Host ("已產生 {0} 筆：純加班 {1}｜純事假 {2}｜加班+事假 {3}｜無扣項 {4}" -f $N,$nOt,$nLv,$nBoth,$nNone) -ForegroundColor DarkGray

# ── 7-2 一次送出（兩端點各一個批次陣列）──
function Post-Batch($url, $recs, $timeout=300) {
    $json  = $recs | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $resp = Invoke-WebRequest -Uri $url -Method POST -Body $bytes `
            -ContentType "application/json; charset=utf-8" -TimeoutSec $timeout -UseBasicParsing
    $sw.Stop()
    $sv = $resp.Headers["X-Execution-Time-Ms"]; if ($sv -is [array]) { $sv = $sv[0] }
    return @{ items=($resp.Content | ConvertFrom-Json); ms=$sw.ElapsedMilliseconds; server=$sv }
}

Write-Host "`n送出 DRL 端點（$N 筆）... " -NoNewline
$drl = Post-Batch $DrlCalcUrl $records
Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $drl.ms, $drl.server, $drl.items.Count) -ForegroundColor Green
Write-Host "送出 Java 端點（$N 筆）... " -NoNewline
$jav = Post-Batch $LegacyUrl $records
Write-Host ("OK（往返 {0} ms，伺服器 {1} ms，回傳 {2} 筆）" -f $jav.ms, $jav.server, $jav.items.Count) -ForegroundColor Green

# ── 7-3 以 employeeId 對映 ──
$drlMap=@{}; foreach ($w in $drl.items) { $drlMap[$w.employeeId]=$w }
$javMap=@{}; foreach ($w in $jav.items) { $javMap[$w.employeeId]=$w }

# ── 7-4 雙層逐筆比對 ──
$L1pass=0; $L1fail=0     # 第一層：DRL ↔ Java（預期 100%）
$L2pass=0; $L2fail=0     # 第二層：DRL ↔ 公司應有值（預期會破）
$L2failLv=0; $L2failOt=0 # 第二層破在哪：事假 / 加班
$L1fails=New-Object System.Collections.Generic.List[string]
$L2fails=New-Object System.Collections.Generic.List[string]
$sample =New-Object System.Collections.Generic.List[object]

foreach ($eid in $expect.Keys) {
    $ex=$expect[$eid]; $dw=$drlMap[$eid]; $jw=$javMap[$eid]
    if ($null -eq $dw -or $null -eq $jw) { $L1fail++; $L2fail++; $L1fails.Add("$eid 缺回傳（DRL=$([bool]$dw) Java=$([bool]$jw)）"); continue }
    if ($dw.error -or $jw.error)         { $L1fail++; $L2fail++; $L1fails.Add("$eid 回傳錯誤 DRL=$($dw.error) Java=$($jw.error)"); continue }
    $dr=$dw.result; $jr=$jw.result

    # 第一層：DRL ↔ Java（整包數值比對，忽略易變欄位）
    $diffs = Get-Diffs (Norm $dr) (Norm $jr) ""
    if (-not $diffs -or $diffs.Count -eq 0) { $L1pass++ }
    else { $L1fail++; $L1fails.Add("$eid ($($diffs.Count) 處)： " + ($diffs -join " ; ")) }

    # 第二層：DRL ↔ 公司應有值（事假分段、加班三階、實領）
    $okL = [math]::Abs([double]$dr.leaveDeduction - [double]$ex.leave) -le 0.01
    $okO = [math]::Abs([double]$dr.overtimeBonus  - [double]$ex.ot)    -le 0.01
    $okF = [math]::Abs([double]$dr.finalSalary    - [double]$ex.final) -le 0.01
    if ($okL -and $okO -and $okF) { $L2pass++ }
    else {
        $L2fail++
        if (-not $okL) { $L2failLv++ }
        if (-not $okO) { $L2failOt++ }
        $L2fails.Add(("{0} 底薪{1} 事假{2}h 加班{3}h | 事假扣 DRL={4}/應{5} 加班 DRL={6}/應{7} 實領 DRL={8}/應{9}" -f `
            $eid,$ex.base,$ex.lvH,$ex.otH,$dr.leaveDeduction,$ex.leave,$dr.overtimeBonus,$ex.ot,$dr.finalSalary,$ex.final))
    }

    if ($sample.Count -lt 14) {
        $mark = if ($okL -and $okO -and $okF) { "OK" } else { "X" }
        $sample.Add([pscustomobject]@{ eid=$eid; base=$ex.base; lvH=$ex.lvH; otH=$ex.otH;
            leaveD=$dr.leaveDeduction; leaveE=$ex.leave; otD=$dr.overtimeBonus; otE=$ex.ot; finD=$dr.finalSalary; finE=$ex.final; mark=$mark })
    }
}

# ── 7-5 彙總 ──
$total=$expect.Count
$r1 = if ($total) { [math]::Round($L1pass*100.0/$total,1) } else { 0 }
$r2 = if ($total) { [math]::Round($L2pass*100.0/$total,1) } else { 0 }

Write-Host "`n==================== 結果（陷阱情境）====================" -ForegroundColor Cyan
$c1 = if ($L1fail -eq 0) { "Green" } else { "Red" }
$c2 = if ($L2fail -eq 0) { "Green" } else { "Yellow" }
Write-Host ("第一層 DRL <-> Java        ：{0}/{1} = {2}%   （預期 100%）" -f $L1pass,$total,$r1) -ForegroundColor $c1
Write-Host ("第二層 DRL <-> 公司應有值  ：{0}/{1} = {2}%   （預期會破）" -f $L2pass,$total,$r2) -ForegroundColor $c2
Write-Host ("  第二層破的來源：事假分段錯 {0} 筆、加班三階錯 {1} 筆" -f $L2failLv,$L2failOt) -ForegroundColor DarkYellow

Write-Host "`n--- 效能（兩端點各一次批次）---" -ForegroundColor Cyan
Write-Host ("  DRL 端點 ：往返 {0} ms，伺服器 {1} ms" -f $drl.ms,$drl.server)
Write-Host ("  Java 端點：往返 {0} ms，伺服器 {1} ms" -f $jav.ms,$jav.server)

if ($L1fail -gt 0) {
    Write-Host "`n[⚠ 第一層竟不一致，前 10 筆]（正常應為 0；若有，多半是 DRL 殘留舊規則）" -ForegroundColor Red
    $L1fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
}
if ($L2fail -gt 0) {
    Write-Host "`n[第二層與公司應有值不符，前 10 筆]（這正是陷阱要證明的破口）" -ForegroundColor Yellow
    $L2fails | Select-Object -First 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkYellow }
}

# ── 7-6 抽樣明細（前 14 筆，含 OK/X）──
Write-Host "`n[ 抽樣明細（前 14 筆，DRL 值 / 公司應有值）]" -ForegroundColor Cyan
Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20} {7}" -f "員工","底薪","事假h","加班h","事假扣(DRL/應)","加班費(DRL/應)","實領(DRL/應)","判定")
foreach ($s in $sample) {
    $col = if ($s.mark -eq "OK") { "Green" } else { "Red" }
    Write-Host ("  {0,-10} {1,-8} {2,-7} {3,-7} {4,-18} {5,-18} {6,-20} {7}" -f `
        $s.eid,$s.base,$s.lvH,$s.otH,("$($s.leaveD)/$($s.leaveE)"),("$($s.otD)/$($s.otE)"),("$($s.finD)/$($s.finE)"),$s.mark) -ForegroundColor $col
}

Write-Host "`n★ 陷阱情境判讀：" -ForegroundColor Magenta
Write-Host "  第一層 100% + 第二層破 => DRL 與硬編碼 Java 錯得一模一樣（共用同一函式），" -ForegroundColor Magenta
Write-Host "  破口只在『事假>16h(超過兩天)』或『加班>2h(進入三階)』時出現。" -ForegroundColor Magenta
Write-Host "  結論：問題在目標函式沒有『分段/階數』參數（表達力上限），不是 AI 看不懂自然語言。" -ForegroundColor Magenta
Write-Host "        且僅第二層抓得到、第一層無感 => 印證雙層比對法的必要性。" -ForegroundColor Magenta