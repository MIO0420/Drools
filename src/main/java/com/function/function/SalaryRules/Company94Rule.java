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
import java.util.Set;

public class Company94Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "94"; }

    private static final String POS_ENGINEER  = "ENGINEER";
    private static final String POS_MANAGER   = "MANAGER";
    private static final String POS_DIRECTOR  = "DIRECTOR";
    private static final String POS_INTERN    = "INTERN";
    private static final String POS_SALES     = "SALES";
    private static final String POS_SUPPORT   = "SUPPORT";
    private static final String POS_HR        = "HR";
    private static final String POS_FINANCE   = "FINANCE";
    private static final String POS_EXECUTIVE = "EXECUTIVE";
    private static final String POS_PARTTIME  = "PART_TIME";

    private static final String DEPT_RD        = "RD";
    private static final String DEPT_SALES     = "SALES";
    private static final String DEPT_OPS       = "OPS";
    private static final String DEPT_HR        = "HR";
    private static final String DEPT_FINANCE   = "FINANCE";
    private static final String DEPT_LEGAL     = "LEGAL";
    private static final String DEPT_MARKETING = "MARKETING";
    private static final String DEPT_CUSTOMER  = "CUSTOMER_SERVICE";
    private static final String DEPT_EXECUTIVE = "EXECUTIVE";
    private static final String DEPT_IT        = "IT";

    private BigDecimal calcHourlyRate(BigDecimal baseSalary) {
        return baseSalary
            .divide(new BigDecimal("22"), 10, RoundingMode.HALF_UP)
            .divide(new BigDecimal("8"),  10, RoundingMode.HALF_UP);
    }

    // ── 客製化請假扣薪實作 ──────────────────────────────────────────────

    @Override
    public boolean hasCustomLeaveDeduction() { return true; }

    @Override
    public BigDecimal getLeaveDeductionRate(String leaveTypeName) {
        return new BigDecimal("0.80");
    }

    @Override
    public boolean processLeaveDeductions(EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result) {
        boolean hasAbsence = false;

        for (LeaveFact leave : leaves) {
            BigDecimal leaveHours = leave.getLeaveHours();
            if (leaveHours == null || leaveHours.compareTo(BigDecimal.ZERO) <= 0) continue;

            String type = leave.getLeaveTypeName();

            if ("曠職".equals(type)) {
                result.setFullAttendanceBonusDeducted(true);
                hasAbsence = true;
            }

            BigDecimal deduct = calcLeaveDeductionAmount(
                employee.getBaseSalary(),
                leaveHours,
                type,
                employee.getPosition(),
                employee.getDepartment(),
                employee.getSeniorityMonths(),
                employee.getTenureMonths()
            );

            if (deduct.compareTo(BigDecimal.ZERO) > 0) {
                result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                result.addRuleDetail(String.format(
                    "【請假扣薪】公司25 %s %s 小時，扣薪 -%s",
                    type, leaveHours.stripTrailingZeros().toPlainString(), deduct));
            } else {
                result.addRuleDetail(String.format(
                    "【給薪假】公司25 %s %s 小時，不扣薪",
                    type, leaveHours.stripTrailingZeros().toPlainString()));
            }
        }
        return hasAbsence;
    }

    public BigDecimal calcLeaveDeductionAmount(
            BigDecimal baseSalary,
            BigDecimal leaveHours,
            String leaveTypeName,
            String position,
            String department,
            int seniorityMonths,
            int tenureMonths) {

        if (leaveHours == null || leaveHours.compareTo(BigDecimal.ZERO) <= 0) {
            return BigDecimal.ZERO;
        }

        String pos  = position   != null ? position.toUpperCase()   : "";
        String dept = department != null ? department.toUpperCase() : "";

        boolean isExec   = POS_EXECUTIVE.equals(pos) || DEPT_EXECUTIVE.equals(dept);
        boolean isDir    = POS_DIRECTOR.equals(pos) && !isExec;
        boolean isMgr    = POS_MANAGER.equals(pos) && !isDir && !isExec;
        boolean isIntern = POS_INTERN.equals(pos) || POS_PARTTIME.equals(pos);
        boolean isRD     = DEPT_RD.equals(dept);
        boolean isIT     = DEPT_IT.equals(dept);
        boolean isSales  = (DEPT_SALES.equals(dept) || POS_SALES.equals(pos)) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isOps    = DEPT_OPS.equals(dept);
        boolean isCust   = DEPT_CUSTOMER.equals(dept);

        BigDecimal rate;

        switch (leaveTypeName) {
            case "事假":
                if (isExec)                                                               rate = new BigDecimal("0.50");
                else if (isDir)                                                           rate = new BigDecimal("0.60");
                else if (isMgr)                                                           rate = new BigDecimal("0.70");
                else if (isIntern)                                                        rate = new BigDecimal("1.00");
                else if (isSales)                                                         rate = new BigDecimal("0.90");
                else if (isCust && !isMgr && !isDir && !isExec && !isIntern)             rate = new BigDecimal("0.85");
                else if ((isRD || isIT) && !isMgr && !isDir && !isExec && !isIntern)     rate = new BigDecimal("0.75");
                else if (seniorityMonths >= 120)                                          rate = new BigDecimal("0.60");
                else                                                                      rate = new BigDecimal("0.80");
                break;

            case "普通病假":
                if (isExec)                                                               rate = BigDecimal.ZERO;
                else if (isDir)                                                           rate = new BigDecimal("0.10");
                else if (isMgr)                                                           rate = new BigDecimal("0.20");
                else if (isIntern)                                                        rate = new BigDecimal("0.50");
                else if ((isRD || isIT) && seniorityMonths >= 36)                         rate = new BigDecimal("0.15");
                else if (isRD || isIT)                                                    rate = new BigDecimal("0.25");
                else if (isSales)                                                         rate = new BigDecimal("0.40");
                else if (seniorityMonths >= 120)                                          rate = new BigDecimal("0.10");
                else                                                                      rate = new BigDecimal("0.30");
                break;

            case "生理假":
                return BigDecimal.ZERO;

            case "曠職":
                if (isExec)                                                               rate = new BigDecimal("2.00");
                else if (isDir)                                                           rate = new BigDecimal("1.80");
                else if (isMgr)                                                           rate = new BigDecimal("1.70");
                else if (isIntern)                                                        rate = new BigDecimal("1.20");
                else if (isCust && !isMgr && !isDir && !isExec && !isIntern)             rate = new BigDecimal("1.80");
                else if (isSales)                                                         rate = new BigDecimal("1.70");
                else if (isOps && !isMgr && !isDir && !isExec && !isIntern)              rate = new BigDecimal("1.60");
                else if (seniorityMonths >= 120)                                          rate = new BigDecimal("1.30");
                else                                                                      rate = new BigDecimal("1.50");
                break;

            case "住院病假":
                if (isExec)                                                               rate = BigDecimal.ZERO;
                else if (isDir || isMgr)                                                  rate = new BigDecimal("0.10");
                else if (isIntern)                                                        rate = new BigDecimal("0.30");
                else if (seniorityMonths >= 60)                                           rate = new BigDecimal("0.10");
                else                                                                      rate = new BigDecimal("0.20");
                break;

            case "安胎假":
                if (isExec)                                                               rate = BigDecimal.ZERO;
                else if (isDir || isMgr)                                                  rate = new BigDecimal("0.20");
                else if (isIntern)                                                        rate = new BigDecimal("0.50");
                else                                                                      rate = new BigDecimal("0.40");
                break;

            case "育嬰假":
                if (isExec)                                                               rate = BigDecimal.ZERO;
                else if (isDir || isMgr)                                                  rate = new BigDecimal("0.05");
                else if (isIntern)                                                        rate = new BigDecimal("0.20");
                else if (DEPT_HR.equals(dept) || POS_HR.equals(pos))                      rate = new BigDecimal("0.05");
                else                                                                      rate = new BigDecimal("0.10");
                break;

            case "家庭照顧假":
                if (isExec)                                                               rate = new BigDecimal("0.20");
                else if (isDir)                                                           rate = new BigDecimal("0.30");
                else if (isMgr)                                                           rate = new BigDecimal("0.40");
                else if (isIntern)                                                        rate = new BigDecimal("0.80");
                else if ((isCust || isOps) && !isMgr && !isDir && !isExec && !isIntern)  rate = new BigDecimal("0.65");
                else if (seniorityMonths >= 60)                                           rate = new BigDecimal("0.40");
                else                                                                      rate = new BigDecimal("0.60");
                break;

            case "留職停薪":
                if (isExec)       rate = new BigDecimal("0.50");
                else if (isDir)   rate = new BigDecimal("0.70");
                else if (isMgr)   rate = new BigDecimal("0.80");
                else              rate = new BigDecimal("1.00");
                break;

            case "天然災害假":
            case "停班":
                return BigDecimal.ZERO;

            case "產假":
                if (tenureMonths >= 6) return BigDecimal.ZERO;
                if (isIntern)          rate = new BigDecimal("0.60");
                else if (isRD || isIT) rate = new BigDecimal("0.30");
                else                   rate = new BigDecimal("0.50");
                break;

            case "流產假": case "補休": case "特休": case "婚假":
            case "喪假":  case "公假": case "陪產假": case "產檢假":
            case "公傷病假": case "生日假":
                return BigDecimal.ZERO;

            default:
                return BigDecimal.ZERO;
        }

        if (rate.compareTo(BigDecimal.ZERO) == 0) return BigDecimal.ZERO;

        return calcHourlyRate(baseSalary)
            .multiply(leaveHours)
            .multiply(rate)
            .setScale(2, RoundingMode.HALF_UP);
    }

    // ── 客製化加班費實作 ──────────────────────────────────────────────

    @Override
    public boolean hasCustomOvertimeCalc() { return true; }

    @Override
    public void processOvertimeBonus(EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result) {
        this.calcOvertimeBonus(employee, overtimes, result);
    }

    @Override
    public BigDecimal calcOvertimePay(String overtimeType, int overtimeHours, BigDecimal hourlyRate) {
        return calcOvertimePayFull(overtimeType, overtimeHours, hourlyRate, "", "");
    }

    // ── BigDecimal 版本（支援小數時數，如 2.5H）────────────────────────
    public BigDecimal calcOvertimePayFull(
            String overtimeType,
            BigDecimal overtimeHours,
            BigDecimal hourlyRate,
            String position,
            String department) {

        String pos  = position   != null ? position.toUpperCase()   : "";
        String dept = department != null ? department.toUpperCase() : "";

        boolean isExec   = POS_EXECUTIVE.equals(pos) || DEPT_EXECUTIVE.equals(dept);
        boolean isDir    = POS_DIRECTOR.equals(pos) && !isExec;
        boolean isMgr    = POS_MANAGER.equals(pos) && !isDir && !isExec;
        boolean isIntern = POS_INTERN.equals(pos) || POS_PARTTIME.equals(pos);
        boolean isRD     = DEPT_RD.equals(dept) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isIT     = DEPT_IT.equals(dept) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isSales  = (DEPT_SALES.equals(dept) || POS_SALES.equals(pos)) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isOps    = DEPT_OPS.equals(dept) && !isMgr && !isDir && !isExec && !isIntern;

        switch (overtimeType) {
            case "WEEKDAY": {
                BigDecimal r1, r2, r3;
                if (isExec)            { r1 = new BigDecimal("1.0"); r2 = new BigDecimal("1.0"); r3 = new BigDecimal("1.0"); }
                else if (isDir)        { r1 = new BigDecimal("1.2"); r2 = new BigDecimal("1.5"); r3 = new BigDecimal("1.8"); }
                else if (isMgr)        { r1 = new BigDecimal("1.3"); r2 = new BigDecimal("1.6"); r3 = new BigDecimal("2.0"); }
                else if (isIntern)     { r1 = new BigDecimal("1.2"); r2 = new BigDecimal("1.2"); r3 = new BigDecimal("1.5"); }
                else if (isRD || isIT) { r1 = new BigDecimal("1.5"); r2 = new BigDecimal("2.0"); r3 = new BigDecimal("2.5"); }
                else if (isSales)      { r1 = new BigDecimal("1.4"); r2 = new BigDecimal("1.8"); r3 = new BigDecimal("2.2"); }
                else                   { r1 = new BigDecimal("1.5"); r2 = new BigDecimal("2.0"); r3 = new BigDecimal("2.5"); }
                BigDecimal TWO  = new BigDecimal("2");
                BigDecimal FOUR = new BigDecimal("4");
                BigDecimal h1 = overtimeHours.min(TWO);
                BigDecimal h2 = overtimeHours.subtract(TWO).max(BigDecimal.ZERO).min(TWO);
                BigDecimal h3 = overtimeHours.subtract(FOUR).max(BigDecimal.ZERO);
                return hourlyRate.multiply(h1).multiply(r1)
                    .add(hourlyRate.multiply(h2).multiply(r2))
                    .add(hourlyRate.multiply(h3).multiply(r3))
                    .setScale(2, RoundingMode.HALF_UP);
            }
            case "REST_DAY": {
                BigDecimal r1, r2, r3;
                if (isExec)              { r1 = new BigDecimal("1.5"); r2 = new BigDecimal("1.5"); r3 = new BigDecimal("1.5"); }
                else if (isDir || isMgr) { r1 = new BigDecimal("2.0"); r2 = new BigDecimal("2.5"); r3 = new BigDecimal("3.0"); }
                else if (isIntern)       { r1 = new BigDecimal("1.5"); r2 = new BigDecimal("2.0"); r3 = new BigDecimal("2.0"); }
                else if (isRD || isIT)   { r1 = new BigDecimal("2.5"); r2 = new BigDecimal("3.0"); r3 = new BigDecimal("3.5"); }
                else if (isSales)        { r1 = new BigDecimal("2.2"); r2 = new BigDecimal("2.8"); r3 = new BigDecimal("3.2"); }
                else                     { r1 = new BigDecimal("2.5"); r2 = new BigDecimal("3.0"); r3 = new BigDecimal("3.5"); }
                BigDecimal FOUR  = new BigDecimal("4");
                BigDecimal EIGHT = new BigDecimal("8");
                BigDecimal h1 = overtimeHours.min(FOUR);
                BigDecimal h2 = overtimeHours.subtract(FOUR).max(BigDecimal.ZERO).min(FOUR);
                BigDecimal h3 = overtimeHours.subtract(EIGHT).max(BigDecimal.ZERO);
                return hourlyRate.multiply(h1).multiply(r1)
                    .add(hourlyRate.multiply(h2).multiply(r2))
                    .add(hourlyRate.multiply(h3).multiply(r3))
                    .setScale(2, RoundingMode.HALF_UP);
            }
            case "NATIONAL_HOLIDAY": {
                BigDecimal rBase, rExtra;
                if (isExec)              { rBase = new BigDecimal("2.0"); rExtra = new BigDecimal("2.5"); }
                else if (isDir || isMgr) { rBase = new BigDecimal("2.5"); rExtra = new BigDecimal("3.5"); }
                else if (isIntern)       { rBase = new BigDecimal("2.0"); rExtra = new BigDecimal("2.5"); }
                else if (isRD || isIT)   { rBase = new BigDecimal("3.0"); rExtra = new BigDecimal("4.0"); }
                else if (isSales)        { rBase = new BigDecimal("2.8"); rExtra = new BigDecimal("3.5"); }
                else                     { rBase = new BigDecimal("3.0"); rExtra = new BigDecimal("4.0"); }
                BigDecimal EIGHT = new BigDecimal("8");
                BigDecimal hBase  = overtimeHours.min(EIGHT);
                BigDecimal hExtra = overtimeHours.subtract(EIGHT).max(BigDecimal.ZERO);
                return hourlyRate.multiply(hBase).multiply(rBase)
                    .add(hourlyRate.multiply(hExtra).multiply(rExtra))
                    .setScale(2, RoundingMode.HALF_UP);
            }
            case "STATUTORY_HOLIDAY": {
                BigDecimal rBase, rExtra;
                if (isExec)              { rBase = new BigDecimal("2.0"); rExtra = new BigDecimal("3.0"); }
                else if (isDir || isMgr) { rBase = new BigDecimal("2.5"); rExtra = new BigDecimal("4.0"); }
                else if (isIntern)       { rBase = new BigDecimal("2.0"); rExtra = new BigDecimal("2.5"); }
                else if (isRD || isIT)   { rBase = new BigDecimal("3.0"); rExtra = new BigDecimal("4.5"); }
                else if (isSales)        { rBase = new BigDecimal("2.8"); rExtra = new BigDecimal("4.0"); }
                else                     { rBase = new BigDecimal("3.0"); rExtra = new BigDecimal("4.5"); }
                BigDecimal EIGHT = new BigDecimal("8");
                BigDecimal hBase  = overtimeHours.min(EIGHT);
                BigDecimal hExtra = overtimeHours.subtract(EIGHT).max(BigDecimal.ZERO);
                return hourlyRate.multiply(hBase).multiply(rBase)
                    .add(hourlyRate.multiply(hExtra).multiply(rExtra))
                    .setScale(2, RoundingMode.HALF_UP);
            }
            case "ANNUAL_LEAVE_DAY": {
                BigDecimal rate;
                if (isExec)              rate = new BigDecimal("1.5");
                else if (isDir || isMgr) rate = new BigDecimal("2.0");
                else if (isIntern)       rate = new BigDecimal("1.5");
                else if (isRD || isIT)   rate = new BigDecimal("2.2");
                else if (isSales)        rate = new BigDecimal("2.0");
                else                     rate = new BigDecimal("2.0");
                return hourlyRate.multiply(overtimeHours).multiply(rate)
                    .setScale(2, RoundingMode.HALF_UP);
            }
            default:
                return BigDecimal.ZERO;
        }
    }

    // ── int 版本（介面相容）────────────────────────────────────────────
    public BigDecimal calcOvertimePayFull(
            String overtimeType,
            int overtimeHours,
            BigDecimal hourlyRate,
            String position,
            String department) {
        return calcOvertimePayFull(overtimeType, new BigDecimal(overtimeHours), hourlyRate, position, department);
    }

    // ── 加班總計算（processOvertimeBonus 呼叫此方法）────────────────────
    public void calcOvertimeBonus(
            EmployeeFact employee,
            List<OvertimeFact> overtimes,
            SalaryResult result) {

        BigDecimal hourlyRate = calcHourlyRate(employee.getBaseSalary());
        BigDecimal totalOvertimeHours = BigDecimal.ZERO;

        for (OvertimeFact ot : overtimes) {
            BigDecimal otHours = ot.getOvertimeHours();
            if (otHours == null || otHours.compareTo(BigDecimal.ZERO) <= 0) continue;

            totalOvertimeHours = totalOvertimeHours.add(otHours);

            BigDecimal pay = calcOvertimePayFull(
                ot.getOvertimeType(),
                otHours,
                hourlyRate,
                employee.getPosition(),
                employee.getDepartment());

            if (pay == null) {
                result.addRuleDetail("【加班費】未知加班類型：" + ot.getOvertimeType() + "，略過");
                continue;
            }

            result.setOvertimeBonus(result.getOvertimeBonus().add(pay));
            result.addRuleDetail(String.format(
                "【加班費】公司25 %s %sH，加給 +%s",
                ot.getOvertimeType(),
                otHours.stripTrailingZeros().toPlainString(),
                pay));

            // ── 夜班津貼 ──────────────────────────────────────────
            BigDecimal nightShift = calcNightShiftAllowance(
                ot.getOvertimeType(), employee.getDepartment());
            if (nightShift.compareTo(BigDecimal.ZERO) > 0) {
                result.setOvertimeBonus(result.getOvertimeBonus().add(nightShift));
                result.addRuleDetail(String.format(
                    "【夜班津貼】公司25 %s，夜班津貼 +%s",
                    ot.getOvertimeType(), nightShift));
            }
        }

        // ── 加班時數獎勵 ──────────────────────────────────────────
        if (totalOvertimeHours.compareTo(BigDecimal.ZERO) > 0) {
            int totalHoursInt = totalOvertimeHours.intValue();
            BigDecimal hoursBonus = calcOvertimeHoursBonus(
                totalHoursInt,
                employee.getPosition(),
                employee.getDepartment());
            if (hoursBonus.compareTo(BigDecimal.ZERO) > 0) {
                result.setOvertimeBonus(result.getOvertimeBonus().add(hoursBonus));
                result.addRuleDetail(String.format(
                    "【加班時數獎勵】公司25 累計 %sH，獎勵 +%s",
                    totalOvertimeHours.stripTrailingZeros().toPlainString(), hoursBonus));
            }

            // ── RD/IT 加班時數額外加成 ──────────────────────────────
            BigDecimal rdItExtra = calcRdItOvertimeHoursExtra(
                totalHoursInt,
                employee.getPosition(),
                employee.getDepartment());
            if (rdItExtra.compareTo(BigDecimal.ZERO) > 0) {
                result.setOvertimeBonus(result.getOvertimeBonus().add(rdItExtra));
                result.addRuleDetail(String.format(
                    "【RD/IT加班時數額外加成】公司25 累計 %sH，額外獎勵 +%s",
                    totalOvertimeHours.stripTrailingZeros().toPlainString(), rdItExtra));
            }
        }
    }

    // ── 客製化全勤與資歷實作 ──────────────────────────────────────────

    @Override
    public boolean hasCustomFullAttendanceCalc() { return true; }

    @Override
    public boolean processFullAttendance(EmployeeFact employee, SalaryResult result, boolean hasAbsence) {
        return !result.isFullAttendanceBonusDeducted()
            && (!hasAbsence || result.isFullAttendancePenaltyExempt());
    }

    @Override
    public boolean hasCustomSeniorityCalc() { return true; }

    @Override
    public BigDecimal processSeniorityBonus(EmployeeFact employee, SalaryResult result) {
        BigDecimal adjustedSeniority = calcSeniorityBonusDirect(
            employee.getSeniorityMonths(),
            employee.getPosition(),
            employee.getDepartment()
        );
        result.addRuleDetail(String.format(
            "【資歷獎金】公司25 直接計算，資歷獎金 %s", adjustedSeniority));
        return adjustedSeniority;
    }

    @Override
    public boolean skipsLegacyPerformanceBonus() { return true; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        return 1.0;
    }

    public BigDecimal calcSeniorityBonusDirect(int seniorityMonths, String position, String department) {
        String pos  = position   != null ? position.toUpperCase()   : "";
        String dept = department != null ? department.toUpperCase() : "";

        boolean isExec   = POS_EXECUTIVE.equals(pos) || DEPT_EXECUTIVE.equals(dept);
        boolean isDir    = POS_DIRECTOR.equals(pos) && !isExec;
        boolean isMgr    = POS_MANAGER.equals(pos) && !isDir && !isExec;
        boolean isIntern = POS_INTERN.equals(pos) || POS_PARTTIME.equals(pos);
        boolean isRD     = DEPT_RD.equals(dept) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isIT     = DEPT_IT.equals(dept) && !isMgr && !isDir && !isExec && !isIntern;
        boolean isSales  = (DEPT_SALES.equals(dept) || POS_SALES.equals(pos)) && !isMgr && !isDir && !isExec && !isIntern;

        if (isExec) {
            if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("1.50")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  60) return new BigDecimal("500").multiply(new BigDecimal("1.80")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("2.20")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("2500").multiply(new BigDecimal("2.80")).setScale(0, RoundingMode.HALF_UP);
        }
        if (isDir) {
            if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("1.40")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  60) return new BigDecimal("500").multiply(new BigDecimal("1.70")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("2.10")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("2500").multiply(new BigDecimal("2.60")).setScale(0, RoundingMode.HALF_UP);
        }
        if (isMgr) {
            if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("1.30")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  60) return new BigDecimal("500").multiply(new BigDecimal("1.60")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("2.00")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("2500").multiply(new BigDecimal("2.40")).setScale(0, RoundingMode.HALF_UP);
        }
        if (isIntern) {
            if (seniorityMonths <  12) return BigDecimal.ZERO;
            if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("0.90")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("800").multiply(new BigDecimal("1.00")).setScale(0, RoundingMode.HALF_UP);
        }
        if (isRD || isIT) {
            if (seniorityMonths <  12) return BigDecimal.ZERO;
            if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("1.30")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  36) return new BigDecimal("800").multiply(new BigDecimal("1.50")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  60) return new BigDecimal("1200").multiply(new BigDecimal("1.70")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths <  84) return new BigDecimal("1800").multiply(new BigDecimal("1.90")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("2.10")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("2500").multiply(new BigDecimal("2.50")).setScale(0, RoundingMode.HALF_UP);
        }
        if (isSales) {
            if (seniorityMonths <  12) return BigDecimal.ZERO;
            if (seniorityMonths <  60) return new BigDecimal("500").multiply(new BigDecimal("1.20")).setScale(0, RoundingMode.HALF_UP);
            if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("1.70")).setScale(0, RoundingMode.HALF_UP);
            return new BigDecimal("2500").multiply(new BigDecimal("2.00")).setScale(0, RoundingMode.HALF_UP);
        }
        if (seniorityMonths <  12) return BigDecimal.ZERO;
        if (seniorityMonths <  24) return new BigDecimal("500").multiply(new BigDecimal("1.25")).setScale(0, RoundingMode.HALF_UP);
        if (seniorityMonths <  36) return new BigDecimal("800").multiply(new BigDecimal("1.40")).setScale(0, RoundingMode.HALF_UP);
        if (seniorityMonths <  60) return new BigDecimal("1200").multiply(new BigDecimal("1.58")).setScale(0, RoundingMode.HALF_UP);
        if (seniorityMonths <  84) return new BigDecimal("1800").multiply(new BigDecimal("1.75")).setScale(0, RoundingMode.HALF_UP);
        if (seniorityMonths < 120) return new BigDecimal("1800").multiply(new BigDecimal("1.90")).setScale(0, RoundingMode.HALF_UP);
        return new BigDecimal("2500").multiply(new BigDecimal("2.00")).setScale(0, RoundingMode.HALF_UP);
    }

    // ── getCustomAllowances 客製化津貼入口 ────────────────────────────────────
    //
    // 【修改點】新增 overtimes 參數版本，用於 Legacy 路徑傳入加班清單以計算夜班津貼。
    // Legacy 呼叫時走 getCustomAllowances(employee, hasFullAttendance, hasOvertime, leaves, result)，
    // 此版本會從 SalaryResult 的 ruleDetails 中推斷不到加班類型，
    // 因此另外新增 getCustomAllowancesWithOvertimes() 供 Legacy calculate() 直接呼叫。

    /**
     * 供 Legacy CalculateSalaryLegacyFunction.calculate() 直接呼叫，
     * 傳入加班清單以計算夜班津貼（REST_DAY / STATUTORY_HOLIDAY）。
     */
    public Map<String, BigDecimal> getCustomAllowancesWithOvertimes(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime,
            List<LeaveFact> leaves,
            List<OvertimeFact> overtimes,
            SalaryResult result) {

        boolean hasAnyLeave = leaves != null && leaves.stream()
            .anyMatch(l -> l.getLeaveHours() != null
                        && l.getLeaveHours().compareTo(BigDecimal.ZERO) > 0);
        BigDecimal absentDays = employee.getAbsentDays() != null
            ? employee.getAbsentDays() : BigDecimal.ZERO;
        boolean isPerfectAttendance = !hasAnyLeave
            && absentDays.compareTo(BigDecimal.ZERO) == 0
            && (result == null || !result.isFullAttendanceBonusDeducted());

        // 夜班津貼已由 processOvertimeBonus/calcOvertimeBonus 計入 overtimeBonus，
        // 此處只計算 companyBonus（allowances），不重複加夜班津貼。
        return getCustomAllowances(
            employee, hasFullAttendance, hasOvertime, isPerfectAttendance);
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime,
            List<LeaveFact> leaves,
            SalaryResult result) {

        boolean hasAnyLeave = leaves != null && leaves.stream()
            .anyMatch(l -> l.getLeaveHours() != null
                        && l.getLeaveHours().compareTo(BigDecimal.ZERO) > 0);
        BigDecimal absentDays = employee.getAbsentDays() != null
            ? employee.getAbsentDays() : BigDecimal.ZERO;
        boolean isPerfectAttendance = !hasAnyLeave
            && absentDays.compareTo(BigDecimal.ZERO) == 0
            && (result == null || !result.isFullAttendanceBonusDeducted());

        return getCustomAllowances(employee, hasFullAttendance, hasOvertime, isPerfectAttendance);
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime) {
        return getCustomAllowances(employee, hasFullAttendance, hasOvertime, false);
    }

    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime,
            boolean isPerfectAttendance,
            List<LeaveFact> leaveFacts) {
        return getCustomAllowances(employee, hasFullAttendance, hasOvertime, isPerfectAttendance);
    }

    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime,
            boolean isPerfectAttendance) {

        Map<String, BigDecimal> map = new LinkedHashMap<>();

        BigDecimal base       = employee.getBaseSalary();
        int        seniority  = employee.getSeniorityMonths();
        int        tenure     = employee.getTenureMonths();
        BigDecimal absentDays = employee.getAbsentDays() != null ? employee.getAbsentDays() : BigDecimal.ZERO;
        String pos  = employee.getPosition()   != null ? employee.getPosition().toUpperCase()   : "";
        String dept = employee.getDepartment() != null ? employee.getDepartment().toUpperCase() : "";

        boolean isExec   = POS_EXECUTIVE.equals(pos) || DEPT_EXECUTIVE.equals(dept);
        boolean isDir    = POS_DIRECTOR.equals(pos) && !isExec;
        boolean isMgr    = POS_MANAGER.equals(pos) && !isDir && !isExec;
        boolean isIntern = POS_INTERN.equals(pos) || POS_PARTTIME.equals(pos);
        boolean isRD     = DEPT_RD.equals(dept);
        boolean isIT     = DEPT_IT.equals(dept);
        boolean isSales  = (DEPT_SALES.equals(dept) || POS_SALES.equals(pos)) && !isMgr && !isDir && !isExec;
        boolean isOps    = DEPT_OPS.equals(dept);
        boolean isHR     = DEPT_HR.equals(dept) || POS_HR.equals(pos);
        boolean isFin    = DEPT_FINANCE.equals(dept) || POS_FINANCE.equals(pos);
        boolean isLegal  = DEPT_LEGAL.equals(dept);
        boolean isMkt    = DEPT_MARKETING.equals(dept);
        boolean isCust   = DEPT_CUSTOMER.equals(dept);

        // ── 職位津貼 ──────────────────────────────────────────────
        if (isExec)        map.put("高管職位津貼",     new BigDecimal("15000"));
        else if (isDir)    map.put("總監職位津貼",     new BigDecimal("10000"));
        else if (isMgr)    map.put("主管職位津貼",     new BigDecimal("6000"));
        else if (isIntern) map.put("實習生基本津貼",   new BigDecimal("500"));
        else               map.put("正職員工基本津貼", new BigDecimal("1000"));

        // ── 部門津貼 ──────────────────────────────────────────────
        if (isRD)    map.put("研發部門津貼", new BigDecimal("6000"));
        if (isIT)    map.put("IT部門津貼",   new BigDecimal("5000"));
        if (isSales) map.put("業務部門津貼", new BigDecimal("3000"));
        if (isOps)   map.put("營運部門津貼", new BigDecimal("2500"));
        if (isHR)    map.put("人資部門津貼", new BigDecimal("2000"));
        if (isFin)   map.put("財務部門津貼", new BigDecimal("3500"));
        if (isLegal) map.put("法務部門津貼", new BigDecimal("4000"));
        if (isMkt)   map.put("行銷部門津貼", new BigDecimal("2800"));
        if (isCust)  map.put("客服部門津貼", new BigDecimal("2200"));

        // ── 技術職等 ──────────────────────────────────────────────
        if ((isRD || isIT) && !isDir && !isMgr && !isExec && !isIntern) {
            if      (base.compareTo(new BigDecimal("120000")) >= 0) map.put("技術職等_T6", new BigDecimal("12000"));
            else if (base.compareTo(new BigDecimal("100000")) >= 0) map.put("技術職等_T5", new BigDecimal("8000"));
            else if (base.compareTo(new BigDecimal("80000"))  >= 0) map.put("技術職等_T4", new BigDecimal("5000"));
            else if (base.compareTo(new BigDecimal("60000"))  >= 0) map.put("技術職等_T3", new BigDecimal("3000"));
            else if (base.compareTo(new BigDecimal("45000"))  >= 0) map.put("技術職等_T2", new BigDecimal("1500"));
            else                                                    map.put("技術職等_T1", new BigDecimal("500"));
        }

        // ── 業務績效 ──────────────────────────────────────────────
        if (isSales) {
            if      (base.compareTo(new BigDecimal("100000")) >= 0) map.put("業務績效_頂尖", new BigDecimal("10000"));
            else if (base.compareTo(new BigDecimal("80000"))  >= 0) map.put("業務績效_優秀", new BigDecimal("7000"));
            else if (base.compareTo(new BigDecimal("60000"))  >= 0) map.put("業務績效_良好", new BigDecimal("4500"));
            else if (base.compareTo(new BigDecimal("45000"))  >= 0) map.put("業務績效_達標", new BigDecimal("2500"));
            else                                                    map.put("業務績效_基本", new BigDecimal("1000"));
            if (hasFullAttendance) map.put("業務全勤加成", new BigDecimal("2000"));
            if (hasOvertime)       map.put("業務加班獎勵", new BigDecimal("1500"));
        }

        // ── 客服 ──────────────────────────────────────────────────
        if (isCust) {
            map.put("客服輪班津貼", new BigDecimal("1800"));
            if (hasOvertime) map.put("客服加班補貼", new BigDecimal("1200"));
        }

        // ── 行銷 ──────────────────────────────────────────────────
        if (isMkt) {
            if (base.compareTo(new BigDecimal("60000")) >= 0) map.put("行銷創意獎金_高", new BigDecimal("3000"));
            else                                              map.put("行銷創意獎金_基", new BigDecimal("1500"));
        }

        // ── 人資 ──────────────────────────────────────────────────
        if (isHR) {
            map.put("人資招募津貼", new BigDecimal("1500"));
            if (seniority >= 36) map.put("人資資深津貼", new BigDecimal("2000"));
        }

        // ── 績效獎金（非業務）────────────────────────────────────
        // 對齊 DRL：DRL 績效獎金規則用 department != "SALES"（純部門判斷），
        // 而非 !isSales（後者排除 EXECUTIVE，導致 EXECUTIVE+SALES 被誤判為非SALES而發獎金）
        if (!DEPT_SALES.equals(dept)) {
            if      (base.compareTo(new BigDecimal("120000")) >= 0) map.put("績效獎金_SS+級", new BigDecimal("8000"));
            else if (base.compareTo(new BigDecimal("100000")) >= 0) map.put("績效獎金_SS級",  new BigDecimal("6000"));
            else if (base.compareTo(new BigDecimal("80000"))  >= 0) map.put("績效獎金_S級",   new BigDecimal("4000"));
            else if (base.compareTo(new BigDecimal("60000"))  >= 0) map.put("績效獎金_A+級",  new BigDecimal("3000"));
            else if (base.compareTo(new BigDecimal("50000"))  >= 0) map.put("績效獎金_A級",   new BigDecimal("2500"));
            else if (base.compareTo(new BigDecimal("38000"))  >= 0) map.put("績效獎金_B+級",  new BigDecimal("1500"));
            else                                                    map.put("績效獎金_B級",   new BigDecimal("1000"));
        }

        // ── 年資津貼 ──────────────────────────────────────────────
        if (seniority >= 12)  map.put("年資津貼_1年",  new BigDecimal("3000"));
        if (seniority >= 36)  map.put("年資津貼_3年",  new BigDecimal("2000"));
        if (seniority >= 60)  map.put("年資津貼_5年",  new BigDecimal("2500"));
        if (seniority >= 120) map.put("年資津貼_10年", new BigDecimal("4000"));
        if (seniority >= 180) map.put("年資津貼_15年", new BigDecimal("5000"));
        if (seniority >= 240) map.put("年資津貼_20年", new BigDecimal("6000"));

        if (seniority >= 120) map.put("高年資特別獎金", new BigDecimal("5000"));
        if (seniority >= 180) map.put("資深顧問獎金",   new BigDecimal("3000"));
        if (seniority >= 240) map.put("退休前特別獎金", new BigDecimal("8000"));

        // ── 資深複合獎金 ──────────────────────────────────────────
        if (isExec && seniority >= 60)  map.put("高管資深複合獎金", new BigDecimal("8000"));
        if (isDir  && seniority >= 60)  map.put("總監資深複合獎金", new BigDecimal("5000"));
        if (isMgr  && seniority >= 36)  map.put("主管資深複合獎金", new BigDecimal("3000"));
        if ((isRD || isIT) && seniority >= 60 && !isDir && !isMgr && !isExec && !isIntern)
            map.put("技術資深複合獎金", new BigDecimal("4000"));

        // ── 試用期 / 到職扣減 ─────────────────────────────────────
        if (tenure < 3) {
            if (isIntern) map.put("試用期扣減_實習", new BigDecimal("-500"));
            else          map.put("試用期扣減",       new BigDecimal("-2000"));
        }
        if (tenure < 6 && !isExec && !isDir) {
            map.put("到職未滿半年扣減", new BigDecimal("-1000"));
        }

        // ── 全勤獎金 ──────────────────────────────────────────────
        if (hasFullAttendance && tenure >= 1) {
            if (isExec)        map.put("高管全勤獎金",   new BigDecimal("5000"));
            else if (isDir)    map.put("總監全勤獎金",   new BigDecimal("3500"));
            else if (isMgr)    map.put("主管全勤獎金",   new BigDecimal("2500"));
            else if (isIntern) map.put("實習生全勤獎金", new BigDecimal("500"));
            else               map.put("全勤獎金",       new BigDecimal("1500"));

            if (seniority >= 24 && !isIntern) map.put("全勤資深加成",   new BigDecimal("500"));
            if (seniority >= 60 && !isIntern) map.put("全勤高資深加成", new BigDecimal("800"));
            if (base.compareTo(new BigDecimal("80000")) >= 0 && !isExec && !isDir)
                map.put("全勤高職等加成", new BigDecimal("800"));
            if (isRD || isIT) map.put("技術全勤加成", new BigDecimal("600"));
            if (isCust)       map.put("客服全勤加成", new BigDecimal("700"));
            if (isOps)        map.put("營運全勤加成", new BigDecimal("600"));
        }

        // ── 加班津貼 ──────────────────────────────────────────────
        if (hasOvertime) {
            if (isExec)        map.put("高管加班責任補償", new BigDecimal("2000"));
            else if (isDir)    map.put("總監加班津貼",     new BigDecimal("2000"));
            else if (isMgr)    map.put("主管加班津貼",     new BigDecimal("1800"));
            else if (isIntern) map.put("實習生加班津貼",   new BigDecimal("400"));
            else               map.put("加班津貼",         new BigDecimal("1200"));

            if (seniority >= 36 && !isIntern && !isExec) map.put("加班資深加成", new BigDecimal("600"));
            if (base.compareTo(new BigDecimal("70000")) >= 0 && !isExec)
                map.put("加班高職等加成", new BigDecimal("900"));
            if (isRD || isIT) map.put("技術加班加成", new BigDecimal("800"));
            if (isOps)        map.put("營運加班加成", new BigDecimal("700"));
        }

        // ── 雙達標獎金 ────────────────────────────────────────────
        if (hasFullAttendance && hasOvertime) {
            if (isExec)     map.put("高管雙達標獎金", new BigDecimal("3000"));
            else if (isDir) map.put("總監雙達標獎金", new BigDecimal("2500"));
            else if (isMgr) map.put("主管雙達標獎金", new BigDecimal("2000"));
            else if (!isIntern) map.put("全勤加班雙達標", new BigDecimal("800"));

            if (seniority >= 60)  map.put("雙達標資深三重加成", new BigDecimal("1000"));
            if (isRD || isIT)     map.put("技術雙達標加成",     new BigDecimal("1200"));
            if (isSales)          map.put("業務雙達標加成",     new BigDecimal("1000"));
        }

        // ── 多假扣減 ──────────────────────────────────────────────
        if (absentDays.compareTo(new BigDecimal("5")) > 0) {
            if (isExec || isDir) map.put("高管多假重罰",  new BigDecimal("-8000"));
            else if (isMgr)      map.put("主管多假重罰",  new BigDecimal("-6000"));
            else                 map.put("多假扣減_嚴重", new BigDecimal("-5000"));
        } else if (absentDays.compareTo(new BigDecimal("3")) > 0) {
            if (isExec || isDir) map.put("高管多假中罰",  new BigDecimal("-5000"));
            else if (isMgr)      map.put("主管多假中罰",  new BigDecimal("-4000"));
            else                 map.put("多假扣減_中度", new BigDecimal("-3000"));
        } else if (absentDays.compareTo(BigDecimal.ONE) > 0) {
            if (isExec || isDir) map.put("高管多假輕罰",  new BigDecimal("-2500"));
            else if (isMgr)      map.put("主管多假輕罰",  new BigDecimal("-2000"));
            else                 map.put("多假扣減_輕度", new BigDecimal("-1500"));
        }

        if (absentDays.compareTo(new BigDecimal("3")) > 0 && !hasFullAttendance) {
            if (isExec || isDir) map.put("高管曠職特別重罰", new BigDecimal("-10000"));
            else if (isMgr)      map.put("主管曠職重罰",     new BigDecimal("-6000"));
            else                 map.put("曠職重罰扣減",     new BigDecimal("-4000"));
        }

        // ── 零缺勤獎勵（對齊 DRL Company_25_PerfectAttendance_*）──
        if (isPerfectAttendance) {
            if (isExec) {
                map.put("高管零缺勤獎勵", new BigDecimal("3000"));
            } else if (isDir) {
                map.put("總監零缺勤獎勵", new BigDecimal("2000"));
            } else if (isMgr) {
                map.put("主管零缺勤獎勵", new BigDecimal("1500"));
            } else if (!isIntern) {
                map.put("零請假完美出勤獎勵", new BigDecimal("1000"));
            }

            if (seniority >= 36 && !isIntern) {
                map.put("資深零缺勤獎勵(≥36m)", new BigDecimal("1800"));
            }

            if (isSales && seniority >= 60 && tenure >= 24) {
                map.put("業務資深完美出勤特別獎", new BigDecimal("4500"));
            }

            if ((isRD || isIT) && !isMgr && !isDir && !isExec && !isIntern
                    && seniority >= 84 && tenure >= 36) {
                map.put("RD/IT資深完美出勤特別獎", new BigDecimal("6000"));
            }
        }

        // ── 服務年資補貼 ──────────────────────────────────────────
        if (tenure >= 60)  map.put("長期服務補貼",     new BigDecimal("2000"));
        if (tenure >= 120) map.put("超長服務特別補貼", new BigDecimal("3000"));

        if (seniority >= 84 && tenure >= 36) map.put("資深穩定津貼", new BigDecimal("2500"));
        if (seniority >= 120 && tenure >= 120) map.put("十年無間斷服務獎", new BigDecimal("6000"));

        // ── 薪資區間補貼 ──────────────────────────────────────────
        if (base.compareTo(new BigDecimal("30000")) < 0 && !isIntern)
            map.put("低薪保障補貼", new BigDecimal("1200"));
        if (base.compareTo(new BigDecimal("30000")) >= 0 && base.compareTo(new BigDecimal("50000")) < 0)
            map.put("中薪激勵津貼", new BigDecimal("800"));
        if (base.compareTo(new BigDecimal("80000")) >= 0 && !isExec && !isDir)
            map.put("高薪責任津貼", new BigDecimal("3000"));
        if (base.compareTo(new BigDecimal("120000")) >= 0 && !isExec)
            map.put("超高薪特別責任津貼", new BigDecimal("5000"));

        // ── 到職穩定獎勵 ──────────────────────────────────────────
        if (tenure >= 3 && tenure < 12 && !isIntern) map.put("新人成長獎勵", new BigDecimal("700"));
        if (tenure >= 12 && tenure < 24)              map.put("一年穩定獎勵", new BigDecimal("500"));
        if (hasFullAttendance && tenure >= 1 && tenure < 12 && !isIntern)
            map.put("新人全勤鼓勵金", new BigDecimal("600"));

        // ── 複合加成 ──────────────────────────────────────────────
        if (seniority >= 60 && base.compareTo(new BigDecimal("60000")) >= 0)
            map.put("年資績效複合加成", new BigDecimal("2000"));
        if (seniority >= 120 && hasFullAttendance && hasOvertime && base.compareTo(new BigDecimal("80000")) >= 0)
            map.put("三重複合頂級獎金", new BigDecimal("3500"));
        if ((isRD || isIT) && seniority >= 60 && hasFullAttendance && hasOvertime)
            map.put("技術四重複合頂尖獎金", new BigDecimal("5000"));
        if (isSales && seniority >= 36 && hasFullAttendance && hasOvertime)
            map.put("業務四重複合獎金", new BigDecimal("3500"));

        // ── 實習生扣減 ────────────────────────────────────────────
        if (isIntern) {
            map.put("實習生管理費扣減", new BigDecimal("-300"));
            if (absentDays.compareTo(BigDecimal.ONE) > 0)
                map.put("實習生缺勤扣減", new BigDecimal("-500"));
        }

        // ── 財務法務資深 ──────────────────────────────────────────
        if ((isFin || isLegal) && seniority >= 60)  map.put("財務法務資深津貼", new BigDecimal("3000"));
        if ((isFin || isLegal) && seniority >= 120) map.put("財務法務頂級津貼", new BigDecimal("5000"));

        return map;
    }

    // ── 夜班津貼（REST_DAY / STATUTORY_HOLIDAY 時觸發）──────────────────
    public BigDecimal calcNightShiftAllowance(String overtimeType, String department) {
        if (!"REST_DAY".equals(overtimeType) && !"STATUTORY_HOLIDAY".equals(overtimeType)) {
            return BigDecimal.ZERO;
        }
        String dept = department != null ? department.toUpperCase() : "";
        if (DEPT_RD.equals(dept) || DEPT_IT.equals(dept)) return new BigDecimal("2500");
        if (DEPT_OPS.equals(dept))                        return new BigDecimal("2200");
        if (DEPT_CUSTOMER.equals(dept))                   return new BigDecimal("2000");
        return new BigDecimal("2000");
    }

    public BigDecimal calcOvertimeHoursBonus(int totalOvertimeHours, String position, String department) {
        String pos  = position   != null ? position.toUpperCase()   : "";
        String dept = department != null ? department.toUpperCase() : "";
        if (POS_EXECUTIVE.equals(pos) || DEPT_EXECUTIVE.equals(dept)) return BigDecimal.ZERO;
        if (totalOvertimeHours >= 40) return new BigDecimal("2500");
        if (totalOvertimeHours >= 20) return new BigDecimal("1200");
        if (totalOvertimeHours >= 8)  return new BigDecimal("500");
        return BigDecimal.ZERO;
    }

    public BigDecimal calcRdItOvertimeHoursExtra(int totalOvertimeHours, String position, String department) {
        String pos  = position   != null ? position.toUpperCase()   : "";
        String dept = department != null ? department.toUpperCase() : "";
        if (!DEPT_RD.equals(dept) && !DEPT_IT.equals(dept)) return BigDecimal.ZERO;
        if (POS_MANAGER.equals(pos) || POS_DIRECTOR.equals(pos) || POS_EXECUTIVE.equals(pos)
                || POS_INTERN.equals(pos) || POS_PARTTIME.equals(pos) || DEPT_EXECUTIVE.equals(dept)) {
            return BigDecimal.ZERO;
        }
        return totalOvertimeHours >= 20 ? new BigDecimal("1500") : BigDecimal.ZERO;
    }

    public BigDecimal calcProjectBonus(BigDecimal baseSalary, BigDecimal bonusRate, String role, String department) {
        if (bonusRate == null) return BigDecimal.ZERO;
        String dept    = department != null ? department.toUpperCase() : "";
        boolean isLead = "LEAD".equalsIgnoreCase(role);
        boolean isRdIt = DEPT_RD.equals(dept) || DEPT_IT.equals(dept);
        BigDecimal bonus = baseSalary
            .multiply(bonusRate)
            .multiply(isLead ? new BigDecimal("1.5") : BigDecimal.ONE)
            .setScale(2, RoundingMode.HALF_UP);
        if (isLead && isRdIt) bonus = bonus.add(new BigDecimal("2000"));
        return bonus;
    }

    // ⚠ 以下三個舊輔助方法：演算法與 DRL 的 Attendance_* 規則「不一致」
    //   （階梯式 -2500/-1200/-500 vs DRL 的 500×floor(late/3)），
    //   且在 Legacy 路徑「從未被呼叫」。保留僅為向下相容，請勿再使用；
    //   出勤扣款一律改走下方 applyAttendanceAdjustments()（已與 DRL 對齊）。
    @Deprecated
    public BigDecimal calcLateDeduction(int lateCount) {
        if (lateCount >= 10) return new BigDecimal("-2500");
        if (lateCount >= 6)  return new BigDecimal("-1200");
        if (lateCount >= 3)  return new BigDecimal("-500");
        return BigDecimal.ZERO;
    }

    public boolean isFullAttendanceLostByLate(int lateCount) {
        return lateCount >= 10;
    }

    @Deprecated
    public BigDecimal calcEarlyLeaveDeduction(int earlyLeaveCount) {
        if (earlyLeaveCount >= 3) return new BigDecimal("-800");
        return BigDecimal.ZERO;
    }

    @Deprecated
    public BigDecimal calcPerfectAttendanceBonus(boolean hasFullAttendance, int lateCount, int earlyLeaveCount) {
        if (hasFullAttendance && lateCount == 0 && earlyLeaveCount == 0) {
            return new BigDecimal("500");
        }
        return BigDecimal.ZERO;
    }

    // ══════════════════════════════════════════════════════════
    //  出勤調整（★修正 Java↔DRL 不一致：完全比照 DRL Company_94_Attendance_*）
    //  原問題：Legacy 只用 AttendanceFact 設「全勤/缺勤旗標」，
    //          從不依 lateCount/earlyLeaveCount 扣款，也不發完美出勤獎金；
    //          但 DRL 有 LateDeduct/EarlyLeaveDeduct/PerfectBonus 會生效，
    //          → 帶遲到/早退次數時，Drools 與 Legacy 結果不同。
    //  對齊規則（與 DRL 逐字相同）：
    //    遲到 lateCount>=3       → 扣 500 × floor(lateCount/3)   到 leaveDeduction
    //    早退 earlyLeaveCount>=3 → 扣 300 × floor(earlyLeaveCount/3) 到 leaveDeduction
    //    完美 late==0 && early==0 → 加 500 到 companyBonus
    //  ☆ 需由 Legacy calculate() 對 Company94 額外呼叫一次（見檔末說明 / 函式 wiring）。
    // ══════════════════════════════════════════════════════════
    public void applyAttendanceAdjustments(java.util.List<AttendanceFact> attendances, SalaryResult result) {
        if (attendances == null) return;
        for (AttendanceFact att : attendances) {
            if (att == null) continue;
            int late  = att.getLateCount();
            int early = att.getEarlyLeaveCount();
            if (late >= 3) {
                BigDecimal d = new BigDecimal("500").multiply(new BigDecimal(late / 3));
                result.setLeaveDeduction(result.getLeaveDeduction().add(d));
                result.addRuleDetail("【出勤扣款】公司94 遲到 " + late + " 次（500×" + (late / 3) + "），扣 " + d);
            }
            if (early >= 3) {
                BigDecimal d = new BigDecimal("300").multiply(new BigDecimal(early / 3));
                result.setLeaveDeduction(result.getLeaveDeduction().add(d));
                result.addRuleDetail("【出勤扣款】公司94 早退 " + early + " 次（300×" + (early / 3) + "），扣 " + d);
            }
            if (late == 0 && early == 0) {
                result.setCompanyBonus(result.getCompanyBonus().add(new BigDecimal("500")));
                result.addRuleDetail("【完美出勤】公司94 無遲到早退，+500");
            }
        }
    }

    // ══════════════════════════════════════════════════════════
    //  L4 專屬入口：在 L3(273條) 基礎上，疊加五大新類別（四維交叉）
    //  KPI連動、專案分潤、簽核、調薪、輪班、留任、證照、彈福
    //  ★ 圈複雜度遠高於 L3，展示四維交叉的硬編碼組合爆炸
    // ══════════════════════════════════════════════════════════
    public java.util.Map<String, BigDecimal> getCustomAllowancesL4(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime,
            java.util.List<LeaveFact> leaves,
            java.util.List<OvertimeFact> overtimes,
            java.util.List<PerformanceFact> performances,
            java.util.List<ProjectFact> projects,
            SalaryResult result) {

        // 先取得 L3 的 273 條津貼（沿用既有邏輯）
        java.util.Map<String, BigDecimal> allowances =
            getCustomAllowancesWithOvertimes(employee, hasFullAttendance, hasOvertime, leaves, overtimes, result);

        String pos  = employee.getPosition()   != null ? employee.getPosition()   : "";
        String dept = employee.getDepartment() != null ? employee.getDepartment() : "";
        int    sen  = employee.getSeniorityMonths();
        BigDecimal base = employee.getBaseSalary() != null ? employee.getBaseSalary() : BigDecimal.ZERO;

        // 取 performance（取第一筆 confirmed）
        String grade = null;
        java.math.BigDecimal score = null;
        if (performances != null) {
            for (PerformanceFact p : performances) {
                if (p.isConfirmed()) { grade = p.getGrade(); score = p.getScore(); break; }
            }
        }
        // 取 project（第一筆 completed）
        String projRole = null;
        if (projects != null) {
            for (ProjectFact pr : projects) {
                if (pr.isCompleted()) { projRole = pr.getRole(); break; }
            }
        }

        // ── 類別1：KPI 連動獎金（score × position）──
        if (score != null) {
            int sc = score.intValue();
            BigDecimal kpi = calcKpiBonus(pos, sc);
            if (kpi.compareTo(BigDecimal.ZERO) > 0) allowances.merge("KPI獎金", kpi, BigDecimal::add);
            BigDecimal kpiDept = calcKpiDeptBonus(dept, sc);
            if (kpiDept.compareTo(BigDecimal.ZERO) > 0) allowances.merge("KPI部門加碼", kpiDept, BigDecimal::add);
            // 類別補1：KPI 全維（pos×dept, score>=110）
            if (sc >= 110) {
                int idxP = java.util.Arrays.asList("EXECUTIVE","DIRECTOR","MANAGER","STAFF").indexOf(pos);
                int idxD = java.util.Arrays.asList("RD","IT","SALES","OPS","HR","FINANCE").indexOf(dept);
                if (idxP >= 0 && idxD >= 0) {
                    int amt = 1000 + idxP*500 + idxD*200;
                    allowances.merge("KPI全維加碼", new BigDecimal(amt), BigDecimal::add);
                }
            }
        }

        // ── 類別2：專案分潤（role × dept × position）──
        if (projRole != null) {
            BigDecimal proj = calcProjectBonus(projRole, dept);
            if (proj.compareTo(BigDecimal.ZERO) > 0) allowances.merge("專案分潤", proj, BigDecimal::add);
            BigDecimal projPos = calcProjPosBonus(projRole, pos);
            if (projPos.compareTo(BigDecimal.ZERO) > 0) allowances.merge("專案領導加碼", projPos, BigDecimal::add);
            // 類別補3：專案細分（dept×role, projectBonus 存在）
            int idxD = java.util.Arrays.asList("RD","IT","SALES","OPS","HR","FINANCE").indexOf(dept);
            int idxR = java.util.Arrays.asList("LEAD","CORE","MEMBER").indexOf(projRole);
            if (idxD >= 0 && idxR >= 0) {
                int amt = Math.max(800 + idxD*150 + idxR*(-200), 300);
                allowances.merge("專案細分", new BigDecimal(amt), BigDecimal::add);
            }
            // L3 原生：RD/IT 部門 LEAD 額外加成 +2000（對齊 DRL Company_94_Project_RD_IT_Lead_Extra）
            if (("RD".equals(dept) || "IT".equals(dept)) && "LEAD".equals(projRole)) {
                allowances.merge("RD/IT專案Leader額外加成", new BigDecimal("2000"), BigDecimal::add);
            }
        }

        // ── 類別3：多層級簽核津貼（pos × salary級距）──
        BigDecimal sign = calcSignBonus(pos, base);
        if (sign.compareTo(BigDecimal.ZERO) > 0) allowances.merge("簽核津貼", sign, BigDecimal::add);
        // 簽核×部門
        BigDecimal signDept = calcSignDeptBonus(pos, dept);
        if (signDept.compareTo(BigDecimal.ZERO) > 0) allowances.merge("簽核部門", signDept, BigDecimal::add);

        // ── 類別4：年度調薪矩陣（pos × grade × sen）──
        if (grade != null) {
            BigDecimal adj = calcSalaryAdjustment(pos, grade, sen);
            if (adj.compareTo(BigDecimal.ZERO) > 0) allowances.merge("年度調薪", adj, BigDecimal::add);
            // 留任獎金（pos × grade, sen>=60）
            if (sen >= 60) {
                BigDecimal retain = calcRetainBonus(pos, grade);
                if (retain.compareTo(BigDecimal.ZERO) > 0) allowances.merge("留任獎金", retain, BigDecimal::add);
            }
        }

        // ── 類別5：輪班加給（dept × pos × sen）──
        BigDecimal shift = calcShiftBonus(dept, pos, sen);
        if (shift.compareTo(BigDecimal.ZERO) > 0) allowances.merge("輪班加給", shift, BigDecimal::add);

        // ── 證照加給（dept × pos × sen）──
        BigDecimal cert = calcCertBonus(dept, pos, sen);
        if (cert.compareTo(BigDecimal.ZERO) > 0) allowances.merge("證照加給", cert, BigDecimal::add);

        // ── 彈性福利（pos × sen）──
        BigDecimal flex = calcFlexBonus(pos, sen);
        if (flex.compareTo(BigDecimal.ZERO) > 0) allowances.merge("彈性福利", flex, BigDecimal::add);

        return allowances;
    }


    // ════ L4 輔助計算方法（金額與 DRL 對應）════

    private BigDecimal calcKpiBonus(String pos, int score) {
        // 達成率段 × 職級
        int[][] table; // [Exceed>=120, Reach100-119, Near80-99]
        java.util.Map<String,int[]> m = new java.util.HashMap<>();
        m.put("EXECUTIVE", new int[]{20000,12000,5000});
        m.put("DIRECTOR",  new int[]{12000,8000,3000});
        m.put("MANAGER",   new int[]{8000,5000,2000});
        m.put("STAFF",     new int[]{5000,3000,1000});
        int[] arr = m.get(pos);
        if (arr == null) return BigDecimal.ZERO;
        if (score >= 120) return new BigDecimal(arr[0]);
        if (score >= 100) return new BigDecimal(arr[1]);
        if (score >= 80)  return new BigDecimal(arr[2]);
        return BigDecimal.ZERO;
    }

    private BigDecimal calcKpiDeptBonus(String dept, int score) {
        java.util.Map<String,Integer> base = new java.util.HashMap<>();
        base.put("SALES",3000); base.put("RD",2000); base.put("IT",1500);
        Integer b = base.get(dept);
        if (b == null) return BigDecimal.ZERO;
        if (score >= 120) return new BigDecimal(b);
        if (score >= 100) return new BigDecimal(b);
        if (score >= 80)  return new BigDecimal(b/2);
        return BigDecimal.ZERO;
    }

    private BigDecimal calcProjectBonus(String role, String dept) {
        java.util.Map<String,Integer> rr = new java.util.HashMap<>();
        rr.put("LEAD",5000); rr.put("CORE",3000); rr.put("MEMBER",1500);
        Integer b = rr.get(role);
        if (b == null) return BigDecimal.ZERO;
        java.util.Map<String,Double> dm = new java.util.HashMap<>();
        dm.put("RD",1.2); dm.put("IT",1.1); dm.put("SALES",1.3); dm.put("OPS",1.0);
        Double mult = dm.get(dept);
        if (mult == null) return BigDecimal.ZERO;
        return new BigDecimal((int)(b*mult));
    }

    private BigDecimal calcProjPosBonus(String role, String pos) {
        if ("LEAD".equals(role)) {
            if ("DIRECTOR".equals(pos)) return new BigDecimal("4000");
            if ("MANAGER".equals(pos))  return new BigDecimal("2500");
        } else if ("CORE".equals(role)) {
            if ("DIRECTOR".equals(pos)) return new BigDecimal("2000");
            if ("MANAGER".equals(pos))  return new BigDecimal("1200");
        }
        return BigDecimal.ZERO;
    }

    private BigDecimal calcSignBonus(String pos, BigDecimal base) {
        java.util.Map<String,int[]> m = new java.util.HashMap<>();
        m.put("EXECUTIVE", new int[]{8000,6000,4000}); // High>=100k, Mid70-100k, Low<70k
        m.put("DIRECTOR",  new int[]{5000,4000,2500});
        m.put("MANAGER",   new int[]{3000,2000,1500});
        int[] arr = m.get(pos);
        if (arr == null) return BigDecimal.ZERO;
        if (base.compareTo(new BigDecimal("100000")) >= 0) return new BigDecimal(arr[0]);
        if (base.compareTo(new BigDecimal("70000"))  >= 0) return new BigDecimal(arr[1]);
        return new BigDecimal(arr[2]);
    }

    private BigDecimal calcSignDeptBonus(String pos, String dept) {
        int idxP = java.util.Arrays.asList("EXECUTIVE","DIRECTOR","MANAGER").indexOf(pos);
        int idxD = java.util.Arrays.asList("RD","IT","SALES","OPS","FINANCE").indexOf(dept);
        if (idxP < 0 || idxD < 0) return BigDecimal.ZERO;
        return new BigDecimal(1500 + idxP*1000 + idxD*100);
    }

    private BigDecimal calcSalaryAdjustment(String pos, String grade, int sen) {
        java.util.Map<String,Integer> pb = new java.util.HashMap<>();
        pb.put("DIRECTOR",4000); pb.put("MANAGER",2500); pb.put("STAFF",1500);
        Integer base = pb.get(pos);
        if (base == null) return BigDecimal.ZERO;
        java.util.Map<String,Double> gm = new java.util.HashMap<>();
        gm.put("SS+",1.5); gm.put("SS",1.3); gm.put("S",1.1); gm.put("A+",0.9); gm.put("A",0.7);
        Double gmult = gm.get(grade);
        if (gmult == null) return BigDecimal.ZERO;
        double smult;
        if (sen >= 60) smult = 1.2;
        else if (sen >= 36) smult = 1.0;
        else if (sen >= 12) smult = 0.8;
        else return BigDecimal.ZERO;
        return new BigDecimal((int)(base*gmult*smult));
    }

    private BigDecimal calcRetainBonus(String pos, String grade) {
        java.util.Map<String,Integer> pb = new java.util.HashMap<>();
        pb.put("DIRECTOR",6000); pb.put("MANAGER",4000); pb.put("STAFF",2500);
        Integer base = pb.get(pos);
        if (base == null) return BigDecimal.ZERO;
        java.util.Map<String,Double> gm = new java.util.HashMap<>();
        gm.put("SS+",1.5); gm.put("SS",1.2); gm.put("S",1.0);
        Double gmult = gm.get(grade);
        if (gmult == null) return BigDecimal.ZERO;
        return new BigDecimal((int)(base*gmult));
    }

    private BigDecimal calcShiftBonus(String dept, String pos, int sen) {
        java.util.Map<String,Integer> db = new java.util.HashMap<>();
        db.put("OPS",3000); db.put("RD",2000); db.put("IT",2500); db.put("SALES",1500);
        Integer base = db.get(dept);
        if (base == null) return BigDecimal.ZERO;
        double pmult;
        if ("MANAGER".equals(pos)) pmult = 1.3;
        else if ("STAFF".equals(pos)) pmult = 1.0;
        else return BigDecimal.ZERO;
        double smult = sen >= 36 ? 1.2 : 1.0;
        return new BigDecimal((int)(base*pmult*smult));
    }

    private BigDecimal calcCertBonus(String dept, String pos, int sen) {
        int idxD = java.util.Arrays.asList("RD","IT","FINANCE").indexOf(dept);
        int idxP = java.util.Arrays.asList("DIRECTOR","MANAGER","STAFF").indexOf(pos);
        if (idxD < 0 || idxP < 0) return BigDecimal.ZERO;
        int amt = 2000 + idxD*300 + idxP*(-300);
        if (sen >= 60) amt += 1000;
        return new BigDecimal(amt);
    }

    private BigDecimal calcFlexBonus(String pos, int sen) {
        java.util.Map<String,Integer> pb = new java.util.HashMap<>();
        pb.put("EXECUTIVE",5000); pb.put("DIRECTOR",3500); pb.put("MANAGER",2500);
        pb.put("STAFF",1500); pb.put("INTERN",500);
        Integer base = pb.get(pos);
        if (base == null) return BigDecimal.ZERO;
        double smult;
        if (sen >= 60) smult = 1.3;
        else if (sen >= 24) smult = 1.0;
        else smult = 0.7;
        return new BigDecimal((int)(base*smult));
    }

}