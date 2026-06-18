// 路徑：Graduate/src/main/java/com/function/model/ClockFact.java
package com.function.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class ClockFact {

    private String        companyId;             // ✅ 新增：公司識別碼
    private String        employeeCode;
    private String        recordType;            // "clock_in" | "clock_out"
    private BigDecimal    latitude;
    private BigDecimal    longitude;
    private BigDecimal    distanceToCompany;     // 後端 Haversine 計算結果（公尺）
    private LocalDateTime recordTime;

    public ClockFact() {}

    // ─── companyId ─────────────────────────────────────────────────────────────
    public String getCompanyId()                   { return companyId; }
    public void   setCompanyId(String companyId)   { this.companyId = companyId; }

    // ─── employeeCode ──────────────────────────────────────────────────────────
    public String getEmployeeCode()                      { return employeeCode; }
    public void   setEmployeeCode(String employeeCode)   { this.employeeCode = employeeCode; }

    // ─── recordType ────────────────────────────────────────────────────────────
    public String getRecordType()                        { return recordType; }
    public void   setRecordType(String recordType)       { this.recordType = recordType; }

    // ─── latitude ──────────────────────────────────────────────────────────────
    public BigDecimal getLatitude()                      { return latitude; }
    public void       setLatitude(BigDecimal latitude)   { this.latitude = latitude; }

    // ─── longitude ─────────────────────────────────────────────────────────────
    public BigDecimal getLongitude()                     { return longitude; }
    public void       setLongitude(BigDecimal longitude) { this.longitude = longitude; }

    // ─── distanceToCompany ─────────────────────────────────────────────────────
    public BigDecimal getDistanceToCompany()                             { return distanceToCompany; }
    public void       setDistanceToCompany(BigDecimal distanceToCompany) { this.distanceToCompany = distanceToCompany; }

    // ─── recordTime ────────────────────────────────────────────────────────────
    public LocalDateTime getRecordTime()                         { return recordTime; }
    public void          setRecordTime(LocalDateTime recordTime) { this.recordTime = recordTime; }

    // ─── toString ──────────────────────────────────────────────────────────────
    @Override
    public String toString() {
        return "ClockFact{" +
               "companyId='"          + companyId         + '\'' +
               ", employeeCode='"     + employeeCode      + '\'' +
               ", recordType='"       + recordType        + '\'' +
               ", latitude="          + latitude          +
               ", longitude="         + longitude         +
               ", distanceToCompany=" + distanceToCompany +
               ", recordTime="        + recordTime        +
               '}';
    }
}
