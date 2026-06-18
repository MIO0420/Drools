package com.function.function;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.EmployeeFact;
import com.function.model.OvertimeFact;
import com.function.model.OvertimeResult;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.math.BigDecimal;
import java.util.Optional;

public class CalculateOvertimeFunction {

    private static final ObjectMapper mapper = new ObjectMapper();
    private final KieSessionService kieSessionService = new KieSessionService();

    @FunctionName("CalculateOvertime")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "calculateovertime")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        String testCaseLabel = request.getHeaders().get("x-test-case");
        if (testCaseLabel != null) {
            context.getLogger().info("Performance-Test-Label: " + testCaseLabel);
        }

        long startTime   = System.currentTimeMillis();
        Runtime runtime  = Runtime.getRuntime();
        long memBeforeMB = (runtime.totalMemory() - runtime.freeMemory()) / (1024 * 1024);

        KieSession session = null;
        try {
            String body = request.getBody().orElse("");
            if (body.isEmpty()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Empty request body").build();
            }

            OvertimeRequest req = mapper.readValue(body, OvertimeRequest.class);

            // ── 1. 組裝 EmployeeFact ──────────────────────────────────
            EmployeeFact employee = new EmployeeFact();
            employee.setEmployeeId(req.employeeId);
            employee.setCompanyId(req.companyId);
            employee.setMonthlyOvertimeHours(req.monthlyOvertimeHours);
            employee.setQuarterlyOvertimeHours(req.quarterlyOvertimeHours);
            employee.setLaborCouncilAgreed(req.laborCouncilAgreed);
            employee.setConsecutiveWorkDays(req.consecutiveWorkDays);
            employee.setRestDaysPerWeek(req.restDaysPerWeek);
            // ✅ 新增：童工 / 妊娠哺乳 / 每日每週工時
            employee.setChildWorker(req.isChildWorker);
            employee.setPregnantOrNursing(req.isPregnantOrNursing);
            employee.setDailyWorkHours(req.dailyWorkHours);
            employee.setWeeklyWorkHours(req.weeklyWorkHours);

            // ── 2. 組裝 OvertimeFact ──────────────────────────────────
            OvertimeFact overtime = new OvertimeFact();

            // overtimeType 中文別名對應
            String mappedType = req.overtimeType;
            if (mappedType != null) {
                if      (mappedType.contains("例假日")) mappedType = "REGULAR_DAY_OFF";
                else if (mappedType.contains("國定"))   mappedType = "NATIONAL_HOLIDAY";
                else if (mappedType.contains("休息日")) mappedType = "REST_DAY";
                else if (mappedType.equals("REGULAR_DAY_OFF")
                      || mappedType.equals("NATIONAL_HOLIDAY")
                      || mappedType.equals("REST_DAY")
                      || mappedType.equals("WEEKDAY")
                      || mappedType.equals("MAKEUP_WORK_DAY")) { /* 已是標準值，不動 */ }
                else    mappedType = "WEEKDAY";
            }
            overtime.setOvertimeType(mappedType);
            overtime.setOvertimeHours(req.overtimeHours);
            overtime.setOvertimeDate(req.overtimeDate);
            overtime.setCompensatoryTimeOff(req.compensatoryTimeOff);
            overtime.setCompensatoryExpired(req.compensatoryExpired);
            // ✅ 新增：天災例外旗標
            overtime.setDisasterException(req.disasterException);

            // ── 3. 組裝 OvertimeResult ────────────────────────────────
            OvertimeResult result = new OvertimeResult();
            result.setEmployeeId(req.employeeId);

            // ── 4. 執行規則引擎 ───────────────────────────────────────
            session = kieSessionService.getKieSession(
                req.ruleSet != null ? req.ruleSet : "overtime", context);
            session.insert(employee);
            session.insert(overtime);
            session.insert(result);
            session.fireAllRules();

            // ── 5. 回傳結果 ───────────────────────────────────────────
            long duration   = System.currentTimeMillis() - startTime;
            long memAfterMB = (runtime.totalMemory() - runtime.freeMemory()) / (1024 * 1024);

            context.getLogger().info(
                "CalculateOvertime complete | type=" + mappedType +
                " | hours=" + req.overtimeHours +
                " | violated=" + result.isViolated() +
                " | durationMs=" + duration
            );

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",        "application/json")
                    .header("X-Execution-Time-Ms", String.valueOf(duration))
                    .header("X-Memory-Before-MB",  String.valueOf(memBeforeMB))
                    .header("X-Memory-After-MB",   String.valueOf(memAfterMB))
                    .body(mapper.writeValueAsString(result))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("CalculateOvertime Error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                    .body(e.getMessage()).build();
        } finally {
            if (session != null) session.dispose();
        }
    }

    // =========================================================
    // Request DTO
    // =========================================================

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OvertimeRequest {

        public String     companyId;
        public String     employeeId;
        public String     overtimeType;
        public BigDecimal overtimeHours;
        public String     overtimeDate;
        public String     ruleSet;

        // ── 第 32 條｜月/季加班時數管制（對應 EmployeeFact）────────
        public int     monthlyOvertimeHours   = 0;
        public int     quarterlyOvertimeHours = 0;
        public boolean laborCouncilAgreed     = false;

        // ── 第 36 條｜連續出勤 / 每週休假（對應 EmployeeFact）───────
        public int     consecutiveWorkDays    = 0;
        public int     restDaysPerWeek        = 2;   // 預設合法值

        // ── 第 32-1 條｜補休（對應 OvertimeFact）────────────────────
        public boolean compensatoryTimeOff    = false;
        public boolean compensatoryExpired    = false;

        // ── 第 32 條第 3 項｜天災例外（對應 OvertimeFact）───────────
        // true = 因天災/事變/突發事件出勤，不受每日 12H 及月上限限制
        public boolean disasterException      = false;

        // ── 第 47 條｜童工保護（對應 EmployeeFact）──────────────────
        // true = 15歲以上未滿16歲之童工，絕對禁止加班
        public boolean isChildWorker          = false;
        public int     dailyWorkHours         = 0;   // 童工每日工時檢查
        public int     weeklyWorkHours        = 0;   // 童工每週工時檢查

        // ── 第 50~51 條｜妊娠/哺乳期間女工保護（對應 EmployeeFact）──
        // true = 妊娠或哺乳期間，禁止加班，即使本人同意亦無效
        public boolean isPregnantOrNursing    = false;
    }
}
