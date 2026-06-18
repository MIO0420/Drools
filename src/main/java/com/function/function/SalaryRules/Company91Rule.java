package com.function.function.SalaryRules;

import com.function.model.AllowanceFact;
import com.function.model.AttendanceFact;
import com.function.model.EmployeeFact;
import com.function.model.LeaveFact;
import com.function.model.OvertimeFact;
import com.function.model.PerformanceFact;
import com.function.model.ProjectFact;
import com.function.model.SalaryAdjustmentFact;
import com.function.model.SalaryResult;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

/**
 * 公司 91 — L1 新創期（~30 條，單維度為主）硬編碼版
 * 對應 Company_91_Salary.drl
 * 特性：所有判斷皆為單一維度互斥分派，可用 switch-case 高效處理
 *       此階段預期硬編碼佔優（switch O(1)，圈複雜度低）
 */
public class Company91Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "91"; }

    // ── 資歷倍率：L1 無倍率客製，回傳 1.0 ──
    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        return 1.0;
    }

    // ══════════════════════════════════════════════════════
    //  請假扣薪（單維度 switch：僅看假別）
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomLeaveDeduction() { return true; }

    @Override
    public boolean processLeaveDeductions(
            EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result) {

        boolean hasAbsence = false;

        for (LeaveFact leave : leaves) {
            BigDecimal hours = leave.getLeaveHours();
            if (hours == null || hours.compareTo(BigDecimal.ZERO) <= 0) continue;

            String type = leave.getLeaveTypeName();
            // 單維度互斥分派 — switch 直接 O(1)
            switch (type) {
                case "事假":
                case "住院病假":
                case "家庭照顧假": {
                    BigDecimal d = employee.calcLeaveDeduction(hours, "1.0");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(d));
                    result.addRuleDetail("【請假扣薪】" + type + " " + hours + "h（100%），扣 " + d);
                    break;
                }
                case "普通病假": {
                    BigDecimal d = employee.calcLeaveDeduction(hours, "0.5");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(d));
                    result.addRuleDetail("【請假扣薪】普通病假 " + hours + "h（50%），扣 " + d);
                    break;
                }
                case "曠職": {
                    BigDecimal d = employee.calcLeaveDeduction(hours, "1.0");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(d));
                    result.setFullAttendanceBonusDeducted(true);
                    hasAbsence = true;
                    result.addRuleDetail("【請假扣薪】曠職 " + hours + "h（100%），扣 " + d + "，喪失全勤");
                    break;
                }
                case "生理假":
                case "婚假":
                case "喪假":
                case "公假":
                case "特休":
                case "陪產假":
                case "產檢假": {
                    result.addRuleDetail("【給薪假】" + type + " " + hours + "h，不扣薪");
                    break;
                }
                default:
                    result.addRuleDetail("【請假扣薪】未知假別：" + type + "，略過");
                    break;
            }
        }
        return hasAbsence;
    }

    // ══════════════════════════════════════════════════════
    //  加班費（單維度 switch：僅看加班類型）
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomOvertimeCalc() { return false; }  // 加班走 Legacy 通用，與 DRL 通用加班對齊

    @Override
    public void processOvertimeBonus(
            EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result) {

        for (OvertimeFact ot : overtimes) {
            BigDecimal h = ot.getOvertimeHours();
            if (h == null || h.compareTo(BigDecimal.ZERO) <= 0) continue;

            BigDecimal bonus;
            String label;
            // 單維度互斥分派 — switch 直接 O(1)
            switch (ot.getOvertimeType()) {
                case "WEEKDAY":
                    bonus = employee.calcWeekdayOvertime(h);
                    label = "平日加班";
                    break;
                case "REST_DAY":
                    bonus = employee.calcRestDayOvertime(h);
                    label = "休息日加班";
                    break;
                case "NATIONAL_HOLIDAY":
                    bonus = h.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcNationalHolidayOvertimeBase()
                            : employee.calcNationalHolidayOvertimeExtra(h);
                    label = "國定假日";
                    break;
                case "STATUTORY_HOLIDAY":
                    bonus = h.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcStatutoryHolidayOvertimeBase()
                            : employee.calcStatutoryHolidayOvertimeExtra(h);
                    label = "例假日";
                    break;
                case "ANNUAL_LEAVE_DAY":
                    bonus = h.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcStatutoryHolidayOvertimeBase()
                            : employee.calcStatutoryHolidayOvertimeExtra(h);
                    label = "特休出勤";
                    break;
                default:
                    result.addRuleDetail("【加班費】未知加班類型：" + ot.getOvertimeType() + "，略過");
                    continue;
            }
            result.setOvertimeBonus(result.getOvertimeBonus().add(bonus));
            result.addRuleDetail("【加班費】" + label + " " + h + "h，加給 " + bonus);
        }
    }

    // ══════════════════════════════════════════════════════
    //  資歷獎金（單維度：僅看年資分段）
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomSeniorityCalc() { return true; }

    @Override
    public BigDecimal processSeniorityBonus(EmployeeFact employee, SalaryResult result) {
        int m = employee.getSeniorityMonths();
        BigDecimal bonus;
        String tier;
        // 單維度分段 — 簡單 if 階梯
        if (m < 12)        { bonus = BigDecimal.ZERO;            tier = "不足12月"; }
        else if (m < 24)   { bonus = new BigDecimal("500");      tier = "12-23月"; }
        else if (m < 36)   { bonus = new BigDecimal("800");      tier = "24-35月"; }
        else if (m < 60)   { bonus = new BigDecimal("1200");     tier = "36-59月"; }
        else if (m < 120)  { bonus = new BigDecimal("1800");     tier = "60-119月"; }
        else               { bonus = new BigDecimal("2500");     tier = "≥120月"; }

        result.addRuleDetail("【資歷獎金】年資" + tier + "，+" + bonus);
        return bonus;
    }

    // ══════════════════════════════════════════════════════
    //  全勤獎金（單維度）
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomFullAttendanceCalc() { return true; }

    @Override
    public boolean processFullAttendance(
            EmployeeFact employee, SalaryResult result, boolean hasAbsence) {

        if (employee.getTenureMonths() < 1) {
            result.addRuleDetail("【全勤獎金】年資不足1月，不發全勤獎金");
            return false;
        }
        if (result.isFullAttendanceBonusDeducted() || hasAbsence) {
            result.addRuleDetail("【全勤獎金】有缺勤紀錄，不發全勤獎金");
            return false;
        }
        result.setOvertimeBonus(result.getOvertimeBonus().add(new BigDecimal("3000")));
        result.addRuleDetail("【全勤獎金】年資滿1月且全勤，+3000");
        return true;
    }

    // ══════════════════════════════════════════════════════
    //  基本職級津貼（單維度 switch：僅看職級）
    // ══════════════════════════════════════════════════════
    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee, boolean hasFullAttendance, boolean hasOvertime) {

        Map<String, BigDecimal> allowances = new LinkedHashMap<>();
        String pos = employee.getPosition();
        if (pos == null) return allowances;

        // 單維度互斥分派 — switch 直接 O(1)
        switch (pos) {
            case "EXECUTIVE": allowances.put("職級津貼", new BigDecimal("15000")); break;
            case "DIRECTOR":  allowances.put("職級津貼", new BigDecimal("8000"));  break;
            case "MANAGER":   allowances.put("職級津貼", new BigDecimal("4000"));  break;
            case "STAFF":     allowances.put("職級津貼", new BigDecimal("1000"));  break;
            case "INTERN":    allowances.put("職級津貼", new BigDecimal("500"));   break;
            default: break;
        }
        return allowances;
    }

    // L1 無績效獎金客製，沿用 Legacy 通用績效處理
    @Override
    public boolean skipsLegacyPerformanceBonus() { return true; }
}