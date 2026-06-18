package com.function.function;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.model.EmployeeFact;
import com.function.model.ProjectFact;
import com.function.model.EmployeeProjectFact;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.math.BigDecimal;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

public class BenchmarkLegacyFunction {
    private static final ObjectMapper mapper = new ObjectMapper();

    @FunctionName("BenchmarkLegacy")
    public HttpResponseMessage run(
            @HttpTrigger(name = "req", methods = {HttpMethod.POST}, route = "benchmark/legacy", authLevel = AuthorizationLevel.ANONYMOUS) HttpRequestMessage<Optional<String>> request,
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

            long startTime = System.currentTimeMillis();
            int matchCount = 0;

            // 傳統 O(N^3) 聚合運算迴圈 (這裡已經完全取代舊的迴圈)
            for (EmployeeFact emp : employees) {
                // 1. 判斷底薪是否小於 5 萬
                if (emp.getBaseSalary() != null && emp.getBaseSalary().compareTo(new BigDecimal("50000")) < 0) {
                    
                    BigDecimal totalBudget = BigDecimal.ZERO;
                    
                    // 2. 尋找該員工參與的所有關聯
                    for (EmployeeProjectFact ep : relations) {
                        if (ep.getEmployeeId() != null && ep.getEmployeeId().equals(emp.getEmployeeId())) {
                            
                            // 3. 尋找對應的專案預算並加總
                            for (ProjectFact p : projects) {
                                if (p.getProjectId() != null && p.getProjectId().equals(ep.getProjectId())) {
                                    if (p.getBudget() != null) {
                                        totalBudget = totalBudget.add(p.getBudget());
                                    }
                                }
                            }
                        }
                    }
                    
                    // 4. 判斷總預算是否大於 500 萬
                    if (totalBudget.compareTo(new BigDecimal("5000000")) > 0) {
                        matchCount++;
                    }
                }
            }

            long duration = System.currentTimeMillis() - startTime;
            return request.createResponseBuilder(HttpStatus.OK)
                    .body("Legacy 耗時: " + duration + " ms, 匹配數量: " + matchCount).build();
        } catch (Exception e) {
            context.getLogger().severe("Legacy 測試錯誤: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR).body("Error: " + e.getMessage()).build();
        }
    }
}