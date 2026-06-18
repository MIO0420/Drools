package com.function.model;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.annotation.JsonFormat;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class TimeCheckFact {

    private String employeeCode;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime clockInTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime clockOutTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime scheduleStartTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime scheduleEndTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime lunchOutTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime lunchInTime;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime punchCorrectionIn;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime punchCorrectionOut;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime effectiveClockIn;

    @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
    private LocalDateTime effectiveClockOut;

    // ── 容錯與豁免設定 ────────────────────────────────────────
    private int toleranceMinutes              = 5;
    private int earlyArrivalToleranceMinutes  = 0;
    private int allowedMonthlyLateMinutes     = 0;
    private int monthlyAccumulatedLateMinutes = 0;

    // ── DRL 計算中間值快取（供 Drools 追蹤狀態變化）─────────
    private int    lateMinutesCache = 0;
    private double totalWorkHours   = 0.0;
    private double overtimeHours    = 0.0;

    // ── 狀態旗標 ──────────────────────────────────────────────
    private boolean late         = false;
    private boolean earlyLeave   = false;
    private boolean earlyArrival = false;

    // DRL 流程控制旗標（控制規則執行順序，防止重複觸發）
    private boolean toleranceResolved = false;
    private boolean leaveResolved     = false;
    private boolean hoursCalculated   = false;

    // ── 子資料 ────────────────────────────────────────────────
    private List<LeaveApplication>    leaveApplications    = new ArrayList<>();
    private List<OvertimeApplication> overtimeApplications = new ArrayList<>();

    private TimeCheckResult result = new TimeCheckResult();

    // 彈性擴充欄位：無需修改 Java Model 即可支援新規則
    // 範例：metadata.put("temperature", 38.5)
    //       metadata.put("isRemoteWork", true)
    //       metadata.put("monthlyLateCount", 3)
    private Map<String, Object> metadata = new HashMap<>();

    // =========================================================
    // @JsonAnySetter：讓 JSON 中所有未定義欄位自動進入 metadata
    // 範例：JSON 傳入 "monthlyLateCount": 3
    //       → metadata.put("monthlyLateCount", 3)
    //       → DRL 中用 getMetaInt("monthlyLateCount") 取值
    // =========================================================
    @JsonAnySetter
    public void setMetaField(String key, Object value) {
        this.metadata.put(key, value);
    }

    // =========================================================
    // 唯一保留的 Helper：月累計豁免判斷
    // 理由：這是純狀態查詢（讀取自身欄位），非計算邏輯
    //       DRL pattern 條件式中無法直接做加法比較，需要封裝
    // =========================================================
    public boolean isMonthlyLateWithinAllowance() {
        if (allowedMonthlyLateMinutes <= 0) return false;
        return (monthlyAccumulatedLateMinutes + lateMinutesCache) <= allowedMonthlyLateMinutes;
    }

    // =========================================================
    // metadata 存取工具方法
    // =========================================================

    /**
     * 取得 metadata 中的 double 值
     * 找不到 key 或轉換失敗時回傳 0.0
     */
    public double getMetaDouble(String key) {
        Object val = metadata.get(key);
        if (val == null) return 0.0;
        if (val instanceof Number) return ((Number) val).doubleValue();
        try { return Double.parseDouble(val.toString()); }
        catch (Exception e) { return 0.0; }
    }

    /**
     * 取得 metadata 中的 String 值
     * 任何型別都會呼叫 toString() 轉換
     * 找不到 key 時回傳空字串 ""
     */
    public String getMetaString(String key) {
        Object val = metadata.get(key);
        return val == null ? "" : val.toString();
    }

    /**
     * 取得 metadata 中的 boolean 值
     * 支援 JSON 傳入的 Boolean / String("true"/"false") 自動轉換
     * 找不到 key 時回傳 false
     */
    public boolean getMetaBool(String key) {
        Object val = metadata.get(key);
        if (val == null) return false;
        if (val instanceof Boolean) return (Boolean) val;
        return Boolean.parseBoolean(val.toString());
    }

    /**
     * 取得 metadata 中的 int 值
     * 支援 JSON 傳入的 Integer / Double / String 型別自動轉換
     * 找不到 key 或轉換失敗時回傳 0
     */
    public int getMetaInt(String key) {
        Object val = metadata.get(key);
        if (val == null) return 0;
        if (val instanceof Number) return ((Number) val).intValue();
        try { return Integer.parseInt(val.toString()); }
        catch (Exception e) { return 0; }
    }

    /**
     * 判斷 metadata 中是否存在某個 key（無論值為何）
     * DRL 範例：$f : TimeCheckFact( hasMeta("typhoonDay") == true )
     */
    public boolean hasMeta(String key) {
        return metadata != null && metadata.containsKey(key);
    }

    /**
     * 鏈式寫法，方便 Java 程式碼中快速塞值
     * 範例：new TimeCheckFact().putMeta("temperature", 39.5).putMeta("isTyphoonDay", true)
     */
    public TimeCheckFact putMeta(String key, Object value) {
        this.metadata.put(key, value);
        return this;
    }

    // =========================================================
    // 內部 DTO
    // =========================================================

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class LeaveApplication {
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime leaveStart;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime leaveEnd;
        private String  leaveType = "";
        private boolean paid      = false;

        public LocalDateTime getLeaveStart()                { return leaveStart; }
        public void          setLeaveStart(LocalDateTime v) { this.leaveStart = v; }
        public LocalDateTime getLeaveEnd()                  { return leaveEnd; }
        public void          setLeaveEnd(LocalDateTime v)   { this.leaveEnd = v; }
        public String        getLeaveType()                 { return leaveType; }
        public void          setLeaveType(String v)         { this.leaveType = v; }
        public boolean       isPaid()                       { return paid; }
        public void          setPaid(boolean v)             { this.paid = v; }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OvertimeApplication {
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime overtimeStart;
        @JsonFormat(pattern = "yyyy-MM-dd'T'HH:mm:ss")
        private LocalDateTime overtimeEnd;
        private String overtimeType = "WEEKDAY";

        public LocalDateTime getOvertimeStart()                { return overtimeStart; }
        public void          setOvertimeStart(LocalDateTime v) { this.overtimeStart = v; }
        public LocalDateTime getOvertimeEnd()                  { return overtimeEnd; }
        public void          setOvertimeEnd(LocalDateTime v)   { this.overtimeEnd = v; }
        public String        getOvertimeType()                 { return overtimeType; }
        public void          setOvertimeType(String v)         { this.overtimeType = v; }
    }

    // ─── Getters ──────────────────────────────────────────────
    public String            getEmployeeCode()                  { return employeeCode; }
    public LocalDateTime     getClockInTime()                   { return clockInTime; }
    public LocalDateTime     getClockOutTime()                  { return clockOutTime; }
    public LocalDateTime     getScheduleStartTime()             { return scheduleStartTime; }
    public LocalDateTime     getScheduleEndTime()               { return scheduleEndTime; }
    public LocalDateTime     getLunchOutTime()                  { return lunchOutTime; }
    public LocalDateTime     getLunchInTime()                   { return lunchInTime; }
    public LocalDateTime     getPunchCorrectionIn()             { return punchCorrectionIn; }
    public LocalDateTime     getPunchCorrectionOut()            { return punchCorrectionOut; }
    public LocalDateTime     getEffectiveClockIn()              { return effectiveClockIn; }
    public LocalDateTime     getEffectiveClockOut()             { return effectiveClockOut; }
    public int               getToleranceMinutes()              { return toleranceMinutes; }
    public int               getEarlyArrivalToleranceMinutes()  { return earlyArrivalToleranceMinutes; }
    public int               getAllowedMonthlyLateMinutes()      { return allowedMonthlyLateMinutes; }
    public int               getMonthlyAccumulatedLateMinutes() { return monthlyAccumulatedLateMinutes; }
    public int               getLateMinutesCache()              { return lateMinutesCache; }
    public double            getTotalWorkHours()                { return totalWorkHours; }
    public double            getOvertimeHours()                 { return overtimeHours; }
    public boolean           isLate()                           { return late; }
    public boolean           isEarlyLeave()                     { return earlyLeave; }
    public boolean           isEarlyArrival()                   { return earlyArrival; }
    public boolean           isToleranceResolved()              { return toleranceResolved; }
    public boolean           isLeaveResolved()                  { return leaveResolved; }
    public boolean           isHoursCalculated()                { return hoursCalculated; }
    public TimeCheckResult   getResult()                        { return result; }
    public List<LeaveApplication>    getLeaveApplications()     { return leaveApplications; }
    public List<OvertimeApplication> getOvertimeApplications()  { return overtimeApplications; }
    public Map<String, Object>       getMetadata()              { return metadata; }

    // ─── Setters ──────────────────────────────────────────────
    public void setEmployeeCode(String v)                             { this.employeeCode = v; }
    public void setClockInTime(LocalDateTime v)                       { this.clockInTime = v; }
    public void setClockOutTime(LocalDateTime v)                      { this.clockOutTime = v; }
    public void setScheduleStartTime(LocalDateTime v)                 { this.scheduleStartTime = v; }
    public void setScheduleEndTime(LocalDateTime v)                   { this.scheduleEndTime = v; }
    public void setLunchOutTime(LocalDateTime v)                      { this.lunchOutTime = v; }
    public void setLunchInTime(LocalDateTime v)                       { this.lunchInTime = v; }
    public void setPunchCorrectionIn(LocalDateTime v)                 { this.punchCorrectionIn = v; }
    public void setPunchCorrectionOut(LocalDateTime v)                { this.punchCorrectionOut = v; }
    public void setEffectiveClockIn(LocalDateTime v)                  { this.effectiveClockIn = v; }
    public void setEffectiveClockOut(LocalDateTime v)                 { this.effectiveClockOut = v; }
    public void setToleranceMinutes(int v)                            { this.toleranceMinutes = v; }
    public void setEarlyArrivalToleranceMinutes(int v)                { this.earlyArrivalToleranceMinutes = v; }
    public void setAllowedMonthlyLateMinutes(int v)                   { this.allowedMonthlyLateMinutes = v; }
    public void setMonthlyAccumulatedLateMinutes(int v)               { this.monthlyAccumulatedLateMinutes = v; }
    public void setLateMinutesCache(int v)                            { this.lateMinutesCache = v; }
    public void setTotalWorkHours(double v)                           { this.totalWorkHours = v; }
    public void setOvertimeHours(double v)                            { this.overtimeHours = v; }
    public void setLate(boolean v)                                    { this.late = v; }
    public void setEarlyLeave(boolean v)                              { this.earlyLeave = v; }
    public void setEarlyArrival(boolean v)                            { this.earlyArrival = v; }
    public void setToleranceResolved(boolean v)                       { this.toleranceResolved = v; }
    public void setLeaveResolved(boolean v)                           { this.leaveResolved = v; }
    public void setHoursCalculated(boolean v)                         { this.hoursCalculated = v; }
    public void setResult(TimeCheckResult v)                          { this.result = v; }
    public void setLeaveApplications(List<LeaveApplication> v)       { this.leaveApplications = v; }
    public void setOvertimeApplications(List<OvertimeApplication> v) { this.overtimeApplications = v; }
    public void setMetadata(Map<String, Object> v)                    { this.metadata = v; }
}
