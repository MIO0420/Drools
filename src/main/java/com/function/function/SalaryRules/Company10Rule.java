package com.function.function.SalaryRules;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import com.function.model.EmployeeFact;
import com.function.model.LeaveFact;
import com.function.model.OvertimeFact;
import com.function.model.SalaryResult;
import static com.function.util.RuleUtils.*;

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
                BigDecimal bonus = calcWeekdayOvertimeByRate(employee.getBaseSalary(), ot.getOvertimeHours(), "2", "4");
                result.setOvertimeBonus(result.getOvertimeBonus().add(bonus));
                result.addRuleDetail("平日加班：前兩小時2倍，超過兩小時4倍 +" + bonus);
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
                BigDecimal deduct = calcLeaveDeduction(employee.getBaseSalary(), lv.getLeaveHours(), "0.5");
                result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                result.addRuleDetail("公司10特有規則：請事假扣半薪（比率0.5） -" + deduct);
                processed = true;
            }
        }
        return processed;
    }
}

