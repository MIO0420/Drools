package com.function.function;

import com.fasterxml.jackson.annotation.JsonAnySetter;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.SchedulingFact;
import com.function.model.SchedulingResult;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class CheckSchedulingFunction {

    private static final ObjectMapper mapper = new ObjectMapper();

    // ============================================================
    // 端點 1：單筆 / 批次合規檢查（Stateless，現有邏輯完全不動）
    // POST /api/checkscheduling
    // ============================================================
    @FunctionName("CheckScheduling")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "checkscheduling")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        long startTime = System.currentTimeMillis();

        try {
            // ── 1. 解析 Request Body ──────────────────────────────
            String body = request.getBody().orElse("");
            if (body.isEmpty()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Empty request body")
                        .build();
            }

            // ── 2. 自動判斷單筆 {} 或批次 [] ─────────────────────
            JsonNode rootNode = mapper.readTree(body);
            boolean isBatch   = rootNode.isArray();

            // ── 3. 讀取 X-Mode header ─────────────────────────────
            String xMode = request.getHeaders().getOrDefault("X-Mode",
                isBatch ? "batch" : "realtime");

            int inputCount = isBatch ? rootNode.size() : 1;

            context.getLogger().info(
                "[SCHEDULING_MODE] mode=" + xMode +
                " | isBatch=" + isBatch +
                " | count=" + inputCount
            );

            // ── 4. 解析請求資料 ───────────────────────────────────
            List<SchedulingRequest> reqs = new ArrayList<>();
            if (isBatch) {
                reqs = mapper.readValue(body, new TypeReference<List<SchedulingRequest>>() {});
                context.getLogger().info("Batch mode: " + reqs.size() + " records");
            } else {
                reqs.add(mapper.readValue(body, SchedulingRequest.class));
                context.getLogger().info("Single mode");
            }

            // ── 5. 逐筆組裝 Fact → 執行規則 → 收集 Result ────────
            List<SchedulingResult> results = new ArrayList<>();

            for (SchedulingRequest req : reqs) {
                SchedulingFact fact   = buildFact(req);
                SchedulingResult result = new SchedulingResult();

                context.getLogger().info(
                    "Firing rules | workTimeType: " + fact.getWorkTimeType()
                );

                long factStart = System.currentTimeMillis();

                // ★ StatelessKieSession：每筆 Working Memory 完全獨立
                KieSessionService.executeStateless("scheduling", context, fact, result);

                long elapsed = System.currentTimeMillis() - factStart;

                context.getLogger().info(
                    "Stateless executed" +
                    ", Violated: "      + result.isViolated()         +
                    ", ViolatedRules: " + result.getViolatedRules()   +
                    ", Warnings: "      + result.getWarnings().size() +
                    ", Notes: "         + result.getNotes().size()    +
                    ", elapsed: "       + elapsed + "ms"
                );

                results.add(result);
            }

            // ── 6. 計算總耗時 ─────────────────────────────────────
            long duration = System.currentTimeMillis() - startTime;

            context.getLogger().info(
                "Complete | isBatch: " + isBatch +
                ", count: "            + results.size() +
                ", totalDuration: "    + duration + "ms"
            );

            context.getLogger().info(
                "[SCHEDULING_RESULT] mode="    + xMode          +
                " | count="                    + results.size() +
                " | durationMs="               + duration
            );

            // ── 7. 回傳結果 ───────────────────────────────────────
            Object responseBody = isBatch ? results : results.get(0);

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",        "application/json")
                    .header("X-Execution-Time-Ms", String.valueOf(duration))
                    .header("X-Batch-Size",        String.valueOf(results.size()))
                    .header("X-Is-Batch",          String.valueOf(isBatch))
                    .header("X-Mode",              xMode)
                    .body(mapper.writeValueAsString(responseBody))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("Error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("伺服器內部錯誤: " + e.getMessage())
                    .build();
        }
    }

    // ============================================================
    // 端點 2：跨日關聯合規檢查（Stateful，按員工分組）
    // POST /api/checkscheduling/crossday
    //
    // 輸入格式：與 /api/checkscheduling 完全相同的 SchedulingRequest[]
    // 差異：每筆 extra 需包含以下欄位（透過 @JsonAnySetter 進入 extra Map）：
    //   - employeeId : 員工識別碼（字串，用於分組）
    //   - dayIndex   : 第幾天（整數，用於排序）
    //   - isWorkDay  : 是否為上班日（boolean）
    //
    // 回傳格式：每位員工一筆 SchedulingResult（含 employeeId 欄位）
    //
    // 與端點 1 的差異：
    //   端點 1（Stateless）：每筆 Fact 獨立執行，無法跨日推論
    //   端點 2（Stateful） ：同一員工所有 Fact 一次 insert，Drools 做跨 Fact 推論
    //   適用場景：連續工作天數、月加班累計、換班間距、週休天數等跨日規則
    // ============================================================
    @FunctionName("CheckSchedulingCrossDay")
    public HttpResponseMessage checkSchedulingCrossDay(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "checkscheduling/crossday")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        long startTime = System.currentTimeMillis();
        context.getLogger().info("[CROSSDAY] 跨日關聯合規檢查開始");

        try {
            // ── 1. 解析 Request Body ──────────────────────────────
            String body = request.getBody().orElse("").trim();
            if (body.isEmpty() || body.equals("null")) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Empty request body").build();
            }

            // ── 2. 反序列化（與端點 1 共用 SchedulingRequest DTO）──
            JsonNode rootNode = mapper.readTree(body);
            List<SchedulingRequest> reqs;
            if (rootNode.isArray()) {
                reqs = mapper.readValue(body, new TypeReference<List<SchedulingRequest>>() {});
            } else {
                // 單筆也接受，自動包成 List
                reqs = new ArrayList<>();
                reqs.add(mapper.readValue(body, SchedulingRequest.class));
            }

            context.getLogger().info("[CROSSDAY] 收到 " + reqs.size() + " 筆排班資料");

            // ── 3. 按 employeeId 分組 ─────────────────────────────
            // employeeId 存在 extra Map 中，透過 getExtra().get("employeeId") 取得
            // 使用 LinkedHashMap 保持插入順序，確保回傳結果順序一致
            Map<String, List<SchedulingFact>> grouped = new LinkedHashMap<>();

            for (SchedulingRequest req : reqs) {
                // ★ 組裝 SchedulingFact（共用 buildFact，extra 欄位含 employeeId / dayIndex / isWorkDay）
                SchedulingFact fact = buildFact(req);

                // employeeId 從 extra 取得（由 @JsonAnySetter 收進 extra Map）
                // buildFact 已將 extra 全部寫入 fact.metadata，可直接用 getMetaString 取得
                String empId = fact.getMetaString("employeeId");
                if (empId == null || empId.isEmpty()) {
                    empId = "unknown";
                }

                grouped.computeIfAbsent(empId, k -> new ArrayList<>()).add(fact);
            }

            context.getLogger().info("[CROSSDAY] 分組完成，共 " + grouped.size() + " 位員工");

            // ── 4. 每位員工執行跨日關聯規則 ──────────────────────
            // KieSessionService.executeStatefulGroup() 內部會按 dayIndex 排序
            // 每位員工獨立一個 Stateful Session，Session 間完全隔離
            List<SchedulingResult> results = new ArrayList<>();

            for (Map.Entry<String, List<SchedulingFact>> entry : grouped.entrySet()) {
                String empId    = entry.getKey();
                List<SchedulingFact> empFacts = entry.getValue();

                context.getLogger().info(String.format(
                    "[CROSSDAY] 處理員工 empId=%s facts=%d", empId, empFacts.size()));

                SchedulingResult result = new SchedulingResult();
                result.setEmployeeId(empId);

                // ★ Stateful Session：同一員工所有 Fact 一次 insert
                //   Drools 在 Working Memory 中做跨 Fact 推論
                //   executeStatefulGroup 內部保證 finally dispose()
                KieSessionService.executeStatefulGroup(
                    "scheduling", context, empFacts, result);

                context.getLogger().info(String.format(
                    "[CROSSDAY] empId=%s violated=%b rules=%s",
                    empId, result.isViolated(), result.getViolatedRules()));

                results.add(result);
            }

            // ── 5. 計算總耗時 ─────────────────────────────────────
            long duration = System.currentTimeMillis() - startTime;

            context.getLogger().info(String.format(
                "[CROSSDAY_RESULT] employees=%d duration=%dms violated=%d",
                results.size(),
                duration,
                results.stream().filter(SchedulingResult::isViolated).count()));

            // ── 6. 回傳結果 ───────────────────────────────────────
            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",        "application/json")
                    .header("X-Execution-Time-Ms", String.valueOf(duration))
                    .header("X-Employee-Count",    String.valueOf(results.size()))
                    .header("X-Mode",              "crossday")
                    .body(mapper.writeValueAsString(results))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("[CROSSDAY] 執行失敗：" + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("跨日關聯檢查失敗: " + e.getMessage()).build();
        }
    }

    // ============================================================
    // 共用工具方法：SchedulingRequest → SchedulingFact
    // 兩個端點共用同一份組裝邏輯，確保欄位對應一致
    // extra 欄位（含 companyId / employeeId / dayIndex / isWorkDay）
    // 全部透過 putMeta 寫入 fact.metadata，DRL 用 getMeta() 取得
    // ============================================================
    private SchedulingFact buildFact(SchedulingRequest req) {

        SchedulingFact fact = new SchedulingFact();

        // 工時制度
        fact.setWorkTimeType(req.workTimeType != null ? req.workTimeType : "GENERAL");

        // 第 30 條｜工時數值
        fact.setDailyWorkHours(req.dailyWorkHours);
        fact.setWeeklyWorkHours(req.weeklyWorkHours);
        fact.setBiweeklyWorkHours(req.biweeklyWorkHours);
        fact.setFourWeekWorkHours(req.fourWeekWorkHours);
        fact.setEightWeekWorkHours(req.eightWeekWorkHours);
        fact.setConsecutiveWorkDays(req.consecutiveWorkDays);
        fact.setRestDaysPerWeek(req.restDaysPerWeek);

        // 第 30-1 條｜四週變形工時專用
        fact.setMandatoryDaysOffBiweekly(req.mandatoryDaysOffBiweekly);
        fact.setTotalDaysOffFourWeeks(req.totalDaysOffFourWeeks);

        // 第 30 條第 3 項｜八週變形工時休假
        fact.setRestDaysBiweeklyEightWeek(req.restDaysBiweeklyEightWeek);
        fact.setRestDaysEightWeek(req.restDaysEightWeek);

        // 第 32 條｜加班上限
        fact.setDailyTotalHours(req.dailyTotalHours);
        fact.setMonthlyOvertimeHours(req.monthlyOvertimeHours);
        fact.setQuarterlyOvertimeHours(req.quarterlyOvertimeHours);
        fact.setLaborCouncilAgreed(req.laborCouncilAgreed);

        // 第 32-1 條｜補休
        fact.setCompensatoryLeaveExpired(req.compensatoryLeaveExpired);
        fact.setCompensatoryLeaveHours(
            req.compensatoryLeaveHours != null ? req.compensatoryLeaveHours : BigDecimal.ZERO
        );

        // 第 34 條｜輪班換班間距
        fact.setShiftWorker(req.shiftWorker);
        fact.setShiftChangeRestHours(req.shiftChangeRestHours);

        // 第 35 條｜工作中休息
        fact.setContinuousWorkHours(req.continuousWorkHours);
        fact.setBreakMinutes(req.breakMinutes);

        // 第 36 條｜例假與休息日
        fact.setMandatoryDayOffPerWeek(req.mandatoryDayOffPerWeek);
        fact.setRestDayPerWeek(req.restDayPerWeek);
        fact.setMandatoryDayOffScheduledAsWork(req.mandatoryDayOffScheduledAsWork);
        fact.setLegalExceptionForMandatoryDayOff(req.legalExceptionForMandatoryDayOff);
        fact.setMandatoryDayOffOvertimePaid(req.mandatoryDayOffOvertimePaid);
        fact.setRestDayWorked(req.restDayWorked);
        fact.setRestDayOvertimePaid(req.restDayOvertimePaid);

        // 第 37 條｜國定假日
        fact.setNationalHolidayScheduledAsWork(req.nationalHolidayScheduledAsWork);
        fact.setNationalHolidayAdjustAgreed(req.nationalHolidayAdjustAgreed);
        fact.setNationalHolidayOvertimePaid(req.nationalHolidayOvertimePaid);

        // 第 38 條第 4 項｜特別休假
        fact.setAnnualLeaveDeniedByEmployer(req.annualLeaveDeniedByEmployer);
        fact.setAnnualLeaveAdjustmentAgreed(req.annualLeaveAdjustmentAgreed);

        // ★ 彈性擴充欄位：extra 全部寫入 metadata
        //   包含：companyId（公司客製化規則分流）
        //         employeeId（跨日分組 key）
        //         dayIndex  （跨日排序依據）
        //         isWorkDay （跨日規則判斷上班/休假）
        //         其他任意自訂欄位
        if (req.extra != null && !req.extra.isEmpty()) {
            req.extra.forEach(fact::putMeta);
        }

        return fact;
    }

    // ============================================================
    // 內部類別 Request DTO
    // 兩個端點共用同一個 DTO，跨日端點的額外欄位透過 @JsonAnySetter 進入 extra
    // ============================================================
    public static class SchedulingRequest {

        // 工時制度：GENERAL / TWO_WEEK_FLEXIBLE / FOUR_WEEK_FLEXIBLE / EIGHT_WEEK_FLEXIBLE
        public String workTimeType;

        // 第 30 條｜工時數值
        public int dailyWorkHours;
        public int weeklyWorkHours;
        public int biweeklyWorkHours;
        public int fourWeekWorkHours;
        public int eightWeekWorkHours;
        public int consecutiveWorkDays;
        public int restDaysPerWeek;

        // 第 30-1 條｜四週變形工時專用
        public int mandatoryDaysOffBiweekly;
        public int totalDaysOffFourWeeks;

        // 第 30 條第 3 項｜八週變形工時休假
        public int restDaysBiweeklyEightWeek;
        public int restDaysEightWeek;

        // 第 32 條｜加班上限
        public int     dailyTotalHours;
        public int     monthlyOvertimeHours;
        public int     quarterlyOvertimeHours;
        public boolean laborCouncilAgreed;

        // 第 32-1 條｜補休
        public boolean    compensatoryLeaveExpired;
        public BigDecimal compensatoryLeaveHours;

        // 第 34 條｜輪班換班間距
        public boolean shiftWorker = false;
        public int     shiftChangeRestHours;

        // 第 35 條｜工作中休息
        public int continuousWorkHours;
        public int breakMinutes;

        // 第 36 條｜例假與休息日
        public boolean mandatoryDayOffPerWeek           = true;
        public boolean restDayPerWeek                   = true;
        public boolean mandatoryDayOffScheduledAsWork   = false;
        public boolean legalExceptionForMandatoryDayOff = false;
        public boolean mandatoryDayOffOvertimePaid      = false;
        public boolean restDayWorked                    = false;
        public boolean restDayOvertimePaid              = true;

        // 第 37 條｜國定假日
        public boolean nationalHolidayScheduledAsWork = false;
        public boolean nationalHolidayAdjustAgreed    = false;
        public boolean nationalHolidayOvertimePaid    = false;

        // 第 38 條第 4 項｜特別休假
        public boolean annualLeaveDeniedByEmployer = false;
        public boolean annualLeaveAdjustmentAgreed = false;

        // ── 彈性擴充欄位 ─────────────────────────────────────────
        // 所有未定義欄位統一收進 extra，透過 buildFact() 寫入 SchedulingFact.metadata
        //
        // 端點 1（Stateless）使用的 extra 欄位：
        //   companyId   → 公司客製化規則分流
        //
        // 端點 2（CrossDay）額外使用的 extra 欄位：
        //   employeeId  → 按員工分組的 key
        //   dayIndex    → 排班日序號（整數），用於跨日排序
        //   isWorkDay   → 是否為上班日（boolean），用於跨日規則判斷
        private Map<String, Object> extra = new HashMap<>();

        @JsonAnySetter
        public void setExtra(String key, Object value) {
            this.extra.put(key, value);
        }

        public Map<String, Object> getExtra() {
            return extra;
        }
    }
}
