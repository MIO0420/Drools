package com.function.function;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.function.model.AllowanceFact;
import com.function.model.AttendanceFact;
import com.function.model.EmployeeFact;
import com.function.model.InsuranceFact;
import com.function.model.LeaveFact;
import com.function.model.OvertimeFact;
import com.function.model.PerformanceFact;
import com.function.model.ProjectFact;
import com.function.model.SalaryAdjustmentFact;
import com.function.model.SalaryResult;
import com.function.service.KieSessionService;
import com.microsoft.applicationinsights.TelemetryClient;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import org.kie.api.runtime.KieSession;
import org.kie.api.runtime.rule.FactHandle;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public class CalculateSalaryFunction {

    private static final ObjectMapper    mapper     = new ObjectMapper();
    private static final int             CHUNK_SIZE = 10000;
    private static final TelemetryClient telemetry  = new TelemetryClient();

    // ═══════════════════════════════════════════════════════════════════
    // Helper：上報記憶體
    // ═══════════════════════════════════════════════════════════════════
    private static long getUsedMemoryMB() {
        Runtime rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / 1_048_576L;
    }

    // ═══════════════════════════════════════════════════════════════════
    // HTTP Entry Point
    // ═══════════════════════════════════════════════════════════════════

    @FunctionName("CalculateSalary")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "calculatesalary")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        long startTime    = System.currentTimeMillis();
        long memBefore    = getUsedMemoryMB();
        int  totalCount   = 0;
        int  failureCount = 0;
        long minDuration  = Long.MAX_VALUE;
        long maxDuration  = 0L;

        // 🚀 初始化自訂計時指標物件
        ComputeMetrics metrics = new ComputeMetrics();

        try {
            String body = request.getBody().orElse("");
            if (body.isEmpty()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("Empty request body").build();
            }

            JsonNode root   = mapper.readTree(body);
            boolean isBatch = root.isArray();

            List<SalaryRequest> requests = new ArrayList<>();
            if (isBatch) {
                for (JsonNode node : root) {
                    requests.add(mapper.treeToValue(node, SalaryRequest.class));
                }
            } else {
                requests.add(mapper.treeToValue(root, SalaryRequest.class));
            }

            if (requests.isEmpty()) {
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                        .body("請求不可為空").build();
            }

            totalCount = requests.size();
            List<SalaryResultWrapper> results;

            if (isBatch) {
                context.getLogger().info(
                    "[CalculateSalary] Batch start: " + requests.size()
                    + " 筆，CHUNK_SIZE=" + CHUNK_SIZE);
                results = processBatchInChunks(requests, context, metrics);
            } else {
                results = new ArrayList<>();
                long singleStart = System.currentTimeMillis();
                try {
                    SalaryResult r = processSingleEmployee(requests.get(0), context, metrics);
                    long singleDuration = System.currentTimeMillis() - singleStart;
                    minDuration = singleDuration;
                    maxDuration = singleDuration;
                    results.add(new SalaryResultWrapper(requests.get(0).employeeId, r, null));
                } catch (Exception e) {
                    failureCount++;
                    results.add(new SalaryResultWrapper(
                        requests.get(0).employeeId, null, e.getMessage()));
                }
            }

            long duration = System.currentTimeMillis() - startTime;
            long memAfter = getUsedMemoryMB();

            // ── 批次模式統計 min/max/failure ──────────────────────
            if (isBatch) {
                for (SalaryResultWrapper w : results) {
                    if (w.error != null) failureCount++;
                }
                maxDuration = duration;
                minDuration = 0;
                context.getLogger().info(
                    "[CalculateSalary] Batch done: " + results.size()
                    + " 筆，耗時 " + duration + " ms");
            }

            // ── 上報 App Insights 指標 ────────────────────────────
            int    successCount = totalCount - failureCount;
            double successRate  = totalCount > 0
                ? (successCount * 100.0 / totalCount) : 100.0;

            telemetry.trackMetric("CalculateSalary Count",         totalCount);
            telemetry.trackMetric("CalculateSalary Successes",      successCount);
            telemetry.trackMetric("CalculateSalary Failures",       failureCount);
            telemetry.trackMetric("CalculateSalary SuccessRate",    successRate);
            telemetry.trackMetric("CalculateSalary AvgDurationMs",  (double) duration / Math.max(totalCount, 1));
            telemetry.trackMetric("CalculateSalary MaxDurationMs",  (double) maxDuration);
            telemetry.trackMetric("CalculateSalary MinDurationMs",  minDuration == Long.MAX_VALUE ? 0 : (double) minDuration);
            telemetry.trackMetric("CalculateSalary MemoryUsedMB",   (double) memAfter);
            telemetry.trackMetric("CalculateSalary MemoryDeltaMB",  (double)(memAfter - memBefore));

            if (!isBatch) {
                SalaryResultWrapper w = results.get(0);
                if (w.error != null) {
                    return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                            .body(w.error).build();
                }
                return request.createResponseBuilder(HttpStatus.OK)
                        .header("Content-Type",        "application/json")
                        .header("X-Execution-Time-Ms", String.valueOf(duration))
                        .body(mapper.writeValueAsString(w.result))
                        .build();
            }

            // 🚀 從自訂物件中提取累加的純規則引擎匹配耗時
            long pureComputeTime = metrics.pureComputeTime;

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",              "application/json")
                    .header("X-Execution-Time-Ms",       String.valueOf(duration))
                    .header("X-Batch-Count",             String.valueOf(results.size()))
                    .header("X-Drools-Pure-Compute-Ms",  String.valueOf(pureComputeTime)) // 回傳純引擎匹配耗時
                    .body(mapper.writeValueAsString(results))
                    .build();

        } catch (IllegalArgumentException e) {
            failureCount = totalCount > 0 ? totalCount : 1;
            telemetry.trackMetric("CalculateSalary Failures",    (double) failureCount);
            telemetry.trackMetric("CalculateSalary SuccessRate", 0.0);
            context.getLogger().warning("[CalculateSalary] 參數錯誤: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.BAD_REQUEST)
                          .body("參數錯誤: " + e.getMessage())
                          .build();
        } catch (Exception e) {
            failureCount = totalCount > 0 ? totalCount : 1;
            telemetry.trackMetric("CalculateSalary Failures",    (double) failureCount);
            telemetry.trackMetric("CalculateSalary SuccessRate", 0.0);
            context.getLogger().severe("[CalculateSalary] Exception: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                          .body("伺服器內部錯誤: " + e.getMessage())
                          .build();
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // 批次主控：切 Chunk
    // ═══════════════════════════════════════════════════════════════════

    private List<SalaryResultWrapper> processBatchInChunks(
            List<SalaryRequest> requests,
            ExecutionContext context,
            ComputeMetrics metrics) { // 🚀 傳入計時物件

        List<SalaryResultWrapper> allResults = new ArrayList<>(requests.size());
        int total = requests.size();

        for (int from = 0; from < total; from += CHUNK_SIZE) {
            int  to = Math.min(from + CHUNK_SIZE, total);
            long t0 = System.currentTimeMillis();

            context.getLogger().info(
                "[CalculateSalary] Chunk " + from + "~" + to + " / " + total + " 開始");

            // 🚀 直接將 metrics 物件代入，由 processChunk 進行時間累加
            allResults.addAll(processChunk(requests.subList(from, to), context, metrics));

            context.getLogger().info(
                "[CalculateSalary] Chunk " + from + "~" + to
                + " 完成，耗時 " + (System.currentTimeMillis() - t0) + " ms");
        }

        return allResults;
    }

    // ═══════════════════════════════════════════════════════════════════
    // 單一 Chunk：真正記憶體全量批次（True Batching）最佳化
    // ═══════════════════════════════════════════════════════════════════

    private List<SalaryResultWrapper> processChunk(
            List<SalaryRequest> requests,
            ExecutionContext context,
            ComputeMetrics metrics) { // 🚀 傳入計時物件

        List<SalaryResult> resultList = new ArrayList<>(requests.size());
        for (SalaryRequest req : requests) {
            SalaryResult r = new SalaryResult();
            r.setEmployeeId(req.employeeId);
            r.setBaseSalary(req.baseSalary != null ? req.baseSalary : BigDecimal.ZERO);
            resultList.add(r);
        }

        Map<String, List<Integer>> companyToIndices = new LinkedHashMap<>();
        for (int i = 0; i < requests.size(); i++) {
            String cid = requests.get(i).companyId;
            String key = (cid != null && !cid.isBlank()) ? cid : "default";
            companyToIndices.computeIfAbsent(key, k -> new ArrayList<>()).add(i);
        }

        for (Map.Entry<String, List<Integer>> entry : companyToIndices.entrySet()) {
            String        companyId         = entry.getKey();
            List<Integer> indices           = entry.getValue();
            String        resolvedCompanyId = "default".equals(companyId) ? null : companyId;

            context.getLogger().info(
                "[CalculateSalary] companyId=" + companyId
                + " 員工數=" + indices.size()
                + " sessionKey=" + (resolvedCompanyId != null
                    ? "salary_company_" + resolvedCompanyId : "salary（通用）"));

            long groupFireTime = 0;
            int  groupFired    = 0;

            // ★ 修正：每個員工使用獨立 KieSession，避免 activation-group 在
            //   共用 session 下「整個 session 只觸發一次」導致跨員工規則被吃掉。
            //   KieContainer（Rete 網路）仍由 KieSessionService 快取重用，
            //   故規則編譯成果不會重建，保留規則引擎效能優勢。
            for (int i : indices) {
                SalaryRequest req    = requests.get(i);
                SalaryResult  result = resultList.get(i);

                if (req.baseSalary == null
                        || req.baseSalary.compareTo(BigDecimal.ZERO) <= 0) {
                    result.setMessage("ERROR: baseSalary 必須大於 0");
                    continue;
                }

                KieSession session = KieSessionService.getSalarySession(resolvedCompanyId);
                try {
                    InsuranceFact insurance = buildInsuranceFact(req);

                    session.insert(buildEmployeeFact(req, resolvedCompanyId));
                    session.insert(insurance);
                    session.insert(result);

                    // ── 請假時數預先聚合 ──────────────────────────
                    if (req.leaves != null) {
                        Map<String, LeaveRequest> mergedLeaves = new LinkedHashMap<>();
                        for (LeaveRequest lr : req.leaves) {
                            if (lr.leaveTypeName == null || lr.leaveTypeName.isBlank()) continue;
                            mergedLeaves.merge(lr.leaveTypeName, lr, (existing, newLr) -> {
                                existing.leaveHours = (existing.leaveHours != null
                                    ? existing.leaveHours : BigDecimal.ZERO)
                                    .add(newLr.leaveHours != null ? newLr.leaveHours : BigDecimal.ZERO);
                                existing.leaveDays = (existing.leaveDays != null
                                    ? existing.leaveDays : BigDecimal.ZERO)
                                    .add(newLr.leaveDays != null ? newLr.leaveDays : BigDecimal.ZERO);
                                return existing;
                            });
                        }
                        for (LeaveRequest lr : mergedLeaves.values()) {
                            session.insert(
                                buildLeaveFact(lr, req.employeeId, insurance.getWorkingDaysInMonth()));
                        }
                    }

                    // ── 加班時數預先聚合 ──────────────────────────
                    if (req.overtimes != null) {
                        Map<String, OvertimeRequest> mergedOvertimes = new LinkedHashMap<>();
                        for (OvertimeRequest or : req.overtimes) {
                            if (or.overtimeType == null || or.overtimeType.isBlank()) continue;
                            mergedOvertimes.merge(or.overtimeType, or, (existing, newOr) -> {
                                existing.overtimeHours = (existing.overtimeHours != null
                                    ? existing.overtimeHours : BigDecimal.ZERO)
                                    .add(newOr.overtimeHours != null ? newOr.overtimeHours : BigDecimal.ZERO);
                                return existing;
                            });
                        }
                        for (OvertimeRequest or : mergedOvertimes.values()) {
                            session.insert(buildOvertimeFact(or, req.employeeId));
                        }
                    }

                    // ── 出勤紀錄 ──────────────────────────────────
                    if (req.attendances != null) {
                        for (AttendanceRequest ar : req.attendances) {
                            session.insert(
                                buildAttendanceFact(ar, req.employeeId, resolvedCompanyId));
                        }
                    }

                    // ── 績效紀錄 ──────────────────────────────────
                    if (req.performances != null) {
                        for (PerformanceRequest pr : req.performances) {
                            session.insert(
                                buildPerformanceFact(pr, req.employeeId, resolvedCompanyId));
                        }
                    }

                    // ── 申請津貼 ──────────────────────────────────
                    if (req.allowances != null) {
                        for (AllowanceRequest alr : req.allowances) {
                            session.insert(
                                buildAllowanceFact(alr, req.employeeId, resolvedCompanyId));
                        }
                    }

                    // ── 專案獎金 ──────────────────────────────────
                    if (req.projects != null) {
                        for (ProjectRequest pjr : req.projects) {
                            session.insert(
                                buildProjectFact(pjr, req.employeeId, resolvedCompanyId));
                        }
                    }

                    // ── 薪資調整 ──────────────────────────────────
                    if (req.salaryAdjustments != null) {
                        for (SalaryAdjustmentRequest sar : req.salaryAdjustments) {
                            session.insert(
                                buildSalaryAdjustmentFact(sar, req.employeeId, resolvedCompanyId));
                        }
                    }

                    // 🚀 【精準計時】核心運算（單一員工）
                    long fireStart = System.currentTimeMillis();
                    int firedCount = session.fireAllRules();
                    groupFireTime += (System.currentTimeMillis() - fireStart);
                    groupFired    += firedCount;

                    // ── 結算 ──────────────────────────────────────
                    result.setFinalSalary(
                        result.getBaseSalary()
                            .subtract(result.getLeaveDeduction())
                            .add(result.getOvertimeBonus())
                            .add(result.getSeniorityBonus())
                            .add(result.getCompanyBonus())
                            .setScale(2, RoundingMode.HALF_UP)
                    );

                } catch (Exception e) {
                    context.getLogger().severe(
                        "[CalculateSalary] employeeId=" + req.employeeId
                        + " error: " + e.getMessage());
                    if (result.getFinalSalary() == null
                            || result.getFinalSalary().compareTo(BigDecimal.ZERO) == 0) {
                        result.setMessage("EMP_ERROR: " + e.getMessage());
                    }
                } finally {
                    session.dispose();
                }
            }

            metrics.pureComputeTime += groupFireTime;

            context.getLogger().info(
                "[CalculateSalary] companyId=" + companyId
                + " 純規則引擎運算耗時(累計): " + groupFireTime
                + " ms, 觸發規則數(累計): " + groupFired);
            context.getLogger().info(
                "[CalculateSalary] companyId=" + companyId
                + " 全部 " + indices.size() + " 筆處理完畢");
        }

        List<SalaryResultWrapper> wrappers = new ArrayList<>(requests.size());
        for (int i = 0; i < requests.size(); i++) {
            wrappers.add(new SalaryResultWrapper(
                requests.get(i).employeeId, resultList.get(i), null));
        }
        return wrappers;
    }

    // ═══════════════════════════════════════════════════════════════════
    // 單筆模式
    // ═══════════════════════════════════════════════════════════════════

    private SalaryResult processSingleEmployee(SalaryRequest req, ExecutionContext context, ComputeMetrics metrics)
            throws Exception {

        if (req.baseSalary == null || req.baseSalary.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException(
                "baseSalary 必須大於 0 (員工: " + req.employeeId + ")");
        }

        String resolvedCompanyId = (req.companyId != null && !req.companyId.isBlank())
                ? req.companyId : null;

        context.getLogger().info(
            "[CalculateSalary] Single Employee=" + req.employeeId
            + " baseSalary="      + req.baseSalary
            + " tenureMonths="    + req.tenureMonths
            + " seniorityMonths=" + (req.seniorityMonths > 0 ? req.seniorityMonths : req.tenureMonths)
            + " companyId="       + req.companyId
            + " 使用規則: "       + (resolvedCompanyId != null
                ? "salary_company_" + resolvedCompanyId : "salary（通用）"));

        InsuranceFact insurance = buildInsuranceFact(req);

        SalaryResult result = new SalaryResult();
        result.setEmployeeId(req.employeeId);
        result.setBaseSalary(req.baseSalary);

        KieSession session = KieSessionService.getSalarySession(resolvedCompanyId);

        try {
            List<FactHandle> handles = new ArrayList<>();

            handles.add(session.insert(buildEmployeeFact(req, resolvedCompanyId)));
            handles.add(session.insert(insurance));
            handles.add(session.insert(result));

            // ── 請假時數預先聚合 ──────────────────────────────────
            if (req.leaves != null) {
                Map<String, LeaveRequest> mergedLeaves = new LinkedHashMap<>();
                for (LeaveRequest lr : req.leaves) {
                    if (lr.leaveTypeName == null || lr.leaveTypeName.isBlank()) continue;
                    mergedLeaves.merge(lr.leaveTypeName, lr, (existing, newLr) -> {
                        existing.leaveHours = (existing.leaveHours != null
                            ? existing.leaveHours : BigDecimal.ZERO)
                            .add(newLr.leaveHours != null ? newLr.leaveHours : BigDecimal.ZERO);
                        existing.leaveDays = (existing.leaveDays != null
                            ? existing.leaveDays : BigDecimal.ZERO)
                            .add(newLr.leaveDays != null ? newLr.leaveDays : BigDecimal.ZERO);
                        return existing;
                    });
                }
                for (LeaveRequest lr : mergedLeaves.values()) {
                    handles.add(session.insert(
                        buildLeaveFact(lr, req.employeeId, insurance.getWorkingDaysInMonth())));
                }
            }

            // ── 加班時數預先聚合 ──────────────────────────────────
            if (req.overtimes != null) {
                Map<String, OvertimeRequest> mergedOvertimes = new LinkedHashMap<>();
                for (OvertimeRequest or : req.overtimes) {
                    if (or.overtimeType == null || or.overtimeType.isBlank()) continue;
                    mergedOvertimes.merge(or.overtimeType, or, (existing, newOr) -> {
                        existing.overtimeHours = (existing.overtimeHours != null
                            ? existing.overtimeHours : BigDecimal.ZERO)
                            .add(newOr.overtimeHours != null ? newOr.overtimeHours : BigDecimal.ZERO);
                        return existing;
                    });
                }
                for (OvertimeRequest or : mergedOvertimes.values()) {
                    handles.add(session.insert(buildOvertimeFact(or, req.employeeId)));
                }
            }

            // ── 出勤紀錄 ──────────────────────────────────────────
            if (req.attendances != null) {
                for (AttendanceRequest ar : req.attendances) {
                    handles.add(session.insert(
                        buildAttendanceFact(ar, req.employeeId, resolvedCompanyId)));
                }
            }

            // ── 績效紀錄 ──────────────────────────────────────────
            if (req.performances != null) {
                for (PerformanceRequest pr : req.performances) {
                    handles.add(session.insert(
                        buildPerformanceFact(pr, req.employeeId, resolvedCompanyId)));
                }
            }

            // ── 申請津貼 ──────────────────────────────────────────
            if (req.allowances != null) {
                for (AllowanceRequest alr : req.allowances) {
                    handles.add(session.insert(
                        buildAllowanceFact(alr, req.employeeId, resolvedCompanyId)));
                }
            }

            // ── 專案獎金 ──────────────────────────────────────────
            if (req.projects != null) {
                for (ProjectRequest pjr : req.projects) {
                    handles.add(session.insert(
                        buildProjectFact(pjr, req.employeeId, resolvedCompanyId)));
                }
            }

            // ── 薪資調整 ──────────────────────────────────────────
            if (req.salaryAdjustments != null) {
                for (SalaryAdjustmentRequest sar : req.salaryAdjustments) {
                    handles.add(session.insert(
                        buildSalaryAdjustmentFact(sar, req.employeeId, resolvedCompanyId)));
                }
            }

            // 🚀 單筆模式計時
            long fireStart = System.currentTimeMillis();
            int firedCount = session.fireAllRules();
            long fireDuration = System.currentTimeMillis() - fireStart;
            metrics.pureComputeTime = fireDuration;

            // ── 強制再結算 ────────────────────────────────────────
            result.setFinalSalary(
                result.getBaseSalary()
                    .subtract(result.getLeaveDeduction())
                    .add(result.getOvertimeBonus())
                    .add(result.getSeniorityBonus())
                    .add(result.getCompanyBonus())
                    .setScale(2, RoundingMode.HALF_UP)
            );

            context.getLogger().info(
                "[CalculateSalary] Rules fired="   + firedCount
                + " finalSalary="                  + result.getFinalSalary()
                + " leaveDeduction="               + result.getLeaveDeduction()
                + " overtimeBonus="                + result.getOvertimeBonus()
                + " fullAttendanceExempt="         + result.isFullAttendancePenaltyExempt());

            for (FactHandle h : handles) {
                session.delete(h);
            }

        } finally {
            session.dispose();
        }

        return result;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Fact 建構 Helper
    // ═══════════════════════════════════════════════════════════════════

    private EmployeeFact buildEmployeeFact(SalaryRequest req, String resolvedCompanyId) {
        EmployeeFact e = new EmployeeFact();
        e.setEmployeeId(req.employeeId);
        e.setCompanyId(resolvedCompanyId);
        e.setBaseSalary(req.baseSalary);
        e.setDailySalary(
            req.baseSalary.divide(new BigDecimal("30"), 10, RoundingMode.HALF_UP));
        // ★ 帶入公司政策日薪除數（工作日數）；未送（≤0）時 EmployeeFact 預設 30
        if (req.workingDaysInMonth > 0) {
            e.setWorkingDaysInMonth(req.workingDaysInMonth);
        }
        e.setPosition(req.position);
        e.setDepartment(req.department);
        e.setIdentity(req.identity);
        e.setTenureMonths(req.tenureMonths);
        e.setSeniorityMonths(
            req.seniorityMonths > 0 ? req.seniorityMonths : req.tenureMonths);
        e.setAbsentDays(req.absentDays != null ? req.absentDays : BigDecimal.ZERO);
        return e;
    }

    private InsuranceFact buildInsuranceFact(SalaryRequest req) {
        InsuranceFact ins = new InsuranceFact();
        ins.setInsuredSalary(req.laborInsuredSalary);
        ins.setLaborInsuredSalary(req.laborInsuredSalary);
        ins.setHealthInsuredSalary(req.healthInsuredSalary);
        ins.setPensionSalary(req.pensionSalary);
        ins.setWorkingDaysInMonth(
            req.workingDaysInMonth > 0 ? req.workingDaysInMonth : 22);
        ins.setVoluntaryPensionRate(
            req.voluntaryPensionRate != null ? req.voluntaryPensionRate : BigDecimal.ZERO);
        return ins;
    }

    private LeaveFact buildLeaveFact(LeaveRequest lr, String employeeId, int workingDays) {
        LeaveFact leave = new LeaveFact();
        leave.setLeaveTypeName(lr.leaveTypeName);
        leave.setLeaveDays(lr.leaveDays != null ? lr.leaveDays : BigDecimal.ZERO);
        leave.setLeaveHours(lr.leaveHours != null ? lr.leaveHours : BigDecimal.ZERO);
        leave.setDeductionRate(
            lr.deductionRate != null ? lr.deductionRate : BigDecimal.ZERO);
        leave.setAffectFullAttendance(lr.affectFullAttendance);
        leave.setWorkingDaysInMonth(workingDays);
        leave.setUsedDaysThisYear(lr.usedDaysThisYear);
        if (lr.bereavementRelation != null && !lr.bereavementRelation.isBlank()) {
            leave.setBereavementRelation(lr.bereavementRelation);
        }
        leave.setHospitalized(lr.hospitalized);
        leave.setPregnancyWeeks(lr.pregnancyWeeks);
        leave.setEmployeeId(employeeId);
        return leave;
    }

    private OvertimeFact buildOvertimeFact(OvertimeRequest or, String employeeId) {
        OvertimeFact ot = new OvertimeFact();
        ot.setOvertimeType(or.overtimeType);
        ot.setOvertimeHours(
            or.overtimeHours != null ? or.overtimeHours : BigDecimal.ZERO);
        ot.setEmployeeId(employeeId);
        return ot;
    }

    private AttendanceFact buildAttendanceFact(
            AttendanceRequest ar, String employeeId, String companyId) {
        AttendanceFact att = new AttendanceFact();
        att.setEmployeeId(employeeId);
        att.setCompanyId(companyId);
        att.setHasFullAttendance(ar.hasFullAttendance);
        att.setLateCount(ar.lateCount);
        att.setLateMinutesTotal(ar.lateMinutesTotal);
        att.setEarlyLeaveCount(ar.earlyLeaveCount);
        att.setEarlyLeaveMinutesTotal(ar.earlyLeaveMinutesTotal);
        att.setWorkDays(ar.workDays);
        att.setRequiredWorkDays(ar.requiredWorkDays);
        return att;
    }

    private PerformanceFact buildPerformanceFact(
            PerformanceRequest pr, String employeeId, String companyId) {
        PerformanceFact pf = new PerformanceFact();
        pf.setEmployeeId(employeeId);
        pf.setCompanyId(companyId != null ? companyId
            : (pr.companyId != null ? pr.companyId : ""));
        pf.setGrade(pr.grade);
        pf.setScore(pr.score);
        pf.setConfirmed(pr.confirmed);
        return pf;
    }

    private AllowanceFact buildAllowanceFact(
            AllowanceRequest alr, String employeeId, String companyId) {
        AllowanceFact all = new AllowanceFact();
        all.setEmployeeId(employeeId);
        all.setCompanyId(companyId != null ? companyId
            : (alr.companyId != null ? alr.companyId : ""));
        all.setAllowanceType(alr.allowanceType);
        all.setAmount(alr.amount != null ? alr.amount : BigDecimal.ZERO);
        all.setApproved(alr.approved);
        all.setApprovedBy(alr.approvedBy);
        return all;
    }

    private ProjectFact buildProjectFact(
            ProjectRequest pjr, String employeeId, String companyId) {
        ProjectFact pj = new ProjectFact();
        pj.setEmployeeId(employeeId);
        pj.setCompanyId(companyId != null ? companyId
            : (pjr.companyId != null ? pjr.companyId : ""));
        pj.setProjectId(pjr.projectId);
        pj.setRole(pjr.role);
        pj.setBonusRate(pjr.bonusRate);
        pj.setCompleted(pjr.completed);
        return pj;
    }

    private SalaryAdjustmentFact buildSalaryAdjustmentFact(
            SalaryAdjustmentRequest sar, String employeeId, String companyId) {
        SalaryAdjustmentFact adj = new SalaryAdjustmentFact();
        adj.setEmployeeId(employeeId);
        adj.setCompanyId(companyId != null ? companyId
            : (sar.companyId != null ? sar.companyId : ""));
        adj.setAdjustmentType(sar.adjustmentType);
        adj.setAmount(sar.amount != null ? sar.amount : BigDecimal.ZERO);
        adj.setApplied(sar.applied);
        adj.setReason(sar.reason);
        adj.setApprovedBy(sar.approvedBy);
        return adj;
    }

    // ═══════════════════════════════════════════════════════════════════
    // Inner Classes
    // ═══════════════════════════════════════════════════════════════════

    // 🚀 新增的計時指標 Context 類別
    public static class ComputeMetrics {
        public long pureComputeTime = 0L;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SalaryResultWrapper {
        public String       employeeId;
        public SalaryResult result;
        public String       error;

        public SalaryResultWrapper(String employeeId, SalaryResult result, String error) {
            this.employeeId = employeeId;
            this.result     = result;
            this.error      = error;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SalaryRequest {
        public String     companyId;
        public String     employeeId;
        public String     position;
        public String     identity;
        public String     department;
        public int        tenureMonths;
        public int        seniorityMonths;
        public BigDecimal baseSalary;
        public BigDecimal absentDays;
        public int        laborInsuredSalary;
        public int        healthInsuredSalary;
        public int        pensionSalary;
        public BigDecimal voluntaryPensionRate;
        public int        workingDaysInMonth;

        @JsonAlias({"leaves", "leaveFacts"})
        public List<LeaveRequest> leaves;

        @JsonAlias({"overtimes", "overtimeFacts"})
        public List<OvertimeRequest> overtimes;

        @JsonAlias({"attendances", "attendanceFacts"})
        public List<AttendanceRequest> attendances;

        @JsonAlias({"performances", "performanceFacts"})
        public List<PerformanceRequest> performances;

        @JsonAlias({"allowances", "allowanceFacts"})
        public List<AllowanceRequest> allowances;

        @JsonAlias({"projects", "projectFacts"})
        public List<ProjectRequest> projects;

        @JsonAlias({"salaryAdjustments", "salaryAdjustmentFacts"})
        public List<SalaryAdjustmentRequest> salaryAdjustments;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class LeaveRequest {
        @JsonAlias({"leaveType", "leaveTypeName"})
        public String     leaveTypeName;
        public BigDecimal leaveDays;
        public BigDecimal leaveHours;
        public BigDecimal deductionRate;
        public boolean    affectFullAttendance;
        public int        usedDaysThisYear;
        public String     bereavementRelation;
        public boolean    hospitalized;
        public int        pregnancyWeeks;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class OvertimeRequest {
        public String     overtimeType;
        public BigDecimal overtimeHours;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class AttendanceRequest {
        public String  employeeId;
        public boolean hasFullAttendance;
        public int     lateCount;
        public int     lateMinutesTotal;
        public int     earlyLeaveCount;
        public int     earlyLeaveMinutesTotal;
        public int     workDays;
        public int     requiredWorkDays;
        public boolean perfectAttendance;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class PerformanceRequest {
        public String     employeeId;
        public String     companyId;
        public String     grade;
        public BigDecimal score;
        public boolean    confirmed;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class AllowanceRequest {
        public String     employeeId;
        public String     companyId;
        public String     allowanceType;
        public BigDecimal amount;
        public boolean    approved;
        public String     approvedBy;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class ProjectRequest {
        public String     employeeId;
        public String     companyId;
        public String     projectId;
        public String     role;
        public BigDecimal bonusRate;
        public boolean    completed;
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    public static class SalaryAdjustmentRequest {
        public String     employeeId;
        public String     companyId;
        public String     adjustmentType;
        public BigDecimal amount;
        public boolean    applied;
        public String     reason;
        public String     approvedBy;
    }
}