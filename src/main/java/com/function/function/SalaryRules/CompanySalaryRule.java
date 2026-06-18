package com.function.function.SalaryRules;

import com.function.model.EmployeeFact;
import com.function.model.LeaveFact;
import com.function.model.OvertimeFact;
import com.function.model.SalaryResult;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

public interface CompanySalaryRule {

    String getCompanyId();

    double getSeniorityMultiplier(int seniorityMonths);

    // 原有方法：保留以向下相容
    Map<String, BigDecimal> getCustomAllowances(
        EmployeeFact employee,
        boolean hasFullAttendance,
        boolean hasOvertime
    );

    // 新增方法：支援傳入請假紀錄、出勤狀態等細節的客製化津貼
    default Map<String, BigDecimal> getCustomAllowances(
        EmployeeFact employee,
        boolean hasFullAttendance,
        boolean hasOvertime,
        List<LeaveFact> leaves,
        SalaryResult result) {
        return getCustomAllowances(employee, hasFullAttendance, hasOvertime);
    }

    // --- 客製化請假扣薪 ----------------------------------------
    // 預設 false，有需要的公司才 override
    default boolean hasCustomLeaveDeduction() {
        return false;
    }

    /**
     * 回傳該假別的扣薪比率
     * null  = 交給通用規則處理
     * ZERO  = 不扣薪
     * 其他  = 自訂比率（例如 0.30、1.50）
     */
    default BigDecimal getLeaveDeductionRate(String leaveTypeName) {
        return null;
    }

    /**
     * 處理客製化請假扣款邏輯
     * 回傳是否包含缺勤紀錄
     */
    default boolean processLeaveDeductions(EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result) {
        return false;
    }

    // --- 客製化加班費 ------------------------------------------
    // 預設 false，有需要的公司才 override
    default boolean hasCustomOvertimeCalc() {
        return false;
    }

    /**
     * 回傳該加班類型的加班費
     * null = 交給通用規則處理
     */
    default BigDecimal calcOvertimePay(
            String overtimeType,
            int overtimeHours,
            BigDecimal hourlyRate) {
        return null;
    }

    /**
     * 處理客製化加班費邏輯
     */
    default void processOvertimeBonus(EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result) {
    }

    // --- 客製化全勤獎金 ----------------------------------------
    default boolean hasCustomFullAttendanceCalc() {
        return false;
    }

    default boolean processFullAttendance(EmployeeFact employee, SalaryResult result, boolean hasAbsence) {
        return false;
    }

    // --- 客製化資歷獎金 ----------------------------------------
    default boolean hasCustomSeniorityCalc() {
        return false;
    }

    default BigDecimal processSeniorityBonus(EmployeeFact employee, SalaryResult result) {
        return BigDecimal.ZERO;
    }

    // --- 客製化效能獎金略過 ------------------------------------
    default boolean skipsLegacyPerformanceBonus() {
        return false;
    }
}