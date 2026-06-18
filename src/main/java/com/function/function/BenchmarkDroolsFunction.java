package com.function.function;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.EmployeeFact;
import com.function.model.ProjectFact;
import com.function.model.EmployeeProjectFact;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class BenchmarkDroolsFunction {
    private static final ObjectMapper mapper = new ObjectMapper();

    @FunctionName("BenchmarkDrools")
    public HttpResponseMessage run(
            @HttpTrigger(name = "req", methods = {HttpMethod.POST}, route = "benchmark/drools", authLevel = AuthorizationLevel.ANONYMOUS) HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {
        
        try {
            String body = request.getBody().orElse("{}");
            JsonNode root = mapper.readTree(body);
            
            // 解析傳入的資料陣列
            List<EmployeeFact> employees = mapper.convertValue(root.get("employees"), new TypeReference<List<EmployeeFact>>(){});
            List<ProjectFact> projects = mapper.convertValue(root.get("projects"), new TypeReference<List<ProjectFact>>(){});
            List<EmployeeProjectFact> relations = mapper.convertValue(root.get("relations"), new TypeReference<List<EmployeeProjectFact>>(){});

            if (employees == null) employees = new ArrayList<>();
            if (projects == null) projects = new ArrayList<>();
            if (relations == null) relations = new ArrayList<>();

            // 取得對應的 Drools Session
            KieSession session = KieSessionService.getDynamicSession("benchmark", null);
            if (session == null) {
                return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                        .body("Session 初始化失敗，請確認已上傳規則 (benchmark/benchmark.drl)").build();
            }

            long startTime = System.currentTimeMillis();

            try {
                // 將所有實體丟入工作記憶體
                for (EmployeeFact emp : employees) session.insert(emp);
                for (ProjectFact p : projects) session.insert(p);
                for (EmployeeProjectFact ep : relations) session.insert(ep);

                // 觸發規則網路匹配
                int matchCount = session.fireAllRules();

                long duration = System.currentTimeMillis() - startTime;
                return request.createResponseBuilder(HttpStatus.OK)
                        .body("Drools 耗時: " + duration + " ms, 觸發規則數: " + matchCount).build();
            } finally {
                session.dispose();
            }
        } catch (Exception e) {
            context.getLogger().severe("Drools 測試錯誤: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR).body("Error: " + e.getMessage()).build();
        }
    }
}