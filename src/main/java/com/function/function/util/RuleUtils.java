package com.function.util;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;

public class RuleUtils {

    // =========================================================
    // 地理距離計算
    // =========================================================

    public static double haversineDistance(double lat1, double lon1,
                                           double lat2, double lon2) {
        final double R = 6371.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                 + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2))
                 * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    // =========================================================
    // 時間差計算
    // =========================================================

    public static long minutesBetween(LocalDateTime start, LocalDateTime end) {
        if (start == null || end == null) return 0L;
        return ChronoUnit.MINUTES.between(start, end);
    }

    public static double hoursBetween(LocalDateTime start, LocalDateTime end) {
        if (start == null || end == null) return 0.0;
        long minutes = ChronoUnit.MINUTES.between(start, end);
        return minutes / 60.0;
    }

    // =========================================================
    // 四則運算
    // =========================================================

    public static double add(double a, double b)      { return a + b; }
    public static double subtract(double a, double b) { return a - b; }
    public static double multiply(double a, double b) { return a * b; }
    public static double divide(double a, double b)   { return b == 0 ? 0.0 : a / b; }

    // =========================================================
    // 比較運算
    // =========================================================

    public static boolean gt(double a, double b)  { return a > b; }
    public static boolean gte(double a, double b) { return a >= b; }
    public static boolean lt(double a, double b)  { return a < b; }
    public static boolean lte(double a, double b) { return a <= b; }
    public static boolean eq(double a, double b)  { return Math.abs(a - b) < 0.0001; }

    // =========================================================
    // 範圍判斷
    // =========================================================

    public static boolean between(double val, double min, double max) {
        return val >= min && val <= max;
    }

    public static boolean isBetween(double val, double min, double max) {
        return val >= min && val <= max;
    }

    public static boolean isBetween(LocalDateTime target,
                                     LocalDateTime start,
                                     LocalDateTime end) {
        if (target == null || start == null || end == null) return false;
        return !target.isBefore(start) && !target.isAfter(end);
    }

    // =========================================================
    // ✅ 薪資計算工具（供 salary.drl 呼叫）
    // 時薪基準 = 底薪 ÷ 30 ÷ 8
    // 日薪基準 = 底薪 ÷ 30
    // =========================================================

    /**
     * 取得時薪：底薪 ÷ 30 ÷ 8
     */
    public static BigDecimal hourlyRate(BigDecimal baseSalary) {
        return baseSalary
            .divide(new BigDecimal("30"), 10, RoundingMode.HALF_UP)
            .divide(new BigDecimal("8"),  10, RoundingMode.HALF_UP);
    }

    /**
     * 取得日薪：底薪 ÷ 30
     */
    public static BigDecimal dailyRate(BigDecimal baseSalary) {
        return baseSalary
            .divide(new BigDecimal("30"), 10, RoundingMode.HALF_UP);
    }

    /**
     * 請假扣薪：時薪 × 小時數 × 扣薪比率
     *
     * @param baseSalary  底薪
     * @param leaveHours  請假小時數
     * @param rate        扣薪比率（100% 傳 "1.0"，50% 傳 "0.5"）
     */
    public static BigDecimal calcLeaveDeduction(BigDecimal baseSalary,
                                                 BigDecimal leaveHours,
                                                 String rate) {
        return hourlyRate(baseSalary)
            .multiply(leaveHours)
            .multiply(new BigDecimal(rate))
            .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 平日加班費
     * - ≤ 2H：全部 × 4/3（1.34 倍）
     * - > 2H：前 2H × 4/3 + 超過 × 5/3（1.67 倍）
     *
     * @param baseSalary    底薪
     * @param overtimeHours 加班小時數
     */
    public static BigDecimal calcWeekdayOvertime(BigDecimal baseSalary,
                                                  BigDecimal overtimeHours) {
        BigDecimal hr     = hourlyRate(baseSalary);
        BigDecimal r134   = new BigDecimal("4").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal r167   = new BigDecimal("5").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal two    = new BigDecimal("2");

        if (overtimeHours.compareTo(two) <= 0) {
            return hr.multiply(r134).multiply(overtimeHours)
                     .setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal extra = overtimeHours.subtract(two);
        return hr.multiply(r134).multiply(two)
                 .add(hr.multiply(r167).multiply(extra))
                 .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 平日加班費（自訂倍率，分段累加）
     * - 前 2H：時薪 × rate1
     * - 超過 2H 的部分：時薪 × rate2
     * 用於公司客製倍率（例如 rate1=2、rate2=4），與法定 calcWeekdayOvertime 區隔。
     */
    public static BigDecimal calcWeekdayOvertimeByRate(BigDecimal baseSalary,
                                                        BigDecimal overtimeHours,
                                                        String rate1Str,
                                                        String rate2Str) {
        BigDecimal hr  = hourlyRate(baseSalary);
        BigDecimal r1  = new BigDecimal(rate1Str);
        BigDecimal r2  = new BigDecimal(rate2Str);
        BigDecimal two = new BigDecimal("2");

        if (overtimeHours.compareTo(two) <= 0) {
            return hr.multiply(r1).multiply(overtimeHours)
                     .setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal extra = overtimeHours.subtract(two);
        return hr.multiply(r1).multiply(two)
                 .add(hr.multiply(r2).multiply(extra))
                 .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 休息日加班費（三段式）
     * - 第 1～2H  × 7/3（2.34 倍）
     * - 第 3～8H  × 8/3（2.67 倍）
     * - 第 9～12H × 11/3（3.67 倍）
     *
     * @param baseSalary    底薪
     * @param overtimeHours 加班小時數
     */
    public static BigDecimal calcRestDayOvertime(BigDecimal baseSalary,
                                                  BigDecimal overtimeHours) {
        BigDecimal hr   = hourlyRate(baseSalary);
        BigDecimal r234 = new BigDecimal("7").divide(new BigDecimal("3"),  10, RoundingMode.HALF_UP);
        BigDecimal r267 = new BigDecimal("8").divide(new BigDecimal("3"),  10, RoundingMode.HALF_UP);
        BigDecimal r367 = new BigDecimal("11").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);

        BigDecimal two   = new BigDecimal("2");
        BigDecimal eight = new BigDecimal("8");
        BigDecimal six   = new BigDecimal("6");

        if (overtimeHours.compareTo(two) <= 0) {
            // 全部落在第一段
            return hr.multiply(r234).multiply(overtimeHours)
                     .setScale(2, RoundingMode.HALF_UP);
        }
        if (overtimeHours.compareTo(eight) <= 0) {
            // 第一段 2H + 第二段
            BigDecimal extra = overtimeHours.subtract(two);
            return hr.multiply(r234).multiply(two)
                     .add(hr.multiply(r267).multiply(extra))
                     .setScale(2, RoundingMode.HALF_UP);
        }
        // 第一段 2H + 第二段 6H + 第三段
        BigDecimal over8 = overtimeHours.subtract(eight);
        return hr.multiply(r234).multiply(two)
                 .add(hr.multiply(r267).multiply(six))
                 .add(hr.multiply(r367).multiply(over8))
                 .setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 國定假日加班費
     * - ≤ 8H：補發一日薪資（底薪 ÷ 30）
     * - > 8H：日薪 + 超過部分依平日加班費率（前 2H×1.34 + 超過×1.67）
     *
     * @param baseSalary    底薪
     * @param overtimeHours 出勤小時數
     */
    public static BigDecimal calcNationalHolidayOvertime(BigDecimal baseSalary,
                                                          BigDecimal overtimeHours) {
        BigDecimal dr    = dailyRate(baseSalary);
        BigDecimal eight = new BigDecimal("8");

        if (overtimeHours.compareTo(eight) <= 0) {
            return dr.setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal extra = overtimeHours.subtract(eight);
        BigDecimal hr    = hourlyRate(baseSalary);
        BigDecimal r134  = new BigDecimal("4").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal r167  = new BigDecimal("5").divide(new BigDecimal("3"), 10, RoundingMode.HALF_UP);
        BigDecimal two   = new BigDecimal("2");

        BigDecimal overtimePart = extra.compareTo(two) <= 0
            ? hr.multiply(r134).multiply(extra)
            : hr.multiply(r134).multiply(two)
                 .add(hr.multiply(r167).multiply(extra.subtract(two)));

        return dr.add(overtimePart).setScale(2, RoundingMode.HALF_UP);
    }

    /**
     * 例假日 / 特休出勤加班費
     * - ≤ 8H：補發一日薪資（底薪 ÷ 30）
     * - > 8H：日薪 + 超過部分 × 2.0
     *
     * @param baseSalary    底薪
     * @param overtimeHours 出勤小時數
     */
    public static BigDecimal calcStatutoryHolidayOvertime(BigDecimal baseSalary,
                                                           BigDecimal overtimeHours) {
        BigDecimal dr    = dailyRate(baseSalary);
        BigDecimal eight = new BigDecimal("8");

        if (overtimeHours.compareTo(eight) <= 0) {
            return dr.setScale(2, RoundingMode.HALF_UP);
        }
        BigDecimal hr    = hourlyRate(baseSalary);
        BigDecimal extra = overtimeHours.subtract(eight);
        return dr.add(hr.multiply(new BigDecimal("2")).multiply(extra))
                 .setScale(2, RoundingMode.HALF_UP);
    }
}