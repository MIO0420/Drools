package com.function.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.math.BigDecimal;
import java.math.RoundingMode;

@JsonIgnoreProperties(ignoreUnknown = true)
public class LeaveFact {
    private String employeeId;
    private String leaveTypeName;
    private BigDecimal leaveDays;
    private BigDecimal leaveHours;
    private BigDecimal deductionRate;
    private int usedDaysThisYear;
    private int publicHolidayDays = 0;

    private boolean affectFullAttendance;
    private String bereavementRelation;
    private boolean hospitalized;
    private int pregnancyWeeks;
    private int workingDaysInMonth;

    public LeaveFact() {}

    public LeaveFact(String leaveTypeName, BigDecimal leaveDays, BigDecimal deductionRate, int usedDaysThisYear) {
        this.leaveTypeName = leaveTypeName;
        this.leaveDays = leaveDays;
        this.deductionRate = deductionRate;
        this.usedDaysThisYear = usedDaysThisYear;
    }

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public String getLeaveTypeName() { return leaveTypeName; }
    public void setLeaveTypeName(String leaveTypeName) { this.leaveTypeName = leaveTypeName; }

    public BigDecimal getLeaveDays() { return leaveDays; }
    public void setLeaveDays(BigDecimal leaveDays) { this.leaveDays = leaveDays; }

    public BigDecimal getDeductionRate() { return deductionRate; }
    public void setDeductionRate(BigDecimal deductionRate) { this.deductionRate = deductionRate; }

    public int getUsedDaysThisYear() { return usedDaysThisYear; }
    public void setUsedDaysThisYear(int usedDaysThisYear) { this.usedDaysThisYear = usedDaysThisYear; }

    public int getPublicHolidayDays() { return publicHolidayDays; }
    public void setPublicHolidayDays(int publicHolidayDays) { this.publicHolidayDays = publicHolidayDays; }

    public BigDecimal getLeaveHours() {
        if (leaveHours != null && leaveHours.compareTo(BigDecimal.ZERO) > 0) {
            return leaveHours;
        }
        return leaveDays != null
            ? leaveDays.multiply(BigDecimal.valueOf(8)).setScale(10, RoundingMode.HALF_UP)
            : BigDecimal.ZERO;
    }
    public void setLeaveHours(BigDecimal leaveHours) { this.leaveHours = leaveHours; }

    public BigDecimal getMaxDaysPerYear() { return BigDecimal.valueOf(14); }

    public int getWorkingDaysInMonth() {
        return workingDaysInMonth > 0 ? workingDaysInMonth : 30;
    }
    public void setWorkingDaysInMonth(int workingDaysInMonth) {
        this.workingDaysInMonth = workingDaysInMonth;
    }

    public boolean isAffectFullAttendance() { return affectFullAttendance; }
    public void setAffectFullAttendance(boolean affectFullAttendance) {
        this.affectFullAttendance = affectFullAttendance;
    }

    public String getBereavementRelation() { return bereavementRelation; }
    public void setBereavementRelation(String bereavementRelation) {
        this.bereavementRelation = bereavementRelation;
    }

    public boolean isHospitalized() { return hospitalized; }
    public void setHospitalized(boolean hospitalized) { this.hospitalized = hospitalized; }

    public int getPregnancyWeeks() { return pregnancyWeeks; }
    public void setPregnancyWeeks(int pregnancyWeeks) { this.pregnancyWeeks = pregnancyWeeks; }
}
