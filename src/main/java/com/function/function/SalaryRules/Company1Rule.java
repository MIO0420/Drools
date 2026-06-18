package com.function.function.SalaryRules;

import com.function.model.EmployeeFact;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 公司 1 — Technology
 * Block 6：< 24m=1.20x | 24-60m=1.50x | ≥60m=1.80x
 * Block 7：年資≥36m +2000 | 全勤 +1000 | 加班 +500
 */
public class Company1Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "1"; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        if (seniorityMonths < 24) return 1.20;
        if (seniorityMonths < 60) return 1.50;
        return 1.80;
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime) {

        Map<String, BigDecimal> map = new LinkedHashMap<>();
        if (employee.getSeniorityMonths() >= 36)
            map.put("年資津貼", new BigDecimal("2000"));
        if (hasFullAttendance)
            map.put("全勤獎金", new BigDecimal("1000"));
        if (hasOvertime)
            map.put("加班津貼", new BigDecimal("500"));
        return map;
    }
}
