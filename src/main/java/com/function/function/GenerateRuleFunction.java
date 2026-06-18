package com.function.function;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ObjectNode;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.util.Optional;
import java.util.logging.Logger;

public class GenerateRuleFunction {

    private static final ObjectMapper mapper = new ObjectMapper();

    // ✅ 從環境變數讀取 Google Gemini API Key
    private static final String GEMINI_API_KEY = System.getenv("GEMINI_API_KEY");
    private static final String GEMINI_API_URL  =
            "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent";

    // ✅ System Prompt：告訴 AI 它的角色與可用的工具清單
    private static final String SYSTEM_PROMPT =
        "你是一個 Drools DRL 規則產生器，專門為台灣勞基法打卡時間檢查系統生成規則。\n\n" +

        "【可用的 Fact 欄位 - TimeCheckFact】\n" +
        "- employeeCode: String（員工代號）\n" +
        "- scheduleStartTime: LocalDateTime（班表上班時間）\n" +
        "- scheduleEndTime: LocalDateTime（班表下班時間）\n" +
        "- clockInTime: LocalDateTime（原始上班打卡）\n" +
        "- clockOutTime: LocalDateTime（原始下班打卡）\n" +
        "- effectiveClockIn: LocalDateTime（有效上班時間，已含容錯修正）\n" +
        "- effectiveClockOut: LocalDateTime（有效下班時間，已含容錯修正）\n" +
        "- toleranceMinutes: int（容錯分鐘數，預設5）\n" +
        "- late: boolean（是否遲到）\n" +
        "- earlyLeave: boolean（是否早退）\n" +
        "- earlyArrival: boolean（是否早到）\n" +
        "- lateMinutesCache: int（遲到分鐘快取）\n" +
        "- totalWorkHours: double（總工時）\n" +
        "- overtimeHours: double（加班時數）\n" +
        "- toleranceResolved: boolean（前置處理是否完成）\n" +
        "- hoursCalculated: boolean（工時是否已計算）\n" +
        "- metadata: Map<String,Object>（彈性擴充欄位）\n\n" +

        "【可用的 Result 方法 - 透過 $f.getResult() 存取】\n" +
        "- setStatus(String)：可設定 NORMAL / LATE / EARLY_LEAVE / LATE_AND_EARLY / EARLY_ARRIVAL\n" +
        "- addViolation(String type, String message)\n" +
        "- addNote(String message)\n" +
        "- setLate(boolean)、setEarlyLeave(boolean)\n" +
        "- setLateMinutes(int)、setEarlyLeaveMinutes(int)\n\n" +

        "【可用的靜態工具方法 - import static com.function.util.RuleUtils.*】\n" +
        "- minutesBetween(LocalDateTime start, LocalDateTime end): long\n" +
        "- hoursBetween(LocalDateTime start, LocalDateTime end): double\n" +
        "- isBetween(LocalDateTime target, LocalDateTime start, LocalDateTime end): boolean\n" +
        "- haversineDistance(double lat1, double lon1, double lat2, double lon2): double\n" +
        "- getDouble(Map metadata, String key, double defaultValue): double\n" +
        "- getString(Map metadata, String key, String defaultValue): String\n" +
        "- getBoolean(Map metadata, String key, boolean defaultValue): boolean\n\n" +

        "【DRL 規則格式規範】\n" +
        "1. package 必須是：package rules.timecheck\n" +
        "2. 必要 import：\n" +
        "   import com.function.model.TimeCheckFact\n" +
        "   import com.function.model.TimeCheckResult\n" +
        "   import java.time.LocalDateTime\n" +
        "   import java.time.Duration\n" +
        "3. 若需要通用工具：import static com.function.util.RuleUtils.方法名稱\n" +
        "4. 若需要特殊計算邏輯，在規則前用 function 區塊定義\n" +
        "5. 新規則的 salience 請使用 1（在所有現有規則之後執行，避免衝突）\n" +
        "6. 必須加上 no-loop true 防止無限循環\n" +
        "7. 只輸出完整的 DRL 內容，不要加任何說明文字、不要用 markdown code block 包裹\n\n" +

        "【重要限制】\n" +
        "- 不要修改或重複現有的 Step1~Step13 規則\n" +
        "- 只新增額外的規則\n" +
        "- 新規則名稱請用英文，格式：\"Custom - 規則描述\"\n";

    // =========================================================
    // Azure Function 入口
    // =========================================================
    @FunctionName("GenerateRule")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "generaterule")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        Logger logger = context.getLogger();

        try {
            // ── 1. 解析請求 ───────────────────────────────────
            String body = request.getBody().orElse("{}");
            var json = mapper.readTree(body);

            String naturalLanguage = json.has("prompt")
                    ? json.get("prompt").asText() : "";
            String ruleSet = json.has("ruleSet")
                    ? json.get("ruleSet").asText() : "timecheck";
            boolean autoApply = json.has("autoApply")
                    && json.get("autoApply").asBoolean();

            if (naturalLanguage.isBlank()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .header("Content-Type", "application/json; charset=utf-8")
                        .body("{\"error\":\"prompt 欄位不可為空\"}")
                        .build();
            }

            logger.info("[GenerateRule] prompt=" + naturalLanguage
                    + " | ruleSet=" + ruleSet
                    + " | autoApply=" + autoApply);

            // ── 2. 呼叫 Gemini 生成 DRL ───────────────────────
            String drlContent = callGemini(naturalLanguage, logger);

            if (drlContent == null || drlContent.isBlank()) {
                return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                        .header("Content-Type", "application/json; charset=utf-8")
                        .body("{\"error\":\"AI 未能生成有效的 DRL 內容\"}")
                        .build();
            }

            // ── 3. 組裝回應 ───────────────────────────────────
            ObjectNode response = mapper.createObjectNode();
            response.put("ruleSet",       ruleSet);
            response.put("prompt",        naturalLanguage);
            response.put("generatedDrl",  drlContent);
            response.put("autoApply",     autoApply);

            // ── 4. autoApply=true → 直接編譯套用 ─────────────
            if (autoApply) {
                String applyResult = KieSessionService.updateDynamicRules(ruleSet, drlContent);
                response.put("applyResult", applyResult);
                response.put("status", "SUCCESS".equals(applyResult) ? "APPLIED" : "COMPILE_ERROR");
                logger.info("[GenerateRule] autoApply result: " + applyResult);
            } else {
                response.put("status", "PREVIEW");
                response.put("hint",
                    "確認 generatedDrl 內容後，POST 到 /api/updaterules 即可套用。" +
                    "或重新呼叫本 API 並設定 autoApply: true");
            }

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json; charset=utf-8")
                    .body(mapper.writeValueAsString(response))
                    .build();

        } catch (Exception e) {
            logger.severe("[GenerateRule] Error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .header("Content-Type", "application/json; charset=utf-8")
                    .body("{\"error\":\"" + e.getMessage() + "\"}")
                    .build();
        }
    }

    // =========================================================
    // 呼叫 Google Gemini API
    // =========================================================
    private String callGemini(String userPrompt, Logger logger) throws Exception {

        if (GEMINI_API_KEY == null || GEMINI_API_KEY.isBlank()) {
            throw new RuntimeException("環境變數 GEMINI_API_KEY 未設定");
        }

        // ── 組裝 Gemini 請求格式 ──────────────────────────────
        // Gemini 沒有獨立的 system role，將 System Prompt 合併進 user message
        ObjectNode requestBody = mapper.createObjectNode();

        var contents = requestBody.putArray("contents");
        var userContent = contents.addObject();
        userContent.put("role", "user");
        var parts = userContent.putArray("parts");
        var part = parts.addObject();
        part.put("text", SYSTEM_PROMPT + "\n\n【使用者需求】\n" + userPrompt);

        // 低溫度確保 DRL 輸出穩定、不隨機
        var generationConfig = requestBody.putObject("generationConfig");
        generationConfig.put("temperature", 0.2);
        generationConfig.put("maxOutputTokens", 2048);

        String requestJson = mapper.writeValueAsString(requestBody);
        logger.info("[GenerateRule] Calling Gemini API...");

        // ── 發送 HTTP 請求 ────────────────────────────────────
        HttpClient client = HttpClient.newHttpClient();
        HttpRequest httpRequest = HttpRequest.newBuilder()
                .uri(URI.create(GEMINI_API_URL + "?key=" + GEMINI_API_KEY))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(requestJson))
                .build();

        HttpResponse<String> httpResponse =
                client.send(httpRequest, HttpResponse.BodyHandlers.ofString());

        logger.info("[GenerateRule] Gemini status: " + httpResponse.statusCode());

        if (httpResponse.statusCode() != 200) {
            throw new RuntimeException("Gemini API error " +
                    httpResponse.statusCode() + ": " + httpResponse.body());
        }

        // ── 解析 Gemini 回應 ──────────────────────────────────
        var responseJson = mapper.readTree(httpResponse.body());
        String drl = responseJson
                .path("candidates").get(0)
                .path("content")
                .path("parts").get(0)
                .path("text")
                .asText();

        // 清理 AI 可能加上的 markdown 包裹（```drl ... ``` 或 ```java ... ```）
        drl = drl.replaceAll("(?s)```[a-zA-Z]*\\n?", "")
                 .replaceAll("```", "")
                 .trim();

        logger.info("[GenerateRule] DRL generated successfully, length=" + drl.length());
        return drl;
    }
}
