package com.function.model;

import java.math.BigDecimal;

public class InsuranceFact {
    private int insuredSalary;
    private int pensionSalary;
    private int laborInsuredSalary;
    private int healthInsuredSalary;
    private int workingDaysInMonth;
    private BigDecimal voluntaryPensionRate;

    public InsuranceFact() {}

    public int getInsuredSalary() { return insuredSalary; }
    public void setInsuredSalary(int insuredSalary) { this.insuredSalary = insuredSalary; }

    public int getPensionSalary() { return pensionSalary; }
    public void setPensionSalary(int pensionSalary) { this.pensionSalary = pensionSalary; }

    public int getLaborInsuredSalary() { return laborInsuredSalary; }
    public void setLaborInsuredSalary(int laborInsuredSalary) { this.laborInsuredSalary = laborInsuredSalary; }

    public int getHealthInsuredSalary() { return healthInsuredSalary; }
    public void setHealthInsuredSalary(int healthInsuredSalary) { this.healthInsuredSalary = healthInsuredSalary; }

    public int getWorkingDaysInMonth() { return workingDaysInMonth; }
    public void setWorkingDaysInMonth(int workingDaysInMonth) { this.workingDaysInMonth = workingDaysInMonth; }

    public BigDecimal getVoluntaryPensionRate() { return voluntaryPensionRate; }
    public void setVoluntaryPensionRate(BigDecimal voluntaryPensionRate) { this.voluntaryPensionRate = voluntaryPensionRate; }
}
