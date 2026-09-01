package com.function.function.SalaryRules;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Collections;
import com.function.model.EmployeeFact;
import com.function.model.OvertimeFact;
import com.function.model.LeaveFact;
import com.function.model.SalaryResult;

public class Company10Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() {
        return "10";
    }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        return 1.0;
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(EmployeeFact employee, boolean hasFullAttendance, boolean hasOvertime) {
        return Collections.emptyMap();
    }

    @Override
    public boolean hasCustomOvertimeCalc() {
        return true;
    }

    @Override
    public void processOvertimeBonus(EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result) {
        if (overtimes == null) {
            return;
        }
        for (OvertimeFact ot : overtimes) {
            if ("WEEKDAY".equals(ot.getOvertimeType())) {
                BigDecimal overtimeHours = ot.getOvertimeHours();
                BigDecimal bonus = BigDecimal.ZERO;
                if (overtimeHours.compareTo(BigDecimal.ZERO) > 0 && overtimeHours.compareTo(new BigDecimal("2")) <= 0) {
                    bonus = com.function.util.RuleUtils.calcWeekdayOvertimeByRate(employee.getBaseSalary(), overtimeHours, "2", "3");
                } else if (overtimeHours.compareTo(new BigDecimal("2")) > 0 && overtimeHours.compareTo(new BigDecimal("4")) <= 0) {
                    bonus = com.function.util.RuleUtils.calcWeekdayOvertimeByRate(employee.getBaseSalary(), overtimeHours, "2", "3");
                } else if (overtimeHours.compareTo(new BigDecimal("4")) > 0) {
                    bonus = com.function.util.RuleUtils.calcWeekdayOvertimeByRate(employee.getBaseSalary(), overtimeHours, "2", "4");
                }
                result.setOvertimeBonus(result.getOvertimeBonus().add(bonus));
            }
        }
    }

    @Override
    public boolean hasCustomLeaveDeduction() {
        return true;
    }

    @Override
    public boolean processLeaveDeductions(EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result) {
        if (leaves == null) {
            return false;
        }
        boolean processed = false;
        for (LeaveFact lv : leaves) {
            if ("事假".equals(lv.getLeaveTypeName())) {
                BigDecimal rate;
                if (lv.getLeaveDays().compareTo(new BigDecimal("2")) <= 0) {
                    rate = new BigDecimal("1.0");
                } else {
                    rate = new BigDecimal("0.5");
                }
                BigDecimal deduct = com.function.util.RuleUtils.calcLeaveDeduction(employee.getBaseSalary(), lv.getLeaveHours(), rate.toString());
                result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                processed = true;
            }
        }
        return processed;
    }
}

