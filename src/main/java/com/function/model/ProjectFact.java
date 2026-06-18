package com.function.model;

import java.math.BigDecimal;

public class ProjectFact {

    private String companyId;
    private String employeeId;
    private String projectId;
    private String projectName;
    private String role;
    private boolean completed;
    private BigDecimal bonusRate;
    private BigDecimal projectBonus;
    private BigDecimal budget;
    private int year;
    private int month;
    private String department;

    public ProjectFact() {}

    public ProjectFact(String employeeId, String companyId, String projectId,
                       String role, boolean completed, BigDecimal bonusRate,
                       int year, int month) {
        this.employeeId  = employeeId;
        this.companyId   = companyId;
        this.projectId   = projectId;
        this.role        = role;
        this.completed   = completed;
        this.bonusRate   = bonusRate;
        this.year        = year;
        this.month       = month;
        this.projectBonus = BigDecimal.ZERO;
    }

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public String getProjectId() { return projectId; }
    public void   setProjectId(String v) { this.projectId = v; }

    public String getProjectName() { return projectName; }
    public void   setProjectName(String v) { this.projectName = v; }

    public String getRole() { return role; }
    public void   setRole(String v) { this.role = v; }

    public boolean isCompleted() { return completed; }
    public void    setCompleted(boolean v) { this.completed = v; }

    public BigDecimal getBonusRate() { return bonusRate; }
    public void       setBonusRate(BigDecimal v) { this.bonusRate = v; }

    public BigDecimal getBudget() { return budget; }
public void setBudget(BigDecimal budget) { this.budget = budget; }

    public BigDecimal getProjectBonus() { return projectBonus; }
    public void       setProjectBonus(BigDecimal v) { this.projectBonus = v; }

    public int  getYear() { return year; }
    public void setYear(int v) { this.year = v; }

    public int  getMonth() { return month; }
    public void setMonth(int v) { this.month = v; }

    public String getDepartment() { return department; }
    public void   setDepartment(String v) { this.department = v; }

    public boolean isLead()   { return "LEAD".equals(role); }
    public boolean isMember() { return "MEMBER".equals(role); }

    public BigDecimal calcBonus(BigDecimal baseSalary) {
        if (bonusRate == null || baseSalary == null) return BigDecimal.ZERO;
        return baseSalary.multiply(bonusRate).setScale(2, java.math.RoundingMode.HALF_UP);
    }
}
