package com.function.function;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.UniversalFact;
import com.function.model.UniversalResult;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.util.Map;
import java.util.Optional;

public class EvaluateUniversalFunction {

    @FunctionName("EvaluateUniversal")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "evaluate/{moduleName}")
            HttpRequestMessage<Optional<String>> request,
            @BindingName("moduleName") String moduleName,
            final ExecutionContext context) {

        try {
            String body = request.getBody().orElse("{}");
            ObjectMapper mapper = new ObjectMapper();

            Map<String, Object> requestMap = mapper.readValue(body, new TypeReference<Map<String, Object>>() {});

            UniversalFact fact = new UniversalFact();
            if (requestMap.containsKey("companyId")) {
                fact.setCompanyId(String.valueOf(requestMap.remove("companyId")));
            }
            if (requestMap.containsKey("employeeId")) {
                fact.setEmployeeId(String.valueOf(requestMap.remove("employeeId")));
            }
            fact.setData(requestMap);

            UniversalResult result = new UniversalResult();

            // ★ 傳入 companyId：優先找公司客製化規則，找不到 fallback 通用規則
            String companyId = fact.getCompanyId();
            KieSession session = KieSessionService.getDynamicSession(moduleName, companyId);

            if (session == null) {
                return request.createResponseBuilder(HttpStatus.NOT_FOUND)
                        .body("無法找到對應模組的規則檔案: " + moduleName
                              + (companyId != null ? " (companyId: " + companyId + ")" : ""))
                        .build();
            }

            session.insert(fact);
            session.insert(result);
            int fired = session.fireAllRules();
            session.dispose();

            result.setValue("rulesFired", fired);
            if (companyId != null) result.setValue("companyId", companyId);

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json")
                    .body(mapper.writeValueAsString(result))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("執行通用規則異常: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("執行通用規則異常: " + e.getMessage()).build();
        }
    }
}