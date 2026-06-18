package com.function.model;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

public class OvertimeFact {

    private String employeeId;             // ★ 新增：用於 Chunk 批次模式 employeeId 綁定
    private String overtimeType;
    private BigDecimal overtimeHours;
    private BigDecimal hourlyRate;
    private String overtimeDate;
    private boolean compensatoryTimeOff  = false;
    private boolean compensatoryExpired  = false;
    private boolean disasterException    = false;
    private Map<String, Object> metadata = new HashMap<>();

    public OvertimeFact() {}

    // ★ 新增
    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    @JsonAnySetter
    public void setMetaField(String key, Object value) {
        this.metadata.put(key, value);
    }

    public int getMetaInt(String key) {
        Object val = metadata.get(key);
        if (val == null) return 0;
        if (val instanceof Number) return ((Number) val).intValue();
        try { return Integer.parseInt(val.toString()); }
        catch (Exception e) { return 0; }
    }

    public double getMetaDouble(String key) {
        Object val = metadata.get(key);
        if (val == null) return 0.0;
        if (val instanceof Number) return ((Number) val).doubleValue();
        try { return Double.parseDouble(val.toString()); }
        catch (Exception e) { return 0.0; }
    }

    public String getMetaString(String key) {
        Object val = metadata.get(key);
        return val == null ? "" : val.toString();
    }

    public boolean getMetaBool(String key) {
        Object val = metadata.get(key);
        if (val == null) return false;
        if (val instanceof Boolean) return (Boolean) val;
        return Boolean.parseBoolean(val.toString());
    }

    public boolean hasMeta(String key) {
        return metadata != null && metadata.containsKey(key);
    }

    public OvertimeFact putMeta(String key, Object value) {
        this.metadata.put(key, value);
        return this;
    }

    public String getOvertimeType() { return overtimeType; }
    public void setOvertimeType(String overtimeType) { this.overtimeType = overtimeType; }

    public BigDecimal getOvertimeHours() { return overtimeHours; }
    public void setOvertimeHours(BigDecimal overtimeHours) { this.overtimeHours = overtimeHours; }

    public BigDecimal getHourlyRate() { return hourlyRate; }
    public void setHourlyRate(BigDecimal hourlyRate) { this.hourlyRate = hourlyRate; }

    public String getOvertimeDate() { return overtimeDate; }
    public void setOvertimeDate(String overtimeDate) { this.overtimeDate = overtimeDate; }

    public boolean isCompensatoryTimeOff() { return compensatoryTimeOff; }
    public void setCompensatoryTimeOff(boolean compensatoryTimeOff) {
        this.compensatoryTimeOff = compensatoryTimeOff;
    }

    public boolean isCompensatoryExpired() { return compensatoryExpired; }
    public void setCompensatoryExpired(boolean compensatoryExpired) {
        this.compensatoryExpired = compensatoryExpired;
    }

    public boolean isDisasterException() { return disasterException; }
    public void setDisasterException(boolean disasterException) {
        this.disasterException = disasterException;
    }

    public Map<String, Object> getMetadata() { return metadata; }
    public void setMetadata(Map<String, Object> metadata) { this.metadata = metadata; }

    @Override
    public String toString() {
        return "OvertimeFact{" +
            "employeeId='"         + employeeId         + '\'' +
            ", overtimeType='"     + overtimeType       + '\'' +
            ", overtimeHours="     + overtimeHours      +
            ", overtimeDate='"     + overtimeDate       + '\'' +
            ", compensatoryTimeOff=" + compensatoryTimeOff +
            ", compensatoryExpired=" + compensatoryExpired +
            ", disasterException=" + disasterException  +
            ", metadata="          + metadata           +
            '}';
    }
}
