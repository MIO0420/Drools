package com.function.model;

import java.math.BigDecimal;

public class PerformanceFact {

    private String companyId;
    private String employeeId;
    private String grade;
    private BigDecimal score;
    private int year;
    private int month;
    private String evaluatorId;
    private boolean confirmed;

    public PerformanceFact() {}

    public PerformanceFact(String employeeId, String companyId, String grade, BigDecimal score, int year, int month) {
        this.employeeId = employeeId;
        this.companyId  = companyId;
        this.grade      = grade;
        this.score      = score;
        this.year       = year;
        this.month      = month;
        this.confirmed  = false;
    }

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public String getGrade() { return grade; }
    public void   setGrade(String v) { this.grade = v; }

    public BigDecimal getScore() { return score; }
    public void       setScore(BigDecimal v) { this.score = v; }

    public int  getYear() { return year; }
    public void setYear(int v) { this.year = v; }

    public int  getMonth() { return month; }
    public void setMonth(int v) { this.month = v; }

    public String getEvaluatorId() { return evaluatorId; }
    public void   setEvaluatorId(String v) { this.evaluatorId = v; }

    public boolean isConfirmed() { return confirmed; }
    public void    setConfirmed(boolean v) { this.confirmed = v; }

    public boolean isGradeSSPlus() { return "SS+".equals(grade); }
    public boolean isGradeSS()     { return "SS".equals(grade); }
    public boolean isGradeS()      { return "S".equals(grade); }
    public boolean isGradeAPlus()  { return "A+".equals(grade); }
    public boolean isGradeA()      { return "A".equals(grade); }
    public boolean isGradeBPlus()  { return "B+".equals(grade); }
    public boolean isGradeB()      { return "B".equals(grade); }
}
