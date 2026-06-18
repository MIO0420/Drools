# # =========================================================
# # experiment_all.ps1 — 完整一條龍 + 內建測試比對（合二為一）
# #   NL -> JSON -> 存DRL -> 查DRL轉Java -> build -> 部署 -> 查詢 -> 比對
# #
# # 本輪重點：公司 10 用「跟通用不同」的客製，才能證明真的用到公司規則。
# #   通用事假 = 1.0（全扣）；公司10事假 = 0.5（半扣）。
# #   驗證：8H事假 通用值 1200 vs 公司值 600 —— 若兩邊都得 600，證明用了公司規則。
# #   （加班沿用通用費率，因 RuleUtils 無任意倍率方法；事假比率天生支援客製。）
# #
# # 用法：
# #   ./experiment_all.ps1                 # 完整跑（含部署 + 比對）
# #   ./experiment_all.ps1 -SkipDeploy     # 跑到編譯關卡，不部署不比對
# #   ./experiment_all.ps1 -NoReset        # 不清空 DRL
# # =========================================================

# param(
#     [string]$ProjectRoot = "C:\Users\PT\Desktop\code\Graduate",
#     [string]$CompanyId   = "10",
#     [int]$MaxFix         = 3,
#     [switch]$NoReset,
#     [switch]$SkipDeploy
# )

# $BaseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# $ParseRuleUrl   = "$BaseUrl/ai/parse-rule"
# $UpdateRulesUrl = "$BaseUrl/updaterules"
# $ResetRulesUrl  = "$BaseUrl/resetrules"
# $GenJavaUrl     = "$BaseUrl/ai/generate-java"
# $DrlCalcUrl     = "$BaseUrl/calculatesalary"
# $LegacyUrl      = "$BaseUrl/checksalary/legacy"
# $QueryUrl       = "$BaseUrl/rules/Salary/Company_${CompanyId}_Salary.drl"

# # ── 公司 10 的自然語言規則（事假改成跟通用不同：半扣 0.5）──
# $Prompts = @(
#     "公司10的員工平日有加班時數的話，加班費用平日加班費率計算（前兩小時1.34倍、超過兩小時1.67倍）。"
#     "公司10的員工請事假，只扣一半薪水（扣薪比率0.5），這跟一般公司全額扣薪不同。"
# )

# # ── 測試案例（含能區分「公司值 vs 通用值」的事假案例）──
# #   8H事假：通用=1200(全扣)、公司=600(半扣)。若兩邊都600 → 證明用了公司規則。
# $Cases = @(
#     @{ name = "無加班無請假_基準"
#        json = '{"companyId":"10","employeeId":"C10-E001","baseSalary":36000,"tenureMonths":12}' }
#     @{ name = "平日加班1H"
#        json = '{"companyId":"10","employeeId":"C10-E002","baseSalary":36000,"tenureMonths":12,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":1}]}' }
#     @{ name = "平日加班3H_跨段"
#        json = '{"companyId":"10","employeeId":"C10-E003","baseSalary":36000,"tenureMonths":12,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":3}]}' }
#     @{ name = "事假8H_公司半扣(應為600非1200)"
#        json = '{"companyId":"10","employeeId":"C10-E004","baseSalary":36000,"tenureMonths":12,"leaves":[{"leaveTypeName":"事假","leaveHours":8,"leaveDays":1}]}' }
#     @{ name = "事假4H_公司半扣(應為300非600)"
#        json = '{"companyId":"10","employeeId":"C10-E005","baseSalary":36000,"tenureMonths":12,"leaves":[{"leaveTypeName":"事假","leaveHours":4,"leaveDays":1}]}' }
#     @{ name = "加班3H加事假4H_混合"
#        json = '{"companyId":"10","employeeId":"C10-E006","baseSalary":41000,"tenureMonths":6,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":3}],"leaves":[{"leaveTypeName":"事假","leaveHours":4,"leaveDays":1}]}' }
# )

# $IgnoreKeys = @('appliedRule','ruleDetails','notes','warnings','executionTimeMs','timestamp','computeTime','message','employeeId')

# # ── 專案根目錄 ──
# if (-not (Test-Path (Join-Path $ProjectRoot "pom.xml"))) {
#     $probe = (Get-Location).Path
#     while ($probe -and -not (Test-Path (Join-Path $probe "pom.xml"))) {
#         $parent = Split-Path $probe -Parent
#         if ($parent -eq $probe) { $probe = $null; break }
#         $probe = $parent
#     }
#     if ($probe) { $ProjectRoot = $probe } else { Write-Host "找不到 pom.xml，請用 -ProjectRoot 指定" -ForegroundColor Red; exit 1 }
# }
# $ProjectRoot    = (Resolve-Path $ProjectRoot).Path
# $SalaryRulesDir = Join-Path $ProjectRoot "src\main\java\com\function\function\SalaryRules"
# $JavaPath       = Join-Path $SalaryRulesDir "Company${CompanyId}Rule.java"
# New-Item -ItemType Directory -Force -Path $SalaryRulesDir | Out-Null
# Write-Host "專案根目錄: $ProjectRoot" -ForegroundColor DarkCyan
# Write-Host "目標公司  : $CompanyId  ->  $JavaPath`n" -ForegroundColor DarkCyan

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

# # ── Step 0：重置 ──
# if (-not $NoReset) {
#     Write-Host "[0] 重置公司 $CompanyId ... " -NoNewline
#     $rr = Invoke-ApiJson -Url $ResetRulesUrl -Payload @{ ruleSet="salary"; companyId="$CompanyId" }
#     if ($rr.Ok) { Write-Host "DRL 已清空" -ForegroundColor Green -NoNewline } else { Write-Host "重置失敗(可能未部署ResetRules): $($rr.Error) $($rr.Body)" -ForegroundColor Yellow -NoNewline }
#     if (Test-Path $JavaPath) { Remove-Item $JavaPath -Force; Write-Host "；已刪舊 Java" -ForegroundColor Green } else { Write-Host "" }
# } else { Write-Host "[0] -NoReset：保留 DRL" -ForegroundColor DarkYellow }

# # ── Step 1+2：NL -> JSON -> 存 DRL ──
# $ruleCount = 0
# for ($i=0; $i -lt $Prompts.Count; $i++) {
#     Write-Host "`n[1] parse-rule ($($i+1)/$($Prompts.Count)) ... " -NoNewline
#     $pr = Invoke-ApiJson -Url $ParseRuleUrl -Payload @{ text=$Prompts[$i]; ruleSet="salary"; companyId="$CompanyId" }
#     if (-not $pr.Ok) { Write-Host "失敗: $($pr.Error) $($pr.Body)" -ForegroundColor Red; continue }
#     $rules = if ($pr.Json -is [array]) { $pr.Json } else { @($pr.Json) }
#     Write-Host "$($rules.Count) 條規則" -ForegroundColor Green
#     foreach ($rule in $rules) {
#         $cleanConditions = @()
#         if ($rule.conditions) {
#             foreach ($cond in $rule.conditions) {
#                 if (($cond.value -is [System.Management.Automation.PSCustomObject]) -or ($cond.operator -eq "+")) { continue }
#                 $clean = @{}
#                 if ($cond.field)           { $clean.field    = $cond.field }
#                 if ($cond.operator)        { $clean.operator = $cond.operator }
#                 if ($null -ne $cond.value) { $clean.value    = $cond.value }
#                 if ($clean.field -and $clean.operator) { $cleanConditions += $clean }
#             }
#         }
#         $up = @{
#             ruleSet="salary"; companyId="$CompanyId"
#             ruleName = if ($rule.ruleName) { $rule.ruleName } else { "rule_$i" }
#             author="pipeline"; version=1
#             priority = if ($rule.priority) { [int]$rule.priority } else { 8 }
#         }
#         if ($cleanConditions.Count -gt 0) { $up.conditions     = $cleanConditions }
#         if ($rule.action)                 { $up.action          = $rule.action }
#         if ($rule.actionNote)             { $up.actionNote      = $rule.actionNote }
#         if ($rule.actionWarning)          { $up.actionWarning   = $rule.actionWarning }
#         if ($rule.activationGroup)        { $up.activationGroup = $rule.activationGroup }
#         Write-Host "    [2] updaterules: $($up.ruleName) ... " -NoNewline
#         $ur = Invoke-ApiJson -Url $UpdateRulesUrl -Payload $up
#         if ($ur.Ok) { Write-Host "OK" -ForegroundColor Green; $ruleCount++ } else { Write-Host "失敗: $($ur.Error) $($ur.Body)" -ForegroundColor Red }
#     }
# }
# if ($ruleCount -eq 0) { Write-Host "`n沒有任何規則寫入，結束。" -ForegroundColor Red; exit 1 }
# Write-Host "`n已寫入 $ruleCount 條規則" -ForegroundColor Green
# Start-Sleep -Seconds 2

# # ── Step 3：查 DRL -> AI 轉 Java ──
# Write-Host "`n[3] generate-java ... " -NoNewline
# $gj = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId" }
# if (-not $gj.Ok -or -not $gj.Json.javaCode) { Write-Host "失敗: $($gj.Error) $($gj.Body)" -ForegroundColor Red; exit 1 }
# $gj.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8
# Write-Host "OK（DRL $($gj.Json.sourceDrlChars) 字元）" -ForegroundColor Green

# # ── Step 4：本地編譯關卡 + AI 修復 ──
# function Invoke-MvnCompile {
#     Push-Location $ProjectRoot
#     $out = & mvn -q compile 2>&1 | Out-String
#     $ok  = ($LASTEXITCODE -eq 0)
#     Pop-Location
#     return @{ Ok=$ok; Out=$out }
# }
# $attempt = 0
# while ($true) {
#     Write-Host "`n[4] mvn compile (第 $($attempt+1) 次) ..." -ForegroundColor Cyan
#     $c = Invoke-MvnCompile
#     if ($c.Ok) { Write-Host "編譯通過 ✅" -ForegroundColor Green; break }
#     Write-Host "編譯失敗 ❌" -ForegroundColor Red
#     if ($attempt -ge $MaxFix) {
#         Write-Host (($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" } | Select-Object -First 20) -join "`n")
#         exit 1
#     }
#     $attempt++
#     $errLines = ($c.Out -split "`n" | Where-Object { $_ -match "\[ERROR\]" }) -join "`n"
#     Write-Host "  -> 請 AI 修 ..." -ForegroundColor Yellow
#     $cur = Get-Content $JavaPath -Raw
#     $fix = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId"; previousCode=$cur; compileError=$errLines }
#     if ($fix.Ok -and $fix.Json.javaCode) { $fix.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8; Write-Host "     已套用修正" -ForegroundColor DarkGreen }
#     else { Write-Host "     AI 修復失敗: $($fix.Error) $($fix.Body)" -ForegroundColor Red }
# }

# if ($SkipDeploy) { Write-Host "`n-SkipDeploy：已編譯通過，未部署。" -ForegroundColor Yellow; exit 0 }

# # ── Step 5：部署 ──
# Write-Host "`n[5] mvn clean package azure-functions:deploy ..." -ForegroundColor Cyan
# Push-Location $ProjectRoot
# $start = Get-Date
# & mvn clean package azure-functions:deploy
# $ok = ($LASTEXITCODE -eq 0)
# Pop-Location
# if (-not $ok) { Write-Host "部署失敗 (exit=$LASTEXITCODE)" -ForegroundColor Red; exit 1 }
# Write-Host ("部署成功（{0} 分）。" -f [math]::Round(((Get-Date)-$start).TotalMinutes,1)) -ForegroundColor Green
# Write-Host "等冷啟動 30 秒 ..." -ForegroundColor DarkGray
# Start-Sleep -Seconds 30

# # ── Step 6：查詢規則 ──
# Write-Host "`n==================== [查詢規則] ====================" -ForegroundColor Cyan
# try {
#     $drlResp = Invoke-WebRequest -Uri $QueryUrl -Method GET -TimeoutSec 60 -ErrorAction Stop
#     Write-Host $drlResp.Content
# } catch { Write-Host "查詢 DRL 失敗：$($_.Exception.Message)" -ForegroundColor Yellow }

# # ── Step 7：比對 DRL vs Java ──
# Write-Host "`n==================== [測試比對] ====================" -ForegroundColor Cyan
# Write-Host "共 $($Cases.Count) 筆案例`n"
# $passed = 0
# for ($i=0; $i -lt $Cases.Count; $i++) {
#     $name = $Cases[$i].name; $body = $Cases[$i].json
#     $drl = Invoke-PostJson -Url $DrlCalcUrl -JsonBody $body
#     $jav = Invoke-PostJson -Url $LegacyUrl  -JsonBody $body
#     if (-not $drl.Ok) { Write-Host "[$($i+1)/$($Cases.Count)] ⚠ $name  DRL 失敗: $($drl.Error) $($drl.Body)" -ForegroundColor Yellow; continue }
#     if (-not $jav.Ok) { Write-Host "[$($i+1)/$($Cases.Count)] ⚠ $name  Java 失敗: $($jav.Error) $($jav.Body)" -ForegroundColor Yellow; continue }
#     $d = Get-Diffs (Norm $drl.Json) (Norm $jav.Json) ""
#     # 額外印出 finalSalary 與 leaveDeduction 方便人工確認「是公司值還是通用值」
#     $fs = $drl.Json.finalSalary; $ld = $drl.Json.leaveDeduction
#     if (-not $d -or $d.Count -eq 0) {
#         $passed++
#         Write-Host ("[$($i+1)/$($Cases.Count)] ✅ {0}  (DRL finalSalary={1}, leaveDeduction={2})" -f $name,$fs,$ld) -ForegroundColor Green
#     } else {
#         Write-Host "[$($i+1)/$($Cases.Count)] ❌ $name  ($($d.Count) 處差異)" -ForegroundColor Red
#         foreach ($line in $d) { Write-Host "        $line" -ForegroundColor DarkYellow }
#     }
# }
# Write-Host "`n==================== 結果 ====================" -ForegroundColor Cyan
# $rate = if ($Cases.Count -gt 0) { [math]::Round($passed * 100.0 / $Cases.Count, 1) } else { 0 }
# $col  = if ($passed -eq $Cases.Count) { "Green" } elseif ($passed -ge $Cases.Count/2) { "Yellow" } else { "Red" }
# Write-Host ("吻合率：{0}/{1} = {2}%" -f $passed, $Cases.Count, $rate) -ForegroundColor $col
# Write-Host "`n★ 證明用到公司規則：看『事假8H』那筆，DRL leaveDeduction 應為 600（公司半扣），" -ForegroundColor Magenta
# Write-Host "   而不是 1200（通用全扣）。是 600 就證明引擎與 Java 都套用了公司客製規則。" -ForegroundColor Magenta
# =========================================================
# experiment_all.ps1 — 完整一條龍 + 內建測試比對（合二為一）
#   NL -> JSON -> 存DRL -> 查DRL轉Java -> build -> 部署 -> 查詢 -> 比對
#
# 本輪重點：公司 10 用「跟通用不同」的客製，才能證明真的用到公司規則。
#   加班：公司10前2H×2、超過×4（法定為1.34/1.67）；事假：公司0.5、通用1.0。
#   驗證：加班/事假兩種客製，兩邊都得「公司值」才證明用了公司規則且 DRL=Java。

#
# 用法：
#   ./experiment_all.ps1                 # 完整跑（含部署 + 比對）
#   ./experiment_all.ps1 -SkipDeploy     # 跑到編譯關卡，不部署不比對
#   ./experiment_all.ps1 -NoReset        # 不清空 DRL
# =========================================================

param(
    [string]$ProjectRoot = "C:\Users\PT\Desktop\code\Graduate",
    [string]$CompanyId   = "10",
    [int]$MaxFix         = 3,
    [switch]$NoReset,
    [switch]$SkipDeploy
)

$BaseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
$ParseRuleUrl   = "$BaseUrl/ai/parse-rule"
$UpdateRulesUrl = "$BaseUrl/updaterules"
$ResetRulesUrl  = "$BaseUrl/resetrules"
$GenJavaUrl     = "$BaseUrl/ai/generate-java"
$DrlCalcUrl     = "$BaseUrl/calculatesalary"
$LegacyUrl      = "$BaseUrl/checksalary/legacy"
$QueryUrl       = "$BaseUrl/rules/Salary/Company_${CompanyId}_Salary.drl"

# ── 公司 10 的自然語言規則（事假改成跟通用不同：半扣 0.5）──
$Prompts = @(
    "公司10的員工平日有加班時數的話，加班費前兩小時2倍、超過兩小時4倍。"
    "公司10的員工請事假，只扣一半薪水（扣薪比率0.5），這跟一般公司全額扣薪不同。"
)

# ── 測試案例（含能區分「公司值 vs 通用值」的事假案例）──
#   8H事假：通用=1200(全扣)、公司=600(半扣)。若兩邊都600 → 證明用了公司規則。
$Cases = @(
    @{ name = "無加班無請假_基準"
       json = '{"companyId":"10","employeeId":"C10-E001","baseSalary":36000,"tenureMonths":12}' }
    @{ name = "平日加班1H_公司2倍(應為300非法定201)"
       json = '{"companyId":"10","employeeId":"C10-E002","baseSalary":36000,"tenureMonths":12,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":1}]}' }
    @{ name = "平日加班3H_公司2/4倍(應為1200非法定650)"
       json = '{"companyId":"10","employeeId":"C10-E003","baseSalary":36000,"tenureMonths":12,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":3}]}' }
    @{ name = "事假8H_公司半扣(應為600非1200)"
       json = '{"companyId":"10","employeeId":"C10-E004","baseSalary":36000,"tenureMonths":12,"leaves":[{"leaveTypeName":"事假","leaveHours":8,"leaveDays":1}]}' }
    @{ name = "事假4H_公司半扣(應為300非600)"
       json = '{"companyId":"10","employeeId":"C10-E005","baseSalary":36000,"tenureMonths":12,"leaves":[{"leaveTypeName":"事假","leaveHours":4,"leaveDays":1}]}' }
    @{ name = "加班3H加事假4H_混合"
       json = '{"companyId":"10","employeeId":"C10-E006","baseSalary":41000,"tenureMonths":6,"overtimes":[{"overtimeType":"WEEKDAY","overtimeHours":3}],"leaves":[{"leaveTypeName":"事假","leaveHours":4,"leaveDays":1}]}' }
)

$IgnoreKeys = @('appliedRule','ruleDetails','notes','warnings','executionTimeMs','timestamp','computeTime','message','employeeId')

# ── 專案根目錄 ──
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
Write-Host "目標公司  : $CompanyId  ->  $JavaPath`n" -ForegroundColor DarkCyan

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

# ── Step 0：重置 ──
if (-not $NoReset) {
    Write-Host "[0] 重置公司 $CompanyId ... " -NoNewline
    $rr = Invoke-ApiJson -Url $ResetRulesUrl -Payload @{ ruleSet="salary"; companyId="$CompanyId" }
    if ($rr.Ok) { Write-Host "DRL 已清空" -ForegroundColor Green -NoNewline } else { Write-Host "重置失敗(可能未部署ResetRules): $($rr.Error) $($rr.Body)" -ForegroundColor Yellow -NoNewline }
    if (Test-Path $JavaPath) { Remove-Item $JavaPath -Force; Write-Host "；已刪舊 Java" -ForegroundColor Green } else { Write-Host "" }
} else { Write-Host "[0] -NoReset：保留 DRL" -ForegroundColor DarkYellow }

# ── Step 1+2：NL -> JSON -> 存 DRL ──
$ruleCount = 0
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
        Write-Host "    [2] updaterules: $($up.ruleName) ... " -NoNewline
        $ur = Invoke-ApiJson -Url $UpdateRulesUrl -Payload $up
        if ($ur.Ok) { Write-Host "OK" -ForegroundColor Green; $ruleCount++ } else { Write-Host "失敗: $($ur.Error) $($ur.Body)" -ForegroundColor Red }
    }
}
if ($ruleCount -eq 0) { Write-Host "`n沒有任何規則寫入，結束。" -ForegroundColor Red; exit 1 }
Write-Host "`n已寫入 $ruleCount 條規則" -ForegroundColor Green
Start-Sleep -Seconds 2

# ── Step 3：查 DRL -> AI 轉 Java ──
Write-Host "`n[3] generate-java ... " -NoNewline
$gj = Invoke-ApiJson -Url $GenJavaUrl -Payload @{ companyId="$CompanyId" }
if (-not $gj.Ok -or -not $gj.Json.javaCode) { Write-Host "失敗: $($gj.Error) $($gj.Body)" -ForegroundColor Red; exit 1 }
$gj.Json.javaCode | Out-File -FilePath $JavaPath -Encoding UTF8
Write-Host "OK（DRL $($gj.Json.sourceDrlChars) 字元）" -ForegroundColor Green

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
    if ($c.Ok) { Write-Host "編譯通過 ✅" -ForegroundColor Green; break }
    Write-Host "編譯失敗 ❌" -ForegroundColor Red
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

# ── Step 6：查詢規則 ──
Write-Host "`n==================== [查詢規則] ====================" -ForegroundColor Cyan
try {
    $drlResp = Invoke-WebRequest -Uri $QueryUrl -Method GET -TimeoutSec 60 -ErrorAction Stop
    Write-Host $drlResp.Content
} catch { Write-Host "查詢 DRL 失敗：$($_.Exception.Message)" -ForegroundColor Yellow }

# ── Step 7：比對 DRL vs Java ──
Write-Host "`n==================== [測試比對] ====================" -ForegroundColor Cyan
Write-Host "共 $($Cases.Count) 筆案例`n"
$passed = 0
for ($i=0; $i -lt $Cases.Count; $i++) {
    $name = $Cases[$i].name; $body = $Cases[$i].json
    $drl = Invoke-PostJson -Url $DrlCalcUrl -JsonBody $body
    $jav = Invoke-PostJson -Url $LegacyUrl  -JsonBody $body
    if (-not $drl.Ok) { Write-Host "[$($i+1)/$($Cases.Count)] ⚠ $name  DRL 失敗: $($drl.Error) $($drl.Body)" -ForegroundColor Yellow; continue }
    if (-not $jav.Ok) { Write-Host "[$($i+1)/$($Cases.Count)] ⚠ $name  Java 失敗: $($jav.Error) $($jav.Body)" -ForegroundColor Yellow; continue }
    $d = Get-Diffs (Norm $drl.Json) (Norm $jav.Json) ""
    # 額外印出 finalSalary 與 leaveDeduction 方便人工確認「是公司值還是通用值」
    $fs = $drl.Json.finalSalary; $ld = $drl.Json.leaveDeduction
    if (-not $d -or $d.Count -eq 0) {
        $passed++
        Write-Host ("[$($i+1)/$($Cases.Count)] ✅ {0}  (DRL finalSalary={1}, leaveDeduction={2})" -f $name,$fs,$ld) -ForegroundColor Green
    } else {
        Write-Host "[$($i+1)/$($Cases.Count)] ❌ $name  ($($d.Count) 處差異)" -ForegroundColor Red
        foreach ($line in $d) { Write-Host "        $line" -ForegroundColor DarkYellow }
    }
}
Write-Host "`n==================== 結果 ====================" -ForegroundColor Cyan
$rate = if ($Cases.Count -gt 0) { [math]::Round($passed * 100.0 / $Cases.Count, 1) } else { 0 }
$col  = if ($passed -eq $Cases.Count) { "Green" } elseif ($passed -ge $Cases.Count/2) { "Yellow" } else { "Red" }
Write-Host ("吻合率：{0}/{1} = {2}%" -f $passed, $Cases.Count, $rate) -ForegroundColor $col
Write-Host "`n★ 證明用到公司規則（公司值 != 法定/通用值）：" -ForegroundColor Magenta
Write-Host "   加班1H：應為 300（公司2倍），非 201（法定1.34倍）" -ForegroundColor Magenta
Write-Host "   加班3H：應為 1200（公司2/4倍），非 650（法定1.34/1.67倍）" -ForegroundColor Magenta
Write-Host "   事假8H：應為 600（公司半扣），非 1200（通用全扣）" -ForegroundColor Magenta
Write-Host "   全為公司值且兩邊一致 => 規則引擎與硬編碼 Java 都正確套用公司客製規則。" -ForegroundColor Magenta