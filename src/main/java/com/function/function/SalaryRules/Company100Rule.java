package com.function.function.SalaryRules;

import com.function.model.EmployeeFact;
import java.math.BigDecimal;
import java.util.LinkedHashMap;
import java.util.Map;

/**
 * 公司 100 — Super AI
 * Block 6：< 24m=1.25x | 24-60m=2.00x | ≥60m=2.50x
 * Block 7：研發津貼(固定) +8000 | 年資≥24m +6000 | 全勤 +2500 | 加班 +2000
 */
public class Company100Rule implements CompanySalaryRule {

    @Override
    public String getCompanyId() { return "100"; }

    @Override
    public double getSeniorityMultiplier(int seniorityMonths) {
        if (seniorityMonths < 24) return 1.25;
        if (seniorityMonths < 60) return 2.00;
        return 2.50;
    }

    @Override
    public Map<String, BigDecimal> getCustomAllowances(
            EmployeeFact employee,
            boolean hasFullAttendance,
            boolean hasOvertime) {

        Map<String, BigDecimal> map = new LinkedHashMap<>();
        map.put("研發津貼", new BigDecimal("8000"));
        if (employee.getSeniorityMonths() >= 24)
            map.put("年資津貼", new BigDecimal("6000"));
        if (hasFullAttendance)
            map.put("全勤獎金", new BigDecimal("2500"));
        if (hasOvertime)
            map.put("加班津貼", new BigDecimal("2000"));
        return map;
    }
}
