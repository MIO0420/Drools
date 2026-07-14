# ============================================================
#  一致性比對 100 筆（隨機生成）：Drools vs Legacy — 公司94
#  固定亂數種子，結果可重現；涵蓋 5職位×6部門×各種出勤/請假/KPI/專案
# ============================================================
$droolsUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculatesalary"
$legacyUrl = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/checksalary/legacy"
$cid = "94"
$N = 100

Get-Random -SetSeed 20260629 | Out-Null   # 可重現

$positions  = @("EXECUTIVE","DIRECTOR","MANAGER","STAFF","INTERN")
$depts      = @("RD","IT","SALES","OPS","FINANCE","CUSTOMER")
$grades     = @("SS+","SS","S","A+","A","B+","B")
$paidLeaves = @("特休","婚假","喪假","公假","補休")        # 給薪假（不扣全勤）
$scenarios  = @("normal","normal","normal","late","early","absent","perfect","paidleave","sickleave")

function GradeForScore($s) {
  if ($s -ge 130) { "SS+" } elseif ($s -ge 120) { "SS" } elseif ($s -ge 110) { "S" }
  elseif ($s -ge 100) { "A+" } elseif ($s -ge 90) { "A" } elseif ($s -ge 80) { "B+" } else { "B" }
}

# 生成 100 筆
$tests = @()
for ($i=1; $i -le $N; $i++) {
  $pos   = $positions[(Get-Random -Maximum $positions.Count)]
  $dept  = $depts[(Get-Random -Maximum $depts.Count)]
  $base  = (Get-Random -Minimum 125 -Maximum 792) * 240    # 30000~190000, 240倍數
  $sen   = Get-Random -Minimum 1 -Maximum 241
  $score = Get-Random -Minimum 70 -Maximum 136
  $scen  = $scenarios[(Get-Random -Maximum $scenarios.Count)]
  $proj  = @($null,"LEAD","CORE","MEMBER")[(Get-Random -Maximum 4)]

  $t = @{ id=("R{0:D3}" -f $i); position=$pos; department=$dept; baseSalary=$base; sen=$sen; score=$score; grade=(GradeForScore $score); proj=$proj; scen=$scen }
  switch ($scen) {
    "late"      { $t.late  = (Get-Random -Minimum 3 -Maximum 15) }
    "early"     { $t.early = (Get-Random -Minimum 3 -Maximum 12) }
    "absent"    { $t.absentH = (@(8,16,24))[(Get-Random -Maximum 3)] }
    "perfect"   { $t.perfect = $true }
    "paidleave" { $t.leaveType = $paidLeaves[(Get-Random -Maximum $paidLeaves.Count)]; $t.leaveH = (Get-Random -Minimum 4 -Maximum 17) }
    "sickleave" { $t.leaveType = "普通病假"; $t.leaveH = (Get-Random -Minimum 4 -Maximum 17) }
  }
  $tests += $t
}

function Build($t) {
  $e = [ordered]@{
    employeeId=$t.id; companyId=$cid; baseSalary=$t.baseSalary
    workingDaysInMonth=30; tenureMonths=$t.sen; seniorityMonths=$t.sen
    position=$t.position; department=$t.department; identity="REGULAR"
    overtimes=@(@{overtimeType="WEEKDAY"; overtimeHours=8})
    performances=@(@{ employeeId=$t.id; companyId=$cid; score=$t.score; grade=$t.grade; confirmed=$true })
  }
  if ($t.proj) { $e.projects = @(@{ employeeId=$t.id; companyId=$cid; role=$t.proj; completed=$true }) }
  $leaves=@()
  if ($t.absentH)   { $leaves += @{ leaveTypeName="曠職"; leaveHours=$t.absentH } }
  if ($t.leaveType) { $leaves += @{ leaveTypeName=$t.leaveType; leaveHours=$t.leaveH } }
  if ($leaves.Count -gt 0) { $e.leaves = $leaves }
  if ($t.late -or $t.early -or $t.perfect) {
    $e.attendances = @(@{ employeeId=$t.id; companyId=$cid; lateCount=([int]$t.late); earlyLeaveCount=([int]$t.early); hasFullAttendance=([bool]$t.perfect) })
  }
  return (,@($e) | ConvertTo-Json -Depth 12)
}

function Post($url, $body) {
  $bytes=[Text.Encoding]::UTF8.GetBytes($body)
  try {
    $resp = Invoke-RestMethod -Uri $url -Method Post -Body $bytes -ContentType "application/json; charset=utf-8" -TimeoutSec 180
    $r = if ($resp -is [array]) { $resp[0] } else { $resp }
    if ($r.result) { return $r.result } else { return $r }
  } catch { return $null }
}

Write-Host "[暖機] 先打一發 Drools 讓 KieContainer 就緒..." -ForegroundColor DarkGray
$null = Post $droolsUrl (Build $tests[0]); Start-Sleep -Milliseconds 500

$fields = "baseSalary","leaveDeduction","overtimeBonus","companyBonus","seniorityBonus","finalSalary"
$pass=0; $fail=0; $failList=@()

Write-Host "============================================================" -ForegroundColor White
Write-Host (" 一致性比對 {0} 筆（隨機）：Drools vs Legacy — 公司94" -f $N) -ForegroundColor White
Write-Host "============================================================" -ForegroundColor White

$idx=0
foreach ($t in $tests) {
  $idx++
  $body = Build $t
  $d = Post $droolsUrl $body
  $l = Post $legacyUrl $body
  if (-not $d -or -not $l) {
    Write-Host ("✗ {0} 請求失敗" -f $t.id) -ForegroundColor Red
    $fail++; $failList += $t.id; continue
  }
  $same=$true; $diffs=@()
  foreach ($f in $fields) {
    $dv=[double]($d.$f); $lv=[double]($l.$f)
    if ([math]::Abs($dv-$lv) -ge 0.01) { $same=$false; $diffs += ("{0}:D={1}/L={2}" -f $f,$dv,$lv) }
  }
  if ($same) { $pass++ }
  else {
    $fail++; $failList += $t.id
    Write-Host ("✗ {0} {1}/{2} base={3} {4}" -f $t.id,$t.position,$t.department,$t.baseSalary,$t.scen) -ForegroundColor Red
    foreach ($x in $diffs) { Write-Host ("      $x") -ForegroundColor Yellow }
  }
  # 每 20 筆報進度
  if ($idx % 20 -eq 0) { Write-Host ("  ...已測 {0}/{1}（{2} 一致）" -f $idx,$N,$pass) -ForegroundColor DarkGray }
}

Write-Host ""
Write-Host ("══════ 結果：{0} 一致 / {1} 不一致（共 {2}）══════" -f $pass,$fail,$N) -ForegroundColor $(if($fail -eq 0){"Green"}else{"Yellow"})
if ($fail -gt 0) { Write-Host (" 不一致：{0}" -f ($failList -join ", ")) -ForegroundColor Yellow }
else { Write-Host (" 全數一致 ✓ 規則引擎與硬編碼對 {0} 筆隨機情境產生完全相同的薪資。" -f $N) -ForegroundColor Green }