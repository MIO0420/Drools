package com.function.model;

import java.math.BigDecimal;

public class AttendanceFact {

    private String companyId;
    private String employeeId;
    private int year;
    private int month;
    private int lateCount;
    private int earlyLeaveCount;
    private BigDecimal absentDays;
    private int workDays;
    private int requiredWorkDays;
    private boolean hasFullAttendance;
    private int lateMinutesTotal;
    private int earlyLeaveMinutesTotal;

    public AttendanceFact() {}

    public AttendanceFact(String employeeId, String companyId, int year, int month,
                          int workDays, int requiredWorkDays) {
        this.employeeId       = employeeId;
        this.companyId        = companyId;
        this.year             = year;
        this.month            = month;
        this.workDays         = workDays;
        this.requiredWorkDays = requiredWorkDays;
        this.absentDays       = BigDecimal.ZERO;
        this.lateCount        = 0;
        this.earlyLeaveCount  = 0;
        this.hasFullAttendance = (workDays >= requiredWorkDays);
    }

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public int  getYear() { return year; }
    public void setYear(int v) { this.year = v; }

    public int  getMonth() { return month; }
    public void setMonth(int v) { this.month = v; }

    public int  getLateCount() { return lateCount; }
    public void setLateCount(int v) { this.lateCount = v; }

    public int  getEarlyLeaveCount() { return earlyLeaveCount; }
    public void setEarlyLeaveCount(int v) { this.earlyLeaveCount = v; }

    public BigDecimal getAbsentDays() { return absentDays; }
    public void       setAbsentDays(BigDecimal v) { this.absentDays = v; }

    public int  getWorkDays() { return workDays; }
    public void setWorkDays(int v) { this.workDays = v; }

    public int  getRequiredWorkDays() { return requiredWorkDays; }
    public void setRequiredWorkDays(int v) { this.requiredWorkDays = v; }

    public boolean isHasFullAttendance() { return hasFullAttendance; }
    public void    setHasFullAttendance(boolean v) { this.hasFullAttendance = v; }

    public int  getLateMinutesTotal() { return lateMinutesTotal; }
    public void setLateMinutesTotal(int v) { this.lateMinutesTotal = v; }

    public int  getEarlyLeaveMinutesTotal() { return earlyLeaveMinutesTotal; }
    public void setEarlyLeaveMinutesTotal(int v) { this.earlyLeaveMinutesTotal = v; }

    public boolean isPerfectAttendance() {
        return hasFullAttendance
            && lateCount == 0
            && earlyLeaveCount == 0
            && (absentDays == null || absentDays.compareTo(BigDecimal.ZERO) == 0);
    }

    public boolean isLateFrequent() {
        return lateCount >= 3;
    }

    public boolean hasAnyAbsence() {
        return absentDays != null && absentDays.compareTo(BigDecimal.ZERO) > 0;
    }
}
