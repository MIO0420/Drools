# ============================================================
# test-scheduling-single-batch.ps1
# 單批 2,000 筆測試：DRL vs Legacy 效能對照
# ★ 核心修正：改用 System.Text.Json 序列化，
#   徹底解決 PowerShell ConvertTo-Json boolean 序列化問題
# ★ v2 新增：companyId 送入 API，觸發公司客製化規則
# ============================================================

$BASE_URL        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net"
$API_DRL         = "$BASE_URL/api/checkscheduling"
$API_LEGACY      = "$BASE_URL/api/checkscheduling/legacy"

# ── 只改這裡 ─────────────────────────────────────────────────
$TOTAL_COMPANIES = 10
$EMPLOYEES       = 10
$WORK_DAYS       = 20
# ─────────────────────────────────────────────────────────────

$WORK_TIME_TYPES = @("GENERAL","TWO_WEEK_FLEXIBLE","FOUR_WEEK_FLEXIBLE","EIGHT_WEEK_FLEXIBLE")

$MEMORY_GB       = 1.5
$COST_PER_GB_SEC = 0.000016
$POWER_KW        = 0.0003
$AZURE_PUE       = 1.2
$CO2_PER_KWH     = 475

# ============================================================
# 函式：產生單筆 SchedulingFact（回傳 Hashtable）
# ============================================================
function New-Fact {
    param([int]$companyId,[int]$employeeId,[int]$dayIndex,[string]$workTimeType,[int]$seed)

    $f = @{
        # ★ companyId：業務欄位，會被送出 API
        #   Java @JsonAnySetter 會將其存入 metadata
        #   DRL   用法：getMeta("companyId") != null
        #               getMeta("companyId").toString() == "1"
        #   Legacy用法：f.getMeta("companyId").toString()
        #   ⚠️  使用字串型別，與 DRL/Legacy 的 .toString() 比對一致
        companyId                        = "$companyId"
        workTimeType                     = $workTimeType
        dailyWorkHours                   = 8
        weeklyWorkHours                  = 40
        biweeklyWorkHours                = 80
        fourWeekWorkHours                = 160
        eightWeekWorkHours               = 320
        consecutiveWorkDays              = 5
        restDaysPerWeek                  = 2
        mandatoryDaysOffBiweekly         = 2
        totalDaysOffFourWeeks            = 8
        restDaysBiweeklyEightWeek        = 4
        restDaysEightWeek                = 16
        dailyTotalHours                  = 8
        monthlyOvertimeHours             = 0
        quarterlyOvertimeHours           = 0
        laborCouncilAgreed               = $false
        compensatoryLeaveExpired         = $false
        compensatoryLeaveHours           = 0
        shiftWorker                      = $false
        shiftChangeRestHours             = 11
        continuousWorkHours              = 4
        breakMinutes                     = 30
        mandatoryDayOffPerWeek           = $true
        restDayPerWeek                   = $true
        mandatoryDayOffScheduledAsWork   = $false
        legalExceptionForMandatoryDayOff = $false
        mandatoryDayOffOvertimePaid      = $false
        restDayWorked                    = $false
        restDayOvertimePaid              = $true
        nationalHolidayScheduledAsWork   = $false
        nationalHolidayAdjustAgreed      = $false
        nationalHolidayOvertimePaid      = $false
        annualLeaveDeniedByEmployer      = $false
        annualLeaveAdjustmentAgreed      = $false
        # _meta 欄位（不送 API，僅供本地比對追蹤）
        _meta_companyId                  = $companyId
        _meta_employeeId                 = $employeeId
        _meta_dayIndex                   = $dayIndex
        _meta_seed                       = $seed
        _meta_workTimeType               = $workTimeType
    }

    # ── 工時制度預設值調整 ────────────────────────────────────
    switch ($workTimeType) {
        "TWO_WEEK_FLEXIBLE"   { $f.dailyWorkHours=9;  $f.weeklyWorkHours=44 }
        "FOUR_WEEK_FLEXIBLE"  { $f.dailyWorkHours=9;  $f.weeklyWorkHours=38; $f.fourWeekWorkHours=155 }
        "EIGHT_WEEK_FLEXIBLE" { $f.weeklyWorkHours=44; $f.eightWeekWorkHours=310 }
    }

    # ── seed 情境注入 ─────────────────────────────────────────
    # seed 0～9 對應 10 種違規情境，每家公司 10 名員工各對應一種
    # 搭配 companyId，可同時觸發勞基法規則 + 公司客製化規則
    switch ($seed % 10) {
        0 {
            # 合規基準線（所有欄位維持預設值）
            # 公司客製化規則：部分公司（如 Company1）每日 7H 上限，
            # 此 seed 的 dailyWorkHours=8 會觸發 Company1/Company8 的客製規則
        }
        1 {
            # 輪班換班情境
            $f.shiftWorker          = $true
            $f.shiftChangeRestHours = 12
            $f.continuousWorkHours  = 6
            $f.breakMinutes         = 45
        }
        2 {
            # 休息日合規出勤（已給薪）
            $f.restDayWorked       = $true
            $f.restDayOvertimePaid = $true
        }
        3 {
            # 國定假日合規出勤（已協商且已給薪）→ 勞基法合規
            # Company4 客製：須同步補休，compensatoryLeaveHours=0 會觸發
            $f.nationalHolidayScheduledAsWork = $true
            $f.nationalHolidayAdjustAgreed    = $true
            $f.nationalHolidayOvertimePaid    = $true
        }
        4 {
            # 每日工時超標情境
            $o = switch($workTimeType){
                "GENERAL"             { 9  }
                "TWO_WEEK_FLEXIBLE"   { 11 }
                "FOUR_WEEK_FLEXIBLE"  { 11 }
                "EIGHT_WEEK_FLEXIBLE" { 9  }
                default               { 9  }
            }
            $f.dailyWorkHours  = $o
            $f.dailyTotalHours = $o + 2
        }
        5 {
            # 月加班超標情境（無勞資會議同意）
            $f.weeklyWorkHours = switch($workTimeType){
                "GENERAL"             { 45 }
                "TWO_WEEK_FLEXIBLE"   { 50 }
                "FOUR_WEEK_FLEXIBLE"  { 42 }
                "EIGHT_WEEK_FLEXIBLE" { 50 }
                default               { 45 }
            }
            $f.monthlyOvertimeHours = 50
            $f.laborCouncilAgreed   = $false
        }
        6 {
            # 例假日違法出勤（無法定例外）
            $f.mandatoryDayOffScheduledAsWork   = $true
            $f.legalExceptionForMandatoryDayOff = $false
        }
        7 {
            # 休息日出勤未給薪
            $f.restDayWorked       = $true
            $f.restDayOvertimePaid = $false
        }
        8 {
            # 每日總工時 + 月/季加班全超標（有勞資會議同意）
            $f.dailyTotalHours        = 13
            $f.monthlyOvertimeHours   = 55
            $f.quarterlyOvertimeHours = 140
            $f.laborCouncilAgreed     = $true
        }
        9 {
            # 複合違規：工時超標 + 無例假 + 國定假日未協商 + 補休逾期 + 換班間距不足
            $f.dailyWorkHours = switch($workTimeType){
                "GENERAL"             { 10 }
                "TWO_WEEK_FLEXIBLE"   { 11 }
                "FOUR_WEEK_FLEXIBLE"  { 11 }
                "EIGHT_WEEK_FLEXIBLE" { 10 }
                default               { 10 }
            }
            $f.restDaysPerWeek                = 1
            $f.mandatoryDayOffPerWeek         = $false
            $f.nationalHolidayScheduledAsWork = $true
            $f.nationalHolidayAdjustAgreed    = $false
            $f.compensatoryLeaveExpired       = $true
            $f.shiftWorker                    = $true
            $f.shiftChangeRestHours           = 6
        }
    }
    return $f
}

# ============================================================
# 函式：★ 使用 System.Text.Json 序列化，確保 boolean 正確
#         PowerShell Hashtable 的 $true/$false 在此函式中
#         會被正確序列化為 JSON true/false
# ============================================================
function ConvertTo-SafeJson {
    param($FactList)

    Add-Type -AssemblyName "System.Text.Json" -ErrorAction SilentlyContinue

    # 過濾掉 _meta_* 欄位，只保留業務欄位（含 companyId）
    $cleanList = [System.Collections.Generic.List[object]]::new()
    foreach ($f in $FactList) {
        $clean = [ordered]@{}
        foreach ($key in $f.Keys) {
            if (-not $key.StartsWith("_meta_")) {
                $clean[$key] = $f[$key]
            }
        }
        $cleanList.Add($clean)
    }

    try {
        $options = [System.Text.Json.JsonSerializerOptions]::new()
        $options.WriteIndented = $false
        $json = [System.Text.Json.JsonSerializer]::Serialize($cleanList, $options)
        return $json
    } catch {
        # fallback：手動轉型後用 ConvertTo-Json
        Write-Host ("  ⚠️  System.Text.Json 不可用，使用 fallback 序列化") -ForegroundColor Yellow
        $typedList = [System.Collections.Generic.List[object]]::new()
        foreach ($f in $FactList) {
            $obj = [PSCustomObject]@{
                # ★ companyId 加入 fallback 序列化（字串型別）
                companyId                        = [string]$f.companyId
                workTimeType                     = [string]$f.workTimeType
                dailyWorkHours                   = [int]$f.dailyWorkHours
                weeklyWorkHours                  = [int]$f.weeklyWorkHours
                biweeklyWorkHours                = [int]$f.biweeklyWorkHours
                fourWeekWorkHours                = [int]$f.fourWeekWorkHours
                eightWeekWorkHours               = [int]$f.eightWeekWorkHours
                consecutiveWorkDays              = [int]$f.consecutiveWorkDays
                restDaysPerWeek                  = [int]$f.restDaysPerWeek
                mandatoryDaysOffBiweekly         = [int]$f.mandatoryDaysOffBiweekly
                totalDaysOffFourWeeks            = [int]$f.totalDaysOffFourWeeks
                restDaysBiweeklyEightWeek        = [int]$f.restDaysBiweeklyEightWeek
                restDaysEightWeek                = [int]$f.restDaysEightWeek
                dailyTotalHours                  = [int]$f.dailyTotalHours
                monthlyOvertimeHours             = [int]$f.monthlyOvertimeHours
                quarterlyOvertimeHours           = [int]$f.quarterlyOvertimeHours
                laborCouncilAgreed               = [bool]($f.laborCouncilAgreed               -eq $true)
                compensatoryLeaveExpired         = [bool]($f.compensatoryLeaveExpired         -eq $true)
                compensatoryLeaveHours           = [int]$f.compensatoryLeaveHours
                shiftWorker                      = [bool]($f.shiftWorker                      -eq $true)
                shiftChangeRestHours             = [int]$f.shiftChangeRestHours
                continuousWorkHours              = [int]$f.continuousWorkHours
                breakMinutes                     = [int]$f.breakMinutes
                mandatoryDayOffPerWeek           = [bool]($f.mandatoryDayOffPerWeek           -eq $true)
                restDayPerWeek                   = [bool]($f.restDayPerWeek                   -eq $true)
                mandatoryDayOffScheduledAsWork   = [bool]($f.mandatoryDayOffScheduledAsWork   -eq $true)
                legalExceptionForMandatoryDayOff = [bool]($f.legalExceptionForMandatoryDayOff -eq $true)
                mandatoryDayOffOvertimePaid      = [bool]($f.mandatoryDayOffOvertimePaid      -eq $true)
                restDayWorked                    = [bool]($f.restDayWorked                    -eq $true)
                restDayOvertimePaid              = [bool]($f.restDayOvertimePaid              -eq $true)
                nationalHolidayScheduledAsWork   = [bool]($f.nationalHolidayScheduledAsWork   -eq $true)
                nationalHolidayAdjustAgreed      = [bool]($f.nationalHolidayAdjustAgreed      -eq $true)
                nationalHolidayOvertimePaid      = [bool]($f.nationalHolidayOvertimePaid      -eq $true)
                annualLeaveDeniedByEmployer      = [bool]($f.annualLeaveDeniedByEmployer      -eq $true)
                annualLeaveAdjustmentAgreed      = [bool]($f.annualLeaveAdjustmentAgreed      -eq $true)
            }
            $typedList.Add($obj)
        }
        return ($typedList | ConvertTo-Json -Depth 5 -Compress)
    }
}

# ============================================================
# 函式：耗能計算
# ============================================================
function Get-EnergyStats {
    param([double]$ElapsedMs)
    $sec = $ElapsedMs / 1000
    return [PSCustomObject]@{
        ElapsedSec = [math]::Round($sec, 3)
        GBSec      = [math]::Round($MEMORY_GB * $sec, 4)
        CostUSD    = [math]::Round($MEMORY_GB * $sec * $COST_PER_GB_SEC, 8)
        EnergyWh   = [math]::Round($POWER_KW * $sec * $AZURE_PUE / 3.6, 6)
        CO2Gram    = [math]::Round($POWER_KW * $sec * $AZURE_PUE / 3600 * $CO2_PER_KWH, 6)
    }
}

# ============================================================
# 函式：單次 POST（HttpClient）
# ============================================================
function Invoke-SchedulingApi {
    param([string]$Url, [string]$JsonBody, [string]$Label, [int]$Count)

    Add-Type -AssemblyName System.Net.Http -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Host ("┌─────────────────────────────────────────────────────") -ForegroundColor Cyan
    Write-Host ("│  ▶ $Label") -ForegroundColor Cyan
    Write-Host ("│  筆數：$Count　大小：$([math]::Round([System.Text.Encoding]::UTF8.GetByteCount($JsonBody)/1KB,1)) KB") -ForegroundColor Gray
    Write-Host ("└─────────────────────────────────────────────────────") -ForegroundColor Cyan

    $start = Get-Date
    try {
        $client         = [System.Net.Http.HttpClient]::new()
        $client.Timeout = [TimeSpan]::FromSeconds(120)

        $content = [System.Net.Http.StringContent]::new(
            $JsonBody,
            [System.Text.Encoding]::UTF8,
            "application/json"
        )
        $content.Headers.Add("X-Mode", "batch")

        $resp     = $client.PostAsync($Url, $content).GetAwaiter().GetResult()
        $body     = $resp.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $clientMs = [math]::Round(((Get-Date) - $start).TotalMilliseconds)

        $hDict = @{}
        foreach ($h in $resp.Headers)         { $hDict[$h.Key] = ($h.Value -join ",") }
        foreach ($h in $resp.Content.Headers) { $hDict[$h.Key] = ($h.Value -join ",") }

        $serverMs  = [int]($hDict["X-Execution-Time-Ms"] ?? 0)
        $batchSize = [int]($hDict["X-Batch-Size"]        ?? 0)
        $headerSrc = if ($serverMs -gt 0) { "[X-Header]" } else { "[fallback]" }
        if ($serverMs -eq 0) { $serverMs = $clientMs }
        if ($batchSize -eq 0) { $batchSize = $Count }

        $networkMs = [math]::Max(0, $clientMs - $serverMs)
        $perItemMs = [math]::Round($serverMs / $batchSize, 6)

        $client.Dispose()

        if (-not $resp.IsSuccessStatusCode) {
            throw "HTTP $([int]$resp.StatusCode)：$($body.Substring(0,[math]::Min(300,$body.Length)))"
        }
        if ([string]::IsNullOrWhiteSpace($body) -or $body -eq "null") {
            throw "回應 body 為空（HTTP $([int]$resp.StatusCode)）"
        }

        $data   = $body | ConvertFrom-Json
        $energy = Get-EnergyStats -ElapsedMs $serverMs

        Write-Host ("  ✅ 回應成功") -ForegroundColor Green
        Write-Host ("  ┌── 時間 ────────────────────────────────────") -ForegroundColor DarkCyan
        Write-Host ("  │  客戶端總耗時  : {0,8:N0} ms"    -f $clientMs)             -ForegroundColor White
        Write-Host ("  │  伺服器執行    : {0,8:N0} ms {1}" -f $serverMs,$headerSrc)  -ForegroundColor Yellow
        Write-Host ("  │  網路傳輸      : {0,8:N0} ms"    -f $networkMs)             -ForegroundColor Gray
        Write-Host ("  │  每筆平均      : {0,8:N6} ms"    -f $perItemMs)             -ForegroundColor Cyan
        Write-Host ("  ├── 耗能 ────────────────────────────────────") -ForegroundColor DarkCyan
        Write-Host ("  │  執行時間      : {0,8:N3} 秒"      -f $energy.ElapsedSec)   -ForegroundColor White
        Write-Host ("  │  GB-秒用量     : {0,8:N4} GB·s"    -f $energy.GBSec)        -ForegroundColor White
        Write-Host ("  │  估算費用      : {0,12:N8} USD"    -f $energy.CostUSD)      -ForegroundColor Yellow
        Write-Host ("  │  估算耗電      : {0,12:N6} Wh"     -f $energy.EnergyWh)     -ForegroundColor Yellow
        Write-Host ("  │  碳排放量      : {0,12:N6} g CO₂"  -f $energy.CO2Gram)      -ForegroundColor Green
        Write-Host ("  └────────────────────────────────────────────") -ForegroundColor DarkCyan

        return [PSCustomObject]@{
            Success   = $true
            Data      = $data
            ClientMs  = $clientMs
            ServerMs  = $serverMs
            NetworkMs = $networkMs
            PerItemMs = $perItemMs
            Energy    = $energy
            Error     = $null
        }

    } catch {
        $clientMs = [math]::Round(((Get-Date) - $start).TotalMilliseconds)
        Write-Host ("  ❌ 失敗（{0:N0} ms）：{1}" -f $clientMs, $_) -ForegroundColor Red
        return [PSCustomObject]@{
            Success   = $false
            Data      = $null
            ClientMs  = $clientMs
            ServerMs  = 0
            PerItemMs = 0
            Energy    = (Get-EnergyStats -ElapsedMs $clientMs)
            Error     = $_.ToString()
        }
    }
}

# ============================================================
# 函式：統計結果
# ============================================================
function Get-ResultStats {
    param($Response, [string]$Label)

    if ($null -eq $Response -or $Response.Count -eq 0) {
        Write-Host ("  ⚠️  $Label 無資料") -ForegroundColor Yellow
        return [PSCustomObject]@{ Total=0; Violated=0; Compliant=0; Rate=0; RuleCount=@{} }
    }

    $total     = $Response.Count
    $violated  = ($Response | Where-Object { $_.violated -eq $true  }).Count
    $compliant = ($Response | Where-Object { $_.violated -eq $false }).Count
    $rate      = [math]::Round($violated / $total * 100, 2)

    $ruleCount = @{}
    foreach ($r in $Response) {
        if ($r.violated -and $r.violatedRules) {
            foreach ($rule in $r.violatedRules) {
                $ruleCount[$rule] = ([int]($ruleCount[$rule] ?? 0)) + 1
            }
        }
    }

    # ── 公司客製化規則統計（Company1～Company10）────────────────
    $companyRuleCount = @{}
    foreach ($key in $ruleCount.Keys) {
        if ($key -match "^Company\d+") {
            $companyRuleCount[$key] = $ruleCount[$key]
        }
    }

    Write-Host ""
    Write-Host ("  ┌── $Label ──────────────────────────────────────") -ForegroundColor Magenta
    Write-Host ("  │  總筆數   : {0,8:N0}" -f $total)     -ForegroundColor White
    Write-Host ("  │  違規筆數 : {0,8:N0}" -f $violated)  -ForegroundColor Red
    Write-Host ("  │  合規筆數 : {0,8:N0}" -f $compliant) -ForegroundColor Green
    Write-Host ("  │  違規率   : {0,8}%"   -f $rate)      -ForegroundColor Yellow
    Write-Host ("  ├── TOP 10 違規規則（含客製化）──────────────────") -ForegroundColor Magenta
    $ruleCount.GetEnumerator() |
        Sort-Object Value -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            $color = if ($_.Key -match "^Company\d+") { "Cyan" } else { "Yellow" }
            Write-Host ("  │  [{0,5:N0}次] {1}" -f $_.Value, $_.Key) -ForegroundColor $color
        }

    if ($companyRuleCount.Count -gt 0) {
        $companyViolationTotal = ($companyRuleCount.Values | Measure-Object -Sum).Sum
        Write-Host ("  ├── 公司客製化規則違規小計 ───────────────────") -ForegroundColor Magenta
        Write-Host ("  │  客製化違規次數合計 : {0,6:N0} 次" -f $companyViolationTotal) -ForegroundColor Cyan
        $companyRuleCount.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                Write-Host ("  │  [{0,5:N0}次] {1}" -f $_.Value, $_.Key) -ForegroundColor Cyan
            }
    }

    Write-Host ("  └─────────────────────────────────────────────────") -ForegroundColor Magenta

    return [PSCustomObject]@{
        Total=$total; Violated=$violated; Compliant=$compliant
        Rate=$rate; RuleCount=$ruleCount; CompanyRuleCount=$companyRuleCount
    }
}

# ============================================================
# 函式：比對差異
# ============================================================
function Compare-Results {
    param($DrlData, $LegacyData, $SourceFacts)

    if ($null -eq $DrlData -or $null -eq $LegacyData) {
        Write-Host ("  ⚠️  資料不足，無法比對") -ForegroundColor Yellow
        return [PSCustomObject]@{ MatchRate=0; DiffCount=0; SameCount=0; DiffSamples=@() }
    }

    $diff    = 0
    $same    = 0
    $samples = [System.Collections.Generic.List[object]]::new()
    $minLen  = [math]::Min($DrlData.Count, $LegacyData.Count)

    for ($i = 0; $i -lt $minLen; $i++) {
        $dv = [bool]$DrlData[$i].violated
        $lv = [bool]$LegacyData[$i].violated

        if ($dv -ne $lv) {
            $diff++
            $src = if ($null -ne $SourceFacts -and $i -lt $SourceFacts.Count) {
                $SourceFacts[$i]
            } else { $null }

            $samples.Add([PSCustomObject]@{
                Index              = $i
                CompanyId          = if ($src) { $src._meta_companyId    } else { "" }
                WorkTimeType       = if ($src) { $src._meta_workTimeType } else { "" }
                Seed               = if ($src) { $src._meta_seed         } else { "" }
                EmployeeId         = if ($src) { $src._meta_employeeId   } else { "" }
                DayIndex           = if ($src) { $src._meta_dayIndex     } else { "" }
                DRL_Violated       = $dv
                Legacy_Violated    = $lv
                DRL_Rules          = ($DrlData[$i].violatedRules    -join " | ")
                Legacy_Rules       = ($LegacyData[$i].violatedRules -join " | ")
                nationalHolidayScheduledAsWork = if ($src) { $src.nationalHolidayScheduledAsWork } else { "" }
                nationalHolidayAdjustAgreed    = if ($src) { $src.nationalHolidayAdjustAgreed    } else { "" }
                nationalHolidayOvertimePaid    = if ($src) { $src.nationalHolidayOvertimePaid    } else { "" }
                mandatoryDayOffScheduledAsWork = if ($src) { $src.mandatoryDayOffScheduledAsWork } else { "" }
                restDayWorked                  = if ($src) { $src.restDayWorked                  } else { "" }
            })
        } else { $same++ }
    }

    $matchRate = [math]::Round($same / $minLen * 100, 4)

    Write-Host ""
    Write-Host ("  ┌── 🔍 DRL vs Legacy 比對 ───────────────────────") -ForegroundColor Magenta
    Write-Host ("  │  比對筆數 : {0:N0}" -f $minLen)    -ForegroundColor White
    Write-Host ("  │  一致筆數 : {0:N0}" -f $same)      -ForegroundColor Green
    Write-Host ("  │  差異筆數 : {0:N0}" -f $diff)      -ForegroundColor $(if($diff -gt 0){"Red"}else{"Green"})
    Write-Host ("  │  一致率   : {0}%"   -f $matchRate) -ForegroundColor Cyan

    if ($diff -gt 0) {
        $drlOnly    = $samples | Where-Object { $_.DRL_Violated -and -not $_.Legacy_Violated }
        $legacyOnly = $samples | Where-Object { $_.Legacy_Violated -and -not $_.DRL_Violated }

        Write-Host ("  ├── 差異分類 ─────────────────────────────────") -ForegroundColor Red
        Write-Host ("  │  DRL 多判違規（Legacy 認為合規）: {0} 筆" -f $drlOnly.Count)    -ForegroundColor Yellow
        Write-Host ("  │  Legacy 多判違規（DRL 認為合規）: {0} 筆" -f $legacyOnly.Count) -ForegroundColor Yellow

        $diffRuleCount = @{}
        foreach ($s in $samples) {
            $triggerRule = if ($s.DRL_Violated) { $s.DRL_Rules } else { $s.Legacy_Rules }
            foreach ($r in ($triggerRule -split " \| ")) {
                if ($r) { $diffRuleCount[$r] = ([int]($diffRuleCount[$r] ?? 0)) + 1 }
            }
        }
        Write-Host ("  ├── 差異來源規則 TOP 5 ───────────────────────") -ForegroundColor Red
        $diffRuleCount.GetEnumerator() |
            Sort-Object Value -Descending |
            Select-Object -First 5 |
            ForEach-Object {
                Write-Host ("  │  [{0,5:N0}次] {1}" -f $_.Value, $_.Key) -ForegroundColor DarkYellow
            }

        Write-Host ("  ├── 差異範例（前 5 筆）────────────────────────") -ForegroundColor Red
        $samples | Select-Object -First 5 | ForEach-Object {
            Write-Host ("  │  [#{0}] co={1} wtt={2} seed={3} emp={4} day={5}" -f `
                $_.Index,$_.CompanyId,$_.WorkTimeType,$_.Seed,$_.EmployeeId,$_.DayIndex) -ForegroundColor Yellow
            Write-Host ("  │    DRL   : {0} → {1}" -f $(if($_.DRL_Violated){"❌"}else{"✅"}),$_.DRL_Rules)      -ForegroundColor DarkYellow
            Write-Host ("  │    Legacy: {0} → {1}" -f $(if($_.Legacy_Violated){"❌"}else{"✅"}),$_.Legacy_Rules) -ForegroundColor DarkYellow
            Write-Host ("  │    欄位  : nhWork={0} nhAgreed={1} nhPaid={2}" -f `
                $_.nationalHolidayScheduledAsWork,$_.nationalHolidayAdjustAgreed,$_.nationalHolidayOvertimePaid) -ForegroundColor Gray
        }
    } else {
        Write-Host ("  │  🎉 兩版本完全一致！") -ForegroundColor Green
    }
    Write-Host ("  └─────────────────────────────────────────────────") -ForegroundColor Magenta

    return [PSCustomObject]@{
        MatchRate   = $matchRate
        DiffCount   = $diff
        SameCount   = $same
        DiffSamples = $samples
    }
}

# ============================================================
# MAIN
# ============================================================
$globalStart = Get-Date
$timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$totalTarget = $TOTAL_COMPANIES * $EMPLOYEES * $WORK_DAYS

Write-Host ""
Write-Host ("╔══════════════════════════════════════════════════════╗") -ForegroundColor Cyan
Write-Host ("║   排班合規 單批測試：DRL vs Legacy                   ║") -ForegroundColor Cyan
Write-Host ("║   目標筆數：$("{0,6:N0}" -f $totalTarget) 筆  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')    ║") -ForegroundColor Cyan
Write-Host ("╚══════════════════════════════════════════════════════╝") -ForegroundColor Cyan

# ── STEP 1：建構資料 ───────────────────────────────────────────
Write-Host "`n【STEP 1】建構 $("{0:N0}" -f $totalTarget) 筆資料..." -ForegroundColor White
$buildStart = Get-Date
$allFacts   = [System.Collections.Generic.List[object]]::new()

for ($c = 1; $c -le $TOTAL_COMPANIES; $c++) {
    for ($e = 1; $e -le $EMPLOYEES; $e++) {
        $wtt  = $WORK_TIME_TYPES[[math]::Floor(($e-1)/25) % 4]
        $seed = ($e-1) % 10
        for ($d = 1; $d -le $WORK_DAYS; $d++) {
            $allFacts.Add((New-Fact -companyId $c -employeeId $e `
                -dayIndex $d -workTimeType $wtt -seed $seed))
        }
    }
}
$buildMs = [math]::Round(((Get-Date) - $buildStart).TotalMilliseconds)
Write-Host ("  ✅ {0:N0} 筆，{1:N0} ms" -f $allFacts.Count, $buildMs) -ForegroundColor Green

# ── STEP 2：★ 使用 System.Text.Json 序列化（確保 boolean 正確）
Write-Host "`n【STEP 2】序列化 JSON（System.Text.Json）..." -ForegroundColor White
$serStart = Get-Date
$jsonBody = ConvertTo-SafeJson -FactList $allFacts

# ★ 驗證點 1：seed=3 的 boolean 是否正確（company=1, employee=4, day=1）
# ★ 驗證點 2：companyId 是否正確送出
$verifyParsed = $jsonBody | ConvertFrom-Json
$seed3Index   = 60

if ($verifyParsed.Count -gt $seed3Index) {
    $s3 = $verifyParsed[$seed3Index]

    # 驗證 boolean
    $nhPaid = $s3.nationalHolidayOvertimePaid
    if ($nhPaid -eq $true) {
        Write-Host ("  ✅ 序列化驗證通過：index[$seed3Index].nationalHolidayOvertimePaid = true") -ForegroundColor Green
    } else {
        Write-Host ("  ❌ 序列化驗證失敗：index[$seed3Index].nationalHolidayOvertimePaid = $nhPaid") -ForegroundColor Red
        Write-Host ("  ⚠️  請確認 PowerShell 版本 >= 7.0 或 .NET >= 5.0") -ForegroundColor Yellow
    }

    # ★ 驗證 companyId（index 60 = company=1, employee=4, day=1）
    $cid = $s3.companyId
    if ($null -ne $cid -and $cid -ne "") {
        Write-Host ("  ✅ companyId 驗證通過：index[$seed3Index].companyId = `"$cid`"") -ForegroundColor Green
    } else {
        Write-Host ("  ❌ companyId 驗證失敗：index[$seed3Index].companyId = null/empty") -ForegroundColor Red
        Write-Host ("  ⚠️  公司客製化規則將無法觸發，請檢查 New-Fact 函式") -ForegroundColor Yellow
    }
}

$jsonKB = [math]::Round([System.Text.Encoding]::UTF8.GetByteCount($jsonBody) / 1KB, 1)
$serMs  = [math]::Round(((Get-Date) - $serStart).TotalMilliseconds)
Write-Host ("  ✅ {0:N0} KB，{1:N0} ms" -f $jsonKB, $serMs) -ForegroundColor Green

# ── STEP 3：DRL ────────────────────────────────────────────────
Write-Host "`n【STEP 3】DRL 規則引擎" -ForegroundColor White
$drlResult = Invoke-SchedulingApi -Url $API_DRL -JsonBody $jsonBody `
    -Label "DRL 規則引擎" -Count $allFacts.Count

# ── STEP 4：Legacy ─────────────────────────────────────────────
Write-Host "`n【STEP 4】Legacy Switch-Case" -ForegroundColor White
$legacyResult = Invoke-SchedulingApi -Url $API_LEGACY -JsonBody $jsonBody `
    -Label "Legacy Switch-Case" -Count $allFacts.Count

# ── STEP 5：統計 ───────────────────────────────────────────────
Write-Host "`n【STEP 5】結果統計" -ForegroundColor White
$drlStats    = Get-ResultStats $drlResult.Data    "DRL 規則引擎"
$legacyStats = Get-ResultStats $legacyResult.Data "Legacy Switch-Case"

# ── STEP 6：比對（SourceFacts 用 $allFacts，保留 _meta_*）──────
Write-Host "`n【STEP 6】差異比對" -ForegroundColor White
$cmp = Compare-Results `
    -DrlData     $drlResult.Data `
    -LegacyData  $legacyResult.Data `
    -SourceFacts $allFacts

# ── STEP 7：對照總表 ───────────────────────────────────────────
$totalMs = [math]::Round(((Get-Date) - $globalStart).TotalMilliseconds)
$dE = $drlResult.Energy
$lE = $legacyResult.Energy

Write-Host ""
Write-Host ("╔══════════════════════════════════════════════════════╗") -ForegroundColor Cyan
Write-Host ("║              📊 效能 & 耗能對照總表                  ║") -ForegroundColor Cyan
Write-Host ("╚══════════════════════════════════════════════════════╝") -ForegroundColor Cyan
Write-Host ("{0,-20} {1,18} {2,18}  {3}" -f "項目","DRL 規則引擎","Legacy Switch","備註") -ForegroundColor White
Write-Host ("{0,-20} {1,18} {2,18}" -f ("─"*20),("─"*18),("─"*18)) -ForegroundColor DarkGray

@(
    ,@("測試筆數",        ("{0:N0} 筆"    -f $allFacts.Count),        ("{0:N0} 筆"    -f $allFacts.Count),        "")
    ,@("JSON 大小",       ("{0:N0} KB"    -f $jsonKB),                 ("{0:N0} KB"    -f $jsonKB),                 "共用")
    ,@("客戶端耗時",      ("{0:N0} ms"    -f $drlResult.ClientMs),     ("{0:N0} ms"    -f $legacyResult.ClientMs),  "")
    ,@("伺服器耗時",      ("{0:N0} ms"    -f $drlResult.ServerMs),     ("{0:N0} ms"    -f $legacyResult.ServerMs),  "X-Header/fallback")
    ,@("網路傳輸",        ("{0:N0} ms"    -f $drlResult.NetworkMs),    ("{0:N0} ms"    -f $legacyResult.NetworkMs), "")
    ,@("每筆平均",        ("{0:N6} ms"    -f $drlResult.PerItemMs),    ("{0:N6} ms"    -f $legacyResult.PerItemMs), "伺服器端")
    ,@("GB-秒用量",       ("{0:N4} GB·s"  -f $dE.GBSec),               ("{0:N4} GB·s"  -f $lE.GBSec),               "1.5GB×秒")
    ,@("估算費用",        ("{0:N8} USD"   -f $dE.CostUSD),             ("{0:N8} USD"   -f $lE.CostUSD),             "Azure")
    ,@("估算耗電",        ("{0:N6} Wh"    -f $dE.EnergyWh),            ("{0:N6} Wh"    -f $lE.EnergyWh),            "PUE 1.2")
    ,@("碳排放量",        ("{0:N6} g CO₂" -f $dE.CO2Gram),             ("{0:N6} g CO₂" -f $lE.CO2Gram),             "475g/kWh")
    ,@("違規率",          ("{0}%"         -f $drlStats.Rate),           ("{0}%"         -f $legacyStats.Rate),        "")
    ,@("客製規則違規次數", ("{0:N0} 次"   -f ($drlStats.CompanyRuleCount.Values | Measure-Object -Sum).Sum),
                          ("{0:N0} 次"   -f ($legacyStats.CompanyRuleCount.Values | Measure-Object -Sum).Sum),      "Company1~10")
    ,@("結果一致率",      ("{0}%"         -f $cmp.MatchRate),           ("{0}%"         -f $cmp.MatchRate),           "兩版本比對")
    ,@("差異筆數",        ("{0:N0}"       -f $cmp.DiffCount),           ("{0:N0}"       -f $cmp.DiffCount),           "")
) | ForEach-Object {
    Write-Host ("{0,-20} {1,18} {2,18}  {3}" -f $_[0],$_[1],$_[2],$_[3]) -ForegroundColor White
}

# ── STEP 8：儲存報告 ───────────────────────────────────────────
Write-Host "`n【STEP 8】儲存報告" -ForegroundColor White
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

if ($drlResult.Success) {
    $p = ".\result_drl_${timestamp}.json"
    $drlResult.Data | ConvertTo-Json -Depth 10 -Compress | Out-File $p -Encoding UTF8
    Write-Host ("  ✅ DRL    → $p") -ForegroundColor Green
}
if ($legacyResult.Success) {
    $p = ".\result_legacy_${timestamp}.json"
    $legacyResult.Data | ConvertTo-Json -Depth 10 -Compress | Out-File $p -Encoding UTF8
    Write-Host ("  ✅ Legacy → $p") -ForegroundColor Green
}
if ($cmp.DiffCount -gt 0) {
    $p = ".\result_diff_${timestamp}.json"
    $cmp.DiffSamples | ConvertTo-Json -Depth 10 | Out-File $p -Encoding UTF8
    Write-Host ("  ⚠️  差異（{0} 筆）→ $p" -f $cmp.DiffCount) -ForegroundColor Yellow
} else {
    Write-Host ("  🎉 無差異，不產生 diff 檔") -ForegroundColor Green
}

$drlCompanyTotal    = ($drlStats.CompanyRuleCount.Values    | Measure-Object -Sum).Sum
$legacyCompanyTotal = ($legacyStats.CompanyRuleCount.Values | Measure-Object -Sum).Sum

$summaryPath = ".\result_summary_${timestamp}.txt"
@"
排班合規 單批測試摘要
執行時間：$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
測試筆數：$($allFacts.Count)
公司數量：$TOTAL_COMPANIES（companyId 1～$TOTAL_COMPANIES）

=== DRL 規則引擎 ===
伺服器耗時        : $($drlResult.ServerMs) ms
每筆平均          : $($drlResult.PerItemMs) ms
違規率            : $($drlStats.Rate)%
客製化規則違規次數 : $drlCompanyTotal 次
估算費用          : $($dE.CostUSD) USD
估算耗電          : $($dE.EnergyWh) Wh
碳排放量          : $($dE.CO2Gram) g CO2

=== Legacy Switch-Case ===
伺服器耗時        : $($legacyResult.ServerMs) ms
每筆平均          : $($legacyResult.PerItemMs) ms
違規率            : $($legacyStats.Rate)%
客製化規則違規次數 : $legacyCompanyTotal 次
估算費用          : $($lE.CostUSD) USD
估算耗電          : $($lE.EnergyWh) Wh
碳排放量          : $($lE.CO2Gram) g CO2

=== 比對結果 ===
一致率      : $($cmp.MatchRate)%
差異筆數    : $($cmp.DiffCount)
DRL 多判    : $(($cmp.DiffSamples | Where-Object { $_.DRL_Violated -and -not $_.Legacy_Violated }).Count) 筆
Legacy 多判 : $(($cmp.DiffSamples | Where-Object { $_.Legacy_Violated -and -not $_.DRL_Violated }).Count) 筆

=== 全流程耗時 ===
建構資料    : $buildMs ms
序列化 JSON : $serMs ms
DRL API     : $($drlResult.ClientMs) ms
Legacy API  : $($legacyResult.ClientMs) ms
全程總計    : $totalMs ms
"@ | Out-File $summaryPath -Encoding UTF8
Write-Host ("  ✅ 摘要   → $summaryPath") -ForegroundColor Green

Write-Host ""
Write-Host ("╔══════════════════════════════════════════════════════╗") -ForegroundColor Cyan
Write-Host ("║  ✅ 完成  總耗時：$("{0:N0}" -f $totalMs) ms（$("{0:N1}" -f ($totalMs/1000)) 秒）") -ForegroundColor Cyan
Write-Host ("╚══════════════════════════════════════════════════════╝") -ForegroundColor Cyan
