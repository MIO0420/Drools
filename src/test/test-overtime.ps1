$base = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api/calculateovertime"

function Test-Overtime {
    param($label, $body)
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "測試：$label" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    try {
        $result = Invoke-RestMethod -Uri $base -Method POST -ContentType "application/json" -Body $body
        $violated = $result.violated
        $color = if ($violated) { "Red" } else { "Green" }
        Write-Host "violated : $violated" -ForegroundColor $color
        Write-Host "appliedRule : $($result.appliedRule)"
        if ($result.warnings.Count -gt 0) {
            Write-Host "warnings :" -ForegroundColor Red
            $result.warnings | ForEach-Object { Write-Host "  ⚠ $_" -ForegroundColor Red }
        }
        if ($result.notes.Count -gt 0) {
            Write-Host "notes :" -ForegroundColor Gray
            $result.notes | ForEach-Object { Write-Host "  ℹ $_" -ForegroundColor Gray }
        }
    } catch {
        Write-Host "ERROR: $_" -ForegroundColor Magenta
    }
}

Test-Overtime "✅ 平日加班 3H（合法）" '{"employeeId":"EMP001","overtimeType":"WEEKDAY","overtimeHours":3,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 平日加班 5H（超過 4H 上限）" '{"employeeId":"EMP002","overtimeType":"WEEKDAY","overtimeHours":5,"monthlyOvertimeHours":40,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 休息日加班 8H（合法）" '{"employeeId":"EMP003","overtimeType":"REST_DAY","overtimeHours":8,"monthlyOvertimeHours":30,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 休息日加班 13H（超過 12H 上限）" '{"employeeId":"EMP004","overtimeType":"REST_DAY","overtimeHours":13,"monthlyOvertimeHours":30,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 例假日出勤 4H（原則違法）" '{"employeeId":"EMP005","overtimeType":"REGULAR_DAY_OFF","overtimeHours":4,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 例假日出勤 14H（超過 12H 上限）" '{"employeeId":"EMP006","overtimeType":"REGULAR_DAY_OFF","overtimeHours":14,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 國定假日出勤 8H（合法，需加給）" '{"employeeId":"EMP007","overtimeType":"NATIONAL_HOLIDAY","overtimeHours":8,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 國定假日出勤 13H（超過 12H）" '{"employeeId":"EMP008","overtimeType":"NATIONAL_HOLIDAY","overtimeHours":13,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 月加班 46H（剛好合法）" '{"employeeId":"EMP009","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":46,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 月加班 50H 無勞資協議（違法）" '{"employeeId":"EMP010","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":50,"laborCouncilAgreed":false,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 月加班 50H 有勞資協議（合法彈性）" '{"employeeId":"EMP011","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":50,"laborCouncilAgreed":true,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 月加班 55H 有勞資協議（超過 54H 上限）" '{"employeeId":"EMP012","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":55,"laborCouncilAgreed":true,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 季加班 100H 有協議（合法）" '{"employeeId":"EMP013","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":30,"quarterlyOvertimeHours":100,"laborCouncilAgreed":true,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "❌ 季加班 140H 有協議（超過 138H）" '{"employeeId":"EMP014","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":30,"quarterlyOvertimeHours":140,"laborCouncilAgreed":true,"consecutiveWorkDays":5,"restDaysPerWeek":2}'
Test-Overtime "✅ 連續出勤 6 天（合法）" '{"employeeId":"EMP015","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":20,"consecutiveWorkDays":6,"restDaysPerWeek":2}'
Test-Overtime "❌ 連續出勤 7 天（違反第 36 條）" '{"employeeId":"EMP016","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":20,"consecutiveWorkDays":7,"restDaysPerWeek":2}'
Test-Overtime "❌ 每週休假 1 天（不足 2 天）" '{"employeeId":"EMP017","overtimeType":"WEEKDAY","overtimeHours":2,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":1}'
Test-Overtime "✅ 補休申請合法（未逾期）" '{"employeeId":"EMP018","overtimeType":"WEEKDAY","overtimeHours":3,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2,"compensatoryTimeOff":true,"compensatoryExpired":false}'
Test-Overtime "❌ 補休已逾期（須折現金）" '{"employeeId":"EMP019","overtimeType":"WEEKDAY","overtimeHours":3,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2,"compensatoryTimeOff":true,"compensatoryExpired":true}'
Test-Overtime "❌ 補班日出勤（2026 已廢止）" '{"employeeId":"EMP020","overtimeType":"MAKEUP_WORK_DAY","overtimeHours":8,"monthlyOvertimeHours":20,"consecutiveWorkDays":5,"restDaysPerWeek":2}'

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "全部測試完成！" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan
