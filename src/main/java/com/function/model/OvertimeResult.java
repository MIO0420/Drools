package com.function.model;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

/**
 * 加班合法性判斷結果
 * 專注於時數合法性，不含薪資計算
 */
public class OvertimeResult {

    private String employeeId;

    /** 是否有任何違規（只要有一條就是 true） */
    private boolean violated = false;

    /** 套用的規則說明（最後觸發的主規則） */
    private String appliedRule = "";

    /** 補休時數（選擇補休時才有值） */
    private BigDecimal compensatoryHours = BigDecimal.ZERO;

    /** 是否免稅 */
    private boolean taxExempt = false;

    /** 違規警告清單 */
    private List<String> warnings = new ArrayList<>();

    /** 合法備註清單 */
    private List<String> notes = new ArrayList<>();

    /** 規則觸發明細（供 debug / audit） */
    private List<String> ruleDetails = new ArrayList<>();

    public OvertimeResult() {}

    public OvertimeResult(String employeeId) {
        this.employeeId = employeeId;
    }

    // ── 工具方法 ──────────────────────────────────────────────

    public void addWarning(String warning) {
        if (warning != null && !warning.isBlank()) {
            this.warnings.add(warning);
        }
    }

    public void addNote(String note) {
        if (note != null && !note.isBlank()) {
            this.notes.add(note);
        }
    }

    public void addRuleDetail(String detail) {
        if (detail != null && !detail.isBlank()) {
            this.ruleDetails.add(detail);
        }
    }

    // ── Getters & Setters ─────────────────────────────────────

    public String getEmployeeId() { return employeeId; }
    public void setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public boolean isViolated() { return violated; }
    public void setViolated(boolean violated) { this.violated = violated; }

    public String getAppliedRule() { return appliedRule; }
    public void setAppliedRule(String appliedRule) {
        this.appliedRule = appliedRule != null ? appliedRule : "";
    }

    public BigDecimal getCompensatoryHours() { return compensatoryHours; }
    public void setCompensatoryHours(BigDecimal compensatoryHours) {
        this.compensatoryHours = compensatoryHours != null ? compensatoryHours : BigDecimal.ZERO;
    }

    public boolean isTaxExempt() { return taxExempt; }
    public void setTaxExempt(boolean taxExempt) { this.taxExempt = taxExempt; }

    public List<String> getWarnings() { return warnings; }
    public void setWarnings(List<String> warnings) {
        this.warnings = warnings != null ? warnings : new ArrayList<>();
    }

    public List<String> getNotes() { return notes; }
    public void setNotes(List<String> notes) {
        this.notes = notes != null ? notes : new ArrayList<>();
    }

    public List<String> getRuleDetails() { return ruleDetails; }
    public void setRuleDetails(List<String> ruleDetails) {
        this.ruleDetails = ruleDetails != null ? ruleDetails : new ArrayList<>();
    }
}
