package com.function.function;

import com.microsoft.azure.functions.ExecutionContext;
import com.microsoft.azure.functions.HttpMethod;
import com.microsoft.azure.functions.HttpRequestMessage;
import com.microsoft.azure.functions.HttpResponseMessage;
import com.microsoft.azure.functions.HttpStatus;
import com.microsoft.azure.functions.annotation.AuthorizationLevel;
import com.microsoft.azure.functions.annotation.FunctionName;
import com.microsoft.azure.functions.annotation.HttpTrigger;

import java.util.Optional;

public class TriggerGCFunction {
    @FunctionName("triggerGC")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.GET, HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "gc") // 設定路由為 /api/gc
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        context.getLogger().info("Manual GC trigger requested.");

        // 建議 JVM 執行垃圾回收
        System.gc();
        Runtime.getRuntime().gc();

        return request.createResponseBuilder(HttpStatus.OK)
                .body("Memory cleanup (GC) triggered successfully.")
                .build();
    }
}