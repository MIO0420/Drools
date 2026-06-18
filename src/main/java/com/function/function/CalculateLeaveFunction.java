package com.function.function;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.EmployeeFact;
import com.function.model.LeaveFact;
import com.function.model.LeaveResult;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.math.BigDecimal;
import java.util.Optional;

public class CalculateLeaveFunction {

    private static final ObjectMapper mapper = new ObjectMapper();

    @FunctionName("CalculateLeave")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "calculateleave")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        long startTime = System.currentTimeMillis();

        try {
            String body = request.getBody().orElse("");
            if (body.isEmpty()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Empty request body")
                        .build();
            }

            JsonNode node = mapper.readTree(body);

            // ── 解析 EmployeeFact ──────────────────────────────────
            EmployeeFact emp = new EmployeeFact();
            if (node.has("employeeId"))      emp.setEmployeeId(node.get("employeeId").asText());
            if (node.has("companyId"))       emp.setCompanyId(node.get("companyId").asText());
            if (node.has("position"))        emp.setPosition(node.get("position").asText());
            if (node.has("identity"))        emp.setIdentity(node.get("identity").asText());
            if (node.has("tenureMonths"))    emp.setTenureMonths(node.get("tenureMonths").asInt());
            if (node.has("seniorityMonths")) emp.setSeniorityMonths(node.get("seniorityMonths").asInt());
            if (node.has("baseSalary"))      emp.setBaseSalary(new BigDecimal(node.get("baseSalary").asText()));

            // ── 解析 LeaveFact ─────────────────────────────────────
            LeaveFact leave = new LeaveFact();
            if (node.has("leaveTypeName"))       leave.setLeaveTypeName(node.get("leaveTypeName").asText());
            if (node.has("leaveDays"))           leave.setLeaveDays(new BigDecimal(node.get("leaveDays").asText()));
            if (node.has("leaveHours"))          leave.setLeaveHours(new BigDecimal(node.get("leaveHours").asText()));
            if (node.has("deductionRate"))       leave.setDeductionRate(new BigDecimal(node.get("deductionRate").asText()));
            if (node.has("usedDaysThisYear"))    leave.setUsedDaysThisYear(node.get("usedDaysThisYear").asInt());
            if (node.has("bereavementRelation")) leave.setBereavementRelation(node.get("bereavementRelation").asText());
            if (node.has("hospitalized"))        leave.setHospitalized(node.get("hospitalized").asBoolean());
            if (node.has("pregnancyWeeks"))      leave.setPregnancyWeeks(node.get("pregnancyWeeks").asInt());
            if (node.has("workingDaysInMonth"))  leave.setWorkingDaysInMonth(node.get("workingDaysInMonth").asInt());
                leave.setPublicHolidayDays(
                    node.has("publicHolidayDays") ? node.get("publicHolidayDays").asInt() : 0
                );
            // ── 建立 LeaveResult ───────────────────────────────────
            LeaveResult result = new LeaveResult();
            result.setEmployeeId(emp.getEmployeeId());
            result.setApproved(true); // 預設核准，由規則引擎決定是否否決

            // ── 執行規則引擎（依 companyId 載入對應規則集）─────────
            // ✅ 唯一改動：從 getLeaveSession() 改為 getLeaveSession(companyId)
            KieSession session = KieSessionService.getLeaveSession(emp.getCompanyId());
            session.insert(emp);
            session.insert(leave);
            session.insert(result);

            context.getLogger().info("Firing leave rules for: " + emp.getEmployeeId()
                    + ", companyId: " + emp.getCompanyId()
                    + ", leaveTypeName: " + leave.getLeaveTypeName());

            int firedCount = session.fireAllRules();
            session.dispose();

            long duration = System.currentTimeMillis() - startTime;
            context.getLogger().info("Rules fired: " + firedCount
                    + ", Approved: " + result.isApproved()
                    + ", Duration: " + duration + "ms");

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json")
                    .header("X-Execution-Time-Ms", String.valueOf(duration))
                    .header("X-Rules-Fired", String.valueOf(firedCount))
                    .body(mapper.writeValueAsString(result))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("CalculateLeaveFunction error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("伺服器內部錯誤: " + e.getMessage())
                    .build();
        }
    }
}
