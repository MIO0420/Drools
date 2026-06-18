package com.function.function.SalaryRules;

import com.function.model.EmployeeFact;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 公司 5 — Finance
 * Block 6：< 24m=1.20x | 24-60m=1.60x | ≥60m=2.00x
 * Block 7：年資≥60m +3000 | 全勤 +1500 | 加班 +1000
 */
public class Company5Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "5"; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        if (seniorityMonths < 24) return 1.20;
        if (seniorityMonths < 60) return 1.60;
        return 2.00;
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime) {

        Map<String, BigDecimal> map = new LinkedHashMap<>();
        if (employee.getSeniorityMonths() >= 60)
            map.put("年資津貼", new BigDecimal("3000"));
        if (hasFullAttendance)
            map.put("全勤獎金", new BigDecimal("1500"));
        if (hasOvertime)
            map.put("加班津貼", new BigDecimal("1000"));
        return map;
    }
}
