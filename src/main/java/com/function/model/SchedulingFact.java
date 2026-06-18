// package com.function.model;

// import com.fasterxml.jackson.annotation.JsonAnySetter;
// import java.math.BigDecimal;
// import java.util.HashMap;
// import java.util.Map;

// public class SchedulingFact {

//     // ============================================================
//     // 工時制度類型
//     // GENERAL              = 一般正常工時（第30條第1項）
//     // TWO_WEEK_FLEXIBLE    = 二週變形工時（第30條第2項）
//     // FOUR_WEEK_FLEXIBLE   = 四週變形工時（第30條之1）
//     // EIGHT_WEEK_FLEXIBLE  = 八週變形工時（第30條第3項）
//     // ============================================================
//     private String workTimeType;

//     // ============================================================
//     // 第 30 條｜工時相關
//     // ============================================================

//     /** 當日正常排班工時（小時），不含加班 */
//     private int dailyWorkHours;

//     /** 當週正常工時合計（小時） */
//     private int weeklyWorkHours;

//     /** 二週總工時合計（小時），二週變形工時用，上限 80H */
//     private int biweeklyWorkHours;

//     /** 四週總工時合計（小時），四週變形工時用，上限 160H */
//     private int fourWeekWorkHours;

//     /** 八週總工時合計（小時），八週變形工時用，上限 320H */
//     private int eightWeekWorkHours;

//     /** 目前連續上班天數（不含例假、休息日） */
//     private int consecutiveWorkDays;

//     /** 每 7 日內休假天數（例假 + 休息日合計，一般工時應 >= 2） */
//     private int restDaysPerWeek;

//     // ============================================================
//     // 第 30-1 條｜四週變形工時專用
//     // ============================================================

//     /** 每 2 週內例假天數，四週變形工時用，應 >= 2 */
//     private int mandatoryDaysOffBiweekly;

//     /** 四週內例假與休息日合計天數，四週變形工時用，應 >= 8 */
//     private int totalDaysOffFourWeeks;

//     // ============================================================
//     // 第 30-3 條｜八週變形工時專用
//     // ============================================================

//     /** 八週制每 2 週內例假及休息日合計天數，應 >= 4 */
//     private int restDaysBiweeklyEightWeek;

//     /** 八週內例假及休息日合計天數，應 >= 16 */
//     private int restDaysEightWeek;

//     // ============================================================
//     // 第 32 條｜延長工時（加班）上限
//     // ============================================================

//     /** 當日正常工時 + 加班時數合計（小時），上限 12H */
//     private int dailyTotalHours;

//     /** 當月累計加班時數（小時），標準上限 46H，彈性上限 54H */
//     private int monthlyOvertimeHours;

//     /** 當季（連續 3 個月）累計加班時數（小時），彈性上限 138H */
//     private int quarterlyOvertimeHours;

//     /** 是否已取得工會或勞資會議同意（影響彈性加班上限） */
//     private boolean laborCouncilAgreed;

//     // ============================================================
//     // 第 32-1 條｜補休制度
//     // ============================================================

//     /** 是否有補休時數已超過 6 個月期限未排定 */
//     private boolean compensatoryLeaveExpired;

//     /** 尚未安排的待補休時數（小時） */
//     private BigDecimal compensatoryLeaveHours;

//     // ============================================================
//     // 第 34 條｜輪班換班間距
//     // ============================================================

//     /** 是否為輪班制勞工（true 才觸發換班間距規則，避免非輪班者預設值 0 被誤判） */
//     private boolean shiftWorker;

//     /** 換班時兩班之間的休息時數（小時），標準 >= 11H，最低 >= 8H */
//     private int shiftChangeRestHours;

//     // ============================================================
//     // 第 35 條｜工作中休息時間
//     // ============================================================

//     /** 單次連續工作時數（小時），達 4H 須給 30 分鐘休息 */
//     private int continuousWorkHours;

//     /** 工作中安排的休息分鐘數（分鐘），連續工作 4H 應 >= 30 分鐘 */
//     private int breakMinutes;

//     // ============================================================
//     // 第 36 條｜例假與休息日
//     // ============================================================

//     /** 每 7 日內是否已安排 1 日例假 */
//     private boolean mandatoryDayOffPerWeek;

//     /** 每 7 日內是否已安排 1 日休息日 */
//     private boolean restDayPerWeek;

//     /** 例假日是否被排定為上班日 */
//     private boolean mandatoryDayOffScheduledAsWork;

//     /**
//      * 例假日出勤是否符合法定例外情形：
//      * 1. 天災、事變
//      * 2. 突發事件
//      * 3. 機器設備損壞需立即搶修
//      * 4. 業務急迫且經勞工同意
//      */
//     private boolean legalExceptionForMandatoryDayOff;

//     /** 例假日符合法定例外出勤後，是否已加倍計給工資 */
//     private boolean mandatoryDayOffOvertimePaid;

//     /** 休息日是否出勤 */
//     private boolean restDayWorked;

//     /** 休息日出勤是否已依法計給加班費 */
//     private boolean restDayOvertimePaid;

//     // ============================================================
//     // 第 37 條｜國定假日
//     // ============================================================

//     /** 國定假日是否被排定為上班日 */
//     private boolean nationalHolidayScheduledAsWork;

//     /** 國定假日出勤是否已事先與勞工協商同意 */
//     private boolean nationalHolidayAdjustAgreed;

//     /** 國定假日出勤後，是否已加倍計給工資 */
//     private boolean nationalHolidayOvertimePaid;

//     // ============================================================
//     // 第 38 條第 4 項｜特別休假排定主導權
//     // ============================================================

//     /** 雇主是否拒絕勞工特別休假申請 */
//     private boolean annualLeaveDeniedByEmployer;

//     /** 特別休假是否已與勞工協商調整日期並取得同意 */
//     private boolean annualLeaveAdjustmentAgreed;

//     // ============================================================
//     // 彈性擴充欄位
//     // 用於動態新增規則時傳入任意 key-value，不需修改 Java Model
//     // JSON 中未定義的欄位會自動進入此 Map
//     //
//     // DRL 取值範例：
//     //   $sch.getMetaBool("customFlag")
//     //   $sch.getMetaInt("customThreshold")
//     // ============================================================
//     private Map<String, Object> metadata = new HashMap<>();

//     // ============================================================
//     // 建構子
//     // ============================================================

//     public SchedulingFact() {
//         // 數值欄位預設為 0
//         this.dailyWorkHours               = 0;
//         this.weeklyWorkHours              = 0;
//         this.biweeklyWorkHours            = 0;
//         this.fourWeekWorkHours            = 0;
//         this.eightWeekWorkHours           = 0;
//         this.consecutiveWorkDays          = 0;
//         this.restDaysPerWeek              = 0;
//         this.mandatoryDaysOffBiweekly     = 0;
//         this.totalDaysOffFourWeeks        = 0;
//         this.restDaysBiweeklyEightWeek    = 0;
//         this.restDaysEightWeek            = 0;
//         this.dailyTotalHours              = 0;
//         this.monthlyOvertimeHours         = 0;
//         this.quarterlyOvertimeHours       = 0;
//         this.shiftChangeRestHours         = 0;
//         this.continuousWorkHours          = 0;
//         this.breakMinutes                 = 0;
//         this.compensatoryLeaveHours       = BigDecimal.ZERO;

//         // boolean 欄位預設為 false（合規狀態）
//         this.laborCouncilAgreed                = false;
//         this.compensatoryLeaveExpired          = false;
//         this.shiftWorker                       = false;
//         this.mandatoryDayOffPerWeek            = true;
//         this.restDayPerWeek                    = true;
//         this.mandatoryDayOffScheduledAsWork    = false;
//         this.legalExceptionForMandatoryDayOff  = false;
//         this.mandatoryDayOffOvertimePaid       = false;
//         this.restDayWorked                     = false;
//         this.restDayOvertimePaid               = true;
//         this.nationalHolidayScheduledAsWork    = false;
//         this.nationalHolidayAdjustAgreed       = false;
//         this.nationalHolidayOvertimePaid       = false;
//         this.annualLeaveDeniedByEmployer       = false;
//         this.annualLeaveAdjustmentAgreed       = false;
//     }

//     // ============================================================
//     // @JsonAnySetter：JSON 中所有未定義欄位自動進入 metadata
//     // ============================================================
//     @JsonAnySetter
//     public void setMetaField(String key, Object value) {
//         this.metadata.put(key, value);
//     }

//     // ============================================================
//     // metadata 存取工具方法
//     // ============================================================

//     public int getMetaInt(String key) {
//         Object val = metadata.get(key);
//         if (val == null) return 0;
//         if (val instanceof Number) return ((Number) val).intValue();
//         try { return Integer.parseInt(val.toString()); }
//         catch (Exception e) { return 0; }
//     }

//     public double getMetaDouble(String key) {
//         Object val = metadata.get(key);
//         if (val == null) return 0.0;
//         if (val instanceof Number) return ((Number) val).doubleValue();
//         try { return Double.parseDouble(val.toString()); }
//         catch (Exception e) { return 0.0; }
//     }

//     public String getMetaString(String key) {
//         Object val = metadata.get(key);
//         return val == null ? "" : val.toString();
//     }

//     public boolean getMetaBool(String key) {
//         Object val = metadata.get(key);
//         if (val == null) return false;
//         if (val instanceof Boolean) return (Boolean) val;
//         return Boolean.parseBoolean(val.toString());
//     }

//     public boolean hasMeta(String key) {
//         return metadata != null && metadata.containsKey(key);
//     }

//     public void putMeta(String key, Object value) {
//         this.metadata.put(key, value);
//     }

//     // ============================================================
//     // Getters & Setters
//     // ============================================================

//     public String getWorkTimeType() { return workTimeType; }
//     public void setWorkTimeType(String v) { this.workTimeType = v; }

//     public int getDailyWorkHours() { return dailyWorkHours; }
//     public void setDailyWorkHours(int v) { this.dailyWorkHours = v; }

//     public int getWeeklyWorkHours() { return weeklyWorkHours; }
//     public void setWeeklyWorkHours(int v) { this.weeklyWorkHours = v; }

//     public int getBiweeklyWorkHours() { return biweeklyWorkHours; }
//     public void setBiweeklyWorkHours(int v) { this.biweeklyWorkHours = v; }

//     public int getFourWeekWorkHours() { return fourWeekWorkHours; }
//     public void setFourWeekWorkHours(int v) { this.fourWeekWorkHours = v; }

//     public int getEightWeekWorkHours() { return eightWeekWorkHours; }
//     public void setEightWeekWorkHours(int v) { this.eightWeekWorkHours = v; }

//     public int getConsecutiveWorkDays() { return consecutiveWorkDays; }
//     public void setConsecutiveWorkDays(int v) { this.consecutiveWorkDays = v; }

//     public int getRestDaysPerWeek() { return restDaysPerWeek; }
//     public void setRestDaysPerWeek(int v) { this.restDaysPerWeek = v; }

//     public int getMandatoryDaysOffBiweekly() { return mandatoryDaysOffBiweekly; }
//     public void setMandatoryDaysOffBiweekly(int v) { this.mandatoryDaysOffBiweekly = v; }

//     public int getTotalDaysOffFourWeeks() { return totalDaysOffFourWeeks; }
//     public void setTotalDaysOffFourWeeks(int v) { this.totalDaysOffFourWeeks = v; }

//     public int getRestDaysBiweeklyEightWeek() { return restDaysBiweeklyEightWeek; }
//     public void setRestDaysBiweeklyEightWeek(int v) { this.restDaysBiweeklyEightWeek = v; }

//     public int getRestDaysEightWeek() { return restDaysEightWeek; }
//     public void setRestDaysEightWeek(int v) { this.restDaysEightWeek = v; }

//     public int getDailyTotalHours() { return dailyTotalHours; }
//     public void setDailyTotalHours(int v) { this.dailyTotalHours = v; }

//     public int getMonthlyOvertimeHours() { return monthlyOvertimeHours; }
//     public void setMonthlyOvertimeHours(int v) { this.monthlyOvertimeHours = v; }

//     public int getQuarterlyOvertimeHours() { return quarterlyOvertimeHours; }
//     public void setQuarterlyOvertimeHours(int v) { this.quarterlyOvertimeHours = v; }

//     public boolean isLaborCouncilAgreed() { return laborCouncilAgreed; }
//     public void setLaborCouncilAgreed(boolean v) { this.laborCouncilAgreed = v; }

//     public boolean isCompensatoryLeaveExpired() { return compensatoryLeaveExpired; }
//     public void setCompensatoryLeaveExpired(boolean v) { this.compensatoryLeaveExpired = v; }

//     public BigDecimal getCompensatoryLeaveHours() { return compensatoryLeaveHours; }
//     public void setCompensatoryLeaveHours(BigDecimal v) { this.compensatoryLeaveHours = v; }

//     public boolean isShiftWorker() { return shiftWorker; }
//     public void setShiftWorker(boolean v) { this.shiftWorker = v; }

//     public int getShiftChangeRestHours() { return shiftChangeRestHours; }
//     public void setShiftChangeRestHours(int v) { this.shiftChangeRestHours = v; }

//     public int getContinuousWorkHours() { return continuousWorkHours; }
//     public void setContinuousWorkHours(int v) { this.continuousWorkHours = v; }

//     public int getBreakMinutes() { return breakMinutes; }
//     public void setBreakMinutes(int v) { this.breakMinutes = v; }

//     public boolean isMandatoryDayOffPerWeek() { return mandatoryDayOffPerWeek; }
//     public void setMandatoryDayOffPerWeek(boolean v) { this.mandatoryDayOffPerWeek = v; }

//     public boolean isRestDayPerWeek() { return restDayPerWeek; }
//     public void setRestDayPerWeek(boolean v) { this.restDayPerWeek = v; }

//     public boolean isMandatoryDayOffScheduledAsWork() { return mandatoryDayOffScheduledAsWork; }
//     public void setMandatoryDayOffScheduledAsWork(boolean v) { this.mandatoryDayOffScheduledAsWork = v; }

//     public boolean isLegalExceptionForMandatoryDayOff() { return legalExceptionForMandatoryDayOff; }
//     public void setLegalExceptionForMandatoryDayOff(boolean v) { this.legalExceptionForMandatoryDayOff = v; }

//     public boolean isMandatoryDayOffOvertimePaid() { return mandatoryDayOffOvertimePaid; }
//     public void setMandatoryDayOffOvertimePaid(boolean v) { this.mandatoryDayOffOvertimePaid = v; }

//     public boolean isRestDayWorked() { return restDayWorked; }
//     public void setRestDayWorked(boolean v) { this.restDayWorked = v; }

//     public boolean isRestDayOvertimePaid() { return restDayOvertimePaid; }
//     public void setRestDayOvertimePaid(boolean v) { this.restDayOvertimePaid = v; }

//     public boolean isNationalHolidayScheduledAsWork() { return nationalHolidayScheduledAsWork; }
//     public void setNationalHolidayScheduledAsWork(boolean v) { this.nationalHolidayScheduledAsWork = v; }

//     public boolean isNationalHolidayAdjustAgreed() { return nationalHolidayAdjustAgreed; }
//     public void setNationalHolidayAdjustAgreed(boolean v) { this.nationalHolidayAdjustAgreed = v; }

//     public boolean isNationalHolidayOvertimePaid() { return nationalHolidayOvertimePaid; }
//     public void setNationalHolidayOvertimePaid(boolean v) { this.nationalHolidayOvertimePaid = v; }

//     public boolean isAnnualLeaveDeniedByEmployer() { return annualLeaveDeniedByEmployer; }
//     public void setAnnualLeaveDeniedByEmployer(boolean v) { this.annualLeaveDeniedByEmployer = v; }

//     public boolean isAnnualLeaveAdjustmentAgreed() { return annualLeaveAdjustmentAgreed; }
//     public void setAnnualLeaveAdjustmentAgreed(boolean v) { this.annualLeaveAdjustmentAgreed = v; }

//     public Map<String, Object> getMetadata() { return metadata; }
//     public void setMetadata(Map<String, Object> v) { this.metadata = v; }

//     // ============================================================
//     // toString（方便 Debug 輸出）
//     // ============================================================

//     @Override
//     public String toString() {
//         return "SchedulingFact{" +
//             "workTimeType='"                         + workTimeType                     + '\'' +
//             ", dailyWorkHours="                      + dailyWorkHours                   +
//             ", weeklyWorkHours="                     + weeklyWorkHours                  +
//             ", biweeklyWorkHours="                   + biweeklyWorkHours                +
//             ", fourWeekWorkHours="                   + fourWeekWorkHours                +
//             ", eightWeekWorkHours="                  + eightWeekWorkHours               +
//             ", consecutiveWorkDays="                 + consecutiveWorkDays              +
//             ", restDaysPerWeek="                     + restDaysPerWeek                  +
//             ", mandatoryDaysOffBiweekly="            + mandatoryDaysOffBiweekly         +
//             ", totalDaysOffFourWeeks="               + totalDaysOffFourWeeks            +
//             ", restDaysBiweeklyEightWeek="           + restDaysBiweeklyEightWeek        +
//             ", restDaysEightWeek="                   + restDaysEightWeek                +
//             ", dailyTotalHours="                     + dailyTotalHours                  +
//             ", monthlyOvertimeHours="                + monthlyOvertimeHours             +
//             ", quarterlyOvertimeHours="              + quarterlyOvertimeHours           +
//             ", laborCouncilAgreed="                  + laborCouncilAgreed               +
//             ", compensatoryLeaveExpired="            + compensatoryLeaveExpired         +
//             ", compensatoryLeaveHours="              + compensatoryLeaveHours           +
//             ", shiftWorker="                         + shiftWorker                      +
//             ", shiftChangeRestHours="                + shiftChangeRestHours             +
//             ", continuousWorkHours="                 + continuousWorkHours              +
//             ", breakMinutes="                        + breakMinutes                     +
//             ", mandatoryDayOffPerWeek="              + mandatoryDayOffPerWeek           +
//             ", restDayPerWeek="                      + restDayPerWeek                   +
//             ", mandatoryDayOffScheduledAsWork="      + mandatoryDayOffScheduledAsWork   +
//             ", legalExceptionForMandatoryDayOff="    + legalExceptionForMandatoryDayOff +
//             ", mandatoryDayOffOvertimePaid="         + mandatoryDayOffOvertimePaid      +
//             ", restDayWorked="                       + restDayWorked                    +
//             ", restDayOvertimePaid="                 + restDayOvertimePaid              +
//             ", nationalHolidayScheduledAsWork="      + nationalHolidayScheduledAsWork   +
//             ", nationalHolidayAdjustAgreed="         + nationalHolidayAdjustAgreed      +
//             ", nationalHolidayOvertimePaid="         + nationalHolidayOvertimePaid      +
//             ", annualLeaveDeniedByEmployer="         + annualLeaveDeniedByEmployer      +
//             ", annualLeaveAdjustmentAgreed="         + annualLeaveAdjustmentAgreed      +
//             ", metadata="                            + metadata                         +
//             '}';
//     }
// }
// 路徑：Graduate/src/main/java/com/function/model/SchedulingFact.java
package com.function.model;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import java.math.BigDecimal;
import java.util.HashMap;
import java.util.Map;

public class SchedulingFact {

    // ============================================================
    // 工時制度類型
    // ============================================================
    private String workTimeType;

    // ============================================================
    // 第 30 條｜工時相關
    // ============================================================
    private int dailyWorkHours;
    private int weeklyWorkHours;
    private int biweeklyWorkHours;
    private int fourWeekWorkHours;
    private int eightWeekWorkHours;
    private int consecutiveWorkDays;
    private int restDaysPerWeek;

    // ============================================================
    // 第 30-1 條｜四週變形工時專用
    // ============================================================
    private int mandatoryDaysOffBiweekly;
    private int totalDaysOffFourWeeks;

    // ============================================================
    // 第 30-3 條｜八週變形工時專用
    // ============================================================
    private int restDaysBiweeklyEightWeek;
    private int restDaysEightWeek;

    // ============================================================
    // 第 32 條｜延長工時（加班）上限
    // ============================================================
    private int     dailyTotalHours;
    private int     monthlyOvertimeHours;
    private int     quarterlyOvertimeHours;
    private boolean laborCouncilAgreed;

    // ============================================================
    // 第 32-1 條｜補休制度
    // ============================================================
    private boolean    compensatoryLeaveExpired;
    private BigDecimal compensatoryLeaveHours;

    // ============================================================
    // 第 34 條｜輪班換班間距
    // ============================================================
    private boolean shiftWorker;
    private int     shiftChangeRestHours;

    // ============================================================
    // 第 35 條｜工作中休息時間
    // ============================================================
    private int continuousWorkHours;
    private int breakMinutes;

    // ============================================================
    // 第 36 條｜例假與休息日
    // ============================================================
    private boolean mandatoryDayOffPerWeek;
    private boolean restDayPerWeek;
    private boolean mandatoryDayOffScheduledAsWork;
    private boolean legalExceptionForMandatoryDayOff;
    private boolean mandatoryDayOffOvertimePaid;
    private boolean restDayWorked;
    private boolean restDayOvertimePaid;

    // ============================================================
    // 第 37 條｜國定假日
    // ============================================================
    private boolean nationalHolidayScheduledAsWork;
    private boolean nationalHolidayAdjustAgreed;
    private boolean nationalHolidayOvertimePaid;

    // ============================================================
    // 第 38 條第 4 項｜特別休假排定主導權
    // ============================================================
    private boolean annualLeaveDeniedByEmployer;
    private boolean annualLeaveAdjustmentAgreed;

    // ============================================================
    // 彈性擴充欄位
    // ============================================================
    private Map<String, Object> metadata = new HashMap<>();

    // ============================================================
    // 建構子
    // ============================================================
    public SchedulingFact() {
        this.dailyWorkHours               = 0;
        this.weeklyWorkHours              = 0;
        this.biweeklyWorkHours            = 0;
        this.fourWeekWorkHours            = 0;
        this.eightWeekWorkHours           = 0;
        this.consecutiveWorkDays          = 0;
        this.restDaysPerWeek              = 0;
        this.mandatoryDaysOffBiweekly     = 0;
        this.totalDaysOffFourWeeks        = 0;
        this.restDaysBiweeklyEightWeek    = 0;
        this.restDaysEightWeek            = 0;
        this.dailyTotalHours              = 0;
        this.monthlyOvertimeHours         = 0;
        this.quarterlyOvertimeHours       = 0;
        this.shiftChangeRestHours         = 0;
        this.continuousWorkHours          = 0;
        this.breakMinutes                 = 0;
        this.compensatoryLeaveHours       = BigDecimal.ZERO;

        this.laborCouncilAgreed                = false;
        this.compensatoryLeaveExpired          = false;
        this.shiftWorker                       = false;
        this.mandatoryDayOffPerWeek            = true;
        this.restDayPerWeek                    = true;
        this.mandatoryDayOffScheduledAsWork    = false;
        this.legalExceptionForMandatoryDayOff  = false;
        this.mandatoryDayOffOvertimePaid       = false;
        this.restDayWorked                     = false;
        this.restDayOvertimePaid               = true;
        this.nationalHolidayScheduledAsWork    = false;
        this.nationalHolidayAdjustAgreed       = false;
        this.nationalHolidayOvertimePaid       = false;
        this.annualLeaveDeniedByEmployer       = false;
        this.annualLeaveAdjustmentAgreed       = false;
    }

    // ============================================================
    // @JsonAnySetter
    // ============================================================
    @JsonAnySetter
    public void setMetaField(String key, Object value) {
        this.metadata.put(key, value);
    }

    // ============================================================
    // metadata 存取工具方法
    // ============================================================

    /**
     * ★ 新增：回傳原始 Object，供 DRL 規則直接呼叫。
     *
     * DRL 使用範例：
     *   getMeta("companyId") != null
     *   getMeta("companyId").toString() == "1"
     *
     * Legacy Java 使用範例：
     *   Object val = f.getMeta("companyId");
     *   if (val != null) companyId = val.toString();
     *
     * @param key metadata 的 key 名稱
     * @return 對應的 Object 值，key 不存在時回傳 null
     */
    public Object getMeta(String key) {
        return metadata != null ? metadata.get(key) : null;
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

    public void putMeta(String key, Object value) {
        this.metadata.put(key, value);
    }

    // ============================================================
    // Getters & Setters（完全不動）
    // ============================================================

    public String getWorkTimeType() { return workTimeType; }
    public void setWorkTimeType(String v) { this.workTimeType = v; }

    public int getDailyWorkHours() { return dailyWorkHours; }
    public void setDailyWorkHours(int v) { this.dailyWorkHours = v; }

    public int getWeeklyWorkHours() { return weeklyWorkHours; }
    public void setWeeklyWorkHours(int v) { this.weeklyWorkHours = v; }

    public int getBiweeklyWorkHours() { return biweeklyWorkHours; }
    public void setBiweeklyWorkHours(int v) { this.biweeklyWorkHours = v; }

    public int getFourWeekWorkHours() { return fourWeekWorkHours; }
    public void setFourWeekWorkHours(int v) { this.fourWeekWorkHours = v; }

    public int getEightWeekWorkHours() { return eightWeekWorkHours; }
    public void setEightWeekWorkHours(int v) { this.eightWeekWorkHours = v; }

    public int getConsecutiveWorkDays() { return consecutiveWorkDays; }
    public void setConsecutiveWorkDays(int v) { this.consecutiveWorkDays = v; }

    public int getRestDaysPerWeek() { return restDaysPerWeek; }
    public void setRestDaysPerWeek(int v) { this.restDaysPerWeek = v; }

    public int getMandatoryDaysOffBiweekly() { return mandatoryDaysOffBiweekly; }
    public void setMandatoryDaysOffBiweekly(int v) { this.mandatoryDaysOffBiweekly = v; }

    public int getTotalDaysOffFourWeeks() { return totalDaysOffFourWeeks; }
    public void setTotalDaysOffFourWeeks(int v) { this.totalDaysOffFourWeeks = v; }

    public int getRestDaysBiweeklyEightWeek() { return restDaysBiweeklyEightWeek; }
    public void setRestDaysBiweeklyEightWeek(int v) { this.restDaysBiweeklyEightWeek = v; }

    public int getRestDaysEightWeek() { return restDaysEightWeek; }
    public void setRestDaysEightWeek(int v) { this.restDaysEightWeek = v; }

    public int getDailyTotalHours() { return dailyTotalHours; }
    public void setDailyTotalHours(int v) { this.dailyTotalHours = v; }

    public int getMonthlyOvertimeHours() { return monthlyOvertimeHours; }
    public void setMonthlyOvertimeHours(int v) { this.monthlyOvertimeHours = v; }

    public int getQuarterlyOvertimeHours() { return quarterlyOvertimeHours; }
    public void setQuarterlyOvertimeHours(int v) { this.quarterlyOvertimeHours = v; }

    public boolean isLaborCouncilAgreed() { return laborCouncilAgreed; }
    public void setLaborCouncilAgreed(boolean v) { this.laborCouncilAgreed = v; }

    public boolean isCompensatoryLeaveExpired() { return compensatoryLeaveExpired; }
    public void setCompensatoryLeaveExpired(boolean v) { this.compensatoryLeaveExpired = v; }

    public BigDecimal getCompensatoryLeaveHours() { return compensatoryLeaveHours; }
    public void setCompensatoryLeaveHours(BigDecimal v) { this.compensatoryLeaveHours = v; }

    public boolean isShiftWorker() { return shiftWorker; }
    public void setShiftWorker(boolean v) { this.shiftWorker = v; }

    public int getShiftChangeRestHours() { return shiftChangeRestHours; }
    public void setShiftChangeRestHours(int v) { this.shiftChangeRestHours = v; }

    public int getContinuousWorkHours() { return continuousWorkHours; }
    public void setContinuousWorkHours(int v) { this.continuousWorkHours = v; }

    public int getBreakMinutes() { return breakMinutes; }
    public void setBreakMinutes(int v) { this.breakMinutes = v; }

    public boolean isMandatoryDayOffPerWeek() { return mandatoryDayOffPerWeek; }
    public void setMandatoryDayOffPerWeek(boolean v) { this.mandatoryDayOffPerWeek = v; }

    public boolean isRestDayPerWeek() { return restDayPerWeek; }
    public void setRestDayPerWeek(boolean v) { this.restDayPerWeek = v; }

    public boolean isMandatoryDayOffScheduledAsWork() { return mandatoryDayOffScheduledAsWork; }
    public void setMandatoryDayOffScheduledAsWork(boolean v) { this.mandatoryDayOffScheduledAsWork = v; }

    public boolean isLegalExceptionForMandatoryDayOff() { return legalExceptionForMandatoryDayOff; }
    public void setLegalExceptionForMandatoryDayOff(boolean v) { this.legalExceptionForMandatoryDayOff = v; }

    public boolean isMandatoryDayOffOvertimePaid() { return mandatoryDayOffOvertimePaid; }
    public void setMandatoryDayOffOvertimePaid(boolean v) { this.mandatoryDayOffOvertimePaid = v; }

    public boolean isRestDayWorked() { return restDayWorked; }
    public void setRestDayWorked(boolean v) { this.restDayWorked = v; }

    public boolean isRestDayOvertimePaid() { return restDayOvertimePaid; }
    public void setRestDayOvertimePaid(boolean v) { this.restDayOvertimePaid = v; }

    public boolean isNationalHolidayScheduledAsWork() { return nationalHolidayScheduledAsWork; }
    public void setNationalHolidayScheduledAsWork(boolean v) { this.nationalHolidayScheduledAsWork = v; }

    public boolean isNationalHolidayAdjustAgreed() { return nationalHolidayAdjustAgreed; }
    public void setNationalHolidayAdjustAgreed(boolean v) { this.nationalHolidayAdjustAgreed = v; }

    public boolean isNationalHolidayOvertimePaid() { return nationalHolidayOvertimePaid; }
    public void setNationalHolidayOvertimePaid(boolean v) { this.nationalHolidayOvertimePaid = v; }

    public boolean isAnnualLeaveDeniedByEmployer() { return annualLeaveDeniedByEmployer; }
    public void setAnnualLeaveDeniedByEmployer(boolean v) { this.annualLeaveDeniedByEmployer = v; }

    public boolean isAnnualLeaveAdjustmentAgreed() { return annualLeaveAdjustmentAgreed; }
    public void setAnnualLeaveAdjustmentAgreed(boolean v) { this.annualLeaveAdjustmentAgreed = v; }

    public Map<String, Object> getMetadata() { return metadata; }
    public void setMetadata(Map<String, Object> v) { this.metadata = v; }

    // ============================================================
    // toString
    // ============================================================
    @Override
    public String toString() {
        return "SchedulingFact{" +
            "workTimeType='"                         + workTimeType                     + '\'' +
            ", dailyWorkHours="                      + dailyWorkHours                   +
            ", weeklyWorkHours="                     + weeklyWorkHours                  +
            ", biweeklyWorkHours="                   + biweeklyWorkHours                +
            ", fourWeekWorkHours="                   + fourWeekWorkHours                +
            ", eightWeekWorkHours="                  + eightWeekWorkHours               +
            ", consecutiveWorkDays="                 + consecutiveWorkDays              +
            ", restDaysPerWeek="                     + restDaysPerWeek                  +
            ", mandatoryDaysOffBiweekly="            + mandatoryDaysOffBiweekly         +
            ", totalDaysOffFourWeeks="               + totalDaysOffFourWeeks            +
            ", restDaysBiweeklyEightWeek="           + restDaysBiweeklyEightWeek        +
            ", restDaysEightWeek="                   + restDaysEightWeek                +
            ", dailyTotalHours="                     + dailyTotalHours                  +
            ", monthlyOvertimeHours="                + monthlyOvertimeHours             +
            ", quarterlyOvertimeHours="              + quarterlyOvertimeHours           +
            ", laborCouncilAgreed="                  + laborCouncilAgreed               +
            ", compensatoryLeaveExpired="            + compensatoryLeaveExpired         +
            ", compensatoryLeaveHours="              + compensatoryLeaveHours           +
            ", shiftWorker="                         + shiftWorker                      +
            ", shiftChangeRestHours="                + shiftChangeRestHours             +
            ", continuousWorkHours="                 + continuousWorkHours              +
            ", breakMinutes="                        + breakMinutes                     +
            ", mandatoryDayOffPerWeek="              + mandatoryDayOffPerWeek           +
            ", restDayPerWeek="                      + restDayPerWeek                   +
            ", mandatoryDayOffScheduledAsWork="      + mandatoryDayOffScheduledAsWork   +
            ", legalExceptionForMandatoryDayOff="    + legalExceptionForMandatoryDayOff +
            ", mandatoryDayOffOvertimePaid="         + mandatoryDayOffOvertimePaid      +
            ", restDayWorked="                       + restDayWorked                    +
            ", restDayOvertimePaid="                 + restDayOvertimePaid              +
            ", nationalHolidayScheduledAsWork="      + nationalHolidayScheduledAsWork   +
            ", nationalHolidayAdjustAgreed="         + nationalHolidayAdjustAgreed      +
            ", nationalHolidayOvertimePaid="         + nationalHolidayOvertimePaid      +
            ", annualLeaveDeniedByEmployer="         + annualLeaveDeniedByEmployer      +
            ", annualLeaveAdjustmentAgreed="         + annualLeaveAdjustmentAgreed      +
            ", metadata="                            + metadata                         +
            '}';
    }
}
