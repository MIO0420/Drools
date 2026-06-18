# # # # # # # # # $BASE_URL        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # # # # # # $DROOLS_URL      = "$BASE_URL/calculatesalary"
# # # # # # # # # $LEGACY_URL      = "$BASE_URL/checksalary/legacy"
# # # # # # # # # $PER_COMPANY     = 50
# # # # # # # # # $COMPANIES       = @("40", "25", "100", "2")

# # # # # # # # # $INSURED_BRACKETS = @(
# # # # # # # # #     26400, 27600, 28800, 30300, 31800, 33300, 34800, 36300, 38200, 40100,
# # # # # # # # #     42000, 43900, 45800, 48200, 50600, 53000, 55400, 57800, 60800, 63800
# # # # # # # # # )
# # # # # # # # # $LEAVE_TYPES     = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # # # # # # $OT_TYPES        = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # # # # # # $PERF_GRADES     = @("SS+","SS","S","A+","A","B+","B")
# # # # # # # # # $ALLOWANCE_TYPES = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # # # # # # $ADJ_TYPES       = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # # # # # # # ── 記憶體輔助函式 ─────────────────────────────────────────────
# # # # # # # # # function Get-ManagedMemoryMB {
# # # # # # # # #     return [math]::Round([System.GC]::GetTotalMemory($true) / 1MB, 2)
# # # # # # # # # }

# # # # # # # # # function Format-MemDelta {
# # # # # # # # #     param([double]$current, [double]$baseline)
# # # # # # # # #     $delta = [math]::Round($current - $baseline, 2)
# # # # # # # # #     $sign  = if ($delta -ge 0) { "+" } else { "" }
# # # # # # # # #     return "$current MB（${sign}${delta} MB）"
# # # # # # # # # }

# # # # # # # # # function Get-InsuredSalary {
# # # # # # # # #     param([int]$baseSalary)
# # # # # # # # #     $bracket = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # # # # # # #     if ($null -eq $bracket) { $bracket = $INSURED_BRACKETS[-1] }
# # # # # # # # #     return $bracket
# # # # # # # # # }

# # # # # # # # # function Get-RandomLeaves {
# # # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # # # # # # #     foreach ($lt in $picked) {
# # # # # # # # #         $hours = Get-Random -Minimum 1 -Maximum 9
# # # # # # # # #         $null  = $result.Add([PSCustomObject]@{
# # # # # # # # #             leaveTypeName        = $lt
# # # # # # # # #             leaveDays            = [math]::Round($hours / 8, 3)
# # # # # # # # #             leaveHours           = $hours
# # # # # # # # #             deductionRate        = 1.0
# # # # # # # # #             affectFullAttendance = $true
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     return ,$result
# # # # # # # # # }

# # # # # # # # # function Get-RandomOvertimes {
# # # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # # # # # # #     foreach ($ot in $picked) {
# # # # # # # # #         $null = $result.Add([PSCustomObject]@{
# # # # # # # # #             overtimeType  = $ot
# # # # # # # # #             overtimeHours = Get-Random -Minimum 1 -Maximum 9
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     return ,$result
# # # # # # # # # }

# # # # # # # # # function Get-RandomPerformance {
# # # # # # # # #     param([string]$employeeId, [string]$companyId)
# # # # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # # # #     $grade     = $PERF_GRADES | Get-Random
# # # # # # # # #     $confirmed = (Get-Random -Minimum 0 -Maximum 10) -lt 8
# # # # # # # # #     return [PSCustomObject]@{
# # # # # # # # #         employeeId  = $employeeId
# # # # # # # # #         companyId   = $companyId
# # # # # # # # #         grade       = $grade
# # # # # # # # #         score       = [math]::Round((Get-Random -Minimum 60 -Maximum 100) + (Get-Random), 1)
# # # # # # # # #         year        = (Get-Date).Year
# # # # # # # # #         month       = (Get-Date).Month
# # # # # # # # #         confirmed   = $confirmed
# # # # # # # # #         evaluatorId = "SYS"
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # function Get-RandomAttendance {
# # # # # # # # #     param([string]$employeeId, [string]$companyId, [int]$workDays = 22)
# # # # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # # # #     $lateCount       = Get-Random -Minimum 0 -Maximum 5
# # # # # # # # #     $earlyLeaveCount = Get-Random -Minimum 0 -Maximum 4
# # # # # # # # #     $absentDays      = [math]::Round((Get-Random -Minimum 0 -Maximum 4) * 0.5, 1)
# # # # # # # # #     $actualWorkDays  = [math]::Max(0, $workDays - [int]$absentDays)
# # # # # # # # #     $hasFullAtt      = ($lateCount -eq 0 -and $earlyLeaveCount -eq 0 -and
# # # # # # # # #                         $absentDays -eq 0 -and $actualWorkDays -ge $workDays)
# # # # # # # # #     return [PSCustomObject]@{
# # # # # # # # #         employeeId             = $employeeId
# # # # # # # # #         companyId              = $companyId
# # # # # # # # #         year                   = (Get-Date).Year
# # # # # # # # #         month                  = (Get-Date).Month
# # # # # # # # #         lateCount              = $lateCount
# # # # # # # # #         earlyLeaveCount        = $earlyLeaveCount
# # # # # # # # #         absentDays             = $absentDays
# # # # # # # # #         workDays               = $actualWorkDays
# # # # # # # # #         requiredWorkDays       = $workDays
# # # # # # # # #         hasFullAttendance      = $hasFullAtt
# # # # # # # # #         lateMinutesTotal       = $lateCount       * (Get-Random -Minimum 5 -Maximum 30)
# # # # # # # # #         earlyLeaveMinutesTotal = $earlyLeaveCount * (Get-Random -Minimum 5 -Maximum 30)
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # function Get-RandomAllowances {
# # # # # # # # #     param([string]$employeeId, [string]$companyId)
# # # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # # # # # # #     foreach ($at in $picked) {
# # # # # # # # #         $approved = (Get-Random -Minimum 0 -Maximum 10) -lt 7
# # # # # # # # #         $null = $result.Add([PSCustomObject]@{
# # # # # # # # #             employeeId    = $employeeId
# # # # # # # # #             companyId     = $companyId
# # # # # # # # #             allowanceType = $at
# # # # # # # # #             amount        = Get-Random -Minimum 500 -Maximum 5000
# # # # # # # # #             approved      = $approved
# # # # # # # # #             approvedBy    = if ($approved) { "MGR001" } else { $null }
# # # # # # # # #             year          = (Get-Date).Year
# # # # # # # # #             month         = (Get-Date).Month
# # # # # # # # #             remark        = $null
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     return ,$result
# # # # # # # # # }

# # # # # # # # # function Get-RandomProjects {
# # # # # # # # #     param([string]$employeeId, [string]$companyId)
# # # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # # #     for ($i = 1; $i -le $count; $i++) {
# # # # # # # # #         $completed = (Get-Random -Minimum 0 -Maximum 10) -lt 6
# # # # # # # # #         $role      = @("LEAD","MEMBER") | Get-Random
# # # # # # # # #         $null = $result.Add([PSCustomObject]@{
# # # # # # # # #             employeeId  = $employeeId
# # # # # # # # #             companyId   = $companyId
# # # # # # # # #             projectId   = "PROJ-$companyId-$i"
# # # # # # # # #             projectName = "專案$i"
# # # # # # # # #             role        = $role
# # # # # # # # #             completed   = $completed
# # # # # # # # #             bonusRate   = [math]::Round((Get-Random -Minimum 1 -Maximum 10) * 0.01, 2)
# # # # # # # # #             year        = (Get-Date).Year
# # # # # # # # #             month       = (Get-Date).Month
# # # # # # # # #             department  = $null
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     return ,$result
# # # # # # # # # }

# # # # # # # # # function Get-RandomSalaryAdjustments {
# # # # # # # # #     param([string]$employeeId, [string]$companyId)
# # # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # # # # # # #     foreach ($at in $picked) {
# # # # # # # # #         $isPositive = $at -ne "DEDUCTION"
# # # # # # # # #         $amount     = if ($isPositive) {
# # # # # # # # #              Get-Random -Minimum 500  -Maximum 8000
# # # # # # # # #         } else {
# # # # # # # # #             -(Get-Random -Minimum 200 -Maximum 3000)
# # # # # # # # #         }
# # # # # # # # #         $null = $result.Add([PSCustomObject]@{
# # # # # # # # #             employeeId     = $employeeId
# # # # # # # # #             companyId      = $companyId
# # # # # # # # #             adjustmentType = $at
# # # # # # # # #             amount         = $amount
# # # # # # # # #             reason         = "系統測試"
# # # # # # # # #             approvedBy     = "SYS"
# # # # # # # # #             year           = (Get-Date).Year
# # # # # # # # #             month          = (Get-Date).Month
# # # # # # # # #             applied        = $false
# # # # # # # # #             remark         = $null
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     return ,$result
# # # # # # # # # }

# # # # # # # # # function Expand-JsonArray {
# # # # # # # # #     param($raw)
# # # # # # # # #     if ($raw -is [System.Object[]] -and $raw.Count -eq 1 -and $raw[0] -is [System.Object[]]) {
# # # # # # # # #         return $raw[0]
# # # # # # # # #     }
# # # # # # # # #     return $raw
# # # # # # # # # }

# # # # # # # # # function Get-FinalSalary {
# # # # # # # # #     param($obj, [switch]$IsDRL)
# # # # # # # # #     if ($IsDRL) {
# # # # # # # # #         $inner = $obj.PSObject.Properties['result']
# # # # # # # # #         if ($null -eq $inner -or $null -eq $inner.Value) { return $null }
# # # # # # # # #         $prop = $inner.Value.PSObject.Properties['finalSalary']
# # # # # # # # #     } else {
# # # # # # # # #         $prop = $obj.PSObject.Properties['finalSalary']
# # # # # # # # #     }
# # # # # # # # #     if ($null -eq $prop) { return $null }
# # # # # # # # #     try { return [double]("$($prop.Value)") } catch { return $null }
# # # # # # # # # }

# # # # # # # # # function Start-HttpPostAsync {
# # # # # # # # #     param([string]$Uri, [string]$Body)
# # # # # # # # #     $client  = [System.Net.Http.HttpClient]::new()
# # # # # # # # #     $content = [System.Net.Http.StringContent]::new(
# # # # # # # # #         $Body,
# # # # # # # # #         [System.Text.Encoding]::UTF8,
# # # # # # # # #         "application/json"
# # # # # # # # #     )
# # # # # # # # #     return $client, $client.PostAsync($Uri, $content)
# # # # # # # # # }

# # # # # # # # # # ══════════════════════════════════════════════════════════════
# # # # # # # # # #  記憶體基準
# # # # # # # # # # ══════════════════════════════════════════════════════════════
# # # # # # # # # $memBaseline = Get-ManagedMemoryMB
# # # # # # # # # Write-Host "`n📊 記憶體基準值：$memBaseline MB（GC 後）" -ForegroundColor DarkGray

# # # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # # #  [1/5] 冷啟動暖機
# # # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # # Write-Host "`n[1/5] 冷啟動暖機..." -ForegroundColor Cyan

# # # # # # # # # # $warmupJson = @{
# # # # # # # # # #     employeeId          = "WARMUP"
# # # # # # # # # #     companyId           = "40"
# # # # # # # # # #     baseSalary          = 30000
# # # # # # # # # #     tenureMonths        = 12
# # # # # # # # # #     seniorityMonths     = 12
# # # # # # # # # #     laborInsuredSalary  = 30300
# # # # # # # # # #     healthInsuredSalary = 30300
# # # # # # # # # #     pensionSalary       = 30300
# # # # # # # # # #     workingDaysInMonth  = 22
# # # # # # # # # #     leaves              = @()
# # # # # # # # # #     overtimes           = @()
# # # # # # # # # #     performances        = @()
# # # # # # # # # #     attendances         = @()
# # # # # # # # # #     allowances          = @()
# # # # # # # # # #     projects            = @()
# # # # # # # # # #     salaryAdjustments   = @()
# # # # # # # # # # } | ConvertTo-Json -Depth 5 -Compress

# # # # # # # # # # $coldDrools = Measure-Command {
# # # # # # # # # #     try {
# # # # # # # # # #         Invoke-RestMethod -Method POST -Uri $DROOLS_URL -ContentType "application/json" `
# # # # # # # # # #             -Body $warmupJson -ErrorAction Stop | Out-Null
# # # # # # # # # #     } catch {
# # # # # # # # # #         Write-Host "    Drools 暖機異常：$_" -ForegroundColor Yellow
# # # # # # # # # #     }
# # # # # # # # # # }
# # # # # # # # # # $droolsColdMs = [math]::Round($coldDrools.TotalMilliseconds, 2)
# # # # # # # # # # Write-Host "    Drools 冷啟動：$droolsColdMs ms" -ForegroundColor Yellow

# # # # # # # # # # $coldLegacy = Measure-Command {
# # # # # # # # # #     try {
# # # # # # # # # #         Invoke-RestMethod -Method POST -Uri $LEGACY_URL -ContentType "application/json" `
# # # # # # # # # #             -Body $warmupJson -ErrorAction Stop | Out-Null
# # # # # # # # # #     } catch {
# # # # # # # # # #         Write-Host "    Legacy 暖機異常：$_" -ForegroundColor Yellow
# # # # # # # # # #     }
# # # # # # # # # # }
# # # # # # # # # # $legacyColdMs = [math]::Round($coldLegacy.TotalMilliseconds, 2)
# # # # # # # # # # Write-Host "    Legacy 冷啟動：$legacyColdMs ms" -ForegroundColor Yellow

# # # # # # # # # # Write-Host "`n    等待 5 秒讓服務穩定..." -ForegroundColor DarkGray
# # # # # # # # # # Start-Sleep -Seconds 5
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # #  [1/5] 冷啟動暖機 (確保所有公司都被編譯進 Cache)
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # Write-Host "`n[1/5] 冷啟動暖機（逐一預熱所有測試公司）..." -ForegroundColor Cyan

# # # # # # # # # $baseWarmupObj = @{
# # # # # # # # #     employeeId          = "WARMUP"
# # # # # # # # #     baseSalary          = 30000
# # # # # # # # #     tenureMonths        = 12
# # # # # # # # #     seniorityMonths     = 12
# # # # # # # # #     laborInsuredSalary  = 30300
# # # # # # # # #     healthInsuredSalary = 30300
# # # # # # # # #     pensionSalary       = 30300
# # # # # # # # #     workingDaysInMonth  = 22
# # # # # # # # #     leaves              = @()
# # # # # # # # #     overtimes           = @()
# # # # # # # # #     performances        = @()
# # # # # # # # #     attendances         = @()
# # # # # # # # #     allowances          = @()
# # # # # # # # #     projects            = @()
# # # # # # # # #     salaryAdjustments   = @()
# # # # # # # # # }

# # # # # # # # # $droolsColdTotalMs = 0

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $baseWarmupObj.companyId = $cid
# # # # # # # # #     $warmupJson = $baseWarmupObj | ConvertTo-Json -Depth 5 -Compress

# # # # # # # # #     $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # # # # # # # #     try {
# # # # # # # # #         Invoke-RestMethod -Method POST -Uri $DROOLS_URL -ContentType "application/json" -Body $warmupJson -ErrorAction Stop | Out-Null
# # # # # # # # #     } catch {
# # # # # # # # #         Write-Host "    公司 $cid Drools 暖機異常：$_" -ForegroundColor Yellow
# # # # # # # # #     }
# # # # # # # # #     $sw.Stop()
# # # # # # # # #     Write-Host "    公司 $cid Drools 編譯/冷啟動：$($sw.ElapsedMilliseconds) ms" -ForegroundColor DarkGray
# # # # # # # # #     $droolsColdTotalMs += $sw.ElapsedMilliseconds
# # # # # # # # # }

# # # # # # # # # Write-Host "    Drools 總冷啟動耗時：$droolsColdTotalMs ms" -ForegroundColor Yellow

# # # # # # # # # # Legacy 不需要分公司編譯，打一次即可
# # # # # # # # # $baseWarmupObj.companyId = $COMPANIES[0]
# # # # # # # # # $warmupJsonLegacy = $baseWarmupObj | ConvertTo-Json -Depth 5 -Compress
# # # # # # # # # $coldLegacy = Measure-Command {
# # # # # # # # #     try {
# # # # # # # # #         Invoke-RestMethod -Method POST -Uri $LEGACY_URL -ContentType "application/json" -Body $warmupJsonLegacy -ErrorAction Stop | Out-Null
# # # # # # # # #     } catch {
# # # # # # # # #         Write-Host "    Legacy 暖機異常：$_" -ForegroundColor Yellow
# # # # # # # # #     }
# # # # # # # # # }
# # # # # # # # # $legacyColdMs = [math]::Round($coldLegacy.TotalMilliseconds, 2)
# # # # # # # # # Write-Host "    Legacy 冷啟動：$legacyColdMs ms" -ForegroundColor Yellow

# # # # # # # # # Write-Host "`n    等待 5 秒讓系統 GC 與穩定..." -ForegroundColor DarkGray
# # # # # # # # # Start-Sleep -Seconds 5

# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # #  [2/5] 產生各公司獨立批次資料
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # Write-Host "`n[2/5] 產生各公司獨立批次資料..." -ForegroundColor Cyan

# # # # # # # # # $companyBatches = @{}
# # # # # # # # # $companyJsons   = @{}

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     [System.Collections.ArrayList]$batch = @()
# # # # # # # # #     for ($i = 1; $i -le $PER_COMPANY; $i++) {
# # # # # # # # #         $empId     = "C$cid-E" + $i.ToString("D3")
# # # # # # # # #         $base      = Get-Random -Minimum 26400 -Maximum 120000
# # # # # # # # #         $tenure    = Get-Random -Minimum 0     -Maximum 180
# # # # # # # # #         $insured   = Get-InsuredSalary -baseSalary $base
# # # # # # # # #         $leaves    = Get-RandomLeaves
# # # # # # # # #         $overtimes = Get-RandomOvertimes
# # # # # # # # #         $perf      = Get-RandomPerformance       -employeeId $empId -companyId $cid
# # # # # # # # #         $att       = Get-RandomAttendance        -employeeId $empId -companyId $cid -workDays 22
# # # # # # # # #         $allows    = Get-RandomAllowances        -employeeId $empId -companyId $cid
# # # # # # # # #         $projs     = Get-RandomProjects          -employeeId $empId -companyId $cid
# # # # # # # # #         $adjs      = Get-RandomSalaryAdjustments -employeeId $empId -companyId $cid

# # # # # # # # #         # ── 關鍵修正：用 ArrayList 確保單元素也序列化為陣列 ──
# # # # # # # # #         [System.Collections.ArrayList]$perfArr = @()
# # # # # # # # #         if ($null -ne $perf) { $null = $perfArr.Add($perf) }

# # # # # # # # #         [System.Collections.ArrayList]$attArr = @()
# # # # # # # # #         if ($null -ne $att) { $null = $attArr.Add($att) }

# # # # # # # # #         $null = $batch.Add([PSCustomObject]@{
# # # # # # # # #             employeeId          = $empId
# # # # # # # # #             companyId           = $cid
# # # # # # # # #             baseSalary          = $base
# # # # # # # # #             tenureMonths        = $tenure
# # # # # # # # #             seniorityMonths     = $tenure
# # # # # # # # #             laborInsuredSalary  = $insured
# # # # # # # # #             healthInsuredSalary = $insured
# # # # # # # # #             pensionSalary       = $insured
# # # # # # # # #             workingDaysInMonth  = 22
# # # # # # # # #             leaves              = $leaves
# # # # # # # # #             overtimes           = $overtimes
# # # # # # # # #             performances        = $perfArr
# # # # # # # # #             attendances         = $attArr
# # # # # # # # #             allowances          = $allows
# # # # # # # # #             projects            = $projs
# # # # # # # # #             salaryAdjustments   = $adjs
# # # # # # # # #         })
# # # # # # # # #     }
# # # # # # # # #     $companyBatches[$cid] = $batch
# # # # # # # # #     $companyJsons[$cid]   = ConvertTo-Json -InputObject ([array]$batch) -Depth 10 -Compress
# # # # # # # # #     $kb = [math]::Round($companyJsons[$cid].Length / 1024, 1)
# # # # # # # # #     Write-Host "    公司 $cid：$PER_COMPANY 筆，JSON $kb KB" -ForegroundColor Green
# # # # # # # # # }

# # # # # # # # # $memAfterDataGen = Get-ManagedMemoryMB
# # # # # # # # # Write-Host "    📊 資料產生後記憶體：$(Format-MemDelta $memAfterDataGen $memBaseline)" -ForegroundColor DarkGray

# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # #  [3/5] 送出測試
# # # # # # # # # #  DRL  → 批次並行（4 家公司同時送）
# # # # # # # # # #  Legacy → 逐筆串行（不支援批次）
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # Write-Host "`n[3/5] 送出測試..." -ForegroundColor Cyan

# # # # # # # # # # ── DRL 平行批次 ───────────────────────────────────────────────
# # # # # # # # # Write-Host "`n  [DRL] 同時送出 $($COMPANIES.Count) 家公司（各 $PER_COMPANY 筆，批次並行）..." -ForegroundColor Cyan

# # # # # # # # # $droolsClients     = @{}
# # # # # # # # # $droolsTasks       = @{}
# # # # # # # # # $droolsStopwatches = @{}
# # # # # # # # # $droolsWallMs      = @{}
# # # # # # # # # $droolsResponses   = @{}

# # # # # # # # # $droolsWallStart = [System.Diagnostics.Stopwatch]::StartNew()

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $droolsStopwatches[$cid] = [System.Diagnostics.Stopwatch]::StartNew()
# # # # # # # # #     $client, $task = Start-HttpPostAsync -Uri $DROOLS_URL -Body $companyJsons[$cid]
# # # # # # # # #     $droolsClients[$cid] = $client
# # # # # # # # #     $droolsTasks[$cid]   = $task
# # # # # # # # # }

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     try {
# # # # # # # # #         $resp = $droolsTasks[$cid].GetAwaiter().GetResult()
# # # # # # # # #         $droolsStopwatches[$cid].Stop()
# # # # # # # # #         $droolsWallMs[$cid]    = [math]::Round($droolsStopwatches[$cid].ElapsedMilliseconds, 2)
# # # # # # # # #         $rawBytes              = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
# # # # # # # # #         $droolsResponses[$cid] = [System.Text.Encoding]::UTF8.GetString($rawBytes)
# # # # # # # # #     } catch {
# # # # # # # # #         $droolsStopwatches[$cid].Stop()
# # # # # # # # #         $droolsWallMs[$cid]    = -1
# # # # # # # # #         $droolsResponses[$cid] = $null
# # # # # # # # #         Write-Host "    公司 $cid DRL 請求失敗：$_" -ForegroundColor Red
# # # # # # # # #     } finally {
# # # # # # # # #         $droolsClients[$cid].Dispose()
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # $droolsWallStart.Stop()
# # # # # # # # # $droolsTotalWallMs = [math]::Round($droolsWallStart.ElapsedMilliseconds, 2)
# # # # # # # # # $memAfterDroolsRaw = Get-ManagedMemoryMB

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $ms  = $droolsWallMs[$cid]
# # # # # # # # #     $avg = if ($ms -gt 0) { [math]::Round($ms / $PER_COMPANY, 4) } else { "N/A" }
# # # # # # # # #     Write-Host "    公司 $cid DRL 回應耗時：$ms ms（平均 $avg ms/筆）" -ForegroundColor Green
# # # # # # # # # }
# # # # # # # # # Write-Host "    DRL 牆鐘總耗時（並行）：$droolsTotalWallMs ms" -ForegroundColor Yellow
# # # # # # # # # Write-Host "    📊 DRL 回應接收後記憶體：$(Format-MemDelta $memAfterDroolsRaw $memBaseline)" -ForegroundColor DarkGray

# # # # # # # # # Write-Host "    等待 3 秒..." -ForegroundColor DarkGray
# # # # # # # # # Start-Sleep -Seconds 3

# # # # # # # # # # ── Legacy 逐筆串行（不支援批次）─────────────────────────────
# # # # # # # # # Write-Host "`n  [Legacy] 逐筆送出 $($COMPANIES.Count) 家公司（各 $PER_COMPANY 筆，串行）..." -ForegroundColor Cyan

# # # # # # # # # $legacyWallMs    = @{}
# # # # # # # # # $legacyResponses = @{}
# # # # # # # # # $legacyParsed    = @{}

# # # # # # # # # $legacyWallStart = [System.Diagnostics.Stopwatch]::StartNew()

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # # # # # # # #     [System.Collections.ArrayList]$allParsed = @()
# # # # # # # # #     $errCount = 0

# # # # # # # # #     foreach ($emp in $companyBatches[$cid]) {
# # # # # # # # #         # 用 -InputObject 避免管線 unwrap 單元素陣列
# # # # # # # # #         $singleJson = ConvertTo-Json -InputObject $emp -Depth 10 -Compress
# # # # # # # # #         $client     = [System.Net.Http.HttpClient]::new()
# # # # # # # # #         try {
# # # # # # # # #             $content  = [System.Net.Http.StringContent]::new(
# # # # # # # # #                 $singleJson,
# # # # # # # # #                 [System.Text.Encoding]::UTF8,
# # # # # # # # #                 "application/json"
# # # # # # # # #             )
# # # # # # # # #             $resp     = $client.PostAsync($LEGACY_URL, $content).GetAwaiter().GetResult()
# # # # # # # # #             $rawBytes = $resp.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
# # # # # # # # #             $body     = [System.Text.Encoding]::UTF8.GetString($rawBytes)
# # # # # # # # #             $parsed   = $body | ConvertFrom-Json -Depth 20
# # # # # # # # #             $null     = $allParsed.Add($parsed)
# # # # # # # # #         } catch {
# # # # # # # # #             Write-Host "    公司 $cid 員工 $($emp.employeeId) Legacy 失敗：$_" -ForegroundColor Red
# # # # # # # # #             $errCount++
# # # # # # # # #         } finally {
# # # # # # # # #             $client.Dispose()
# # # # # # # # #         }
# # # # # # # # #     }

# # # # # # # # #     $sw.Stop()
# # # # # # # # #     $legacyWallMs[$cid]    = [math]::Round($sw.ElapsedMilliseconds, 2)
# # # # # # # # #     $legacyParsed[$cid]    = if ($allParsed.Count -gt 0) { $allParsed.ToArray() } else { $null }
# # # # # # # # #     $legacyResponses[$cid] = if ($errCount -eq 0) { "ok" } else { $null }

# # # # # # # # #     $ms  = $legacyWallMs[$cid]
# # # # # # # # #     $avg = if ($ms -gt 0) { [math]::Round($ms / $PER_COMPANY, 4) } else { "N/A" }
# # # # # # # # #     Write-Host "    公司 $cid Legacy 回應耗時：$ms ms（平均 $avg ms/筆）" -ForegroundColor Green
# # # # # # # # # }

# # # # # # # # # $legacyWallStart.Stop()
# # # # # # # # # $legacyTotalWallMs = [math]::Round($legacyWallStart.ElapsedMilliseconds, 2)
# # # # # # # # # $memAfterLegacyRaw = Get-ManagedMemoryMB

# # # # # # # # # Write-Host "    Legacy 牆鐘總耗時（逐筆串行）：$legacyTotalWallMs ms" -ForegroundColor Yellow
# # # # # # # # # Write-Host "    📊 Legacy 回應接收後記憶體：$(Format-MemDelta $memAfterLegacyRaw $memBaseline)" -ForegroundColor DarkGray

# # # # # # # # # # ── 解析回應（DRL 需解析；Legacy 已直接存入 $legacyParsed）──
# # # # # # # # # $droolsParsed = @{}

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     if ($droolsResponses[$cid]) {
# # # # # # # # #         try {
# # # # # # # # #             $droolsParsed[$cid] = Expand-JsonArray ($droolsResponses[$cid] | ConvertFrom-Json -Depth 20)
# # # # # # # # #         } catch {
# # # # # # # # #             Write-Host "    公司 $cid DRL JSON 解析失敗：$_" -ForegroundColor Red
# # # # # # # # #         }
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # $memAfterParsed = Get-ManagedMemoryMB
# # # # # # # # # Write-Host "    📊 JSON 解析後記憶體：$(Format-MemDelta $memAfterParsed $memBaseline)" -ForegroundColor DarkGray

# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # #  [4/5] 終端摘要
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
# # # # # # # # # $fileTs    = Get-Date -Format 'yyyyMMdd_HHmmss'

# # # # # # # # # $wallRatio = if ($droolsTotalWallMs -gt 0 -and $legacyTotalWallMs -gt 0) {
# # # # # # # # #     [math]::Round($legacyTotalWallMs / $droolsTotalWallMs, 2)
# # # # # # # # # } else { "N/A" }

# # # # # # # # # $memDataGenDelta = [math]::Round($memAfterDataGen   - $memBaseline, 2)
# # # # # # # # # $memDroolsDelta  = [math]::Round($memAfterDroolsRaw - $memBaseline, 2)
# # # # # # # # # $memLegacyDelta  = [math]::Round($memAfterLegacyRaw - $memBaseline, 2)
# # # # # # # # # $memParsedDelta  = [math]::Round($memAfterParsed    - $memBaseline, 2)
# # # # # # # # # $memPeak         = [math]::Round(
# # # # # # # # #     (@($memAfterDataGen,$memAfterDroolsRaw,$memAfterLegacyRaw,$memAfterParsed) |
# # # # # # # # #         Measure-Object -Maximum).Maximum, 2)
# # # # # # # # # $memPeakDelta    = [math]::Round($memPeak - $memBaseline, 2)

# # # # # # # # # Write-Host "`n╔══════════════════════════════════════════════════════╗" -ForegroundColor Cyan
# # # # # # # # # Write-Host "║   批次效能測試總結  $timestamp   ║" -ForegroundColor Cyan
# # # # # # # # # Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # # # # # # Write-Host "║  冷啟動  Drools：$droolsColdMs ms   Legacy：$legacyColdMs ms" -ForegroundColor Cyan
# # # # # # # # # Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $dMs  = $droolsWallMs[$cid]
# # # # # # # # #     $lMs  = $legacyWallMs[$cid]
# # # # # # # # #     $r    = if ($dMs -gt 0 -and $lMs -gt 0) { [math]::Round($lMs / $dMs, 2) } else { "N/A" }
# # # # # # # # #     $dAvg = if ($dMs -gt 0) { [math]::Round($dMs / $PER_COMPANY, 4) } else { "N/A" }
# # # # # # # # #     $lAvg = if ($lMs -gt 0) { [math]::Round($lMs / $PER_COMPANY, 4) } else { "N/A" }
# # # # # # # # #     Write-Host "║  公司 $cid" -ForegroundColor Yellow
# # # # # # # # #     Write-Host "║    DRL（批次並行）回應：$dMs ms   平均：$dAvg ms/筆"
# # # # # # # # #     Write-Host "║    Legacy（逐筆串行）  ：$lMs ms   平均：$lAvg ms/筆"
# # # # # # # # #     Write-Host "║    速度比(L/D)：$r 倍"
# # # # # # # # # }

# # # # # # # # # Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # # # # # # Write-Host "║  牆鐘總耗時  DRL（並行）：$droolsTotalWallMs ms   Legacy（串行）：$legacyTotalWallMs ms" -ForegroundColor Yellow
# # # # # # # # # Write-Host "║  牆鐘速度比(L/D)：$wallRatio 倍" -ForegroundColor Yellow
# # # # # # # # # Write-Host "╠══════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # # # # # # Write-Host "║  📊 記憶體消耗（Managed Heap，GC 後）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    基準值           ：$memBaseline MB" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    資料產生後       ：$memAfterDataGen MB（+$memDataGenDelta MB）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    DRL 回應接收後   ：$memAfterDroolsRaw MB（+$memDroolsDelta MB）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    Legacy 回應接收後：$memAfterLegacyRaw MB（+$memLegacyDelta MB）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    JSON 解析後      ：$memAfterParsed MB（+$memParsedDelta MB）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "║    峰值             ：$memPeak MB（+$memPeakDelta MB vs 基準）" -ForegroundColor Magenta
# # # # # # # # # Write-Host "╚══════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # #  [5/5] 產生 CSV
# # # # # # # # # # ═══════════════════════════════════════════════════════════════
# # # # # # # # # Write-Host "`n[5/5] 產生 CSV..." -ForegroundColor Cyan

# # # # # # # # # [System.Collections.ArrayList]$csvRows = @()

# # # # # # # # # # ── 效能摘要區塊 ────────────────────────────────────────────────
# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $dMs = $droolsWallMs[$cid]
# # # # # # # # #     $lMs = $legacyWallMs[$cid]
# # # # # # # # #     $r   = if ($dMs -gt 0 -and $lMs -gt 0) { [math]::Round($lMs / $dMs, 2) } else { "N/A" }

# # # # # # # # #     foreach ($row in @(
# # # # # # # # #         @{ 引擎="Drools規則引擎(批次並行)"; Cold=$droolsColdMs; Total=$dMs
# # # # # # # # #            WithCold=if($dMs -gt 0){[math]::Round($dMs+$droolsColdMs,2)}else{"N/A"}
# # # # # # # # #            Avg=if($dMs -gt 0){[math]::Round($dMs/$PER_COMPANY,4)}else{"N/A"}
# # # # # # # # #            Ratio=$r },
# # # # # # # # #         @{ 引擎="Legacy硬編碼(逐筆串行)";   Cold=$legacyColdMs; Total=$lMs
# # # # # # # # #            WithCold=if($lMs -gt 0){[math]::Round($lMs+$legacyColdMs,2)}else{"N/A"}
# # # # # # # # #            Avg=if($lMs -gt 0){[math]::Round($lMs/$PER_COMPANY,4)}else{"N/A"}
# # # # # # # # #            Ratio=$r }
# # # # # # # # #     )) {
# # # # # # # # #         $parsed = if ($row.引擎 -like "Drools*") { $droolsParsed[$cid] } else { $legacyParsed[$cid] }
# # # # # # # # #         $ok  = if ($parsed) { ($parsed | Where-Object { $null -eq $_.error -or $_.error -eq "" }).Count } else { 0 }
# # # # # # # # #         $err = if ($parsed) { ($parsed | Where-Object { $null -ne $_.error -and $_.error -ne "" }).Count } else { 0 }

# # # # # # # # #         $csvRows.Add([PSCustomObject]@{
# # # # # # # # #             Section                  = "效能摘要"
# # # # # # # # #             員工ID                   = ""
# # # # # # # # #             公司ID                   = $cid
# # # # # # # # #             底薪                     = ""
# # # # # # # # #             年資月數                 = ""
# # # # # # # # #             假別筆數                 = ""
# # # # # # # # #             加班筆數                 = ""
# # # # # # # # #             績效筆數                 = ""
# # # # # # # # #             出勤筆數                 = ""
# # # # # # # # #             津貼筆數                 = ""
# # # # # # # # #             專案筆數                 = ""
# # # # # # # # #             薪資調整筆數             = ""
# # # # # # # # #             引擎類型                 = $row.引擎
# # # # # # # # #             冷啟動耗時_ms            = $row.Cold
# # # # # # # # #             批次總耗時_ms            = $row.Total
# # # # # # # # #             含冷啟動總耗時_ms        = $row.WithCold
# # # # # # # # #             平均每筆耗時_ms          = $row.Avg
# # # # # # # # #             成功筆數                 = $ok
# # # # # # # # #             失敗筆數                 = $err
# # # # # # # # #             速度比_Legacy除DRL       = $row.Ratio
# # # # # # # # #             DRL_finalSalary          = ""
# # # # # # # # #             Legacy_finalSalary       = ""
# # # # # # # # #             結果是否一致             = ""
# # # # # # # # #             記憶體基準_MB            = $memBaseline
# # # # # # # # #             記憶體_資料產生後_MB     = $memAfterDataGen
# # # # # # # # #             記憶體_DRL回應後_MB      = $memAfterDroolsRaw
# # # # # # # # #             記憶體_Legacy回應後_MB   = $memAfterLegacyRaw
# # # # # # # # #             記憶體_JSON解析後_MB     = $memAfterParsed
# # # # # # # # #             記憶體峰值_MB            = $memPeak
# # # # # # # # #             記憶體增量_峰值vs基準_MB = $memPeakDelta
# # # # # # # # #         }) | Out-Null
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # # ── 牆鐘摘要行 ─────────────────────────────────────────────────
# # # # # # # # # $csvRows.Add([PSCustomObject]@{
# # # # # # # # #     Section                  = "牆鐘總耗時"
# # # # # # # # #     員工ID                   = ""
# # # # # # # # #     公司ID                   = ($COMPANIES -join "+")
# # # # # # # # #     底薪                     = ""
# # # # # # # # #     年資月數                 = ""
# # # # # # # # #     假別筆數                 = ""
# # # # # # # # #     加班筆數                 = ""
# # # # # # # # #     績效筆數                 = ""
# # # # # # # # #     出勤筆數                 = ""
# # # # # # # # #     津貼筆數                 = ""
# # # # # # # # #     專案筆數                 = ""
# # # # # # # # #     薪資調整筆數             = ""
# # # # # # # # #     引擎類型                 = "DRL(並行) vs Legacy(串行)"
# # # # # # # # #     冷啟動耗時_ms            = ""
# # # # # # # # #     批次總耗時_ms            = ""
# # # # # # # # #     含冷啟動總耗時_ms        = ""
# # # # # # # # #     平均每筆耗時_ms          = ""
# # # # # # # # #     成功筆數                 = ""
# # # # # # # # #     失敗筆數                 = ""
# # # # # # # # #     速度比_Legacy除DRL       = $wallRatio
# # # # # # # # #     DRL_finalSalary          = "DRL並行牆鐘=$droolsTotalWallMs ms"
# # # # # # # # #     Legacy_finalSalary       = "Legacy串行牆鐘=$legacyTotalWallMs ms"
# # # # # # # # #     結果是否一致             = ""
# # # # # # # # #     記憶體基準_MB            = $memBaseline
# # # # # # # # #     記憶體_資料產生後_MB     = $memAfterDataGen
# # # # # # # # #     記憶體_DRL回應後_MB      = $memAfterDroolsRaw
# # # # # # # # #     記憶體_Legacy回應後_MB   = $memAfterLegacyRaw
# # # # # # # # #     記憶體_JSON解析後_MB     = $memAfterParsed
# # # # # # # # #     記憶體峰值_MB            = $memPeak
# # # # # # # # #     記憶體增量_峰值vs基準_MB = $memPeakDelta
# # # # # # # # # }) | Out-Null

# # # # # # # # # # ── 空白分隔 ────────────────────────────────────────────────────
# # # # # # # # # $blankRow = [PSCustomObject]@{
# # # # # # # # #     Section="---"; 員工ID=""; 公司ID=""; 底薪=""; 年資月數=""; 假別筆數=""; 加班筆數=""
# # # # # # # # #     績效筆數=""; 出勤筆數=""; 津貼筆數=""; 專案筆數=""; 薪資調整筆數=""
# # # # # # # # #     引擎類型=""; 冷啟動耗時_ms=""; 批次總耗時_ms=""; 含冷啟動總耗時_ms=""; 平均每筆耗時_ms=""
# # # # # # # # #     成功筆數=""; 失敗筆數=""; 速度比_Legacy除DRL=""; DRL_finalSalary=""; Legacy_finalSalary=""
# # # # # # # # #     結果是否一致=""; 記憶體基準_MB=""; 記憶體_資料產生後_MB=""; 記憶體_DRL回應後_MB=""
# # # # # # # # #     記憶體_Legacy回應後_MB=""; 記憶體_JSON解析後_MB=""; 記憶體峰值_MB=""; 記憶體增量_峰值vs基準_MB=""
# # # # # # # # # }
# # # # # # # # # $csvRows.Add($blankRow) | Out-Null

# # # # # # # # # # ── 逐筆明細 ────────────────────────────────────────────────────
# # # # # # # # # $totalMatch    = 0
# # # # # # # # # $totalMismatch = 0
# # # # # # # # # $totalError    = 0

# # # # # # # # # foreach ($cid in $COMPANIES) {
# # # # # # # # #     $matchCount    = 0
# # # # # # # # #     $mismatchCount = 0
# # # # # # # # #     $errorCount    = 0

# # # # # # # # #     $legacyMap = @{}
# # # # # # # # #     if ($legacyParsed[$cid]) {
# # # # # # # # #         foreach ($lr in $legacyParsed[$cid]) {
# # # # # # # # #             if ($lr.employeeId) { $legacyMap[$lr.employeeId] = $lr }
# # # # # # # # #         }
# # # # # # # # #     }

# # # # # # # # #     $inputMap = @{}
# # # # # # # # #     foreach ($emp in $companyBatches[$cid]) { $inputMap[$emp.employeeId] = $emp }

# # # # # # # # #     if ($droolsParsed[$cid]) {
# # # # # # # # #         foreach ($dr in $droolsParsed[$cid]) {
# # # # # # # # #             $empId   = $dr.employeeId
# # # # # # # # #             $lg      = $legacyMap[$empId]
# # # # # # # # #             $input   = $inputMap[$empId]
# # # # # # # # #             $drFinal = Get-FinalSalary $dr -IsDRL
# # # # # # # # #             $lgFinal = if ($lg) { Get-FinalSalary $lg } else { $null }

# # # # # # # # #             $match = if ($null -ne $drFinal -and $null -ne $lgFinal) {
# # # # # # # # #                 if ([math]::Round($drFinal, 2) -eq [math]::Round($lgFinal, 2)) {
# # # # # # # # #                     $matchCount++; $totalMatch++; "一致"
# # # # # # # # #                 } else {
# # # # # # # # #                     $mismatchCount++; $totalMismatch++; "不同"
# # # # # # # # #                 }
# # # # # # # # #             } else {
# # # # # # # # #                 $errorCount++; $totalError++; "無法比對"
# # # # # # # # #             }

# # # # # # # # #             $perfCnt = if ($input -and $input.performances)     { $input.performances.Count }     else { 0 }
# # # # # # # # #             $attCnt  = if ($input -and $input.attendances)       { $input.attendances.Count }       else { 0 }
# # # # # # # # #             $allCnt  = if ($input -and $input.allowances)        { $input.allowances.Count }        else { 0 }
# # # # # # # # #             $projCnt = if ($input -and $input.projects)          { $input.projects.Count }          else { 0 }
# # # # # # # # #             $adjCnt  = if ($input -and $input.salaryAdjustments) { $input.salaryAdjustments.Count } else { 0 }

# # # # # # # # #             $csvRows.Add([PSCustomObject]@{
# # # # # # # # #                 Section                  = "逐筆明細"
# # # # # # # # #                 員工ID                   = $empId
# # # # # # # # #                 公司ID                   = $cid
# # # # # # # # #                 底薪                     = if ($input) { $input.baseSalary }      else { "" }
# # # # # # # # #                 年資月數                 = if ($input) { $input.tenureMonths }    else { "" }
# # # # # # # # #                 假別筆數                 = if ($input) { $input.leaves.Count }    else { "" }
# # # # # # # # #                 加班筆數                 = if ($input) { $input.overtimes.Count } else { "" }
# # # # # # # # #                 績效筆數                 = $perfCnt
# # # # # # # # #                 出勤筆數                 = $attCnt
# # # # # # # # #                 津貼筆數                 = $allCnt
# # # # # # # # #                 專案筆數                 = $projCnt
# # # # # # # # #                 薪資調整筆數             = $adjCnt
# # # # # # # # #                 引擎類型                 = "DRL vs Legacy"
# # # # # # # # #                 冷啟動耗時_ms            = ""
# # # # # # # # #                 批次總耗時_ms            = ""
# # # # # # # # #                 含冷啟動總耗時_ms        = ""
# # # # # # # # #                 平均每筆耗時_ms          = ""
# # # # # # # # #                 成功筆數                 = ""
# # # # # # # # #                 失敗筆數                 = ""
# # # # # # # # #                 速度比_Legacy除DRL       = ""
# # # # # # # # #                 DRL_finalSalary          = if ($null -ne $drFinal) { $drFinal } else { "ERROR" }
# # # # # # # # #                 Legacy_finalSalary       = if ($null -ne $lgFinal) { $lgFinal } else { "ERROR" }
# # # # # # # # #                 結果是否一致             = $match
# # # # # # # # #                 記憶體基準_MB            = ""
# # # # # # # # #                 記憶體_資料產生後_MB     = ""
# # # # # # # # #                 記憶體_DRL回應後_MB      = ""
# # # # # # # # #                 記憶體_Legacy回應後_MB   = ""
# # # # # # # # #                 記憶體_JSON解析後_MB     = ""
# # # # # # # # #                 記憶體峰值_MB            = ""
# # # # # # # # #                 記憶體增量_峰值vs基準_MB = ""
# # # # # # # # #             }) | Out-Null
# # # # # # # # #         }
# # # # # # # # #     }

# # # # # # # # #     $color = if ($mismatchCount -gt 0) { "Red" } elseif ($errorCount -gt 0) { "Yellow" } else { "Green" }
# # # # # # # # #     Write-Host "  公司 $cid：一致 $matchCount 筆 / 不同 $mismatchCount 筆 / 無法比對 $errorCount 筆" -ForegroundColor $color

# # # # # # # # #     if ($cid -ne $COMPANIES[-1]) {
# # # # # # # # #         $csvRows.Add([PSCustomObject]@{
# # # # # # # # #             Section="═══"; 員工ID=""; 公司ID=""; 底薪=""; 年資月數=""; 假別筆數=""; 加班筆數=""
# # # # # # # # #             績效筆數=""; 出勤筆數=""; 津貼筆數=""; 專案筆數=""; 薪資調整筆數=""
# # # # # # # # #             引擎類型=""; 冷啟動耗時_ms=""; 批次總耗時_ms=""; 含冷啟動總耗時_ms=""; 平均每筆耗時_ms=""
# # # # # # # # #             成功筆數=""; 失敗筆數=""; 速度比_Legacy除DRL=""; DRL_finalSalary=""; Legacy_finalSalary=""
# # # # # # # # #             結果是否一致=""; 記憶體基準_MB=""; 記憶體_資料產生後_MB=""; 記憶體_DRL回應後_MB=""
# # # # # # # # #             記憶體_Legacy回應後_MB=""; 記憶體_JSON解析後_MB=""; 記憶體峰值_MB=""; 記憶體增量_峰值vs基準_MB=""
# # # # # # # # #         }) | Out-Null
# # # # # # # # #     }
# # # # # # # # # }

# # # # # # # # # $memAfterCsv      = Get-ManagedMemoryMB
# # # # # # # # # $memAfterCsvDelta = [math]::Round($memAfterCsv - $memBaseline, 2)

# # # # # # # # # $totalColor = if ($totalMismatch -gt 0) { "Red" } elseif ($totalError -gt 0) { "Yellow" } else { "Green" }
# # # # # # # # # Write-Host "  總計：一致 $totalMatch 筆 / 不同 $totalMismatch 筆 / 無法比對 $totalError 筆" -ForegroundColor $totalColor
# # # # # # # # # Write-Host "  📊 CSV 物件建立後記憶體：$memAfterCsv MB（+$memAfterCsvDelta MB）" -ForegroundColor DarkGray

# # # # # # # # # $csvPath = "benchmark_parallel_$fileTs.csv"
# # # # # # # # # $csvRows | Export-Csv -Path $csvPath -Encoding UTF8 -NoTypeInformation
# # # # # # # # # Write-Host "`nCSV 已儲存：$csvPath" -ForegroundColor Green
# # # # # # # # # Write-Host "`n測試完成！`n" -ForegroundColor Green
# # # # # # # # # 1. 定義 API 端點與變數
# # # # # # # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # # # # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # # # # # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # # # # # # $COMPANY_ID = "25"
# # # # # # # # $BATCH_SIZE = 50

# # # # # # # # # 輔助資料陣列
# # # # # # # # $INSURED_BRACKETS = @(26400, 27600, 28800, 30300, 31800, 33300, 34800, 36300, 38200, 40100, 42000, 43900, 45800, 48200, 50600, 53000, 55400, 57800, 60800, 63800)
# # # # # # # # $LEAVE_TYPES      = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # # # # # $OT_TYPES         = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # # # # # $PERF_GRADES      = @("SS+","SS","S","A+","A","B+","B")
# # # # # # # # $ALLOWANCE_TYPES  = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # # # # # $ADJ_TYPES        = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # # # # # # 2. 定義資料產生函式
# # # # # # # # function Get-InsuredSalary([int]$baseSalary) {
# # # # # # # #     $bracket = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # # # # # #     if ($null -eq $bracket) { $bracket = $INSURED_BRACKETS[-1] }
# # # # # # # #     return $bracket
# # # # # # # # }
# # # # # # # # function Get-RandomLeaves {
# # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # # # # # #     foreach ($lt in $picked) {
# # # # # # # #         $hours = Get-Random -Minimum 1 -Maximum 9
# # # # # # # #         $null  = $result.Add([PSCustomObject]@{ leaveTypeName=$lt; leaveDays=[math]::Round($hours/8,3); leaveHours=$hours; deductionRate=1.0; affectFullAttendance=$true })
# # # # # # # #     }
# # # # # # # #     return ,$result
# # # # # # # # }
# # # # # # # # function Get-RandomOvertimes {
# # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # # # # # #     foreach ($ot in $picked) {
# # # # # # # #         $null = $result.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # # # # # # #     }
# # # # # # # #     return ,$result
# # # # # # # # }
# # # # # # # # function Get-RandomPerformance([string]$empId) {
# # # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; grade=($PERF_GRADES | Get-Random); score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1); confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8) }
# # # # # # # # }
# # # # # # # # function Get-RandomAttendance([string]$empId) {
# # # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # # #     $lc = Get-Random -Minimum 0 -Maximum 5; $ec = Get-Random -Minimum 0 -Maximum 4; $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # # # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs; workDays=[math]::Max(0, 22-[int]$abs); requiredWorkDays=22; hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0); lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15) }
# # # # # # # # }
# # # # # # # # function Get-RandomAllowances([string]$empId) {
# # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # # # # # #     foreach ($at in $picked) {
# # # # # # # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at; amount=(Get-Random -Minimum 500 -Maximum 5000); approved=$appr; approvedBy=if($appr){"MGR"}else{$null} })
# # # # # # # #     }
# # # # # # # #     return ,$result
# # # # # # # # }
# # # # # # # # function Get-RandomProjects([string]$empId) {
# # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # #     for ($i = 1; $i -le $count; $i++) {
# # # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"; role=(@("LEAD","MEMBER")|Get-Random); completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6); bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2) })
# # # # # # # #     }
# # # # # # # #     return ,$result
# # # # # # # # }
# # # # # # # # function Get-RandomSalaryAdjustments([string]$empId) {
# # # # # # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # # # # # #     foreach ($at in $picked) {
# # # # # # # #         $isPos = $at -ne "DEDUCTION"
# # # # # # # #         $amt = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false })
# # # # # # # #     }
# # # # # # # #     return ,$result
# # # # # # # # }

# # # # # # # # # 3. 產生測試資料
# # # # # # # # Write-Host "開始產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆批次資料..." -ForegroundColor Cyan
# # # # # # # # [System.Collections.ArrayList]$batch = @()
# # # # # # # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # # # # # # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # # # # # # #     $base  = Get-Random -Minimum 30000 -Maximum 100000
    
# # # # # # # #     [System.Collections.ArrayList]$perfArr = @(); $perf = Get-RandomPerformance -empId $empId; if ($null -ne $perf) { $null = $perfArr.Add($perf) }
# # # # # # # #     [System.Collections.ArrayList]$attArr  = @(); $att = Get-RandomAttendance -empId $empId; if ($null -ne $att) { $null = $attArr.Add($att) }
    
# # # # # # # #     $null = $batch.Add([PSCustomObject]@{
# # # # # # # #         employeeId = $empId; companyId = $COMPANY_ID; baseSalary = $base; tenureMonths = 24; seniorityMonths = 24;
# # # # # # # #         laborInsuredSalary = (Get-InsuredSalary $base); healthInsuredSalary = (Get-InsuredSalary $base); pensionSalary = (Get-InsuredSalary $base);
# # # # # # # #         leaves = Get-RandomLeaves; overtimes = Get-RandomOvertimes; allowances = Get-RandomAllowances -empId $empId;
# # # # # # # #         projects = Get-RandomProjects -empId $empId; salaryAdjustments = Get-RandomSalaryAdjustments -empId $empId;
# # # # # # # #         performances = $perfArr; attendances = $attArr; workingDaysInMonth = 22
# # # # # # # #     })
# # # # # # # # }
# # # # # # # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress
# # # # # # # # Write-Host "資料產生完畢，Payload 長度：$($batchPayload.Length) bytes" -ForegroundColor White

# # # # # # # # # 4. 預熱階段（此步驟不計時，用來排除冷啟動與編譯耗時）
# # # # # # # # Write-Host "`n[預熱階段] 正在對雙端 API 進行首度呼召以排除冷啟動..." -ForegroundColor Cyan
# # # # # # # # try {
# # # # # # # #     # 預熱 Legacy (送出單筆資料)
# # # # # # # #     $warmupSingle = ConvertTo-Json -InputObject $batch[0] -Depth 10 -Compress
# # # # # # # #     $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $warmupSingle -ErrorAction SilentlyContinue
    
# # # # # # # #     # 預熱 Drools (送出整包陣列)
# # # # # # # #     $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
    
# # # # # # # #     Write-Host "預熱完畢，等待 2 秒讓伺服器資源穩定..." -ForegroundColor DarkGray
# # # # # # # #     Start-Sleep -Seconds 2
# # # # # # # # } catch {
# # # # # # # #     Write-Host "預熱過程發生部分異常，將嘗試繼續執行正式測試" -ForegroundColor Yellow
# # # # # # # # }

# # # # # # # # # 5. 正式測試：發送至 Legacy API (硬編碼改成逐筆串行處理)
# # # # # # # # Write-Host "`n[測試 1] 發送資料至 Legacy API (非批次，改為逐筆串行處理)..." -ForegroundColor Yellow
# # # # # # # # $legacyStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
# # # # # # # # [System.Collections.ArrayList]$legacyParsed = @()

# # # # # # # # foreach ($emp in $batch) {
# # # # # # # #     $singleJson = ConvertTo-Json -InputObject $emp -Depth 10 -Compress
# # # # # # # #     try {
# # # # # # # #         $resp = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $singleJson
# # # # # # # #         $null = $legacyParsed.Add($resp)
# # # # # # # #     } catch {
# # # # # # # #         Write-Host "Legacy API 發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # # # #     }
# # # # # # # # }
# # # # # # # # $legacyStopwatch.Stop()
# # # # # # # # $legacyMs = $legacyStopwatch.ElapsedMilliseconds
# # # # # # # # Write-Host "Legacy 處理總耗時: $legacyMs ms (平均 $([math]::Round($legacyMs / $BATCH_SIZE, 2)) ms/筆)" -ForegroundColor Yellow

# # # # # # # # # 6. 正式測試：發送至 Drools API (維持整包批次處理)
# # # # # # # # Write-Host "`n[測試 2] 發送整包陣列至 Drools API (單次批次處理)..." -ForegroundColor Magenta
# # # # # # # # $droolsStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
# # # # # # # # try {
# # # # # # # #     $droolsResp = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
# # # # # # # # } catch {
# # # # # # # #     Write-Host "Drools API 發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # # # # }
# # # # # # # # $droolsStopwatch.Stop()
# # # # # # # # $droolsMs = $droolsStopwatch.ElapsedMilliseconds
# # # # # # # # Write-Host "Drools 處理總耗時: $droolsMs ms (平均 $([math]::Round($droolsMs / $BATCH_SIZE, 2)) ms/筆)" -ForegroundColor Magenta

# # # # # # # # # 7. 效能與架構對比摘要
# # # # # # # # Write-Host "`n========================================================" -ForegroundColor Cyan
# # # # # # # # Write-Host " 運算效能與架構對比總結 (熱啟動狀態, 資料量: $BATCH_SIZE 筆)" -ForegroundColor Cyan
# # # # # # # # Write-Host "========================================================" -ForegroundColor Cyan
# # # # # # # # Write-Host " 舊版硬編碼 (Legacy - 逐筆串行) 總耗時 : $legacyMs ms"
# # # # # # # # Write-Host " 新版規則引擎 (Drools - 單次批次) 總耗時 : $droolsMs ms"

# # # # # # # # if ($droolsMs -gt 0 -and $legacyMs -gt 0) {
# # # # # # # #     if ($legacyMs -lt $droolsMs) {
# # # # # # # #         $ratio = [math]::Round($droolsMs / $legacyMs, 2)
# # # # # # # #         Write-Host " 效能結果: 硬編碼(逐筆串行)速度較快，是 Drools(單次批次) 的 $ratio 倍" -ForegroundColor Green
# # # # # # # #     } else {
# # # # # # # #         $ratio = [math]::Round($legacyMs / $droolsMs, 2)
# # # # # # # #         Write-Host " 效能結果: Drools(單次批次)速度較快，是硬編碼(逐筆串行) 的 $ratio 倍" -ForegroundColor Green
# # # # # # # #     }
# # # # # # # # }

# # # # # # # # $lgCount = $legacyParsed.Count
# # # # # # # # $drCount = if ($null -ne $droolsResp) { $droolsResp.Count } else { 0 }
# # # # # # # # Write-Host "`n回傳筆數確認 - Legacy: $lgCount 筆 / Drools: $drCount 筆" -ForegroundColor DarkGray
# # # # # # # # 1. 定義 API 端點與變數
# # # # # # # # 1. 定義 API 端點與變數
# # # # # # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # # # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # # # # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # # # # # $COMPANY_ID = "25"
# # # # # # # $BATCH_SIZE = 50

# # # # # # # # 輔助資料陣列
# # # # # # # $INSURED_BRACKETS = @(26400, 27600, 28800, 30300, 31800, 33300, 34800, 36300, 38200, 40100, 42000, 43900, 45800, 48200, 50600, 53000, 55400, 57800, 60800, 63800)
# # # # # # # $LEAVE_TYPES      = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # # # # $OT_TYPES         = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # # # # $PERF_GRADES      = @("SS+","SS","S","A+","A","B+","B")
# # # # # # # $ALLOWANCE_TYPES  = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # # # # $ADJ_TYPES        = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # # # # # 2. 定義資料產生函式
# # # # # # # function Get-InsuredSalary([int]$baseSalary) {
# # # # # # #     $bracket = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # # # # #     if ($null -eq $bracket) { $bracket = $INSURED_BRACKETS[-1] }
# # # # # # #     return $bracket
# # # # # # # }
# # # # # # # function Get-RandomLeaves {
# # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # # # # #     foreach ($lt in $picked) {
# # # # # # #         $hours = Get-Random -Minimum 1 -Maximum 9
# # # # # # #         $null  = $result.Add([PSCustomObject]@{ leaveTypeName=$lt; leaveDays=[math]::Round($hours/8,3); leaveHours=$hours; deductionRate=1.0; affectFullAttendance=$true })
# # # # # # #     }
# # # # # # #     return ,$result
# # # # # # # }
# # # # # # # function Get-RandomOvertimes {
# # # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # # # # #     foreach ($ot in $picked) {
# # # # # # #         $null = $result.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # # # # # #     }
# # # # # # #     return ,$result
# # # # # # # }
# # # # # # # function Get-RandomPerformance([string]$empId) {
# # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; grade=($PERF_GRADES | Get-Random); score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1); confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8) }
# # # # # # # }
# # # # # # # function Get-RandomAttendance([string]$empId) {
# # # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # # #     $lc = Get-Random -Minimum 0 -Maximum 5; $ec = Get-Random -Minimum 0 -Maximum 4; $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs; workDays=[math]::Max(0, 22-[int]$abs); requiredWorkDays=22; hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0); lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15) }
# # # # # # # }
# # # # # # # function Get-RandomAllowances([string]$empId) {
# # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # # # # #     foreach ($at in $picked) {
# # # # # # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at; amount=(Get-Random -Minimum 500 -Maximum 5000); approved=$appr; approvedBy=if($appr){"MGR"}else{$null} })
# # # # # # #     }
# # # # # # #     return ,$result
# # # # # # # }
# # # # # # # function Get-RandomProjects([string]$empId) {
# # # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # #     for ($i = 1; $i -le $count; $i++) {
# # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"; role=(@("LEAD","MEMBER")|Get-Random); completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6); bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2) })
# # # # # # #     }
# # # # # # #     return ,$result
# # # # # # # }
# # # # # # # function Get-RandomSalaryAdjustments([string]$empId) {
# # # # # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # # #     if ($count -eq 0) { return ,$result }
# # # # # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # # # # #     foreach ($at in $picked) {
# # # # # # #         $isPos = $at -ne "DEDUCTION"
# # # # # # #         $amt = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false })
# # # # # # #     }
# # # # # # #     return ,$result
# # # # # # # }

# # # # # # # # 3. 產生測試資料
# # # # # # # Write-Host "開始產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆批次資料..." -ForegroundColor Cyan
# # # # # # # [System.Collections.ArrayList]$batch = @()
# # # # # # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # # # # # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # # # # # #     $base  = Get-Random -Minimum 30000 -Maximum 100000
    
# # # # # # #     [System.Collections.ArrayList]$perfArr = @(); $perf = Get-RandomPerformance -empId $empId; if ($null -ne $perf) { $null = $perfArr.Add($perf) }
# # # # # # #     [System.Collections.ArrayList]$attArr  = @(); $att = Get-RandomAttendance -empId $empId; if ($null -ne $att) { $null = $attArr.Add($att) }
    
# # # # # # #     $null = $batch.Add([PSCustomObject]@{
# # # # # # #         employeeId = $empId; companyId = $COMPANY_ID; baseSalary = $base; tenureMonths = 24; seniorityMonths = 24;
# # # # # # #         laborInsuredSalary = (Get-InsuredSalary $base); healthInsuredSalary = (Get-InsuredSalary $base); pensionSalary = (Get-InsuredSalary $base);
# # # # # # #         leaves = Get-RandomLeaves; overtimes = Get-RandomOvertimes; allowances = Get-RandomAllowances -empId $empId;
# # # # # # #         projects = Get-RandomProjects -empId $empId; salaryAdjustments = Get-RandomSalaryAdjustments -empId $empId;
# # # # # # #         performances = $perfArr; attendances = $attArr; workingDaysInMonth = 22
# # # # # # #     })
# # # # # # # }
# # # # # # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress
# # # # # # # Write-Host "資料產生完畢，Payload 長度：$($batchPayload.Length) bytes" -ForegroundColor White

# # # # # # # # 4. 預熱階段（此步驟不計時，用來排除冷啟動與編譯耗時）
# # # # # # # Write-Host "`n[預熱階段] 正在對雙端 API 進行首度呼叫以排除冷啟動..." -ForegroundColor Cyan
# # # # # # # try {
# # # # # # #     # 預熱 Legacy (送出單筆資料)
# # # # # # #     $warmupSingle = ConvertTo-Json -InputObject $batch[0] -Depth 10 -Compress
# # # # # # #     $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $warmupSingle -ErrorAction SilentlyContinue
    
# # # # # # #     # 預熱 Drools (送出整包陣列)
# # # # # # #     $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
    
# # # # # # #     Write-Host "預熱完畢，等待 2 秒讓伺服器資源穩定..." -ForegroundColor DarkGray
# # # # # # #     Start-Sleep -Seconds 2
# # # # # # # } catch {
# # # # # # #     Write-Host "預熱過程發生部分異常，將嘗試繼續執行正式測試" -ForegroundColor Yellow
# # # # # # # }

# # # # # # # # 5. 正式測試：發送至 Legacy API (硬編碼改成逐筆串行處理)
# # # # # # # Write-Host "`n[測試 1] 發送資料至 Legacy API (非批次，改為逐筆串行處理)..." -ForegroundColor Yellow
# # # # # # # [System.Collections.ArrayList]$legacyParsed = @()
# # # # # # # $legacyMs = 0L # 用來累加每一筆在後端真正的「純運算/處理時間」

# # # # # # # foreach ($emp in $batch) {
# # # # # # #     $singleJson = ConvertTo-Json -InputObject $emp -Depth 10 -Compress
# # # # # # #     try {
# # # # # # #         $legacyResponse = Invoke-WebRequest -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $singleJson
        
# # # # # # #         # 🚀 【安全修正】使用 @(...) 將其強制作為陣列處理，並取第一個元素轉成純字串，避免 System.String[] 導致轉型失敗
# # # # # # #         if ($legacyResponse.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # # # # #             $rawHeaderValue = (@($legacyResponse.Headers["X-Execution-Time-Ms"])[0]).ToString()
# # # # # # #             $legacyMs += [int64]$rawHeaderValue
# # # # # # #         }
        
# # # # # # #         $resp = $legacyResponse.Content | ConvertFrom-Json
# # # # # # #         $null = $legacyParsed.Add($resp)
# # # # # # #     } catch {
# # # # # # #         Write-Host "Legacy API 發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # # #     }
# # # # # # # }
# # # # # # # Write-Host "Legacy 純運算累計耗時 (已排除網路連線延遲): $legacyMs ms (平均 $([math]::Round($legacyMs / $BATCH_SIZE, 2)) ms/筆)" -ForegroundColor Yellow


# # # # # # # # 6. 正式測試：發送至 Drools API (維持整包批次處理 + 讀取純匹配時間)
# # # # # # # Write-Host "`n[測試 2] 發送整包陣列至 Drools API (單次批次處理)..." -ForegroundColor Magenta
# # # # # # # $droolsMs = 0L

# # # # # # # try {
# # # # # # #     $droolsResponse = Invoke-WebRequest -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
    
# # # # # # #     # 🚀 【安全修正】同樣使用 @(...)[0].ToString() 規避 String[] 轉型障礙
# # # # # # #     if ($droolsResponse.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
# # # # # # #         $rawDroolsValue = (@($droolsResponse.Headers["X-Drools-Pure-Compute-Ms"])[0]).ToString()
# # # # # # #         $droolsMs = [int64]$rawDroolsValue
# # # # # # #     } else {
# # # # # # #         Write-Host "警告: 未從後端偵測到純運算 X-Drools-Pure-Compute-Ms 標頭，改採用備援機制。" -ForegroundColor Yellow
# # # # # # #         if ($droolsResponse.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # # # # #             $rawExecValue = (@($droolsResponse.Headers["X-Execution-Time-Ms"])[0]).ToString()
# # # # # # #             $droolsMs = [int64]$rawExecValue
# # # # # # #         }
# # # # # # #     }
    
# # # # # # #     # 解析 Content 供後續驗證資料筆數
# # # # # # #     $droolsResp = $droolsResponse.Content | ConvertFrom-Json
# # # # # # # } catch {
# # # # # # #     Write-Host "Drools API 發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # # # }
# # # # # # # Write-Host "Drools 純引擎匹配耗時 (已排除建立 Session 與網路開銷): $droolsMs ms (平均 $([math]::Round($droolsMs / $BATCH_SIZE, 4)) ms/筆)" -ForegroundColor Magenta


# # # # # # # # 7. 純粹演算法匹配效能對比摘要
# # # # # # # Write-Host "`n========================================================" -ForegroundColor Cyan
# # # # # # # Write-Host " 核心匹配演算法純運算效能對比總結 (資料量: $BATCH_SIZE 筆)" -ForegroundColor Cyan
# # # # # # # Write-Host "========================================================" -ForegroundColor Cyan
# # # # # # # Write-Host " 舊版硬編碼 (Legacy - 純運算累計) 總耗時 : $legacyMs ms"
# # # # # # # Write-Host " 新版規則引擎 (Drools - Rete純匹配) 總耗時 : $droolsMs ms"

# # # # # # # if ($droolsMs -gt 0 -and $legacyMs -gt 0) {
# # # # # # #     if ($legacyMs -lt $droolsMs) {
# # # # # # #         $ratio = [math]::Round($droolsMs / $legacyMs, 2)
# # # # # # #         Write-Host " 效能運算結果: 記憶體內 If-Else 硬編碼迴圈較快，是 Drools Rete 的 $ratio 倍" -ForegroundColor Green
# # # # # # #     } else {
# # # # # # #         $ratio = [math]::Round($legacyMs / $droolsMs, 2)
# # # # # # #         Write-Host " 效能運算結果: Drools 規則引擎(Rete樹)速度較快，是硬編碼迴圈的 $ratio 倍" -ForegroundColor Green
# # # # # # #     }
# # # # # # # } else {
# # # # # # #     if ($droolsMs -eq 0 -and $legacyMs -gt 0) {
# # # # # # #         Write-Host " 效能運算結果: Drools 耗時趨近於 0ms，效能展現壓倒性優勢（趨近無限倍快於硬編碼）" -ForegroundColor Green
# # # # # # #     }
# # # # # # # }

# # # # # # # $lgCount = $legacyParsed.Count
# # # # # # # $drCount = if ($null -ne $droolsResp) { $droolsResp.Count } else { 0 }
# # # # # # # Write-Host "`n回傳筆數確認 - Legacy: $lgCount 筆 / Drools: $drCount 筆" -ForegroundColor DarkGray

# # # # # # # 1. 定義 API 端點與變數
# # # # # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # # # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # # # # $COMPANY_ID = "25"
# # # # # # $BATCH_SIZE = 50

# # # # # # # 輔助資料陣列
# # # # # # $INSURED_BRACKETS = @(26400, 27600, 28800, 30300, 31800, 33300, 34800, 36300, 38200, 40100, 42000, 43900, 45800, 48200, 50600, 53000, 55400, 57800, 60800, 63800)
# # # # # # $LEAVE_TYPES      = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # # # $OT_TYPES         = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # # # $PERF_GRADES      = @("SS+","SS","S","A+","A","B+","B")
# # # # # # $ALLOWANCE_TYPES  = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # # # $ADJ_TYPES        = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # # # # 2. 定義資料產生函式
# # # # # # function Get-InsuredSalary([int]$baseSalary) {
# # # # # #     $bracket = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # # # #     if ($null -eq $bracket) { $bracket = $INSURED_BRACKETS[-1] }
# # # # # #     return $bracket
# # # # # # }
# # # # # # function Get-RandomLeaves {
# # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # #     if ($count -eq 0) { return ,$result }
# # # # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # # # #     foreach ($lt in $picked) {
# # # # # #         $hours = Get-Random -Minimum 1 -Maximum 9
# # # # # #         $null  = $result.Add([PSCustomObject]@{ leaveTypeName=$lt; leaveDays=[math]::Round($hours/8,3); leaveHours=$hours; deductionRate=1.0; affectFullAttendance=$true })
# # # # # #     }
# # # # # #     return ,$result
# # # # # # }
# # # # # # function Get-RandomOvertimes {
# # # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # #     if ($count -eq 0) { return ,$result }
# # # # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # # # #     foreach ($ot in $picked) {
# # # # # #         $null = $result.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # # # # #     }
# # # # # #     return ,$result
# # # # # # }
# # # # # # function Get-RandomPerformance([string]$empId) {
# # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; grade=($PERF_GRADES | Get-Random); score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1); confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8) }
# # # # # # }
# # # # # # function Get-RandomAttendance([string]$empId) {
# # # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # # #     $lc = Get-Random -Minimum 0 -Maximum 5; $ec = Get-Random -Minimum 0 -Maximum 4; $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs; workDays=[math]::Max(0, 22-[int]$abs); requiredWorkDays=22; hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0); lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15) }
# # # # # # }
# # # # # # function Get-RandomAllowances([string]$empId) {
# # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # #     if ($count -eq 0) { return ,$result }
# # # # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # # # #     foreach ($at in $picked) {
# # # # # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at; amount=(Get-Random -Minimum 500 -Maximum 5000); approved=$appr; approvedBy=if($appr){"MGR"}else{$null} })
# # # # # #     }
# # # # # #     return ,$result
# # # # # # }
# # # # # # function Get-RandomProjects([string]$empId) {
# # # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # #     if ($count -eq 0) { return ,$result }
# # # # # #     for ($i = 1; $i -le $count; $i++) {
# # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"; role=(@("LEAD","MEMBER")|Get-Random); completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6); bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2) })
# # # # # #     }
# # # # # #     return ,$result
# # # # # # }
# # # # # # function Get-RandomSalaryAdjustments([string]$empId) {
# # # # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # # # #     [System.Collections.ArrayList]$result = @()
# # # # # #     if ($count -eq 0) { return ,$result }
# # # # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # # # #     foreach ($at in $picked) {
# # # # # #         $isPos = $at -ne "DEDUCTION"
# # # # # #         $amt = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false })
# # # # # #     }
# # # # # #     return ,$result
# # # # # # }

# # # # # # # 3. 產生測試資料
# # # # # # Write-Host "開始產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆批次資料..." -ForegroundColor Cyan
# # # # # # [System.Collections.ArrayList]$batch = @()
# # # # # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # # # # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # # # # #     $base  = Get-Random -Minimum 30000 -Maximum 100000
    
# # # # # #     [System.Collections.ArrayList]$perfArr = @(); $perf = Get-RandomPerformance -empId $empId; if ($null -ne $perf) { $null = $perfArr.Add($perf) }
# # # # # #     [System.Collections.ArrayList]$attArr  = @(); $att = Get-RandomAttendance -empId $empId; if ($null -ne $att) { $null = $attArr.Add($att) }
    
# # # # # #     $null = $batch.Add([PSCustomObject]@{
# # # # # #         employeeId = $empId; companyId = $COMPANY_ID; baseSalary = $base; tenureMonths = 24; seniorityMonths = 24;
# # # # # #         laborInsuredSalary = (Get-InsuredSalary $base); healthInsuredSalary = (Get-InsuredSalary $base); pensionSalary = (Get-InsuredSalary $base);
# # # # # #         leaves = Get-RandomLeaves; overtimes = Get-RandomOvertimes; allowances = Get-RandomAllowances -empId $empId;
# # # # # #         projects = Get-RandomProjects -empId $empId; salaryAdjustments = Get-RandomSalaryAdjustments -empId $empId;
# # # # # #         performances = $perfArr; attendances = $attArr; workingDaysInMonth = 22
# # # # # #     })
# # # # # # }
# # # # # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress
# # # # # # Write-Host "資料產生完畢，Payload 長度：$($batchPayload.Length) bytes" -ForegroundColor White

# # # # # # # 4. 預熱階段（此步驟不計時，用來排除冷啟動與編譯耗時）
# # # # # # Write-Host "`n[預熱階段] 正在對雙端 API 進行首度呼叫以排除冷啟動..." -ForegroundColor Cyan
# # # # # # try {
# # # # # #     # 預熱 Legacy (送出單筆資料)
# # # # # #     $warmupSingle = ConvertTo-Json -InputObject $batch[0] -Depth 10 -Compress
# # # # # #     $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $warmupSingle -ErrorAction SilentlyContinue
    
# # # # # #     # 預熱 Drools (送出整包陣列)
# # # # # #     $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
    
# # # # # #     Write-Host "預熱完畢，等待 2 秒讓伺服器資源穩定..." -ForegroundColor DarkGray
# # # # # #     Start-Sleep -Seconds 2
# # # # # # } catch {
# # # # # #     Write-Host "預熱過程發生部分異常，將嘗試繼續執行正式測試" -ForegroundColor Yellow
# # # # # # }

# # # # # # # 5. 正式測試：發送至 Legacy API (多執行緒平行處理修正版)
# # # # # # Write-Host "`n[測試 1] 發送資料至 Legacy API (非批次，改為多執行緒平行處理)..." -ForegroundColor Yellow

# # # # # # # 使用執行緒安全的 .NET ConcurrentBag
# # # # # # $legacyParsed = [System.Collections.Concurrent.ConcurrentBag[Object]]::new()
# # # # # # $globalLegacyMs = [long]0

# # # # # # # 🚀 建立一個乾淨的、只包含單純屬性的變數供平行執行緒複製傳入
# # # # # # $targetUrl = $LEGACY_URL

# # # # # # # 啟動平行發送機制
# # # # # # $batch | ForEach-Object -ThrottleLimit 32 -Parallel {
# # # # # #     $emp = $_
# # # # # #     $singleJson = ConvertTo-Json -InputObject $emp -Depth 10 -Compress
    
# # # # # #     # 🚀 【關鍵修正點】在內部先引用外部變數至本地端，完全避開 Expression is not allowed 限制
# # # # # #     $localUrl  = $using:targetUrl
# # # # # #     $localBag  = $using:legacyParsed
    
# # # # # #     try {
# # # # # #         $legacyResponse = Invoke-WebRequest -Method Post -Uri $localUrl -ContentType "application/json" -Body $singleJson
        
# # # # # #         if ($legacyResponse.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # # # #             $rawHeaderValue = (@($legacyResponse.Headers["X-Execution-Time-Ms"])[0]).ToString()
            
# # # # # #             # 使用原子操作累加跨執行緒數值
# # # # # #             $null = [System.Threading.Interlocked]::Add([ref]$using:globalLegacyMs, [int64]$rawHeaderValue)
# # # # # #         }
        
# # # # # #         $resp = $legacyResponse.Content | ConvertFrom-Json
# # # # # #         $localBag.Add($resp)
# # # # # #     } catch {
# # # # # #         Write-Host "Legacy API 平行呼叫發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # #     }
# # # # # # }

# # # # # # $legacyMs = $globalLegacyMs
# # # # # # Write-Host "Legacy 純運算累計耗時 (多執行緒已排除網路連線延遲): $legacyMs ms (平均 $([math]::Round($legacyMs / $BATCH_SIZE, 2)) ms/筆)" -ForegroundColor Yellow


# # # # # # # 6. 正式測試：發送至 Drools API (維持整包批次處理 + 讀取純匹配時間)
# # # # # # Write-Host "`n[測試 2] 發送整包陣列至 Drools API (單次批次處理)..." -ForegroundColor Magenta
# # # # # # $droolsMs = 0L

# # # # # # try {
# # # # # #     $droolsResponse = Invoke-WebRequest -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
    
# # # # # #     if ($droolsResponse.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
# # # # # #         $rawDroolsValue = (@($droolsResponse.Headers["X-Drools-Pure-Compute-Ms"])[0]).ToString()
# # # # # #         $droolsMs = [int64]$rawDroolsValue
# # # # # #     } else {
# # # # # #         Write-Host "警告: 未從後端偵測到純運算 X-Drools-Pure-Compute-Ms 標頭，改採用備援機制。" -ForegroundColor Yellow
# # # # # #         if ($droolsResponse.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # # # #             $rawExecValue = (@($droolsResponse.Headers["X-Execution-Time-Ms"])[0]).ToString()
# # # # # #             $droolsMs = [int64]$rawExecValue
# # # # # #         }
# # # # # #     }
    
# # # # # #     $droolsResp = $droolsResponse.Content | ConvertFrom-Json
# # # # # # } catch {
# # # # # #     Write-Host "Drools API 發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # # # }
# # # # # # Write-Host "Drools 純引擎匹配耗時 (已排除建立 Session 與網路開銷): $droolsMs ms (平均 $([math]::Round($droolsMs / $BATCH_SIZE, 4)) ms/筆)" -ForegroundColor Magenta


# # # # # # # 7. 純粹演算法匹配效能對比摘要
# # # # # # Write-Host "`n========================================================" -ForegroundColor Cyan
# # # # # # Write-Host " 核心匹配演算法純運算效能對比總結 (資料量: $BATCH_SIZE 筆)" -ForegroundColor Cyan
# # # # # # Write-Host "========================================================" -ForegroundColor Cyan
# # # # # # Write-Host " 舊版硬編碼 (Legacy - 純運算累計) 總耗時 : $legacyMs ms"
# # # # # # Write-Host " 新版規則引擎 (Drools - Rete純匹配) 總耗時 : $droolsMs ms"

# # # # # # if ($droolsMs -gt 0 -and $legacyMs -gt 0) {
# # # # # #     if ($legacyMs -lt $droolsMs) {
# # # # # #         $ratio = [math]::Round($droolsMs / $legacyMs, 2)
# # # # # #         Write-Host " 效能運算結果: 記憶體內 If-Else 硬編碼迴圈較快，是 Drools Rete 的 $ratio 倍" -ForegroundColor Green
# # # # # #     } else {
# # # # # #         $ratio = [math]::Round($legacyMs / $droolsMs, 2)
# # # # # #         Write-Host " 效能運算結果: Drools 規則引擎(Rete樹)速度較快，是硬編碼迴圈的 $ratio 倍" -ForegroundColor Green
# # # # # #     }
# # # # # # } else {
# # # # # #     if ($droolsMs -eq 0 -and $legacyMs -gt 0) {
# # # # # #         Write-Host " 效能運算結果: Drools 耗時趨近於 0ms，效能展現壓倒性優勢（趨近無限倍快於硬編碼）" -ForegroundColor Green
# # # # # #     }
# # # # # # }

# # # # # # $lgCount = $legacyParsed.Count
# # # # # # $drCount = if ($null -ne $droolsResp) { $droolsResp.Count } else { 0 }
# # # # # # Write-Host "`n回傳筆數確認 - Legacy: $lgCount 筆 / Drools: $drCount 筆" -ForegroundColor DarkGray
# # # # # # 1. 定義 API 端點與變數
# # # # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # # # $COMPANY_ID = "25"
# # # # # $BATCH_SIZE = 5

# # # # # # 輔助資料陣列
# # # # # $INSURED_BRACKETS = @(26400, 27600, 28800, 30300, 31800, 33300, 34800, 36300, 38200, 40100, 42000, 43900, 45800, 48200, 50600, 53000, 55400, 57800, 60800, 63800)
# # # # # $LEAVE_TYPES      = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # # $OT_TYPES         = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # # $PERF_GRADES      = @("SS+","SS","S","A+","A","B+","B")
# # # # # $ALLOWANCE_TYPES  = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # # $ADJ_TYPES        = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # # # 2. 定義資料產生函式 (省略細節，維持原樣)
# # # # # function Get-InsuredSalary([int]$baseSalary) {
# # # # #     $bracket = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # # #     if ($null -eq $bracket) { $bracket = $INSURED_BRACKETS[-1] }
# # # # #     return $bracket
# # # # # }
# # # # # function Get-RandomLeaves {
# # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # #     [System.Collections.ArrayList]$result = @()
# # # # #     if ($count -eq 0) { return ,$result }
# # # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # # #     foreach ($lt in $picked) {
# # # # #         $hours = Get-Random -Minimum 1 -Maximum 9
# # # # #         $null  = $result.Add([PSCustomObject]@{ leaveTypeName=$lt; leaveDays=[math]::Round($hours/8,3); leaveHours=$hours; deductionRate=1.0; affectFullAttendance=$true })
# # # # #     }
# # # # #     return ,$result
# # # # # }
# # # # # function Get-RandomOvertimes {
# # # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # # #     [System.Collections.ArrayList]$result = @()
# # # # #     if ($count -eq 0) { return ,$result }
# # # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # # #     foreach ($ot in $picked) {
# # # # #         $null = $result.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # # # #     }
# # # # #     return ,$result
# # # # # }
# # # # # function Get-RandomPerformance([string]$empId) {
# # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; grade=($PERF_GRADES | Get-Random); score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1); confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8) }
# # # # # }
# # # # # function Get-RandomAttendance([string]$empId) {
# # # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # # #     $lc = Get-Random -Minimum 0 -Maximum 5; $ec = Get-Random -Minimum 0 -Maximum 4; $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # # # #     return [PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs; workDays=[math]::Max(0, 22-[int]$abs); requiredWorkDays=22; hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0); lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15) }
# # # # # }
# # # # # function Get-RandomAllowances([string]$empId) {
# # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # #     [System.Collections.ArrayList]$result = @()
# # # # #     if ($count -eq 0) { return ,$result }
# # # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # # #     foreach ($at in $picked) {
# # # # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at; amount=(Get-Random -Minimum 500 -Maximum 5000); approved=$appr; approvedBy=if($appr){"MGR"}else{$null} })
# # # # #     }
# # # # #     return ,$result
# # # # # }
# # # # # function Get-RandomProjects([string]$empId) {
# # # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # # #     [System.Collections.ArrayList]$result = @()
# # # # #     if ($count -eq 0) { return ,$result }
# # # # #     for ($i = 1; $i -le $count; $i++) {
# # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"; role=(@("LEAD","MEMBER")|Get-Random); completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6); bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2) })
# # # # #     }
# # # # #     return ,$result
# # # # # }
# # # # # function Get-RandomSalaryAdjustments([string]$empId) {
# # # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # # #     [System.Collections.ArrayList]$result = @()
# # # # #     if ($count -eq 0) { return ,$result }
# # # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # # #     foreach ($at in $picked) {
# # # # #         $isPos = $at -ne "DEDUCTION"
# # # # #         $amt = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # # # #         $null = $result.Add([PSCustomObject]@{ employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false })
# # # # #     }
# # # # #     return ,$result
# # # # # }

# # # # # # 3. 產生測試資料
# # # # # Write-Host "開始產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆批次資料..." -ForegroundColor Cyan
# # # # # [System.Collections.ArrayList]$batch = @()
# # # # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # # # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # # # #     $base  = Get-Random -Minimum 30000 -Maximum 100000
# # # # #     [System.Collections.ArrayList]$perfArr = @(); $perf = Get-RandomPerformance -empId $empId; if ($null -ne $perf) { $null = $perfArr.Add($perf) }
# # # # #     [System.Collections.ArrayList]$attArr  = @(); $att = Get-RandomAttendance -empId $empId; if ($null -ne $att) { $null = $attArr.Add($att) }
    
# # # # #     $null = $batch.Add([PSCustomObject]@{
# # # # #         employeeId = $empId; companyId = $COMPANY_ID; baseSalary = $base; tenureMonths = 24; seniorityMonths = 24;
# # # # #         laborInsuredSalary = (Get-InsuredSalary $base); healthInsuredSalary = (Get-InsuredSalary $base); pensionSalary = (Get-InsuredSalary $base);
# # # # #         leaves = Get-RandomLeaves; overtimes = Get-RandomOvertimes; allowances = Get-RandomAllowances -empId $empId;
# # # # #         projects = Get-RandomProjects -empId $empId; salaryAdjustments = Get-RandomSalaryAdjustments -empId $empId;
# # # # #         performances = $perfArr; attendances = $attArr; workingDaysInMonth = 22
# # # # #     })
# # # # # }
# # # # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress

# # # # # # 4. 預熱階段
# # # # # Write-Host "`n[預熱階段] 正在對雙端 API 進行首度呼叫以排除冷啟動..." -ForegroundColor Cyan
# # # # # $warmupSingle = ConvertTo-Json -InputObject $batch[0] -Depth 10 -Compress
# # # # # $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $warmupSingle -ErrorAction SilentlyContinue
# # # # # $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # # # # Start-Sleep -Seconds 2

# # # # # # 5. 正式測試：發送至 Legacy API (平行處理)
# # # # # Write-Host "`n[測試 1] 發送資料至 Legacy API (多執行緒平行處理)..." -ForegroundColor Yellow
# # # # # $legacyParsed = [System.Collections.Concurrent.ConcurrentBag[Object]]::new()
# # # # # $legacyTimeBag = [System.Collections.Concurrent.ConcurrentBag[long]]::new()
# # # # # $targetUrl = $LEGACY_URL

# # # # # # 啟動平行發送機制
# # # # # $batch | ForEach-Object -ThrottleLimit 32 -Parallel {
# # # # #     $emp = $_
# # # # #     $singleJson = ConvertTo-Json -InputObject $emp -Depth 10 -Compress
    
# # # # #     # 在平行區塊內建立本地參照
# # # # #     $localUrl  = $using:targetUrl
# # # # #     $localBag  = $using:legacyParsed
# # # # #     $timeBag   = $using:legacyTimeBag
    
# # # # #     try {
# # # # #         $legacyResponse = Invoke-WebRequest -Method Post -Uri $localUrl -ContentType "application/json" -Body $singleJson
        
# # # # #         # 處理 Header 耗時
# # # # #         if ($legacyResponse.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # # #             $rawHeaderValue = (@($legacyResponse.Headers["X-Execution-Time-Ms"])[0]).ToString()
# # # # #             $timeBag.Add([int64]$rawHeaderValue)
# # # # #         }
        
# # # # #         # 🚀 【修正】拆解步驟：先解析 Json，再由 Add 方法處理，避免解析器混淆
# # # # #         $parsedObj = $legacyResponse.Content | ConvertFrom-Json
# # # # #         $localBag.Add($parsedObj)
        
# # # # #     } catch {
# # # # #         Write-Host "Legacy API 平行呼叫發生錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # #     }
# # # # # }
# # # # # $legacyMs = 0; foreach ($t in $legacyTimeBag) { $legacyMs += $t }
# # # # # Write-Host "Legacy 純運算累計: $legacyMs ms" -ForegroundColor Yellow

# # # # # # 6. 正式測試：發送至 Drools API (批次處理)
# # # # # Write-Host "`n[測試 2] 發送整包陣列至 Drools API (單次批次處理)..." -ForegroundColor Magenta
# # # # # $droolsResponse = Invoke-WebRequest -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
# # # # # $droolsMs = if ($droolsResponse.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) { [int64](@($droolsResponse.Headers["X-Drools-Pure-Compute-Ms"])[0]) } else { 0 }
# # # # # Write-Host "Drools 純運算累計: $droolsMs ms" -ForegroundColor Magenta

# # # # # # 7. 總結
# # # # # Write-Host "`n========================================================" -ForegroundColor Cyan
# # # # # Write-Host " 最終比對 (Legacy: $legacyMs ms | Drools: $droolsMs ms)" -ForegroundColor Cyan
# # # # # # ========================================================
# # # # # # 6.5 比對 Legacy 與 Drools 計算結果
# # # # # # ========================================================

# # # # # Write-Host "`n[測試 3] 比對計算結果..." -ForegroundColor Green

# # # # # $droolsParsed = $droolsResponse.Content | ConvertFrom-Json

# # # # # # 建立 employeeId 索引
# # # # # $legacyMap = @{}
# # # # # foreach ($item in $legacyParsed) {
# # # # #     $legacyMap[$item.employeeId] = $item
# # # # # }

# # # # # $droolsMap = @{}
# # # # # foreach ($item in $droolsParsed) {
# # # # #     $droolsMap[$item.employeeId] = $item
# # # # # }

# # # # # $matched = 0
# # # # # $mismatched = 0

# # # # # foreach ($empId in $legacyMap.Keys) {

# # # # #     if (-not $droolsMap.ContainsKey($empId)) {
# # # # #         Write-Host "Drools 缺少員工資料: $empId" -ForegroundColor Red
# # # # #         $mismatched++
# # # # #         continue
# # # # #     }

# # # # #     $legacy = $legacyMap[$empId]
# # # # #     $drools = $droolsMap[$empId]

# # # # #     # 比對最終薪資
# # # # #     $legacySalary = [decimal]$legacy.finalSalary
# # # # #     $droolsSalary = [decimal]$drools.result.finalSalary

# # # # #     if ($legacySalary -eq $droolsSalary) {
# # # # #         $matched++
# # # # #     }
# # # # #     else {
# # # # #         $mismatched++

# # # # #         Write-Host ""
# # # # #         Write-Host "======================================" -ForegroundColor Red
# # # # #         Write-Host "員工: $empId" -ForegroundColor Red
# # # # #         Write-Host "Legacy Final Salary : $legacySalary"
# # # # #         Write-Host "Drools Final Salary : $droolsSalary"
# # # # #         Write-Host "差額               : $($droolsSalary - $legacySalary)"
# # # # #         Write-Host "======================================" -ForegroundColor Red
# # # # #     }
# # # # # }

# # # # # Write-Host ""
# # # # # Write-Host "比對完成" -ForegroundColor Green
# # # # # Write-Host "一致筆數 : $matched" -ForegroundColor Green
# # # # # Write-Host "不一致筆數 : $mismatched" -ForegroundColor Red
# # # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # # $COMPANY_ID = "25"
# # # # $BATCH_SIZE = 500

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 輔助資料
# # # # # ──────────────────────────────────────────────────────────────
# # # # $INSURED_BRACKETS = @(26400,27600,28800,30300,31800,33300,34800,36300,38200,
# # # #                        40100,42000,43900,45800,48200,50600,53000,55400,57800,
# # # #                        60800,63800)
# # # # $LEAVE_TYPES     = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # # $OT_TYPES        = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # # $PERF_GRADES     = @("SS+","SS","S","A+","A","B+","B")
# # # # $ALLOWANCE_TYPES = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # # $ADJ_TYPES       = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # # function Get-InsuredSalary([int]$baseSalary) {
# # # #     $b = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # # #     if ($null -eq $b) { $b = $INSURED_BRACKETS[-1] }
# # # #     return $b
# # # # }
# # # # function Get-RandomLeaves {
# # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # #     [System.Collections.ArrayList]$r = @()
# # # #     if ($count -eq 0) { return ,$r }
# # # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # # #     foreach ($lt in $picked) {
# # # #         $h = Get-Random -Minimum 1 -Maximum 9
# # # #         $null = $r.Add([PSCustomObject]@{
# # # #             leaveTypeName=$lt; leaveDays=[math]::Round($h/8,3)
# # # #             leaveHours=$h; deductionRate=1.0; affectFullAttendance=$true
# # # #         })
# # # #     }
# # # #     return ,$r
# # # # }
# # # # function Get-RandomOvertimes {
# # # #     $count = Get-Random -Minimum 0 -Maximum 4
# # # #     [System.Collections.ArrayList]$r = @()
# # # #     if ($count -eq 0) { return ,$r }
# # # #     $picked = $OT_TYPES | Get-Random -Count $count
# # # #     foreach ($ot in $picked) {
# # # #         $null = $r.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # # #     }
# # # #     return ,$r
# # # # }
# # # # function Get-RandomPerformance([string]$empId) {
# # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # #     return [PSCustomObject]@{
# # # #         employeeId=$empId; companyId=$COMPANY_ID
# # # #         grade=($PERF_GRADES | Get-Random)
# # # #         score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1)
# # # #         confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8)
# # # #     }
# # # # }
# # # # function Get-RandomAttendance([string]$empId) {
# # # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # # #     $lc  = Get-Random -Minimum 0 -Maximum 5
# # # #     $ec  = Get-Random -Minimum 0 -Maximum 4
# # # #     $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # # #     return [PSCustomObject]@{
# # # #         employeeId=$empId; companyId=$COMPANY_ID
# # # #         lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs
# # # #         workDays=[math]::Max(0,22-[int]$abs); requiredWorkDays=22
# # # #         hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0)
# # # #         lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15)
# # # #     }
# # # # }
# # # # function Get-RandomAllowances([string]$empId) {
# # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # #     [System.Collections.ArrayList]$r = @()
# # # #     if ($count -eq 0) { return ,$r }
# # # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # # #     foreach ($at in $picked) {
# # # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # # #         $null = $r.Add([PSCustomObject]@{
# # # #             employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at
# # # #             amount=(Get-Random -Minimum 500 -Maximum 5000)
# # # #             approved=$appr; approvedBy=if($appr){"MGR"}else{$null}
# # # #         })
# # # #     }
# # # #     return ,$r
# # # # }
# # # # function Get-RandomProjects([string]$empId) {
# # # #     $count = Get-Random -Minimum 0 -Maximum 3
# # # #     [System.Collections.ArrayList]$r = @()
# # # #     if ($count -eq 0) { return ,$r }
# # # #     for ($i = 1; $i -le $count; $i++) {
# # # #         $null = $r.Add([PSCustomObject]@{
# # # #             employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"
# # # #             role=(@("LEAD","MEMBER")|Get-Random)
# # # #             completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6)
# # # #             bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2)
# # # #         })
# # # #     }
# # # #     return ,$r
# # # # }
# # # # function Get-RandomSalaryAdjustments([string]$empId) {
# # # #     $count = Get-Random -Minimum 0 -Maximum 2
# # # #     [System.Collections.ArrayList]$r = @()
# # # #     if ($count -eq 0) { return ,$r }
# # # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # # #     foreach ($at in $picked) {
# # # #         $isPos = $at -ne "DEDUCTION"
# # # #         $amt   = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # # #         $null  = $r.Add([PSCustomObject]@{
# # # #             employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false
# # # #         })
# # # #     }
# # # #     return ,$r
# # # # }

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 1. 產生測試資料（一次產生，兩端共用完全相同的 payload）
# # # # # ──────────────────────────────────────────────────────────────
# # # # Write-Host "產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆資料..." -ForegroundColor Cyan
# # # # [System.Collections.ArrayList]$batch = @()
# # # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # # #     $base  = Get-Random -Minimum 30000 -Maximum 100000

# # # #     [System.Collections.ArrayList]$perfArr = @()
# # # #     $perf = Get-RandomPerformance -empId $empId
# # # #     if ($null -ne $perf) { $null = $perfArr.Add($perf) }

# # # #     [System.Collections.ArrayList]$attArr = @()
# # # #     $att = Get-RandomAttendance -empId $empId
# # # #     if ($null -ne $att) { $null = $attArr.Add($att) }

# # # #     $null = $batch.Add([PSCustomObject]@{
# # # #         employeeId          = $empId
# # # #         companyId           = $COMPANY_ID
# # # #         baseSalary          = $base
# # # #         tenureMonths        = 24
# # # #         seniorityMonths     = 24
# # # #         laborInsuredSalary  = (Get-InsuredSalary $base)
# # # #         healthInsuredSalary = (Get-InsuredSalary $base)
# # # #         pensionSalary       = (Get-InsuredSalary $base)
# # # #         workingDaysInMonth  = 22
# # # #         leaves              = Get-RandomLeaves
# # # #         overtimes           = Get-RandomOvertimes
# # # #         allowances          = Get-RandomAllowances -empId $empId
# # # #         projects            = Get-RandomProjects   -empId $empId
# # # #         salaryAdjustments   = Get-RandomSalaryAdjustments -empId $empId
# # # #         performances        = $perfArr
# # # #         attendances         = $attArr
# # # #     })
# # # # }

# # # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress
# # # # Write-Host "Payload 長度：$($batchPayload.Length) bytes" -ForegroundColor White

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 2. 預熱（排除冷啟動與 Drools 規則編譯耗時）
# # # # # ──────────────────────────────────────────────────────────────
# # # # Write-Host "`n[預熱] 排除冷啟動..." -ForegroundColor Cyan
# # # # $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # # # $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # # # Start-Sleep -Seconds 2
# # # # Write-Host "預熱完畢" -ForegroundColor DarkGray

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 3. Legacy API — 批次呼叫（計算端對端總耗時 + 伺服器回報耗時）
# # # # # ──────────────────────────────────────────────────────────────
# # # # Write-Host "`n[測試 1] Legacy API（批次）..." -ForegroundColor Yellow
# # # # $legacyServerMs = 0L
# # # # $legacyTotalMs  = 0L
# # # # $legacyResp     = $null

# # # # try {
# # # #     $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # # #     $legacyRaw = Invoke-WebRequest -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $batchPayload
# # # #     $sw.Stop()
# # # #     $legacyTotalMs = $sw.ElapsedMilliseconds

# # # #     if ($legacyRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # #         $legacyServerMs = [long](@($legacyRaw.Headers["X-Execution-Time-Ms"])[0])
# # # #     }
# # # #     $legacyResp = $legacyRaw.Content | ConvertFrom-Json
# # # # } catch {
# # # #     Write-Host "Legacy 錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # }

# # # # Write-Host "Legacy 伺服器純運算: $legacyServerMs ms  |  端對端總耗時: $legacyTotalMs ms" -ForegroundColor Yellow

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 4. Drools API — 批次呼叫（計算端對端總耗時 + 伺服器回報耗時）
# # # # # ──────────────────────────────────────────────────────────────
# # # # Write-Host "`n[測試 2] Drools API（批次）..." -ForegroundColor Magenta
# # # # $droolsServerMs = 0L
# # # # $droolsTotalMs  = 0L
# # # # $droolsResp     = $null

# # # # try {
# # # #     $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # # #     $droolsRaw = Invoke-WebRequest -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
# # # #     $sw.Stop()
# # # #     $droolsTotalMs = $sw.ElapsedMilliseconds

# # # #     if ($droolsRaw.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
# # # #         $droolsServerMs = [long](@($droolsRaw.Headers["X-Drools-Pure-Compute-Ms"])[0])
# # # #     } elseif ($droolsRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # # #         $droolsServerMs = [long](@($droolsRaw.Headers["X-Execution-Time-Ms"])[0])
# # # #         Write-Host "（備援：使用 X-Execution-Time-Ms）" -ForegroundColor DarkGray
# # # #     }
# # # #     $droolsResp = $droolsRaw.Content | ConvertFrom-Json
# # # # } catch {
# # # #     Write-Host "Drools 錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # # # }

# # # # Write-Host "Drools 伺服器純運算: $droolsServerMs ms  |  端對端總耗時: $droolsTotalMs ms" -ForegroundColor Magenta

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 5. 計算結果比對
# # # # # ──────────────────────────────────────────────────────────────
# # # # Write-Host "`n[比對] Legacy vs Drools 計算結果..." -ForegroundColor Green

# # # # $legacyMap = @{}
# # # # if ($null -ne $legacyResp) {
# # # #     foreach ($item in $legacyResp) {
# # # #         if ($null -ne $item -and $null -ne $item.employeeId) {
# # # #             $legacyMap[$item.employeeId] = $item
# # # #         }
# # # #     }
# # # # }

# # # # $droolsMap = @{}
# # # # if ($null -ne $droolsResp) {
# # # #     foreach ($item in $droolsResp) {
# # # #         if ($null -ne $item -and $null -ne $item.employeeId) {
# # # #             $droolsMap[$item.employeeId] = $item
# # # #         }
# # # #     }
# # # # }

# # # # $matched    = 0
# # # # $mismatched = 0
# # # # $missing    = 0

# # # # foreach ($empId in ($batch | Select-Object -ExpandProperty employeeId)) {
# # # #     $hasLegacy = $legacyMap.ContainsKey($empId)
# # # #     $hasDrools = $droolsMap.ContainsKey($empId)

# # # #     if (-not $hasLegacy -or -not $hasDrools) {
# # # #         Write-Host "  ⚠ $empId — 資料缺失 (Legacy:$hasLegacy / Drools:$hasDrools)" -ForegroundColor Yellow
# # # #         $missing++
# # # #         continue
# # # #     }

# # # #     $legacyResult = $legacyMap[$empId].result
# # # #     $droolsResult = $droolsMap[$empId].result

# # # #     $legacySalary = if ($null -ne $legacyResult) { [decimal]$legacyResult.finalSalary } else { [decimal]-1 }
# # # #     $droolsSalary = if ($null -ne $droolsResult) { [decimal]$droolsResult.finalSalary } else { [decimal]-1 }

# # # #     if ($legacySalary -eq $droolsSalary) {
# # # #         Write-Host "  ✅ $empId  finalSalary = $legacySalary" -ForegroundColor Green
# # # #         $matched++
# # # #     } else {
# # # #         $diff = $droolsSalary - $legacySalary
# # # #         Write-Host ""
# # # #         Write-Host "  ❌ $empId" -ForegroundColor Red
# # # #         Write-Host "     Legacy : $legacySalary" -ForegroundColor Yellow
# # # #         Write-Host "     Drools : $droolsSalary" -ForegroundColor Magenta
# # # #         Write-Host "     差額   : $diff" -ForegroundColor Red
# # # #         Write-Host "  --- Legacy ruleDetails ---" -ForegroundColor Yellow
# # # #         if ($null -ne $legacyResult) { $legacyResult.ruleDetails | ForEach-Object { Write-Host "    $_" } }
# # # #         Write-Host "  --- Drools ruleDetails ---" -ForegroundColor Magenta
# # # #         if ($null -ne $droolsResult) { $droolsResult.ruleDetails | ForEach-Object { Write-Host "    $_" } }
# # # #         $mismatched++
# # # #     }
# # # # }

# # # # # ──────────────────────────────────────────────────────────────
# # # # # 6. 最終摘要
# # # # # ──────────────────────────────────────────────────────────────
# # # # $avgLegacyServer = if ($BATCH_SIZE -gt 0) { [math]::Round($legacyServerMs / $BATCH_SIZE, 2) } else { 0 }
# # # # $avgDroolsServer = if ($BATCH_SIZE -gt 0) { [math]::Round($droolsServerMs / $BATCH_SIZE, 4) } else { 0 }
# # # # $avgLegacyTotal  = if ($BATCH_SIZE -gt 0) { [math]::Round($legacyTotalMs  / $BATCH_SIZE, 2) } else { 0 }
# # # # $avgDroolsTotal  = if ($BATCH_SIZE -gt 0) { [math]::Round($droolsTotalMs  / $BATCH_SIZE, 4) } else { 0 }

# # # # Write-Host ""
# # # # Write-Host "╔══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
# # # # Write-Host "║          效能 & 正確性總結報告（$BATCH_SIZE 筆）" -ForegroundColor Cyan
# # # # Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # Write-Host "║  【Legacy 硬編碼 If-Else】" -ForegroundColor Yellow
# # # # Write-Host "║    伺服器純運算  : $legacyServerMs ms  (平均 $avgLegacyServer ms/筆)" -ForegroundColor Yellow
# # # # Write-Host "║    端對端總耗時  : $legacyTotalMs ms  (平均 $avgLegacyTotal ms/筆)" -ForegroundColor Yellow
# # # # Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # Write-Host "║  【Drools 規則引擎（Rete）】" -ForegroundColor Magenta
# # # # Write-Host "║    伺服器純運算  : $droolsServerMs ms  (平均 $avgDroolsServer ms/筆)" -ForegroundColor Magenta
# # # # Write-Host "║    端對端總耗時  : $droolsTotalMs ms  (平均 $avgDroolsTotal ms/筆)" -ForegroundColor Magenta
# # # # Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan

# # # # # 效能比較（以伺服器純運算為準）
# # # # if ($legacyServerMs -gt 0 -and $droolsServerMs -gt 0) {
# # # #     if ($legacyServerMs -le $droolsServerMs) {
# # # #         $ratio = [math]::Round($droolsServerMs / $legacyServerMs, 2)
# # # #         Write-Host "║  效能：Legacy 較快，Drools 耗時是 Legacy 的 $ratio 倍" -ForegroundColor Green
# # # #     } else {
# # # #         $ratio = [math]::Round($legacyServerMs / $droolsServerMs, 2)
# # # #         Write-Host "║  效能：Drools 較快，Legacy 耗時是 Drools 的 $ratio 倍" -ForegroundColor Green
# # # #     }
# # # # } elseif ($droolsServerMs -eq 0 -and $legacyServerMs -gt 0) {
# # # #     Write-Host "║  效能：Drools 趨近 0ms，壓倒性優勢" -ForegroundColor Green
# # # # } else {
# # # #     Write-Host "║  效能：無法計算（耗時資料不足）" -ForegroundColor Yellow
# # # # }

# # # # Write-Host "╠══════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # # $correctnessColor = if ($mismatched -eq 0 -and $missing -eq 0) { "Green" } else { "Red" }
# # # # Write-Host "║  正確性：✅ 一致 $matched 筆  ❌ 不一致 $mismatched 筆  ⚠ 缺失 $missing 筆" -ForegroundColor $correctnessColor
# # # # Write-Host "╚══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
# # # $BASE_URL   = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
# # # $DROOLS_URL = "$BASE_URL/calculatesalary"
# # # $LEGACY_URL = "$BASE_URL/checksalary/legacy"
# # # $COMPANY_ID = "25"
# # # $BATCH_SIZE = 500   # 每次送出筆數
# # # $ROUNDS     = 7     # 正式跑幾輪（建議奇數，去頭去尾後至少剩 3 輪）

# # # # ──────────────────────────────────────────────────────────────
# # # # 輔助資料
# # # # ──────────────────────────────────────────────────────────────
# # # $INSURED_BRACKETS = @(26400,27600,28800,30300,31800,33300,34800,36300,38200,
# # #                        40100,42000,43900,45800,48200,50600,53000,55400,57800,
# # #                        60800,63800)
# # # $LEAVE_TYPES     = @("事假","普通病假","特休","婚假","喪假","公假","生理假","陪產假","曠職")
# # # $OT_TYPES        = @("WEEKDAY","REST_DAY","NATIONAL_HOLIDAY","STATUTORY_HOLIDAY")
# # # $PERF_GRADES     = @("SS+","SS","S","A+","A","B+","B")
# # # $ALLOWANCE_TYPES = @("TRANSPORTATION","MEAL","HOUSING","CERTIFICATE","SPECIAL")
# # # $ADJ_TYPES       = @("BONUS","DEDUCTION","SPECIAL","RAISE")

# # # function Get-InsuredSalary([int]$baseSalary) {
# # #     $b = $INSURED_BRACKETS | Where-Object { $_ -ge $baseSalary } | Select-Object -First 1
# # #     if ($null -eq $b) { $b = $INSURED_BRACKETS[-1] }
# # #     return $b
# # # }
# # # function Get-RandomLeaves {
# # #     $count = Get-Random -Minimum 0 -Maximum 4
# # #     [System.Collections.ArrayList]$r = @()
# # #     if ($count -eq 0) { return ,$r }
# # #     $picked = $LEAVE_TYPES | Get-Random -Count $count
# # #     foreach ($lt in $picked) {
# # #         $h = Get-Random -Minimum 1 -Maximum 9
# # #         $null = $r.Add([PSCustomObject]@{
# # #             leaveTypeName=$lt; leaveDays=[math]::Round($h/8,3)
# # #             leaveHours=$h; deductionRate=1.0; affectFullAttendance=$true
# # #         })
# # #     }
# # #     return ,$r
# # # }
# # # function Get-RandomOvertimes {
# # #     $count = Get-Random -Minimum 0 -Maximum 4
# # #     [System.Collections.ArrayList]$r = @()
# # #     if ($count -eq 0) { return ,$r }
# # #     $picked = $OT_TYPES | Get-Random -Count $count
# # #     foreach ($ot in $picked) {
# # #         $null = $r.Add([PSCustomObject]@{ overtimeType=$ot; overtimeHours=Get-Random -Minimum 1 -Maximum 9 })
# # #     }
# # #     return ,$r
# # # }
# # # function Get-RandomPerformance([string]$empId) {
# # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # #     return [PSCustomObject]@{
# # #         employeeId=$empId; companyId=$COMPANY_ID
# # #         grade=($PERF_GRADES | Get-Random)
# # #         score=[math]::Round((Get-Random -Minimum 60 -Maximum 100)+(Get-Random),1)
# # #         confirmed=((Get-Random -Minimum 0 -Maximum 10) -lt 8)
# # #     }
# # # }
# # # function Get-RandomAttendance([string]$empId) {
# # #     if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) { return $null }
# # #     $lc  = Get-Random -Minimum 0 -Maximum 5
# # #     $ec  = Get-Random -Minimum 0 -Maximum 4
# # #     $abs = [math]::Round((Get-Random -Minimum 0 -Maximum 4)*0.5,1)
# # #     return [PSCustomObject]@{
# # #         employeeId=$empId; companyId=$COMPANY_ID
# # #         lateCount=$lc; earlyLeaveCount=$ec; absentDays=$abs
# # #         workDays=[math]::Max(0,22-[int]$abs); requiredWorkDays=22
# # #         hasFullAttendance=($lc -eq 0 -and $ec -eq 0 -and $abs -eq 0)
# # #         lateMinutesTotal=($lc*15); earlyLeaveMinutesTotal=($ec*15)
# # #     }
# # # }
# # # function Get-RandomAllowances([string]$empId) {
# # #     $count = Get-Random -Minimum 0 -Maximum 3
# # #     [System.Collections.ArrayList]$r = @()
# # #     if ($count -eq 0) { return ,$r }
# # #     $picked = $ALLOWANCE_TYPES | Get-Random -Count $count
# # #     foreach ($at in $picked) {
# # #         $appr = ((Get-Random -Minimum 0 -Maximum 10) -lt 7)
# # #         $null = $r.Add([PSCustomObject]@{
# # #             employeeId=$empId; companyId=$COMPANY_ID; allowanceType=$at
# # #             amount=(Get-Random -Minimum 500 -Maximum 5000)
# # #             approved=$appr; approvedBy=if($appr){"MGR"}else{$null}
# # #         })
# # #     }
# # #     return ,$r
# # # }
# # # function Get-RandomProjects([string]$empId) {
# # #     $count = Get-Random -Minimum 0 -Maximum 3
# # #     [System.Collections.ArrayList]$r = @()
# # #     if ($count -eq 0) { return ,$r }
# # #     for ($i = 1; $i -le $count; $i++) {
# # #         $null = $r.Add([PSCustomObject]@{
# # #             employeeId=$empId; companyId=$COMPANY_ID; projectId="P$i"
# # #             role=(@("LEAD","MEMBER")|Get-Random)
# # #             completed=((Get-Random -Minimum 0 -Maximum 10) -lt 6)
# # #             bonusRate=[math]::Round((Get-Random -Minimum 1 -Maximum 10)*0.01,2)
# # #         })
# # #     }
# # #     return ,$r
# # # }
# # # function Get-RandomSalaryAdjustments([string]$empId) {
# # #     $count = Get-Random -Minimum 0 -Maximum 2
# # #     [System.Collections.ArrayList]$r = @()
# # #     if ($count -eq 0) { return ,$r }
# # #     $picked = $ADJ_TYPES | Get-Random -Count $count
# # #     foreach ($at in $picked) {
# # #         $isPos = $at -ne "DEDUCTION"
# # #         $amt   = if ($isPos) { Get-Random -Minimum 500 -Maximum 8000 } else { -(Get-Random -Minimum 200 -Maximum 3000) }
# # #         $null  = $r.Add([PSCustomObject]@{
# # #             employeeId=$empId; companyId=$COMPANY_ID; adjustmentType=$at; amount=$amt; applied=$false
# # #         })
# # #     }
# # #     return ,$r
# # # }

# # # # ──────────────────────────────────────────────────────────────
# # # # 產生一份固定測試資料（所有輪次共用，確保公平）
# # # # ──────────────────────────────────────────────────────────────
# # # Write-Host "產生公司 $COMPANY_ID 的 $BATCH_SIZE 筆固定測試資料..." -ForegroundColor Cyan
# # # [System.Collections.ArrayList]$batch = @()
# # # for ($i = 1; $i -le $BATCH_SIZE; $i++) {
# # #     $empId = "C$COMPANY_ID-E" + $i.ToString("D3")
# # #     $base  = Get-Random -Minimum 30000 -Maximum 100000

# # #     [System.Collections.ArrayList]$perfArr = @()
# # #     $perf = Get-RandomPerformance -empId $empId
# # #     if ($null -ne $perf) { $null = $perfArr.Add($perf) }

# # #     [System.Collections.ArrayList]$attArr = @()
# # #     $att = Get-RandomAttendance -empId $empId
# # #     if ($null -ne $att) { $null = $attArr.Add($att) }

# # #     $null = $batch.Add([PSCustomObject]@{
# # #         employeeId          = $empId
# # #         companyId           = $COMPANY_ID
# # #         baseSalary          = $base
# # #         tenureMonths        = 24
# # #         seniorityMonths     = 24
# # #         laborInsuredSalary  = (Get-InsuredSalary $base)
# # #         healthInsuredSalary = (Get-InsuredSalary $base)
# # #         pensionSalary       = (Get-InsuredSalary $base)
# # #         workingDaysInMonth  = 22
# # #         leaves              = Get-RandomLeaves
# # #         overtimes           = Get-RandomOvertimes
# # #         allowances          = Get-RandomAllowances -empId $empId
# # #         projects            = Get-RandomProjects   -empId $empId
# # #         salaryAdjustments   = Get-RandomSalaryAdjustments -empId $empId
# # #         performances        = $perfArr
# # #         attendances         = $attArr
# # #     })
# # # }
# # # $batchPayload = $batch | ConvertTo-Json -Depth 10 -Compress
# # # Write-Host "Payload 長度：$($batchPayload.Length) bytes" -ForegroundColor White

# # # # ──────────────────────────────────────────────────────────────
# # # # 預熱（讓 JVM、Drools Rete 樹、Legacy 規則快取全部到位）
# # # # ──────────────────────────────────────────────────────────────
# # # Write-Host "`n[預熱] 各跑 2 次，排除冷啟動與規則編譯..." -ForegroundColor Cyan
# # # for ($w = 1; $w -le 2; $w++) {
# # #     $null = Invoke-RestMethod -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # #     $null = Invoke-RestMethod -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # # }
# # # Start-Sleep -Seconds 3
# # # Write-Host "預熱完畢，等待 3 秒讓伺服器穩定..." -ForegroundColor DarkGray

# # # # ──────────────────────────────────────────────────────────────
# # # # 正式 N 輪測試
# # # # ──────────────────────────────────────────────────────────────
# # # Write-Host "`n[正式測試] 開始跑 $ROUNDS 輪..." -ForegroundColor Cyan

# # # [System.Collections.ArrayList]$legacyServerList = @()  # 每輪伺服器純運算
# # # [System.Collections.ArrayList]$legacyTotalList  = @()  # 每輪端對端
# # # [System.Collections.ArrayList]$droolsServerList = @()
# # # [System.Collections.ArrayList]$droolsTotalList  = @()

# # # # 最後一輪的回應留下來做正確性比對
# # # $lastLegacyResp = $null
# # # $lastDroolsResp = $null

# # # for ($round = 1; $round -le $ROUNDS; $round++) {
# # #     Write-Host "  第 $round / $ROUNDS 輪..." -ForegroundColor DarkGray

# # #     # ── Legacy ──
# # #     try {
# # #         $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # #         $legacyRaw = Invoke-WebRequest -Method Post -Uri $LEGACY_URL -ContentType "application/json" -Body $batchPayload
# # #         $sw.Stop()

# # #         $lServer = 0L
# # #         if ($legacyRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # #             $lServer = [long](@($legacyRaw.Headers["X-Execution-Time-Ms"])[0])
# # #         }
# # #         $null = $legacyServerList.Add($lServer)
# # #         $null = $legacyTotalList.Add($sw.ElapsedMilliseconds)

# # #         if ($round -eq $ROUNDS) { $lastLegacyResp = $legacyRaw.Content | ConvertFrom-Json }
# # #     } catch {
# # #         Write-Host "  Legacy 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # #         $null = $legacyServerList.Add(0L)
# # #         $null = $legacyTotalList.Add(0L)
# # #     }

# # #     # ── Drools ──
# # #     try {
# # #         $sw = [System.Diagnostics.Stopwatch]::StartNew()
# # #         $droolsRaw = Invoke-WebRequest -Method Post -Uri $DROOLS_URL -ContentType "application/json" -Body $batchPayload
# # #         $sw.Stop()

# # #         $dServer = 0L
# # #         if ($droolsRaw.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
# # #             $dServer = [long](@($droolsRaw.Headers["X-Drools-Pure-Compute-Ms"])[0])
# # #         } elseif ($droolsRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
# # #             $dServer = [long](@($droolsRaw.Headers["X-Execution-Time-Ms"])[0])
# # #         }
# # #         $null = $droolsServerList.Add($dServer)
# # #         $null = $droolsTotalList.Add($sw.ElapsedMilliseconds)

# # #         if ($round -eq $ROUNDS) { $lastDroolsResp = $droolsRaw.Content | ConvertFrom-Json }
# # #     } catch {
# # #         Write-Host "  Drools 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
# # #         $null = $droolsServerList.Add(0L)
# # #         $null = $droolsTotalList.Add(0L)
# # #     }

# # #     # 輪次間稍微等一下，避免伺服器資源爭用
# # #     if ($round -lt $ROUNDS) { Start-Sleep -Milliseconds 500 }
# # # }

# # # # ──────────────────────────────────────────────────────────────
# # # # 統計：去掉最大值與最小值後取平均（Trimmed Mean）
# # # # ──────────────────────────────────────────────────────────────
# # # function Get-TrimmedAvg([System.Collections.ArrayList]$list) {
# # #     if ($list.Count -le 2) {
# # #         # 太少輪次就直接算平均
# # #         return [math]::Round(($list | Measure-Object -Sum).Sum / [math]::Max($list.Count,1), 2)
# # #     }
# # #     $sorted  = $list | Sort-Object
# # #     # 去頭去尾各一個
# # #     $trimmed = $sorted[1..($sorted.Count - 2)]
# # #     return [math]::Round(($trimmed | Measure-Object -Sum).Sum / $trimmed.Count, 2)
# # # }

# # # function Get-StatSummary([System.Collections.ArrayList]$list) {
# # #     $sorted = $list | Sort-Object
# # #     $min    = $sorted[0]
# # #     $max    = $sorted[-1]
# # #     $avg    = Get-TrimmedAvg $list
# # #     return [PSCustomObject]@{ Min=$min; Max=$max; TrimmedAvg=$avg }
# # # }

# # # $lServerStat = Get-StatSummary $legacyServerList
# # # $lTotalStat  = Get-StatSummary $legacyTotalList
# # # $dServerStat = Get-StatSummary $droolsServerList
# # # $dTotalStat  = Get-StatSummary $droolsTotalList

# # # # ──────────────────────────────────────────────────────────────
# # # # 正確性比對（使用最後一輪的回應）
# # # # ──────────────────────────────────────────────────────────────
# # # Write-Host "`n[比對] 最後一輪 Legacy vs Drools 計算結果..." -ForegroundColor Green

# # # $legacyMap = @{}
# # # if ($null -ne $lastLegacyResp) {
# # #     foreach ($item in $lastLegacyResp) {
# # #         if ($null -ne $item -and $null -ne $item.employeeId) {
# # #             $legacyMap[$item.employeeId] = $item
# # #         }
# # #     }
# # # }
# # # $droolsMap = @{}
# # # if ($null -ne $lastDroolsResp) {
# # #     foreach ($item in $lastDroolsResp) {
# # #         if ($null -ne $item -and $null -ne $item.employeeId) {
# # #             $droolsMap[$item.employeeId] = $item
# # #         }
# # #     }
# # # }

# # # $matched    = 0
# # # $mismatched = 0
# # # $missing    = 0

# # # foreach ($empId in ($batch | Select-Object -ExpandProperty employeeId)) {
# # #     $hasLegacy = $legacyMap.ContainsKey($empId)
# # #     $hasDrools = $droolsMap.ContainsKey($empId)

# # #     if (-not $hasLegacy -or -not $hasDrools) {
# # #         Write-Host "  ⚠ $empId — 資料缺失 (Legacy:$hasLegacy / Drools:$hasDrools)" -ForegroundColor Yellow
# # #         $missing++
# # #         continue
# # #     }

# # #     $legacyResult = $legacyMap[$empId].result
# # #     $droolsResult = $droolsMap[$empId].result
# # #     $legacySalary = if ($null -ne $legacyResult) { [decimal]$legacyResult.finalSalary } else { [decimal]-1 }
# # #     $droolsSalary = if ($null -ne $droolsResult) { [decimal]$droolsResult.finalSalary } else { [decimal]-1 }

# # #     if ($legacySalary -eq $droolsSalary) {
# # #         Write-Host "  ✅ $empId  finalSalary = $legacySalary" -ForegroundColor Green
# # #         $matched++
# # #     } else {
# # #         $diff = $droolsSalary - $legacySalary
# # #         Write-Host ""
# # #         Write-Host "  ❌ $empId" -ForegroundColor Red
# # #         Write-Host "     Legacy : $legacySalary" -ForegroundColor Yellow
# # #         Write-Host "     Drools : $droolsSalary" -ForegroundColor Magenta
# # #         Write-Host "     差額   : $diff" -ForegroundColor Red
# # #         Write-Host "  --- Legacy ruleDetails ---" -ForegroundColor Yellow
# # #         if ($null -ne $legacyResult) { $legacyResult.ruleDetails | ForEach-Object { Write-Host "    $_" } }
# # #         Write-Host "  --- Drools ruleDetails ---" -ForegroundColor Magenta
# # #         if ($null -ne $droolsResult) { $droolsResult.ruleDetails | ForEach-Object { Write-Host "    $_" } }
# # #         $mismatched++
# # #     }
# # # }

# # # # ──────────────────────────────────────────────────────────────
# # # # 最終摘要報告
# # # # ──────────────────────────────────────────────────────────────
# # # $avgLegacyServerPerItem = [math]::Round($lServerStat.TrimmedAvg / $BATCH_SIZE, 4)
# # # $avgDroolsServerPerItem = [math]::Round($dServerStat.TrimmedAvg / $BATCH_SIZE, 4)
# # # $avgLegacyTotalPerItem  = [math]::Round($lTotalStat.TrimmedAvg  / $BATCH_SIZE, 4)
# # # $avgDroolsTotalPerItem  = [math]::Round($dTotalStat.TrimmedAvg  / $BATCH_SIZE, 4)

# # # # 效能比（以伺服器純運算 TrimmedAvg 為準）
# # # $perfNote = ""
# # # if ($lServerStat.TrimmedAvg -gt 0 -and $dServerStat.TrimmedAvg -gt 0) {
# # #     if ($lServerStat.TrimmedAvg -le $dServerStat.TrimmedAvg) {
# # #         $ratio    = [math]::Round($dServerStat.TrimmedAvg / $lServerStat.TrimmedAvg, 2)
# # #         $perfNote = "Legacy 較快，Drools 耗時是 Legacy 的 $ratio 倍"
# # #     } else {
# # #         $ratio    = [math]::Round($lServerStat.TrimmedAvg / $dServerStat.TrimmedAvg, 2)
# # #         $perfNote = "Drools 較快，Legacy 耗時是 Drools 的 $ratio 倍"
# # #     }
# # # } elseif ($dServerStat.TrimmedAvg -eq 0 -and $lServerStat.TrimmedAvg -gt 0) {
# # #     $perfNote = "Drools 趨近 0ms，壓倒性優勢"
# # # } else {
# # #     $perfNote = "無法計算（耗時資料不足）"
# # # }

# # # $correctnessColor = if ($mismatched -eq 0 -and $missing -eq 0) { "Green" } else { "Red" }

# # # Write-Host ""
# # # Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
# # # Write-Host "║   效能 & 正確性總結（$BATCH_SIZE 筆 × $ROUNDS 輪，去頭尾取平均）" -ForegroundColor Cyan
# # # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # Write-Host "║  各輪原始數據（伺服器純運算 ms）" -ForegroundColor DarkGray
# # # for ($i = 0; $i -lt $ROUNDS; $i++) {
# # #     Write-Host ("║    輪 {0}  Legacy={1,6} ms   Drools={2,6} ms" -f ($i+1), $legacyServerList[$i], $droolsServerList[$i]) -ForegroundColor DarkGray
# # # }
# # # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # Write-Host "║  【Legacy 硬編碼 If-Else】" -ForegroundColor Yellow
# # # Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lServerStat.Min, $lServerStat.Max, $lServerStat.TrimmedAvg, $avgLegacyServerPerItem) -ForegroundColor Yellow
# # # Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lTotalStat.Min,  $lTotalStat.Max,  $lTotalStat.TrimmedAvg,  $avgLegacyTotalPerItem)  -ForegroundColor Yellow
# # # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # Write-Host "║  【Drools 規則引擎（Rete）】" -ForegroundColor Magenta
# # # Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dServerStat.Min, $dServerStat.Max, $dServerStat.TrimmedAvg, $avgDroolsServerPerItem) -ForegroundColor Magenta
# # # Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dTotalStat.Min,  $dTotalStat.Max,  $dTotalStat.TrimmedAvg,  $avgDroolsTotalPerItem)  -ForegroundColor Magenta
# # # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # Write-Host "║  效能（伺服器純運算 TrimmedAvg 為基準）：$perfNote" -ForegroundColor Green
# # # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # # Write-Host "║  正確性：✅ 一致 $matched 筆  ❌ 不一致 $mismatched 筆  ⚠ 缺失 $missing 筆" -ForegroundColor $correctnessColor
# # # Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
# # $uri1 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"
# # $uri2 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"

# # $MULTIPLIER = 10      # ← 改這裡：1=22筆 / 2=44筆 / 3=66筆 / 以此類推
# # $ROUNDS     = 7      # 正式輪次（去頭尾取 5 輪平均）

# # # ── 22 筆固定案例（與正確性測試相同）──────────────────────────
# # $baseCases = @(
# #     '{"companyId":"25","employeeId":"T_L01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L01","companyId":"25","lateCount":3,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":45,"earlyLeaveMinutesTotal":0}]}',
# #     '{"companyId":"25","employeeId":"T_L02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L02","companyId":"25","lateCount":6,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":90,"earlyLeaveMinutesTotal":0}]}',
# #     '{"companyId":"25","employeeId":"T_L03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L03","companyId":"25","lateCount":9,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":135,"earlyLeaveMinutesTotal":0}]}',
# #     '{"companyId":"25","employeeId":"T_L04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L04","companyId":"25","lateCount":10,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":150,"earlyLeaveMinutesTotal":0}]}',
# #     '{"companyId":"25","employeeId":"T_E01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E01","companyId":"25","lateCount":0,"earlyLeaveCount":3,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":45}]}',
# #     '{"companyId":"25","employeeId":"T_E02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E02","companyId":"25","lateCount":0,"earlyLeaveCount":6,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":90}]}',
# #     '{"companyId":"25","employeeId":"T_P01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P01","companyId":"25","grade":"SS+","score":99,"confirmed":true}]}',
# #     '{"companyId":"25","employeeId":"T_P02","baseSalary":80000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P02","companyId":"25","grade":"B","score":61,"confirmed":true}]}',
# #     '{"companyId":"25","employeeId":"T_P03","baseSalary":50000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
# #     '{"companyId":"25","employeeId":"T_P04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"SALES","performances":[{"employeeId":"T_P04","companyId":"25","grade":"SS+","score":99,"confirmed":true}]}',
# #     '{"companyId":"25","employeeId":"T_O01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O01","overtimeType":"WEEKDAY","overtimeHours":4}]}',
# #     '{"companyId":"25","employeeId":"T_O02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O02","overtimeType":"WEEKDAY","overtimeHours":4},{"employeeId":"T_O02","overtimeType":"REST_DAY","overtimeHours":4}]}',
# #     '{"companyId":"25","employeeId":"T_O03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O03","overtimeType":"WEEKDAY","overtimeHours":2},{"employeeId":"T_O03","overtimeType":"REST_DAY","overtimeHours":3},{"employeeId":"T_O03","overtimeType":"NATIONAL_HOLIDAY","overtimeHours":4}]}',
# #     '{"companyId":"25","employeeId":"T_O04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O04","overtimeType":"WEEKDAY","overtimeHours":3},{"employeeId":"T_O04","overtimeType":"REST_DAY","overtimeHours":3}],"attendances":[{"employeeId":"T_O04","companyId":"25","lateCount":0,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":true,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":0}]}',
# #     '{"companyId":"25","employeeId":"T_R01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R01","leaveTypeName":"事假","leaveHours":8}]}',
# #     '{"companyId":"25","employeeId":"T_R02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R02","leaveTypeName":"曠職","leaveHours":8}]}',
# #     '{"companyId":"25","employeeId":"T_R03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R03","leaveTypeName":"特休","leaveHours":8}]}',
# #     '{"companyId":"25","employeeId":"T_R04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimeFacts":[{"employeeId":"T_R04","overtimeType":"WEEKDAY","overtimeHours":4}]}',
# #     '{"companyId":"25","employeeId":"T_R05","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","department":"RD","overtimeFacts":[{"employeeId":"T_R05","overtimeType":"REST_DAY","overtimeHours":8}]}',
# #     '{"companyId":"25","employeeId":"T_R06","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
# #     '{"companyId":"25","employeeId":"T_R07","baseSalary":80000,"tenureMonths":36,"seniorityMonths":36,"position":"MANAGER","leaveFacts":[{"employeeId":"T_R07","leaveTypeName":"事假","leaveHours":8}]}',
# #     '{"companyId":"25","employeeId":"T_R08","baseSalary":70000,"tenureMonths":120,"seniorityMonths":120,"position":"ENGINEER"}'
# # )

# # # ── 依倍數擴充：每份複製時給不同的 employeeId 避免重複 ──────────
# # [System.Collections.ArrayList]$scaledObjects = @()
# # for ($m = 1; $m -le $MULTIPLIER; $m++) {
# #     foreach ($json in $baseCases) {
# #         $obj = $json | ConvertFrom-Json
# #         # 加上倍數後綴，讓 employeeId 不重複
# #         $obj.employeeId = "$($obj.employeeId)_x$m"
# #         # attendances / performances 裡的 employeeId 也同步修改
# #         if ($null -ne $obj.attendances) {
# #             $obj.attendances | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" }
# #         }
# #         if ($null -ne $obj.performances) {
# #             $obj.performances | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" }
# #         }
# #         if ($null -ne $obj.overtimes) {
# #             $obj.overtimes | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" }
# #         }
# #         if ($null -ne $obj.overtimeFacts) {
# #             $obj.overtimeFacts | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" }
# #         }
# #         if ($null -ne $obj.leaveFacts) {
# #             $obj.leaveFacts | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" }
# #         }
# #         $null = $scaledObjects.Add($obj)
# #     }
# # }

# # $BATCH_SIZE   = $scaledObjects.Count
# # $batchPayload = $scaledObjects | ConvertTo-Json -Depth 10 -Compress

# # Write-Host "測試規模：$MULTIPLIER 倍 × 22 筆 = $BATCH_SIZE 筆  |  Payload：$([math]::Round($batchPayload.Length/1KB,1)) KB" -ForegroundColor Cyan

# # # ──────────────────────────────────────────────────────────────
# # # 預熱
# # # ──────────────────────────────────────────────────────────────
# # Write-Host "`n[預熱] 各打 2 次排除冷啟動..." -ForegroundColor Cyan
# # for ($w = 1; $w -le 2; $w++) {
# #     $null = Invoke-RestMethod -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# #     $null = Invoke-RestMethod -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# # }
# # Start-Sleep -Seconds 2
# # Write-Host "預熱完畢`n" -ForegroundColor DarkGray

# # # ──────────────────────────────────────────────────────────────
# # # 正式 N 輪測試
# # # ──────────────────────────────────────────────────────────────
# # [System.Collections.ArrayList]$legacyServerList = @()
# # [System.Collections.ArrayList]$legacyTotalList  = @()
# # [System.Collections.ArrayList]$droolsServerList = @()
# # [System.Collections.ArrayList]$droolsTotalList  = @()

# # Write-Host "[正式測試] $ROUNDS 輪..." -ForegroundColor Cyan

# # for ($round = 1; $round -le $ROUNDS; $round++) {
# #     Write-Host "  第 $round / $ROUNDS 輪..." -ForegroundColor DarkGray

# #     # Legacy
# #     try {
# #         $sw = [System.Diagnostics.Stopwatch]::StartNew()
# #         $lRaw = Invoke-WebRequest -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload
# #         $sw.Stop()
# #         $lServer = if ($lRaw.Headers.ContainsKey("X-Execution-Time-Ms")) { [long](@($lRaw.Headers["X-Execution-Time-Ms"])[0]) } else { 0L }
# #         $null = $legacyServerList.Add($lServer)
# #         $null = $legacyTotalList.Add($sw.ElapsedMilliseconds)
# #     } catch {
# #         Write-Host "  Legacy 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
# #         $null = $legacyServerList.Add(0L); $null = $legacyTotalList.Add(0L)
# #     }

# #     # Drools
# #     try {
# #         $sw = [System.Diagnostics.Stopwatch]::StartNew()
# #         $dRaw = Invoke-WebRequest -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload
# #         $sw.Stop()
# #         $dServer = if ($dRaw.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
# #             [long](@($dRaw.Headers["X-Drools-Pure-Compute-Ms"])[0])
# #         } elseif ($dRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
# #             [long](@($dRaw.Headers["X-Execution-Time-Ms"])[0])
# #         } else { 0L }
# #         $null = $droolsServerList.Add($dServer)
# #         $null = $droolsTotalList.Add($sw.ElapsedMilliseconds)
# #     } catch {
# #         Write-Host "  Drools 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
# #         $null = $droolsServerList.Add(0L); $null = $droolsTotalList.Add(0L)
# #     }

# #     if ($round -lt $ROUNDS) { Start-Sleep -Milliseconds 300 }
# # }

# # # ──────────────────────────────────────────────────────────────
# # # 統計：去頭尾取平均（Trimmed Mean）
# # # ──────────────────────────────────────────────────────────────
# # function Get-Stat([System.Collections.ArrayList]$list) {
# #     $s = $list | Sort-Object
# #     if ($s.Count -le 2) {
# #         $avg = [math]::Round(($s | Measure-Object -Sum).Sum / [math]::Max($s.Count,1), 2)
# #         return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
# #     }
# #     $trimmed = $s[1..($s.Count-2)]
# #     $avg = [math]::Round(($trimmed | Measure-Object -Sum).Sum / $trimmed.Count, 2)
# #     return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
# # }

# # $lSS = Get-Stat $legacyServerList
# # $lTS = Get-Stat $legacyTotalList
# # $dSS = Get-Stat $droolsServerList
# # $dTS = Get-Stat $droolsTotalList

# # $avgLSP = [math]::Round($lSS.TrimmedAvg / $BATCH_SIZE, 4)
# # $avgDSP = [math]::Round($dSS.TrimmedAvg / $BATCH_SIZE, 4)
# # $avgLTP = [math]::Round($lTS.TrimmedAvg / $BATCH_SIZE, 4)
# # $avgDTP = [math]::Round($dTS.TrimmedAvg / $BATCH_SIZE, 4)

# # $perfNote = if ($lSS.TrimmedAvg -gt 0 -and $dSS.TrimmedAvg -gt 0) {
# #     if ($lSS.TrimmedAvg -le $dSS.TrimmedAvg) {
# #         "Legacy 較快，Drools 耗時是 Legacy 的 $([math]::Round($dSS.TrimmedAvg/$lSS.TrimmedAvg,2)) 倍"
# #     } else {
# #         "Drools 較快，Legacy 耗時是 Drools 的 $([math]::Round($lSS.TrimmedAvg/$dSS.TrimmedAvg,2)) 倍"
# #     }
# # } else { "無法計算（耗時資料不足）" }

# # # ──────────────────────────────────────────────────────────────
# # # 最終報告
# # # ──────────────────────────────────────────────────────────────
# # Write-Host ""
# # Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
# # Write-Host "║  效能測試總結（${MULTIPLIER}x=${BATCH_SIZE} 筆 × $ROUNDS 輪，去頭尾 TrimmedAvg）" -ForegroundColor Cyan
# # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # Write-Host "║  各輪原始數據（伺服器純運算 ms）" -ForegroundColor DarkGray
# # for ($i = 0; $i -lt $ROUNDS; $i++) {
# #     Write-Host ("║    輪 {0}  Legacy={1,5} ms   Drools={2,5} ms" -f ($i+1), $legacyServerList[$i], $droolsServerList[$i]) -ForegroundColor DarkGray
# # }
# # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # Write-Host "║  【Legacy 硬編碼 If-Else】" -ForegroundColor Yellow
# # Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lSS.Min,$lSS.Max,$lSS.TrimmedAvg,$avgLSP) -ForegroundColor Yellow
# # Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lTS.Min,$lTS.Max,$lTS.TrimmedAvg,$avgLTP) -ForegroundColor Yellow
# # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # Write-Host "║  【Drools 規則引擎（Rete）】" -ForegroundColor Magenta
# # Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dSS.Min,$dSS.Max,$dSS.TrimmedAvg,$avgDSP) -ForegroundColor Magenta
# # Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dTS.Min,$dTS.Max,$dTS.TrimmedAvg,$avgDTP) -ForegroundColor Magenta
# # Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# # Write-Host "║  效能（伺服器純運算 TrimmedAvg）：$perfNote" -ForegroundColor Green
# # Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
# $uri1 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"
# $uri2 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"

# $MULTIPLIER = 22      # ← 改這裡：1=22筆 / 2=44筆 / 5=110筆 / 10=220筆
# $ROUNDS     = 3      # 正式輪次（去頭尾取 5 輪平均）

# # ── 22 筆固定案例（公司3，走通用規則 salary.drl，共 62 條）──────
# # 注意：companyId 改為 "3"，其餘資料結構與公司25相同
# $baseCases = @(
#     '{"companyId":"3","employeeId":"T_L01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L01","companyId":"3","lateCount":3,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":45,"earlyLeaveMinutesTotal":0}]}',
#     '{"companyId":"3","employeeId":"T_L02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L02","companyId":"3","lateCount":6,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":90,"earlyLeaveMinutesTotal":0}]}',
#     '{"companyId":"3","employeeId":"T_L03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L03","companyId":"3","lateCount":9,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":135,"earlyLeaveMinutesTotal":0}]}',
#     '{"companyId":"3","employeeId":"T_L04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L04","companyId":"3","lateCount":10,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":150,"earlyLeaveMinutesTotal":0}]}',
#     '{"companyId":"3","employeeId":"T_E01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E01","companyId":"3","lateCount":0,"earlyLeaveCount":3,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":45}]}',
#     '{"companyId":"3","employeeId":"T_E02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E02","companyId":"3","lateCount":0,"earlyLeaveCount":6,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":90}]}',
#     '{"companyId":"3","employeeId":"T_P01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P01","companyId":"3","grade":"SS+","score":99,"confirmed":true}]}',
#     '{"companyId":"3","employeeId":"T_P02","baseSalary":80000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P02","companyId":"3","grade":"B","score":61,"confirmed":true}]}',
#     '{"companyId":"3","employeeId":"T_P03","baseSalary":50000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
#     '{"companyId":"3","employeeId":"T_P04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"SALES","performances":[{"employeeId":"T_P04","companyId":"3","grade":"SS+","score":99,"confirmed":true}]}',
#     '{"companyId":"3","employeeId":"T_O01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O01","overtimeType":"WEEKDAY","overtimeHours":4}]}',
#     '{"companyId":"3","employeeId":"T_O02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O02","overtimeType":"WEEKDAY","overtimeHours":4},{"employeeId":"T_O02","overtimeType":"REST_DAY","overtimeHours":4}]}',
#     '{"companyId":"3","employeeId":"T_O03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O03","overtimeType":"WEEKDAY","overtimeHours":2},{"employeeId":"T_O03","overtimeType":"REST_DAY","overtimeHours":3},{"employeeId":"T_O03","overtimeType":"NATIONAL_HOLIDAY","overtimeHours":4}]}',
#     '{"companyId":"3","employeeId":"T_O04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O04","overtimeType":"WEEKDAY","overtimeHours":3},{"employeeId":"T_O04","overtimeType":"REST_DAY","overtimeHours":3}],"attendances":[{"employeeId":"T_O04","companyId":"3","lateCount":0,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":true,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":0}]}',
#     '{"companyId":"3","employeeId":"T_R01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R01","leaveTypeName":"事假","leaveHours":8}]}',
#     '{"companyId":"3","employeeId":"T_R02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R02","leaveTypeName":"曠職","leaveHours":8}]}',
#     '{"companyId":"3","employeeId":"T_R03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R03","leaveTypeName":"特休","leaveHours":8}]}',
#     '{"companyId":"3","employeeId":"T_R04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimeFacts":[{"employeeId":"T_R04","overtimeType":"WEEKDAY","overtimeHours":4}]}',
#     '{"companyId":"3","employeeId":"T_R05","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","department":"RD","overtimeFacts":[{"employeeId":"T_R05","overtimeType":"REST_DAY","overtimeHours":8}]}',
#     '{"companyId":"3","employeeId":"T_R06","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
#     '{"companyId":"3","employeeId":"T_R07","baseSalary":80000,"tenureMonths":36,"seniorityMonths":36,"position":"MANAGER","leaveFacts":[{"employeeId":"T_R07","leaveTypeName":"事假","leaveHours":8}]}',
#     '{"companyId":"3","employeeId":"T_R08","baseSalary":70000,"tenureMonths":120,"seniorityMonths":120,"position":"ENGINEER"}'
# )

# # ── 依倍數擴充（每份給不同 employeeId 避免重複）────────────────
# [System.Collections.ArrayList]$scaledObjects = @()
# for ($m = 1; $m -le $MULTIPLIER; $m++) {
#     foreach ($json in $baseCases) {
#         $obj = $json | ConvertFrom-Json
#         $obj.employeeId = "$($obj.employeeId)_x$m"
#         if ($null -ne $obj.attendances)      { $obj.attendances      | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
#         if ($null -ne $obj.performances)     { $obj.performances      | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
#         if ($null -ne $obj.overtimes)        { $obj.overtimes         | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
#         if ($null -ne $obj.overtimeFacts)    { $obj.overtimeFacts     | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
#         if ($null -ne $obj.leaveFacts)       { $obj.leaveFacts        | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
#         $null = $scaledObjects.Add($obj)
#     }
# }

# $BATCH_SIZE   = $scaledObjects.Count
# $batchPayload = $scaledObjects | ConvertTo-Json -Depth 10 -Compress

# Write-Host "公司3（通用規則 62 條）" -ForegroundColor Cyan
# Write-Host "測試規模：${MULTIPLIER}x × 22 筆 = $BATCH_SIZE 筆  |  Payload：$([math]::Round($batchPayload.Length/1KB,1)) KB" -ForegroundColor Cyan

# # ──────────────────────────────────────────────────────────────
# # 預熱
# # ──────────────────────────────────────────────────────────────
# Write-Host "`n[預熱] 各打 2 次排除冷啟動..." -ForegroundColor Cyan
# for ($w = 1; $w -le 2; $w++) {
#     $null = Invoke-RestMethod -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
#     $null = Invoke-RestMethod -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload -ErrorAction SilentlyContinue
# }
# Start-Sleep -Seconds 2
# Write-Host "預熱完畢`n" -ForegroundColor DarkGray

# # ──────────────────────────────────────────────────────────────
# # 正式 N 輪測試
# # ──────────────────────────────────────────────────────────────
# [System.Collections.ArrayList]$legacyServerList = @()
# [System.Collections.ArrayList]$legacyTotalList  = @()
# [System.Collections.ArrayList]$droolsServerList = @()
# [System.Collections.ArrayList]$droolsTotalList  = @()

# Write-Host "[正式測試] $ROUNDS 輪..." -ForegroundColor Cyan

# for ($round = 1; $round -le $ROUNDS; $round++) {
#     Write-Host "  第 $round / $ROUNDS 輪..." -ForegroundColor DarkGray

#     # Legacy
#     try {
#         $sw = [System.Diagnostics.Stopwatch]::StartNew()
#         $lRaw = Invoke-WebRequest -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload
#         $sw.Stop()
#         $lServer = if ($lRaw.Headers.ContainsKey("X-Execution-Time-Ms")) { [long](@($lRaw.Headers["X-Execution-Time-Ms"])[0]) } else { 0L }
#         $null = $legacyServerList.Add($lServer)
#         $null = $legacyTotalList.Add($sw.ElapsedMilliseconds)
#     } catch {
#         Write-Host "  Legacy 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
#         $null = $legacyServerList.Add(0L); $null = $legacyTotalList.Add(0L)
#     }

#     # Drools
#     try {
#         $sw = [System.Diagnostics.Stopwatch]::StartNew()
#         $dRaw = Invoke-WebRequest -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload
#         $sw.Stop()
#         $dServer = if ($dRaw.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
#             [long](@($dRaw.Headers["X-Drools-Pure-Compute-Ms"])[0])
#         } elseif ($dRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
#             [long](@($dRaw.Headers["X-Execution-Time-Ms"])[0])
#         } else { 0L }
#         $null = $droolsServerList.Add($dServer)
#         $null = $droolsTotalList.Add($sw.ElapsedMilliseconds)
#     } catch {
#         Write-Host "  Drools 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
#         $null = $droolsServerList.Add(0L); $null = $droolsTotalList.Add(0L)
#     }

#     if ($round -lt $ROUNDS) { Start-Sleep -Milliseconds 300 }
# }

# # ──────────────────────────────────────────────────────────────
# # 統計：去頭尾取平均
# # ──────────────────────────────────────────────────────────────
# function Get-Stat([System.Collections.ArrayList]$list) {
#     $s = $list | Sort-Object
#     if ($s.Count -le 2) {
#         $avg = [math]::Round(($s | Measure-Object -Sum).Sum / [math]::Max($s.Count,1), 2)
#         return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
#     }
#     $trimmed = $s[1..($s.Count-2)]
#     $avg = [math]::Round(($trimmed | Measure-Object -Sum).Sum / $trimmed.Count, 2)
#     return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
# }

# $lSS = Get-Stat $legacyServerList
# $lTS = Get-Stat $legacyTotalList
# $dSS = Get-Stat $droolsServerList
# $dTS = Get-Stat $droolsTotalList

# $avgLSP = [math]::Round($lSS.TrimmedAvg / $BATCH_SIZE, 4)
# $avgDSP = [math]::Round($dSS.TrimmedAvg / $BATCH_SIZE, 4)
# $avgLTP = [math]::Round($lTS.TrimmedAvg / $BATCH_SIZE, 4)
# $avgDTP = [math]::Round($dTS.TrimmedAvg / $BATCH_SIZE, 4)

# $perfNote = if ($lSS.TrimmedAvg -gt 0 -and $dSS.TrimmedAvg -gt 0) {
#     if ($lSS.TrimmedAvg -le $dSS.TrimmedAvg) {
#         "Legacy 較快，Drools 耗時是 Legacy 的 $([math]::Round($dSS.TrimmedAvg/$lSS.TrimmedAvg,2)) 倍"
#     } else {
#         "Drools 較快，Legacy 耗時是 Drools 的 $([math]::Round($lSS.TrimmedAvg/$dSS.TrimmedAvg,2)) 倍"
#     }
# } else { "無法計算（耗時資料不足）" }

# # ──────────────────────────────────────────────────────────────
# # 最終報告
# # ──────────────────────────────────────────────────────────────
# Write-Host ""
# Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
# Write-Host "║  公司3（通用規則 62 條）效能測試總結" -ForegroundColor Cyan
# Write-Host "║  ${MULTIPLIER}x = $BATCH_SIZE 筆 × $ROUNDS 輪，去頭尾 TrimmedAvg" -ForegroundColor Cyan
# Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# Write-Host "║  各輪原始數據（伺服器純運算 ms）" -ForegroundColor DarkGray
# for ($i = 0; $i -lt $ROUNDS; $i++) {
#     Write-Host ("║    輪 {0}  Legacy={1,5} ms   Drools={2,5} ms" -f ($i+1), $legacyServerList[$i], $droolsServerList[$i]) -ForegroundColor DarkGray
# }
# Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# Write-Host "║  【Legacy 硬編碼 If-Else】" -ForegroundColor Yellow
# Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lSS.Min,$lSS.Max,$lSS.TrimmedAvg,$avgLSP) -ForegroundColor Yellow
# Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lTS.Min,$lTS.Max,$lTS.TrimmedAvg,$avgLTP) -ForegroundColor Yellow
# Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# Write-Host "║  【Drools 規則引擎（Rete，僅通用規則 62 條）】" -ForegroundColor Magenta
# Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dSS.Min,$dSS.Max,$dSS.TrimmedAvg,$avgDSP) -ForegroundColor Magenta
# Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dTS.Min,$dTS.Max,$dTS.TrimmedAvg,$avgDTP) -ForegroundColor Magenta
# Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
# Write-Host "║  效能（伺服器純運算 TrimmedAvg）：$perfNote" -ForegroundColor Green
# Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
$uri1 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"
$uri2 = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"

$MULTIPLIER   = 22   # ← 改這裡：1=22筆 / 2=44筆 / 10=220筆
$ROUNDS       = 7    # 正式輪次（去頭尾取平均）
$WARMUP_LIMIT = 2000 # 冷啟動定義：端對端耗時超過此 ms 視為冷啟動，自動重打

# ── 22 筆固定案例（公司3，走通用規則 salary.drl）──────────────
$baseCases = @(
    '{"companyId":"25","employeeId":"T_L01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L01","companyId":"25","lateCount":3,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":45,"earlyLeaveMinutesTotal":0}]}',
    '{"companyId":"25","employeeId":"T_L02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L02","companyId":"25","lateCount":6,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":90,"earlyLeaveMinutesTotal":0}]}',
    '{"companyId":"25","employeeId":"T_L03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L03","companyId":"25","lateCount":9,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":135,"earlyLeaveMinutesTotal":0}]}',
    '{"companyId":"25","employeeId":"T_L04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_L04","companyId":"25","lateCount":10,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":150,"earlyLeaveMinutesTotal":0}]}',
    '{"companyId":"25","employeeId":"T_E01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E01","companyId":"25","lateCount":0,"earlyLeaveCount":3,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":45}]}',
    '{"companyId":"25","employeeId":"T_E02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","attendances":[{"employeeId":"T_E02","companyId":"25","lateCount":0,"earlyLeaveCount":6,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":false,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":90}]}',
    '{"companyId":"25","employeeId":"T_P01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P01","companyId":"25","grade":"SS+","score":99,"confirmed":true}]}',
    '{"companyId":"25","employeeId":"T_P02","baseSalary":80000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","performances":[{"employeeId":"T_P02","companyId":"25","grade":"B","score":61,"confirmed":true}]}',
    '{"companyId":"25","employeeId":"T_P03","baseSalary":50000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
    '{"companyId":"25","employeeId":"T_P04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"SALES","performances":[{"employeeId":"T_P04","companyId":"25","grade":"SS+","score":99,"confirmed":true}]}',
    '{"companyId":"25","employeeId":"T_O01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O01","overtimeType":"WEEKDAY","overtimeHours":4}]}',
    '{"companyId":"25","employeeId":"T_O02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O02","overtimeType":"WEEKDAY","overtimeHours":4},{"employeeId":"T_O02","overtimeType":"REST_DAY","overtimeHours":4}]}',
    '{"companyId":"25","employeeId":"T_O03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O03","overtimeType":"WEEKDAY","overtimeHours":2},{"employeeId":"T_O03","overtimeType":"REST_DAY","overtimeHours":3},{"employeeId":"T_O03","overtimeType":"NATIONAL_HOLIDAY","overtimeHours":4}]}',
    '{"companyId":"25","employeeId":"T_O04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimes":[{"employeeId":"T_O04","overtimeType":"WEEKDAY","overtimeHours":3},{"employeeId":"T_O04","overtimeType":"REST_DAY","overtimeHours":3}],"attendances":[{"employeeId":"T_O04","companyId":"25","lateCount":0,"earlyLeaveCount":0,"absentDays":0,"workDays":22,"requiredWorkDays":22,"hasFullAttendance":true,"lateMinutesTotal":0,"earlyLeaveMinutesTotal":0}]}',
    '{"companyId":"25","employeeId":"T_R01","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R01","leaveTypeName":"事假","leaveHours":8}]}',
    '{"companyId":"25","employeeId":"T_R02","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R02","leaveTypeName":"曠職","leaveHours":8}]}',
    '{"companyId":"25","employeeId":"T_R03","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","leaveFacts":[{"employeeId":"T_R03","leaveTypeName":"特休","leaveHours":8}]}',
    '{"companyId":"25","employeeId":"T_R04","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","overtimeFacts":[{"employeeId":"T_R04","overtimeType":"WEEKDAY","overtimeHours":4}]}',
    '{"companyId":"25","employeeId":"T_R05","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER","department":"RD","overtimeFacts":[{"employeeId":"T_R05","overtimeType":"REST_DAY","overtimeHours":8}]}',
    '{"companyId":"25","employeeId":"T_R06","baseSalary":60000,"tenureMonths":24,"seniorityMonths":24,"position":"ENGINEER"}',
    '{"companyId":"25","employeeId":"T_R07","baseSalary":80000,"tenureMonths":36,"seniorityMonths":36,"position":"MANAGER","leaveFacts":[{"employeeId":"T_R07","leaveTypeName":"事假","leaveHours":8}]}',
    '{"companyId":"25","employeeId":"T_R08","baseSalary":70000,"tenureMonths":120,"seniorityMonths":120,"position":"ENGINEER"}'
)

# ── 依倍數擴充（每份給不同 employeeId 避免重複）────────────────
[System.Collections.ArrayList]$scaledObjects = @()
for ($m = 1; $m -le $MULTIPLIER; $m++) {
    foreach ($json in $baseCases) {
        $obj = $json | ConvertFrom-Json
        $obj.employeeId = "$($obj.employeeId)_x$m"
        if ($null -ne $obj.attendances)   { $obj.attendances   | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
        if ($null -ne $obj.performances)  { $obj.performances  | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
        if ($null -ne $obj.overtimes)     { $obj.overtimes     | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
        if ($null -ne $obj.overtimeFacts) { $obj.overtimeFacts | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
        if ($null -ne $obj.leaveFacts)    { $obj.leaveFacts    | ForEach-Object { $_.employeeId = "$($_.employeeId)_x$m" } }
        $null = $scaledObjects.Add($obj)
    }
}

$BATCH_SIZE   = $scaledObjects.Count
$batchPayload = $scaledObjects | ConvertTo-Json -Depth 10 -Compress

Write-Host "公司3（通用規則）｜${MULTIPLIER}x × 22 = $BATCH_SIZE 筆｜Payload：$([math]::Round($batchPayload.Length/1KB,1)) KB" -ForegroundColor Cyan
Write-Host "冷啟動定義：端對端耗時 > ${WARMUP_LIMIT}ms 自動重打，直到兩端都暖機完成" -ForegroundColor DarkGray

# ──────────────────────────────────────────────────────────────
# 暖機階段：持續重打直到兩端端對端耗時都 <= WARMUP_LIMIT
# ──────────────────────────────────────────────────────────────
Write-Host "`n[暖機] 持續打到兩端端對端耗時皆 <= ${WARMUP_LIMIT}ms..." -ForegroundColor Cyan

$warmupAttempt = 0
$legacyWarm    = $false
$droolsWarm    = $false

while (-not $legacyWarm -or -not $droolsWarm) {
    $warmupAttempt++
    Write-Host "  暖機第 $warmupAttempt 次..." -ForegroundColor DarkGray

    if (-not $legacyWarm) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Invoke-WebRequest -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload -ErrorAction Stop
            $sw.Stop()
            if ($sw.ElapsedMilliseconds -le $WARMUP_LIMIT) {
                $legacyWarm = $true
                Write-Host "    Legacy  暖機完成（$($sw.ElapsedMilliseconds)ms）✅" -ForegroundColor Green
            } else {
                Write-Host "    Legacy  仍在冷啟動（$($sw.ElapsedMilliseconds)ms > ${WARMUP_LIMIT}ms），繼續..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    Legacy  暖機錯誤: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $droolsWarm) {
        try {
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $null = Invoke-WebRequest -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload -ErrorAction Stop
            $sw.Stop()
            if ($sw.ElapsedMilliseconds -le $WARMUP_LIMIT) {
                $droolsWarm = $true
                Write-Host "    Drools  暖機完成（$($sw.ElapsedMilliseconds)ms）✅" -ForegroundColor Green
            } else {
                Write-Host "    Drools  仍在冷啟動（$($sw.ElapsedMilliseconds)ms > ${WARMUP_LIMIT}ms），繼續..." -ForegroundColor Yellow
            }
        } catch {
            Write-Host "    Drools  暖機錯誤: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    if (-not $legacyWarm -or -not $droolsWarm) { Start-Sleep -Seconds 1 }
}

Write-Host "暖機完成（共 $warmupAttempt 次）。等待 2 秒讓伺服器穩定...`n" -ForegroundColor DarkGray
Start-Sleep -Seconds 2

# ──────────────────────────────────────────────────────────────
# 正式 N 輪測試
# ──────────────────────────────────────────────────────────────
[System.Collections.ArrayList]$legacyServerList = @()
[System.Collections.ArrayList]$legacyTotalList  = @()
[System.Collections.ArrayList]$droolsServerList = @()
[System.Collections.ArrayList]$droolsTotalList  = @()

Write-Host "[正式測試] $ROUNDS 輪..." -ForegroundColor Cyan

for ($round = 1; $round -le $ROUNDS; $round++) {
    Write-Host "  第 $round / $ROUNDS 輪..." -ForegroundColor DarkGray

    # Legacy
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $lRaw = Invoke-WebRequest -Method Post -Uri $uri1 -ContentType "application/json" -Body $batchPayload
        $sw.Stop()
        $lTotal  = $sw.ElapsedMilliseconds
        $lServer = if ($lRaw.Headers.ContainsKey("X-Execution-Time-Ms")) { [long](@($lRaw.Headers["X-Execution-Time-Ms"])[0]) } else { 0L }
        $null = $legacyServerList.Add($lServer)
        $null = $legacyTotalList.Add($lTotal)
        $coldFlag = if ($lTotal -gt $WARMUP_LIMIT) { "  ⚠ 端對端 ${lTotal}ms 超過閾值" } else { "" }
        Write-Host ("    Legacy  伺服器={0,5}ms  端對端={1,5}ms{2}" -f $lServer, $lTotal, $coldFlag) -ForegroundColor DarkGray
    } catch {
        Write-Host "    Legacy 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
        $null = $legacyServerList.Add(0L); $null = $legacyTotalList.Add(0L)
    }

    # Drools
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $dRaw = Invoke-WebRequest -Method Post -Uri $uri2 -ContentType "application/json" -Body $batchPayload
        $sw.Stop()
        $dTotal  = $sw.ElapsedMilliseconds
        $dServer = if ($dRaw.Headers.ContainsKey("X-Drools-Pure-Compute-Ms")) {
            [long](@($dRaw.Headers["X-Drools-Pure-Compute-Ms"])[0])
        } elseif ($dRaw.Headers.ContainsKey("X-Execution-Time-Ms")) {
            [long](@($dRaw.Headers["X-Execution-Time-Ms"])[0])
        } else { 0L }
        $null = $droolsServerList.Add($dServer)
        $null = $droolsTotalList.Add($dTotal)
        $coldFlag = if ($dTotal -gt $WARMUP_LIMIT) { "  ⚠ 端對端 ${dTotal}ms 超過閾值" } else { "" }
        Write-Host ("    Drools  伺服器={0,5}ms  端對端={1,5}ms{2}" -f $dServer, $dTotal, $coldFlag) -ForegroundColor DarkGray
    } catch {
        Write-Host "    Drools 第 $round 輪錯誤: $($_.Exception.Message)" -ForegroundColor Red
        $null = $droolsServerList.Add(0L); $null = $droolsTotalList.Add(0L)
    }

    if ($round -lt $ROUNDS) { Start-Sleep -Milliseconds 300 }
}

# ──────────────────────────────────────────────────────────────
# 統計：去頭尾取平均（Trimmed Mean）
# ──────────────────────────────────────────────────────────────
function Get-Stat([System.Collections.ArrayList]$list) {
    $s = $list | Sort-Object
    if ($s.Count -le 2) {
        $avg = [math]::Round(($s | Measure-Object -Sum).Sum / [math]::Max($s.Count,1), 2)
        return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
    }
    $trimmed = $s[1..($s.Count-2)]
    $avg = [math]::Round(($trimmed | Measure-Object -Sum).Sum / $trimmed.Count, 2)
    return [PSCustomObject]@{ Min=$s[0]; Max=$s[-1]; TrimmedAvg=$avg }
}

$lSS = Get-Stat $legacyServerList
$lTS = Get-Stat $legacyTotalList
$dSS = Get-Stat $droolsServerList
$dTS = Get-Stat $droolsTotalList

$avgLSP = [math]::Round($lSS.TrimmedAvg / $BATCH_SIZE, 4)
$avgDSP = [math]::Round($dSS.TrimmedAvg / $BATCH_SIZE, 4)
$avgLTP = [math]::Round($lTS.TrimmedAvg / $BATCH_SIZE, 4)
$avgDTP = [math]::Round($dTS.TrimmedAvg / $BATCH_SIZE, 4)

$perfNote = if ($lSS.TrimmedAvg -gt 0 -and $dSS.TrimmedAvg -gt 0) {
    if ($lSS.TrimmedAvg -le $dSS.TrimmedAvg) {
        "Legacy 較快，Drools 耗時是 Legacy 的 $([math]::Round($dSS.TrimmedAvg/$lSS.TrimmedAvg,2)) 倍"
    } else {
        "Drools 較快，Legacy 耗時是 Drools 的 $([math]::Round($lSS.TrimmedAvg/$dSS.TrimmedAvg,2)) 倍"
    }
} else { "無法計算（耗時資料不足）" }

# ──────────────────────────────────────────────────────────────
# 最終報告
# ──────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  公司3（通用規則）效能測試總結" -ForegroundColor Cyan
Write-Host "║  ${MULTIPLIER}x = $BATCH_SIZE 筆 × $ROUNDS 輪，去頭尾 TrimmedAvg" -ForegroundColor Cyan
Write-Host "║  冷啟動定義：端對端 > ${WARMUP_LIMIT}ms，已於暖機階段排除" -ForegroundColor Cyan
Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  各輪數據（伺服器純運算 ms）" -ForegroundColor DarkGray
for ($i = 0; $i -lt $ROUNDS; $i++) {
    $lFlag = if ($legacyTotalList[$i] -gt $WARMUP_LIMIT) { " ⚠" } else { "  " }
    $dFlag = if ($droolsTotalList[$i] -gt $WARMUP_LIMIT) { " ⚠" } else { "  " }
    Write-Host ("║    輪 {0}  Legacy={1,5}ms{2}  Drools={3,5}ms{4}" -f ($i+1), $legacyServerList[$i], $lFlag, $droolsServerList[$i], $dFlag) -ForegroundColor DarkGray
}
Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  【Legacy 硬編碼 If-Else】" -ForegroundColor Yellow
Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lSS.Min,$lSS.Max,$lSS.TrimmedAvg,$avgLSP) -ForegroundColor Yellow
Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $lTS.Min,$lTS.Max,$lTS.TrimmedAvg,$avgLTP) -ForegroundColor Yellow
Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  【Drools 規則引擎（Rete，通用規則）】" -ForegroundColor Magenta
Write-Host ("║    伺服器純運算  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dSS.Min,$dSS.Max,$dSS.TrimmedAvg,$avgDSP) -ForegroundColor Magenta
Write-Host ("║    端對端總耗時  Min={0} / Max={1} / TrimmedAvg={2} ms  ({3} ms/筆)" -f $dTS.Min,$dTS.Max,$dTS.TrimmedAvg,$avgDTP) -ForegroundColor Magenta
Write-Host "╠════════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "║  效能（伺服器純運算 TrimmedAvg）：$perfNote" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan