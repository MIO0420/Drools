package com.function.function;

import com.function.model.TimeCheckFact;
import com.function.model.TimeCheckResult;
import com.function.service.KieSessionService;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;
import com.fasterxml.jackson.databind.SerializationFeature;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.logging.Logger;

public class CheckTimeFunction {

    private static final ObjectMapper mapper = new ObjectMapper()
            .registerModule(new JavaTimeModule())
            .disable(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS);

    @FunctionName("CheckTime")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "checktime")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        Logger logger = context.getLogger();

        try {
            // ── 1. 解析 Request Body ──────────────────────────
            String body = request.getBody().orElse("{}");
            if (body.isBlank()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                              .body("Empty request body").build();
            }

            List<TimeCheckFact> facts;
            String trimmed = body.trim();
            if (trimmed.startsWith("[")) {
                facts = mapper.readValue(body,
                        mapper.getTypeFactory().constructCollectionType(
                                List.class, TimeCheckFact.class));
            } else {
                facts = new ArrayList<>();
                facts.add(mapper.readValue(body, TimeCheckFact.class));
            }

            logger.info("[CheckTime] 收到 " + facts.size() + " 筆資料，開始批次處理。");

            // ── 2. 逐筆執行規則引擎 ──────────────────────────
            List<TimeCheckResult> results = new ArrayList<>();

            for (TimeCheckFact fact : facts) {

                // 防禦性初始化（避免 null）
                if (fact.getLeaveApplications()    == null) fact.setLeaveApplications(new ArrayList<>());
                if (fact.getOvertimeApplications() == null) fact.setOvertimeApplications(new ArrayList<>());

                // ✅ 所有計算邏輯交給 DRL，Java 只負責 insert + fireAllRules
                KieSession session = KieSessionService.getTimeCheckSession();
                session.insert(fact);
                int fired = session.fireAllRules();
                session.dispose();

                logger.info("[CheckTime] " + fact.getEmployeeCode()
                    + " fired=" + fired
                    + " workH=" + String.format("%.2f", fact.getTotalWorkHours())
                    + " late=" + fact.getResult().getLateMinutes());

                TimeCheckResult result = fact.getResult();
                result.setEmployeeCode(fact.getEmployeeCode());
                result.setScheduleDate(fact.getScheduleStartTime());
                results.add(result);
            }

            // ── 3. 回傳結果 ──────────────────────────────────
            return request.createResponseBuilder(HttpStatus.OK)
                          .header("Content-Type", "application/json; charset=utf-8")
                          .body(mapper.writeValueAsString(results))
                          .build();

        } catch (Exception e) {
            logger.severe("CheckTime error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                          .body("Error: " + e.getMessage())
                          .build();
        }
    }
}
