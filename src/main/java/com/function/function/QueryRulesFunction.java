package com.function.function;

import com.function.service.DrlStorageService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.util.Optional;

public class QueryRulesFunction {

    private final DrlStorageService storageService = new DrlStorageService();

    @FunctionName("QueryRules")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.GET, HttpMethod.OPTIONS},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "rules/{*ruleSet}")
            HttpRequestMessage<Optional<String>> request,
            @BindingName("ruleSet") String ruleSet,
            final ExecutionContext context) {

        // ── OPTIONS preflight（瀏覽器 CORS 預檢請求）──────────────────────────
        if (request.getHttpMethod() == HttpMethod.OPTIONS) {
            return request.createResponseBuilder(HttpStatus.NO_CONTENT)
                    .header("Access-Control-Allow-Origin",  "*")
                    .header("Access-Control-Allow-Methods", "GET, OPTIONS")
                    .header("Access-Control-Allow-Headers", "Content-Type")
                    .build();
        }

        try {
            String existingDrl = storageService.downloadDrl(ruleSet);

            if (existingDrl == null || existingDrl.isBlank()) {
                return request.createResponseBuilder(HttpStatus.NOT_FOUND)
                        .header("Access-Control-Allow-Origin", "*")
                        .body("RuleSet not found or empty: " + ruleSet)
                        .build();
            }

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",                "text/plain; charset=UTF-8")
                    .header("Access-Control-Allow-Origin", "*")
                    .body(existingDrl)
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("[QueryRules] Exception: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .header("Access-Control-Allow-Origin", "*")
                    .body("Exception: " + e.getMessage())
                    .build();
        }
    }
}