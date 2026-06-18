package com.function.function.SalaryRules;

import com.function.model.EmployeeFact;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 公司 3 — Medical
 * Block 6：< 24m=1.10x | 24-60m=1.40x | ≥60m=1.70x
 * Block 7：危險津貼(固定) +5000 | 年資≥24m +2500 | 全勤 +1000 | 加班 +800
 */
public class Company3Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "3"; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        if (seniorityMonths < 24) return 1.10;
        if (seniorityMonths < 60) return 1.40;
        return 1.70;
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime) {

        Map<String, BigDecimal> map = new LinkedHashMap<>();
        map.put("危險津貼", new BigDecimal("5000"));
        if (employee.getSeniorityMonths() >= 24)
            map.put("年資津貼", new BigDecimal("2500"));
        if (hasFullAttendance)
            map.put("全勤獎金", new BigDecimal("1000"));
        if (hasOvertime)
            map.put("加班津貼", new BigDecimal("800"));
        return map;
    }
}
