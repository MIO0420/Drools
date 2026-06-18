package com.function.model;

import com.fasterxml.jackson.annotation.JsonAnyGetter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

public class SchedulingResult {

    // ============================================================
    // 核心結果
    // ============================================================

    /** 是否有任何違規（只要有一條就是 true） */
    private boolean violated = false;

    /** 所有違規規則名稱清單（可累積多條） */
    private List<String> violatedRules = new ArrayList<>();

    /** 所有違規訊息清單（與 violatedRules 一一對應） */
    private List<String> violatedMessages = new ArrayList<>();

    // ============================================================
    // 警告與備註（可累積多條）
    // ============================================================

    /** 警告清單（非違規但需注意，例如換班間距偏低） */
    private List<String> warnings = new ArrayList<>();

    /** 備註清單（合規確認訊息） */
    private List<String> notes = new ArrayList<>();

    // ============================================================
    // ★ 跨日關聯識別欄位
    // 供 checkSchedulingCrossDay 端點使用
    // 每筆 SchedulingResult 對應一位員工的整段排班檢查結果
    // CheckSchedulingFunction.checkSchedulingCrossDay() 在分組後設定此欄位
    // ============================================================

    /**
     * 員工識別碼，對應 SchedulingRequest.extra["employeeId"]。
     * 單筆 / 批次端點（/api/checkscheduling）不使用此欄位，預設空字串。
     * 跨日端點（/api/checkscheduling/crossday）每筆結果都會填入對應的 employeeId。
     */
    private String employeeId = "";

    // ============================================================
    // 彈性擴充欄位
    // DRL 可透過 putExtra() 寫入任意 key-value
    // 序列化時會自動展開到 JSON 根層級（不會包在 "extra" 物件裡）
    //
    // DRL 範例：
    //   $result.putExtra("nextCheckDate", "2026-06-01");
    //   $result.putExtra("flexibleQuotaRemaining", 8);
    // ============================================================
    private Map<String, Object> extra = new LinkedHashMap<>();

    // ============================================================
    // 累積方法（DRL 規則統一呼叫這裡）
    // ============================================================

    /** 新增一筆違規（自動將 violated 設為 true） */
    public void addViolation(String rule, String message) {
        this.violated = true;
        this.violatedRules.add(rule);
        this.violatedMessages.add(message);
    }

    /** 新增一筆警告（不影響 violated 狀態） */
    public void addWarning(String warning) {
        this.warnings.add(warning);
    }

    /** 新增一筆備註（合規確認用） */
    public void addNote(String note) {
        this.notes.add(note);
    }

    // ============================================================
    // extra 存取工具方法
    // ============================================================

    /**
     * 寫入彈性欄位，支援鏈式呼叫
     * DRL 範例：$result.putExtra("flexibleQuotaRemaining", 8);
     */
    public SchedulingResult putExtra(String key, Object value) {
        this.extra.put(key, value);
        return this;
    }

    /**
     * 取得 extra 中的 int 值
     * 找不到 key 或轉換失敗時回傳 0
     */
    public int getExtraInt(String key) {
        Object val = extra.get(key);
        if (val == null) return 0;
        if (val instanceof Number) return ((Number) val).intValue();
        try { return Integer.parseInt(val.toString()); }
        catch (Exception e) { return 0; }
    }

    /**
     * 取得 extra 中的 double 值
     * 找不到 key 或轉換失敗時回傳 0.0
     */
    public double getExtraDouble(String key) {
        Object val = extra.get(key);
        if (val == null) return 0.0;
        if (val instanceof Number) return ((Number) val).doubleValue();
        try { return Double.parseDouble(val.toString()); }
        catch (Exception e) { return 0.0; }
    }

    /**
     * 取得 extra 中的 String 值
     * 找不到 key 時回傳空字串 ""
     */
    public String getExtraString(String key) {
        Object val = extra.get(key);
        return val == null ? "" : val.toString();
    }

    /**
     * 取得 extra 中的 boolean 值
     * 支援 Boolean / String("true"/"false") 自動轉換
     * 找不到 key 時回傳 false
     */
    public boolean getExtraBool(String key) {
        Object val = extra.get(key);
        if (val == null) return false;
        if (val instanceof Boolean) return (Boolean) val;
        return Boolean.parseBoolean(val.toString());
    }

    /**
     * 判斷 extra 中是否存在某個 key
     */
    public boolean hasExtra(String key) {
        return extra != null && extra.containsKey(key);
    }

    // ============================================================
    // Getters & Setters
    // ============================================================

    public boolean isViolated() { return violated; }
    public void setViolated(boolean violated) { this.violated = violated; }

    public List<String> getViolatedRules() { return violatedRules; }
    public void setViolatedRules(List<String> violatedRules) { this.violatedRules = violatedRules; }

    public List<String> getViolatedMessages() { return violatedMessages; }
    public void setViolatedMessages(List<String> violatedMessages) { this.violatedMessages = violatedMessages; }

    public List<String> getWarnings() { return warnings; }
    public void setWarnings(List<String> warnings) { this.warnings = warnings; }

    public List<String> getNotes() { return notes; }
    public void setNotes(List<String> notes) { this.notes = notes; }

    // ★ employeeId getter / setter
    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) {
        this.employeeId = employeeId != null ? employeeId : "";
    }

    /**
     * @JsonAnyGetter：序列化時將 extra 的所有 key 展開到 JSON 根層級
     * 例如 extra = {"flexibleQuotaRemaining": 8} 會輸出成：
     * { ..., "flexibleQuotaRemaining": 8, ... }
     * 而不是 { ..., "extra": { "flexibleQuotaRemaining": 8 } }
     */
    @JsonAnyGetter
    public Map<String, Object> getExtra() { return extra; }
    public void setExtra(Map<String, Object> extra) { this.extra = extra; }

    // ============================================================
    // toString
    // ============================================================

    @Override
    public String toString() {
        return "SchedulingResult{" +
            "violated="           + violated          +
            ", violatedRules="    + violatedRules      +
            ", violatedMessages=" + violatedMessages   +
            ", warnings="         + warnings           +
            ", notes="            + notes              +
            ", employeeId='"      + employeeId         + '\'' +
            ", extra="            + extra              +
            '}';
    }
}
