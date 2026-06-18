# ============================================================
# A/B 公司請假扣薪比例客製化測試
# 驗證：同一個假別，A、B、C 三方扣薪比例各不相同，互不干擾
#
# 底薪 36000、workingDaysInMonth 30 → 時薪 150（36000/30/8）
# 8 小時扣薪基準 = 150 × 8 = 1200（100%）
#
# 扣薪比例對照：
#   假別         通用(C)   A客製    B客製
#   普通病假      50%      30%     10%
#   事假         100%     80%     50%
#   家庭照顧假    100%     50%     20%
#   育嬰假       100%     60%     30%
#   生理假       不扣      不扣     不扣
# ============================================================

$calcUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$BASE    = 36000
$H8      = 1200    # 8H × 時薪150 = 100% 扣薪基準

$pass = 0; $fail = 0
function Check($cond, $msg, $got, $exp) {
    $detail = if ($null -ne $got) { "（得到 $got，預期 $exp）" } else { "" }
    if ($cond) { Write-Host "    [PASS] $msg $detail" -ForegroundColor Green; $script:pass++ }
    else       { Write-Host "    [FAIL] $msg $detail" -ForegroundColor Red;   $script:fail++ }
}

function Calc($companyId, $empId, $leaveType, $hours) {
    $body = @{
        employeeId         = $empId
        baseSalary         = $BASE
        companyId          = $companyId
        workingDaysInMonth = 30
        tenureMonths       = 12
        seniorityMonths    = 12
        leaves             = @(@{ employeeId=$empId; leaveTypeName=$leaveType; leaveHours=$hours })
        overtimes          = @()
    } | ConvertTo-Json -Depth 10
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
    $resp  = Invoke-RestMethod -Uri $calcUrl -Method Post -Body $bytes `
             -ContentType "application/json; charset=utf-8"
    if ($resp.result) { return $resp.result }
    return $resp
}

# 一個假別測三方（A/B/C）的共用函式
function TestLeave($leaveType, $expA, $expB, $expC) {
    Write-Host "`n[$leaveType] 三方扣薪對照（8H）" -ForegroundColor Magenta

    $rA = Calc "A" "LV-A" $leaveType 8
    $rB = Calc "B" "LV-B" $leaveType 8
    $rC = Calc "C" "LV-C" $leaveType 8

    Write-Host ("    A 客製 leaveDeduction={0}  預期={1}" -f $rA.leaveDeduction, $expA)
    Write-Host ("    B 客製 leaveDeduction={0}  預期={1}" -f $rB.leaveDeduction, $expB)
    Write-Host ("    C 通用 leaveDeduction={0}  預期={1}" -f $rC.leaveDeduction, $expC)

    Check ([decimal]$rA.leaveDeduction -eq $expA) "A 公司 $leaveType 扣薪 = $expA" $rA.leaveDeduction $expA
    Check ([decimal]$rB.leaveDeduction -eq $expB) "B 公司 $leaveType 扣薪 = $expB" $rB.leaveDeduction $expB
    Check ([decimal]$rC.leaveDeduction -eq $expC) "C 公司 $leaveType 扣薪 = $expC（通用法定）" $rC.leaveDeduction $expC

    # 隔離驗證：A 結果不含乙、B 結果不含甲
    Check (-not (($rA.ruleDetails -join "") -match "乙公司")) "A $leaveType 結果不含乙公司規則" "" ""
    Check (-not (($rB.ruleDetails -join "") -match "甲公司")) "B $leaveType 結果不含甲公司規則" "" ""

    # 三方互異驗證（生理假三方皆 0，不做互異檢查）
    if ($expA -ne $expB -or $expB -ne $expC) {
        Check (([decimal]$rA.leaveDeduction -ne [decimal]$rB.leaveDeduction) -or `
               ([decimal]$rB.leaveDeduction -ne [decimal]$rC.leaveDeduction)) `
              "$leaveType 三方扣薪確實不同（隔離成立）" "" ""
    }

    return @{ A=$rA; B=$rB; C=$rC }
}

Write-Host "============================================================" -ForegroundColor White
Write-Host " A/B 公司請假扣薪比例客製化測試  底薪 $BASE  時薪 150" -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

# ── 五個假別逐一測試 ──────────────────────────────────────
# 普通病假：通用50% A30% B10%
$sick = TestLeave "普通病假" ($H8*0.3) ($H8*0.1) ($H8*0.5)

# 事假：通用100% A80% B50%
$personal = TestLeave "事假" ($H8*0.8) ($H8*0.5) ($H8*1.0)

# 家庭照顧假：通用100% A50% B20%
$family = TestLeave "家庭照顧假" ($H8*0.5) ($H8*0.2) ($H8*1.0)

# 育嬰假：通用100% A60% B30%
$parental = TestLeave "育嬰假" ($H8*0.6) ($H8*0.3) ($H8*1.0)

# 生理假：三方皆不扣薪
$menstrual = TestLeave "生理假" 0 0 0

# ── 補充驗證：A 公司 ruleDetails 標記確認 ─────────────────
Write-Host "`n[補充] 客製規則標記與通用規則被擋確認" -ForegroundColor Magenta
Check (($sick.A.ruleDetails -join "") -match "甲公司客製.*普通病假")  "A 普通病假觸發甲公司客製規則" "" ""
Check (-not (($sick.A.ruleDetails -join "") -match "50%扣薪"))        "A 普通病假未走通用50%規則（LeaveProcessed 防重複）" "" ""
Check (($sick.B.ruleDetails -join "") -match "乙公司客製.*普通病假")  "B 普通病假觸發乙公司客製規則" "" ""
Check (($sick.C.ruleDetails -join "") -match "50%扣薪")               "C 普通病假走通用50%規則（無客製）" "" ""

# ── 補充驗證：A 公司多假別同時請假，各走各的客製比例 ──────
Write-Host "`n[補充] A 公司同時請普通病假+事假（各自客製比例）" -ForegroundColor Magenta
$body = @{
    employeeId="MULTI-A"; baseSalary=$BASE; companyId="A"; workingDaysInMonth=30
    tenureMonths=12; seniorityMonths=12
    leaves=@(
        @{ employeeId="MULTI-A"; leaveTypeName="普通病假"; leaveHours=8 }
        @{ employeeId="MULTI-A"; leaveTypeName="事假";     leaveHours=8 }
    )
    overtimes=@()
} | ConvertTo-Json -Depth 10
$bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
$rMulti = Invoke-RestMethod -Uri $calcUrl -Method Post -Body $bytes -ContentType "application/json; charset=utf-8"
if ($rMulti.result) { $rMulti = $rMulti.result }
# 病假30% + 事假80% = 360 + 960 = 1320
$expMulti = ($H8*0.3) + ($H8*0.8)
Write-Host ("    leaveDeduction={0}  預期={1}（病假360 + 事假960）" -f $rMulti.leaveDeduction, $expMulti)
Write-Host "    ruleDetails:"
$rMulti.ruleDetails | ForEach-Object { Write-Host "      - $_" }
Check ([decimal]$rMulti.leaveDeduction -eq $expMulti) "A 病假30%+事假80% 合計 = $expMulti" $rMulti.leaveDeduction $expMulti

# ── 彙總 ──────────────────────────────────────────────────
Write-Host "`n============================================================" -ForegroundColor Yellow
Write-Host (" 請假扣薪比例客製化測試：PASS {0}  |  FAIL {1}" -f $pass, $fail) -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Yellow

# ── 對照表輸出 ────────────────────────────────────────────
Write-Host "`n[ 三方扣薪對照表（8H，時薪150）]" -ForegroundColor Cyan
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "假別", "A客製", "B客製", "C通用")
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "普通病假", $sick.A.leaveDeduction, $sick.B.leaveDeduction, $sick.C.leaveDeduction)
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "事假",     $personal.A.leaveDeduction, $personal.B.leaveDeduction, $personal.C.leaveDeduction)
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "家庭照顧假", $family.A.leaveDeduction, $family.B.leaveDeduction, $family.C.leaveDeduction)
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "育嬰假",   $parental.A.leaveDeduction, $parental.B.leaveDeduction, $parental.C.leaveDeduction)
Write-Host ("  {0,-12} {1,-12} {2,-12} {3,-12}" -f "生理假",   $menstrual.A.leaveDeduction, $menstrual.B.leaveDeduction, $menstrual.C.leaveDeduction)