// 路徑：Graduate/src/main/java/com/function/function/CheckClockFunction.java
package com.function.function;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.DeserializationFeature;
import com.function.model.ClockFact;
import com.function.model.ClockResult;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.Optional;

public class CheckClockFunction {

    private static final ObjectMapper mapper = new ObjectMapper()
            .enable(DeserializationFeature.USE_BIG_DECIMAL_FOR_FLOATS);

    @FunctionName("CheckClock")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "checkclock")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        try {
            String       body = request.getBody().orElse("");
            ClockRequest req  = mapper.readValue(body, ClockRequest.class);

            // ── 1. 驗證必填欄位 ───────────────────────────────────────────────
            if (req.companyId == null || req.companyId.isBlank()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Error: Missing required field: companyId")
                        .build();
            }
            if (req.latitude == null || req.longitude == null) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Error: Missing required field: latitude / longitude")
                        .build();
            }
            if (req.companyLatitude == null || req.companyLongitude == null) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Error: Missing required field: companyLatitude / companyLongitude")
                        .build();
            }

            // ── 2. 後端計算距離（Haversine），完全不信任前端 ──────────────────
            double distanceM = haversine(
                req.latitude.doubleValue(),
                req.longitude.doubleValue(),
                req.companyLatitude.doubleValue(),
                req.companyLongitude.doubleValue()
            );

            context.getLogger().info(String.format(
                "[CheckClock] company=%s | employee=%s | type=%s | companyLoc=(%.6f,%.6f) | distance=%.4f m",
                req.companyId, req.employeeCode, req.recordType,
                req.companyLatitude.doubleValue(), req.companyLongitude.doubleValue(),
                distanceM
            ));

            // ── 3. 組裝 Fact ──────────────────────────────────────────────────
            ClockFact fact = new ClockFact();
            fact.setCompanyId(req.companyId);
            fact.setEmployeeCode(req.employeeCode);
            fact.setRecordType(req.recordType);
            fact.setLatitude(req.latitude);
            fact.setLongitude(req.longitude);
            fact.setDistanceToCompany(
                BigDecimal.valueOf(distanceM).setScale(4, RoundingMode.HALF_UP)
            );

            context.getLogger().info("[CheckClock] Fact: " + fact);

            // ── 4. 執行規則引擎 ───────────────────────────────────────────────
            ClockResult result  = new ClockResult();
            KieSession  session = KieSessionService.getClockSession();
            session.insert(fact);
            session.insert(result);
            session.fireAllRules();
            session.dispose();

            context.getLogger().info("[CheckClock] Result: " + mapper.writeValueAsString(result));

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json")
                    .body(mapper.writeValueAsString(result))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("[CheckClock] Error: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                    .body("Error: " + e.getMessage())
                    .build();
        }
    }

    // ── Haversine 公式 ────────────────────────────────────────────────────────
    private static double haversine(double lat1, double lon1,
                                    double lat2, double lon2) {
        final double R = 6_371_000.0;
        double dLat = Math.toRadians(lat2 - lat1);
        double dLon = Math.toRadians(lon2 - lon1);
        double a    = Math.sin(dLat / 2) * Math.sin(dLat / 2)
                    + Math.cos(Math.toRadians(lat1))
                    * Math.cos(Math.toRadians(lat2))
                    * Math.sin(dLon / 2) * Math.sin(dLon / 2);
        double c    = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return R * c;
    }

    // ── Inner DTO ─────────────────────────────────────────────────────────────
    public static class ClockRequest {
        public String     companyId;          // 公司識別碼
        public String     employeeCode;       // 員工編號
        public String     recordType;         // "clock_in" | "clock_out"
        public BigDecimal latitude;           // 打卡緯度
        public BigDecimal longitude;          // 打卡經度
        public BigDecimal companyLatitude;    // ✅ 公司辦公室緯度（由呼叫端傳入）
        public BigDecimal companyLongitude;   // ✅ 公司辦公室經度（由呼叫端傳入）
    }
}
