package com.function.model;

import java.math.BigDecimal;

public class SalaryAdjustmentFact {

    private String companyId;
    private String employeeId;
    private String adjustmentType;
    private BigDecimal amount;
    private String reason;
    private String approvedBy;
    private int year;
    private int month;
    private boolean applied;
    private String remark;

    public SalaryAdjustmentFact() {}

    public SalaryAdjustmentFact(String employeeId, String companyId, String adjustmentType,
                                 BigDecimal amount, String reason, String approvedBy,
                                 int year, int month) {
        this.employeeId      = employeeId;
        this.companyId       = companyId;
        this.adjustmentType  = adjustmentType;
        this.amount          = amount;
        this.reason          = reason;
        this.approvedBy      = approvedBy;
        this.year            = year;
        this.month           = month;
        this.applied         = false;
    }

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public String getAdjustmentType() { return adjustmentType; }
    public void   setAdjustmentType(String v) { this.adjustmentType = v; }

    public BigDecimal getAmount() { return amount; }
    public void       setAmount(BigDecimal v) { this.amount = v; }

    public String getReason() { return reason; }
    public void   setReason(String v) { this.reason = v; }

    public String getApprovedBy() { return approvedBy; }
    public void   setApprovedBy(String v) { this.approvedBy = v; }

    public int  getYear() { return year; }
    public void setYear(int v) { this.year = v; }

    public int  getMonth() { return month; }
    public void setMonth(int v) { this.month = v; }

    public boolean isApplied() { return applied; }
    public void    setApplied(boolean v) { this.applied = v; }

    public String getRemark() { return remark; }
    public void   setRemark(String v) { this.remark = v; }

    public boolean isBonus()     { return "BONUS".equals(adjustmentType); }
    public boolean isDeduction() { return "DEDUCTION".equals(adjustmentType); }
    public boolean isSpecial()   { return "SPECIAL".equals(adjustmentType); }
    public boolean isRaise()     { return "RAISE".equals(adjustmentType); }

    public boolean isPositive() {
        return amount != null && amount.compareTo(BigDecimal.ZERO) > 0;
    }

    public boolean isNegative() {
        return amount != null && amount.compareTo(BigDecimal.ZERO) < 0;
    }
}
