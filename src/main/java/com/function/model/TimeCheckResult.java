package com.function.model;

import com.fasterxml.jackson.annotation.JsonAnyGetter;
import com.fasterxml.jackson.annotation.JsonFormat;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class TimeCheckResult {

    private String        employeeCode;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime scheduleDate;

    private double  totalWorkHours;
    private double  overtimeHours;
    private int     overtimeMinutes;
    private boolean isLate;
    private boolean isEarlyLeave;
    private boolean isEarlyArrival;
    private int     lateMinutes;
    private int     earlyLeaveMinutes;
    private int     lunchBreakMinutes;
    private int     earlyArrivalMinutes;
    private String  effectiveClockIn;
    private String  effectiveClockOut;
    private String  status = "NORMAL";

    private List<String> violations = new ArrayList<>();
    private List<String> notes      = new ArrayList<>();

    // ✅ 彈性擴充欄位：DRL 可透過 putExtra() 寫入任意 key-value
    //    序列化時會自動展開到 JSON 根層級（不會包在 "extra" 物件裡）
    //    範例：result.putExtra("deductionMinutes", 30)
    //          result.putExtra("approvedBy", "Manager A")
    //          result.putExtra("typhoonExempt", true)
    private Map<String, Object> extra = new LinkedHashMap<>();

    // ─── 輔助方法 ─────────────────────────────────────────────

    public void addViolation(String type, String message) {
        this.violations.add("[" + type + "] " + message);
    }

    public void addNote(String message) {
        this.notes.add(message);
    }

    /**
     * 寫入彈性欄位
     * DRL 範例：$f.getResult().putExtra("deductionMinutes", 30);
     */
    public TimeCheckResult putExtra(String key, Object value) {
        this.extra.put(key, value);
        return this;
    }

    /**
     * 讀取彈性欄位（double）
     */
    public double getExtraDouble(String key) {
        Object val = extra.get(key);
        if (val == null) return 0.0;
        if (val instanceof Number) return ((Number) val).doubleValue();
        try { return Double.parseDouble(val.toString()); }
        catch (Exception e) { return 0.0; }
    }

    /**
     * 讀取彈性欄位（String）
     */
    public String getExtraString(String key) {
        Object val = extra.get(key);
        return val == null ? "" : val.toString();
    }

    /**
     * 讀取彈性欄位（boolean）
     */
    public boolean getExtraBool(String key) {
        Object val = extra.get(key);
        if (val == null) return false;
        if (val instanceof Boolean) return (Boolean) val;
        return Boolean.parseBoolean(val.toString());
    }

    /**
     * 讀取彈性欄位（int）
     */
    public int getExtraInt(String key) {
        Object val = extra.get(key);
        if (val == null) return 0;
        if (val instanceof Number) return ((Number) val).intValue();
        try { return Integer.parseInt(val.toString()); }
        catch (Exception e) { return 0; }
    }

    /**
     * 判斷彈性欄位是否存在
     */
    public boolean hasExtra(String key) {
        return extra != null && extra.containsKey(key);
    }

    /**
     * ✅ @JsonAnyGetter：序列化時將 extra 的所有 key 展開到 JSON 根層級
     *    例如 extra = {"deductionMinutes": 30} 會輸出成：
     *    { ..., "deductionMinutes": 30, ... }
     *    而不是 { ..., "extra": { "deductionMinutes": 30 } }
     */
    @JsonAnyGetter
    public Map<String, Object> getExtra() {
        return extra;
    }

    public void setExtra(Map<String, Object> v) { this.extra = v; }

    // ─── Getters ─────────────────────────────────────────────
    public String        getEmployeeCode()        { return employeeCode; }
    public LocalDateTime getScheduleDate()        { return scheduleDate; }
    public double        getTotalWorkHours()      { return totalWorkHours; }
    public double        getOvertimeHours()       { return overtimeHours; }
    public int           getOvertimeMinutes()     { return overtimeMinutes; }
    public boolean       isLate()                 { return isLate; }
    public boolean       isEarlyLeave()           { return isEarlyLeave; }
    public boolean       isEarlyArrival()         { return isEarlyArrival; }
    public int           getLateMinutes()         { return lateMinutes; }
    public int           getEarlyLeaveMinutes()   { return earlyLeaveMinutes; }
    public int           getLunchBreakMinutes()   { return lunchBreakMinutes; }
    public int           getEarlyArrivalMinutes() { return earlyArrivalMinutes; }
    public String        getEffectiveClockIn()    { return effectiveClockIn; }
    public String        getEffectiveClockOut()   { return effectiveClockOut; }
    public String        getStatus()              { return status; }
    public List<String>  getViolations()          { return violations; }
    public List<String>  getNotes()               { return notes; }

    // ─── Setters ─────────────────────────────────────────────
    public void setEmployeeCode(String v)          { this.employeeCode = v; }
    public void setScheduleDate(LocalDateTime v)   { this.scheduleDate = v; }
    public void setTotalWorkHours(double v)        { this.totalWorkHours = v; }
    public void setOvertimeHours(double v)         { this.overtimeHours = v; }
    public void setOvertimeMinutes(int v)          { this.overtimeMinutes = v; }
    public void setLate(boolean v)                 { this.isLate = v; }
    public void setEarlyLeave(boolean v)           { this.isEarlyLeave = v; }
    public void setEarlyArrival(boolean v)         { this.isEarlyArrival = v; }
    public void setLateMinutes(int v)              { this.lateMinutes = v; }
    public void setEarlyLeaveMinutes(int v)        { this.earlyLeaveMinutes = v; }
    public void setLunchBreakMinutes(int v)        { this.lunchBreakMinutes = v; }
    public void setEarlyArrivalMinutes(int v)      { this.earlyArrivalMinutes = v; }
    public void setEffectiveClockIn(String v)      { this.effectiveClockIn = v; }
    public void setEffectiveClockOut(String v)     { this.effectiveClockOut = v; }
    public void setStatus(String v)                { this.status = v; }
}
