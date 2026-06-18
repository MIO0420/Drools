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
 * 公司 92 — L2 成長期（~100 條，雙維度交叉）硬編碼版
 * 對應 Company_92_Salary.drl
 * 特性：在 L1 單維度基礎上，疊加職級×部門、年資×職級、績效×職級雙維度判斷
 *       switch 開始需要巢狀（職級內再判部門/年資/績效），圈複雜度上升
 * 疊加邏輯：各區塊獨立累加至 companyBonus（與 DRL activation-group 各自觸發對應）
 */
public class Company92Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "92"; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        return 1.0;
    }

    // ══════════════════════════════════════════════════════
    //  請假扣薪（單維度 switch，繼承 L1）
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
    //  加班費 — 走 Legacy 通用，與 DRL 通用加班對齊
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomOvertimeCalc() { return false; }

    // ══════════════════════════════════════════════════════
    //  資歷獎金（單維度，繼承 L1）
    // ══════════════════════════════════════════════════════
    @Override
    public boolean hasCustomSeniorityCalc() { return true; }

    @Override
    public BigDecimal processSeniorityBonus(EmployeeFact employee, SalaryResult result) {
        int m = employee.getSeniorityMonths();
        BigDecimal bonus;
        String tier;
        if (m < 12)        { bonus = BigDecimal.ZERO;        tier = "不足12月"; }
        else if (m < 24)   { bonus = new BigDecimal("500");  tier = "12-23月"; }
        else if (m < 36)   { bonus = new BigDecimal("800");  tier = "24-35月"; }
        else if (m < 60)   { bonus = new BigDecimal("1200"); tier = "36-59月"; }
        else if (m < 120)  { bonus = new BigDecimal("1800"); tier = "60-119月"; }
        else               { bonus = new BigDecimal("2500"); tier = "≥120月"; }

        result.addRuleDetail("【資歷獎金】年資" + tier + "，+" + bonus);
        return bonus;
    }

    // ══════════════════════════════════════════════════════
    //  全勤獎金（單維度，繼承 L1）
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
    //  公司津貼（雙維度疊加核心）
    //  各區塊獨立累加，對應 DRL 各 activation-group
    //  ★ 此方法圈複雜度明顯高於 L1（雙維度巢狀判斷）
    // ══════════════════════════════════════════════════════
    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee, boolean hasFullAttendance, boolean hasOvertime) {

        Map<String, BigDecimal> allowances = new LinkedHashMap<>();
        String pos  = employee.getPosition();
        String dept = employee.getDepartment();
        int    sen  = employee.getSeniorityMonths();

        if (pos == null) pos = "";
        if (dept == null) dept = "";

        // ── 區塊5：職級津貼（單維度 switch）──
        switch (pos) {
            case "EXECUTIVE": allowances.put("職級津貼", new BigDecimal("15000")); break;
            case "DIRECTOR":  allowances.put("職級津貼", new BigDecimal("8000"));  break;
            case "MANAGER":   allowances.put("職級津貼", new BigDecimal("4000"));  break;
            case "STAFF":     allowances.put("職級津貼", new BigDecimal("1000"));  break;
            case "INTERN":    allowances.put("職級津貼", new BigDecimal("500"));   break;
            default: break;
        }

        // ── 區塊6：部門津貼（單維度 switch）──
        switch (dept) {
            case "RD":      allowances.put("部門津貼", new BigDecimal("3000")); break;
            case "IT":      allowances.put("部門津貼", new BigDecimal("2500")); break;
            case "SALES":   allowances.put("部門津貼", new BigDecimal("2000")); break;
            case "OPS":     allowances.put("部門津貼", new BigDecimal("1500")); break;
            case "HR":      allowances.put("部門津貼", new BigDecimal("1200")); break;
            case "FINANCE": allowances.put("部門津貼", new BigDecimal("1800")); break;
            default: break;
        }

        // ── 區塊7：職級×部門矩陣加給（雙維度，巢狀 switch）──
        BigDecimal matrix = calcMatrixAllowance(pos, dept);
        if (matrix.compareTo(BigDecimal.ZERO) > 0) {
            allowances.put("矩陣加給", matrix);
        }

        // ── 區塊8：年資×職級加成（雙維度）──
        BigDecimal senPos = calcSeniorityPositionBonus(pos, sen);
        if (senPos.compareTo(BigDecimal.ZERO) > 0) {
            allowances.put("資深加成", senPos);
        }

        // ── 區塊11：技術等級津貼（部門×年資）──
        if (sen >= 60) {
            if ("RD".equals(dept))      allowances.put("技術津貼", new BigDecimal("3000"));
            else if ("IT".equals(dept)) allowances.put("技術津貼", new BigDecimal("2500"));
        }

        return allowances;
    }

    // 職級×部門矩陣（雙維度巢狀 switch — 圈複雜度上升點）
    private BigDecimal calcMatrixAllowance(String pos, String dept) {
        switch (pos) {
            case "EXECUTIVE":
                switch (dept) {
                    case "RD":    return new BigDecimal("8000");
                    case "SALES": return new BigDecimal("9000");
                    default: return BigDecimal.ZERO;
                }
            case "DIRECTOR":
                switch (dept) {
                    case "RD":    return new BigDecimal("5000");
                    case "IT":    return new BigDecimal("4500");
                    case "SALES": return new BigDecimal("6000");
                    default: return BigDecimal.ZERO;
                }
            case "MANAGER":
                switch (dept) {
                    case "RD":      return new BigDecimal("3500");
                    case "IT":      return new BigDecimal("3000");
                    case "SALES":   return new BigDecimal("4000");
                    case "OPS":     return new BigDecimal("2500");
                    case "HR":      return new BigDecimal("2200");
                    case "FINANCE": return new BigDecimal("2800");
                    default: return BigDecimal.ZERO;
                }
            case "STAFF":
                switch (dept) {
                    case "RD":    return new BigDecimal("2000");
                    case "IT":    return new BigDecimal("1800");
                    case "SALES": return new BigDecimal("2200");
                    case "OPS":   return new BigDecimal("1500");
                    default: return BigDecimal.ZERO;
                }
            default:
                return BigDecimal.ZERO;
        }
    }

    // 年資×職級加成（雙維度）
    private BigDecimal calcSeniorityPositionBonus(String pos, int sen) {
        switch (pos) {
            case "DIRECTOR":
                if (sen >= 60) return new BigDecimal("4000");
                if (sen >= 36) return new BigDecimal("2500");
                return BigDecimal.ZERO;
            case "MANAGER":
                if (sen >= 60) return new BigDecimal("3000");
                if (sen >= 36) return new BigDecimal("1800");
                return BigDecimal.ZERO;
            case "EXECUTIVE":
                if (sen >= 60) return new BigDecimal("6000");
                return BigDecimal.ZERO;
            case "STAFF":
                if (sen >= 60) return new BigDecimal("1500");
                if (sen >= 36) return new BigDecimal("800");
                return BigDecimal.ZERO;
            default:
                return BigDecimal.ZERO;
        }
    }

    // ══════════════════════════════════════════════════════
    //  績效獎金（單維度）— 走 Legacy 通用 calcPerformanceBonus
    //  DRL BLOCK9 依 grade 給獎金，金額與 Legacy 通用完全相同
    //  （SS+8000 / SS6000 / S4000 / A+3000 / A2500 / B+1500 / B1000）
    //  前提：測試員工明確帶 performances，兩端 grade 一致
    // ══════════════════════════════════════════════════════
    @Override
    public boolean skipsLegacyPerformanceBonus() { return false; }
}