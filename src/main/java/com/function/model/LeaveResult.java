package com.function.model;

import java.math.BigDecimal;

public class LeaveResult {
    private String employeeId;
    private BigDecimal leaveDeduction;
    private String message;
    private boolean affectFullAttendance;
    private double fullAttendanceDeductRatio;

    private boolean approved        = true;
    private BigDecimal deductAmount = BigDecimal.ZERO;
    private int remainingDays;          // ← 改回 int
    private String appliedRule;

    public LeaveResult() {}

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public BigDecimal getLeaveDeduction() { return leaveDeduction; }
    public void setLeaveDeduction(BigDecimal leaveDeduction) { this.leaveDeduction = leaveDeduction; }

    public String getMessage() { return message; }
    public void setMessage(String message) { this.message = message; }

    public boolean isAffectFullAttendance() { return affectFullAttendance; }
    public void setAffectFullAttendance(boolean affectFullAttendance) {
        this.affectFullAttendance = affectFullAttendance;
    }

    public double getFullAttendanceDeductRatio() { return fullAttendanceDeductRatio; }
    public void setFullAttendanceDeductRatio(double fullAttendanceDeductRatio) {
        this.fullAttendanceDeductRatio = fullAttendanceDeductRatio;
    }

    public boolean isApproved() { return approved; }
    public void setApproved(boolean approved) { this.approved = approved; }

    public BigDecimal getDeductAmount() { return deductAmount; }
    public void setDeductAmount(BigDecimal deductAmount) { this.deductAmount = deductAmount; }

    public int getRemainingDays() { return remainingDays; }
    public void setRemainingDays(int remainingDays) { this.remainingDays = remainingDays; }

    public String getAppliedRule() { return appliedRule; }
    public void setAppliedRule(String appliedRule) { this.appliedRule = appliedRule; }
}
