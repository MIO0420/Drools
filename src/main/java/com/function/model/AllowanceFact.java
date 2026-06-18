package com.function.model;

import java.math.BigDecimal;

public class AllowanceFact {

    private String companyId;
    private String employeeId;
    private String allowanceType;
    private BigDecimal amount;
    private boolean approved;
    private String approvedBy;
    private int year;
    private int month;
    private String remark;

    public AllowanceFact() {}

    public AllowanceFact(String employeeId, String companyId, String allowanceType,
                         BigDecimal amount, boolean approved, int year, int month) {
        this.employeeId    = employeeId;
        this.companyId     = companyId;
        this.allowanceType = allowanceType;
        this.amount        = amount;
        this.approved      = approved;
        this.year          = year;
        this.month         = month;
    }

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public String getAllowanceType() { return allowanceType; }
    public void   setAllowanceType(String v) { this.allowanceType = v; }

    public BigDecimal getAmount() { return amount; }
    public void       setAmount(BigDecimal v) { this.amount = v; }

    public boolean isApproved() { return approved; }
    public void    setApproved(boolean v) { this.approved = v; }

    public String getApprovedBy() { return approvedBy; }
    public void   setApprovedBy(String v) { this.approvedBy = v; }

    public int  getYear() { return year; }
    public void setYear(int v) { this.year = v; }

    public int  getMonth() { return month; }
    public void setMonth(int v) { this.month = v; }

    public String getRemark() { return remark; }
    public void   setRemark(String v) { this.remark = v; }

    public boolean isTransportation() { return "TRANSPORTATION".equals(allowanceType); }
    public boolean isMeal()           { return "MEAL".equals(allowanceType); }
    public boolean isHousing()        { return "HOUSING".equals(allowanceType); }
    public boolean isCertificate()    { return "CERTIFICATE".equals(allowanceType); }
    public boolean isSpecial()        { return "SPECIAL".equals(allowanceType); }
}
