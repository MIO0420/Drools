package com.function.model;

import java.math.BigDecimal;
import java.math.RoundingMode;

public class EmployeeFact {
    private String     managerId;
    private String     companyId;
    private String     employeeId;
    private String     position;
    private String     identity;
    private String     department;          // ← 新增
    private int        tenureMonths;
    private int        seniorityMonths;
    private BigDecimal baseSalary;
    private BigDecimal dailySalary;
    private BigDecimal absentDays;
    private boolean    laborCouncilAgreed;

    // ── 新增：DRL 版欄位 ──────────────────────────────────────
    // workingDaysInMonth = 公司計薪基準（月薪攤到幾個工作日）
    //   預設 30；公司可設 22（= 攤到實際工作日，時薪與日薪皆較高）
    //   影響所有薪資計算：加班費、請假扣薪、客製加給全部依此除數計算
    //   各公司設定互相獨立，是租戶隔離的一個維度
    private int        workingDaysInMonth  = 30;
    private BigDecimal laborInsuredSalary;
    private BigDecimal healthInsuredSalary;
    private BigDecimal pensionSalary;

    // ── 第 32 條｜加班時數管制 ────────────────────────────────
    private int monthlyOvertimeHours;
    private int quarterlyOvertimeHours;

    // ── 第 36 條｜出勤排班管制 ────────────────────────────────
    private int consecutiveWorkDays;
    private int restDaysPerWeek;

    // ── 第 47 條｜童工保護 ────────────────────────────────────
    private boolean isChildWorker       = false;
    private int     dailyWorkHours      = 0;
    private int     weeklyWorkHours     = 0;

    // ── 第 50~51 條｜妊娠/哺乳期間女工保護 ───────────────────
    private boolean isPregnantOrNursing = false;

    // ============================================================
    // 建構子
    // ============================================================

    public EmployeeFact() {}

    public EmployeeFact(String employeeId, String position, String identity,
                        int tenureMonths, BigDecimal baseSalary) {
        this.employeeId      = employeeId;
        this.position        = position;
        this.identity        = identity;
        this.tenureMonths    = tenureMonths;
        this.seniorityMonths = tenureMonths;
        this.baseSalary      = baseSalary;
        this.dailySalary     = baseSalary.divide(BigDecimal.valueOf(30), 10, RoundingMode.HALF_UP);
        this.restDaysPerWeek = 2;
    }

    // ============================================================
    // Getters & Setters
    // ============================================================

    public String getCompanyId() { return companyId; }
    public void   setCompanyId(String v) { this.companyId = v; }
public String getManagerId() { return managerId; }
public void setManagerId(String managerId) { this.managerId = managerId; }
    public String getEmployeeId() { return employeeId; }
    public void   setEmployeeId(String v) { this.employeeId = v; }

    public String getPosition() { return position; }
    public void   setPosition(String v) { this.position = v; }

    public String getIdentity() { return identity; }
    public void   setIdentity(String v) { this.identity = v; }

    public String getDepartment() { return department; }          // ← 新增
    public void   setDepartment(String v) { this.department = v; } // ← 新增

    public int  getTenureMonths() { return tenureMonths; }
    public void setTenureMonths(int v) { this.tenureMonths = v; }

    public int  getSeniorityMonths() { return seniorityMonths; }
    public void setSeniorityMonths(int v) { this.seniorityMonths = v; }

    public BigDecimal getBaseSalary() { return baseSalary; }
    public void       setBaseSalary(BigDecimal v) { this.baseSalary = v; }

    public BigDecimal getDailySalary() { return dailySalary; }
    public void       setDailySalary(BigDecimal v) { this.dailySalary = v; }

    public BigDecimal getAbsentDays() { return absentDays; }
    public void       setAbsentDays(BigDecimal v) { this.absentDays = v; }

    public boolean isLaborCouncilAgreed() { return laborCouncilAgreed; }
    public void    setLaborCouncilAgreed(boolean v) { this.laborCouncilAgreed = v; }

    // ── 新增欄位 getter/setter ────────────────────────────────

    public int  getWorkingDaysInMonth() { return workingDaysInMonth; }
    public void setWorkingDaysInMonth(int v) { this.workingDaysInMonth = v; }

    public BigDecimal getLaborInsuredSalary() { return laborInsuredSalary; }
    public void       setLaborInsuredSalary(BigDecimal v) { this.laborInsuredSalary = v; }

    public BigDecimal getHealthInsuredSalary() { return healthInsuredSalary; }
    public void       setHealthInsuredSalary(BigDecimal v) { this.healthInsuredSalary = v; }

    public BigDecimal getPensionSalary() { return pensionSalary; }
    public void       setPensionSalary(BigDecimal v) { this.pensionSalary = v; }

    // ── 加班時數管制 ──────────────────────────────────────────

    public int  getMonthlyOvertimeHours() { return monthlyOvertimeHours; }
    public void setMonthlyOvertimeHours(int v) { this.monthlyOvertimeHours = v; }

    public int  getQuarterlyOvertimeHours() { return quarterlyOvertimeHours; }
    public void setQuarterlyOvertimeHours(int v) { this.quarterlyOvertimeHours = v; }

    public int  getConsecutiveWorkDays() { return consecutiveWorkDays; }
    public void setConsecutiveWorkDays(int v) { this.consecutiveWorkDays = v; }

    public int  getRestDaysPerWeek() { return restDaysPerWeek; }
    public void setRestDaysPerWeek(int v) { this.restDaysPerWeek = v; }

    // ── 童工欄位 ──────────────────────────────────────────────

    public boolean isChildWorker() { return isChildWorker; }
    public void    setChildWorker(boolean v) { this.isChildWorker = v; }

    public int  getDailyWorkHours() { return dailyWorkHours; }
    public void setDailyWorkHours(int v) { this.dailyWorkHours = v; }

    public int  getWeeklyWorkHours() { return weeklyWorkHours; }
    public void setWeeklyWorkHours(int v) { this.weeklyWorkHours = v; }

    // ── 妊娠/哺乳欄位 ─────────────────────────────────────────

    public boolean isPregnantOrNursing() { return isPregnantOrNursing; }
    public void    setPregnantOrNursing(boolean v) { this.isPregnantOrNursing = v; }

    // ============================================================
    // 職級判斷
    // ============================================================

    public boolean isManagerOrAbove() {
        return position != null &&
                (position.equals("MANAGER") ||
                 position.equals("DIRECTOR") ||
                 position.equals("VP") ||
                 position.equals("C_LEVEL"));
    }

    // ============================================================
    // Helper Methods（供 DRL 呼叫的計算工具）
    // ============================================================

    /**
     * 時薪 = 底薪 ÷ workingDaysInMonth ÷ 8
     * 預設除數 30；公司可透過 workingDaysInMonth 設定計薪基準
     * 設定 22 表示月薪攤至 22 個工作天，加班費與請假扣薪皆依此基準計算
     */
    public BigDecimal getHourlyRate() {
        int divisor = workingDaysInMonth > 0 ? workingDaysInMonth : 30;
        return baseSalary
            .divide(BigDecimal.valueOf(divisor), 10, RoundingMode.HALF_UP)
            .divide(new BigDecimal("8"),         10, RoundingMode.HALF_UP);
    }

    /**
     * 日薪 = 底薪 ÷ workingDaysInMonth
     * 與 getHourlyRate() 使用相同除數，保持一致
     * 供客製加給與需要日薪基準的計算使用
     */
    public BigDecimal getDailyRate() {
        int divisor = workingDaysInMonth > 0 ? workingDaysInMonth : 30;
        return baseSalary.divide(BigDecimal.valueOf(divisor), 10, RoundingMode.HALF_UP);
    }

    /**
     * 請假扣薪 = 法定時薪 × 小時數 × 扣薪比率
     */
    public BigDecimal calcLeaveDeduction(BigDecimal leaveHours, String rate) {
        return getHourlyRate()
            .multiply(leaveHours)
            .multiply(new BigDecimal(rate))
            .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 平日加班費：前 2H × (4/3)，超過部分 × (5/3)
     */

public BigDecimal calcWeekdayOvertime(BigDecimal overtimeHours) {
    BigDecimal hourly  = getHourlyRate();
    BigDecimal rate134 = new BigDecimal("4").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
    BigDecimal rate167 = new BigDecimal("5").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);

    if (overtimeHours.compareTo(new BigDecimal("2")) <= 0) {
        return hourly.multiply(rate134).multiply(overtimeHours)
            .setScale(2, RoundingMode.HALF_UP);
    }

    BigDecimal step1 = hourly.multiply(rate134).multiply(new BigDecimal("2"));
    BigDecimal step2 = hourly.multiply(rate167).multiply(overtimeHours.subtract(new BigDecimal("2")));

    return step1.add(step2).setScale(2, RoundingMode.HALF_UP);
}


    /**
     * 休息日加班費（三段式）
     * 第 1~2H × (7/3)、第 3~8H × (8/3)、第 9~12H × (11/3)
     */
    public BigDecimal calcRestDayOvertime(BigDecimal overtimeHours) {
        BigDecimal hourly  = getHourlyRate();
        BigDecimal rate234 = new BigDecimal("7").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal rate267 = new BigDecimal("8").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal rate367 = new BigDecimal("11").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);

        if (overtimeHours.compareTo(new BigDecimal("2")) <= 0) {
            return hourly.multiply(rate234).multiply(overtimeHours)
                .setScale(0, RoundingMode.UP);
        }
        if (overtimeHours.compareTo(new BigDecimal("8")) <= 0) {
            BigDecimal s1 = hourly.multiply(rate234).multiply(new BigDecimal("2"));
            BigDecimal s2 = hourly.multiply(rate267).multiply(overtimeHours.subtract(new BigDecimal("2")));
            return s1.add(s2).setScale(0, RoundingMode.UP);
        }
        BigDecimal s1 = hourly.multiply(rate234).multiply(new BigDecimal("2"));
        BigDecimal s2 = hourly.multiply(rate267).multiply(new BigDecimal("6"));
        BigDecimal s3 = hourly.multiply(rate367).multiply(overtimeHours.subtract(new BigDecimal("8")));
        return s1.add(s2).add(s3).setScale(0, RoundingMode.UP);
    }

    /**
     * 國定假日加班費（8H 以內）= 補發一日薪
     */
    public BigDecimal calcNationalHolidayOvertimeBase() {
        return getDailyRate().setScale(0, RoundingMode.HALF_UP);
    }

    /**
     * 國定假日加班費（超過 8H）= 日薪 + 超過部分依平日加班費率
     */
    public BigDecimal calcNationalHolidayOvertimeExtra(BigDecimal overtimeHours) {
        BigDecimal daily   = getDailyRate();
        BigDecimal hourly  = getHourlyRate();
        BigDecimal rate134 = new BigDecimal("4").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal rate167 = new BigDecimal("5").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal extra   = overtimeHours.subtract(new BigDecimal("8"));

        BigDecimal overtimePart;
        if (extra.compareTo(new BigDecimal("2")) <= 0) {
            overtimePart = hourly.multiply(rate134).multiply(extra);
        } else {
            overtimePart = hourly.multiply(rate134).multiply(new BigDecimal("2"))
                .add(hourly.multiply(rate167).multiply(extra.subtract(new BigDecimal("2"))));
        }
        return daily.add(overtimePart).setScale(0, RoundingMode.HALF_UP);
    }

    /**
     * 例假日加班費（8H 以內）= 補發一日薪
     */
    public BigDecimal calcStatutoryHolidayOvertimeBase() {
        return getDailyRate().setScale(0, RoundingMode.HALF_UP);
    }

    /**
     * 例假日加班費（超過 8H）= 日薪 + 超過部分 × 2.0
     */
    public BigDecimal calcStatutoryHolidayOvertimeExtra(BigDecimal overtimeHours) {
        BigDecimal extra = overtimeHours.subtract(new BigDecimal("8"))
            .multiply(getHourlyRate())
            .multiply(new BigDecimal("2.0"))
            .setScale(0, RoundingMode.UP);
        return getDailyRate().setScale(0, RoundingMode.HALF_UP).add(extra);
    }

    /**
     * 特休出勤（8H 以內）= 補發一日薪
     */
    public BigDecimal calcAnnualLeaveDayOvertimeBase() {
        return getDailyRate().setScale(0, RoundingMode.HALF_UP);
    }
}