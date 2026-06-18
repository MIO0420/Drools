package com.function.model;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;

public class SalaryResult {

    // ── 核心薪資欄位 ──────────────────────────────────────────
    private String     employeeId;
    private BigDecimal baseSalary;
    private BigDecimal leaveDeduction;
    private BigDecimal overtimeBonus;
    private BigDecimal finalSalary;
    private String     appliedRule;
    private String     message;

    // ── ★ 新增：年資加給 & 公司津貼 ──────────────────────────
    private BigDecimal seniorityBonus;
    private BigDecimal companyBonus;

    // ── 健保相關 ──────────────────────────────────────────────
    private int employeeHealthInsurance;
    private int employerHealthInsurance;
    private int governmentHealthInsurance;

    // ── 勞保相關 ──────────────────────────────────────────────
    private int employeeLaborInsurance;
    private int employeeEmploymentInsurance;
    private int employerLaborInsurance;
    private int employerEmploymentInsurance;
    private int wageGuaranteeFund;

    // ── 退休金相關 ────────────────────────────────────────────
    private int        employerPension;
    private BigDecimal employeePension;

    // ── 其他扣項 ──────────────────────────────────────────────
    private boolean    taxExempt;
    private BigDecimal absentDeduction;

    // ── 全勤獎金相關 ──────────────────────────────────────────
    private boolean    fullAttendanceBonusDeducted;
    private BigDecimal fullAttendanceBonusDeductRatio;
    private boolean    fullAttendancePenaltyExempt = false;

    // ── 雇主成本彙總 ──────────────────────────────────────────
    private BigDecimal employerTotalCost;
    private BigDecimal employeeTotalInsurance;
    private BigDecimal employerTotalInsurance;

    // ── 補休時數 ──────────────────────────────────────────────
    private BigDecimal compensatoryHours;

    // ── 規則觸發明細清單 ──────────────────────────────────────
    private List<String> ruleDetails = new ArrayList<>();

    // ============================================================
    // 建構子
    // ============================================================

    public SalaryResult() {
        this.baseSalary                     = BigDecimal.ZERO;
        this.leaveDeduction                 = BigDecimal.ZERO;
        this.overtimeBonus                  = BigDecimal.ZERO;
        this.finalSalary                    = BigDecimal.ZERO;
        this.absentDeduction                = BigDecimal.ZERO;
        this.employeePension                = BigDecimal.ZERO;
        this.fullAttendanceBonusDeductRatio = BigDecimal.ZERO;
        this.employerTotalCost              = BigDecimal.ZERO;
        this.employeeTotalInsurance         = BigDecimal.ZERO;
        this.employerTotalInsurance         = BigDecimal.ZERO;
        this.compensatoryHours              = BigDecimal.ZERO;
        this.message                        = "";
        this.appliedRule                    = "";
        this.fullAttendancePenaltyExempt    = false;
        this.ruleDetails                    = new ArrayList<>();
        // ★ 新增初始化
        this.seniorityBonus                 = BigDecimal.ZERO;
        this.companyBonus                   = BigDecimal.ZERO;
    }

    // ============================================================
    // 輔助方法（供 DRL 呼叫）
    // ============================================================

    public void addRuleDetail(String detail) {
        if (detail != null && !detail.isEmpty()) {
            this.ruleDetails.add(detail);
        }
    }

    public void addWarning(String warning) {
        if (warning != null && !warning.isEmpty()) {
            this.message = (this.message == null || this.message.isEmpty()
                ? "" : this.message + " | ")
                + "[警告] " + warning;
        }
    }

    public void addNote(String note) {
        if (note != null && !note.isEmpty()) {
            this.message = (this.message == null || this.message.isEmpty()
                ? "" : this.message + " | ")
                + "[備註] " + note;
        }
    }

    // ============================================================
    // Getters & Setters
    // ============================================================

    // ── 核心薪資 ──────────────────────────────────────────────

    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String employeeId) { this.employeeId = employeeId; }

    public BigDecimal getBaseSalary() { return baseSalary; }
    public void       setBaseSalary(BigDecimal baseSalary) { this.baseSalary = baseSalary; }

    public BigDecimal getLeaveDeduction() { return leaveDeduction; }
    public void       setLeaveDeduction(BigDecimal leaveDeduction) { this.leaveDeduction = leaveDeduction; }

    public BigDecimal getOvertimeBonus() { return overtimeBonus; }
    public void       setOvertimeBonus(BigDecimal overtimeBonus) { this.overtimeBonus = overtimeBonus; }

    public BigDecimal getFinalSalary() { return finalSalary; }
    public void       setFinalSalary(BigDecimal finalSalary) { this.finalSalary = finalSalary; }

    public String getAppliedRule() { return appliedRule; }
    public void   setAppliedRule(String appliedRule) { this.appliedRule = appliedRule; }

    public String getMessage() { return message; }
    public void   setMessage(String message) { this.message = message; }

    public List<String> getRuleDetails() { return ruleDetails; }
    public void         setRuleDetails(List<String> ruleDetails) { this.ruleDetails = ruleDetails; }

    // ── ★ 新增：年資加給 ──────────────────────────────────────

    public BigDecimal getSeniorityBonus() {
        return seniorityBonus != null ? seniorityBonus : BigDecimal.ZERO;
    }
    public void setSeniorityBonus(BigDecimal seniorityBonus) {
        this.seniorityBonus = seniorityBonus != null ? seniorityBonus : BigDecimal.ZERO;
    }

    // ── ★ 新增：公司津貼 ──────────────────────────────────────

    public BigDecimal getCompanyBonus() {
        return companyBonus != null ? companyBonus : BigDecimal.ZERO;
    }
    public void setCompanyBonus(BigDecimal companyBonus) {
        this.companyBonus = companyBonus != null ? companyBonus : BigDecimal.ZERO;
    }

    // ── 健保 ──────────────────────────────────────────────────

    public int getEmployeeHealthInsurance() { return employeeHealthInsurance; }
    public void setEmployeeHealthInsurance(int v) { this.employeeHealthInsurance = v; }

    public int getEmployerHealthInsurance() { return employerHealthInsurance; }
    public void setEmployerHealthInsurance(int v) { this.employerHealthInsurance = v; }

    public int getGovernmentHealthInsurance() { return governmentHealthInsurance; }
    public void setGovernmentHealthInsurance(int v) { this.governmentHealthInsurance = v; }

    // ── 勞保 ──────────────────────────────────────────────────

    public int getEmployeeLaborInsurance() { return employeeLaborInsurance; }
    public void setEmployeeLaborInsurance(int v) { this.employeeLaborInsurance = v; }

    public int getEmployeeEmploymentInsurance() { return employeeEmploymentInsurance; }
    public void setEmployeeEmploymentInsurance(int v) { this.employeeEmploymentInsurance = v; }

    public int getEmployerLaborInsurance() { return employerLaborInsurance; }
    public void setEmployerLaborInsurance(int v) { this.employerLaborInsurance = v; }

    public int getEmployerEmploymentInsurance() { return employerEmploymentInsurance; }
    public void setEmployerEmploymentInsurance(int v) { this.employerEmploymentInsurance = v; }

    public int getWageGuaranteeFund() { return wageGuaranteeFund; }
    public void setWageGuaranteeFund(int v) { this.wageGuaranteeFund = v; }

    // ── 退休金 ────────────────────────────────────────────────

    public int getEmployerPension() { return employerPension; }
    public void setEmployerPension(int v) { this.employerPension = v; }

    public BigDecimal getEmployeePension() { return employeePension; }
    public void       setEmployeePension(BigDecimal v) { this.employeePension = v; }

    // ── 其他扣項 ──────────────────────────────────────────────

    public boolean isTaxExempt() { return taxExempt; }
    public void    setTaxExempt(boolean v) { this.taxExempt = v; }

    public BigDecimal getAbsentDeduction() { return absentDeduction; }
    public void       setAbsentDeduction(BigDecimal v) { this.absentDeduction = v; }

    // ── 全勤獎金 ──────────────────────────────────────────────

    public boolean isFullAttendanceBonusDeducted() { return fullAttendanceBonusDeducted; }
    public void    setFullAttendanceBonusDeducted(boolean v) { this.fullAttendanceBonusDeducted = v; }

    public BigDecimal getFullAttendanceBonusDeductRatio() { return fullAttendanceBonusDeductRatio; }
    public void       setFullAttendanceBonusDeductRatio(BigDecimal v) { this.fullAttendanceBonusDeductRatio = v; }

    public boolean isFullAttendancePenaltyExempt() { return fullAttendancePenaltyExempt; }
    public void    setFullAttendancePenaltyExempt(boolean v) { this.fullAttendancePenaltyExempt = v; }

    // ── 雇主成本彙總 ──────────────────────────────────────────

    public BigDecimal getEmployerTotalCost() { return employerTotalCost; }
    public void       setEmployerTotalCost(BigDecimal v) { this.employerTotalCost = v; }

    public BigDecimal getEmployeeTotalInsurance() { return employeeTotalInsurance; }
    public void       setEmployeeTotalInsurance(BigDecimal v) { this.employeeTotalInsurance = v; }

    public BigDecimal getEmployerTotalInsurance() { return employerTotalInsurance; }
    public void       setEmployerTotalInsurance(BigDecimal v) { this.employerTotalInsurance = v; }

    // ── 補休時數 ──────────────────────────────────────────────

    public BigDecimal getCompensatoryHours() { return compensatoryHours; }
    public void       setCompensatoryHours(BigDecimal v) { this.compensatoryHours = v; }
}
