

package com.function.function;

import com.fasterxml.jackson.annotation.JsonAlias;
import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.function.SalaryRules.Company25Rule;
import com.function.function.SalaryRules.Company94Rule;
import com.function.function.SalaryRules.Company95Rule;
import com.function.function.SalaryRules.CompanySalaryRule;
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
import com.function.util.RuleUtils;
import com.microsoft.applicationinsights.TelemetryClient;
import com.microsoft.azure.functions.ExecutionContext;
import com.microsoft.azure.functions.HttpMethod;
import com.microsoft.azure.functions.HttpRequestMessage;
import com.microsoft.azure.functions.HttpResponseMessage;
import com.microsoft.azure.functions.HttpStatus;
import com.microsoft.azure.functions.annotation.AuthorizationLevel;
import com.microsoft.azure.functions.annotation.FunctionName;
import com.microsoft.azure.functions.annotation.HttpTrigger;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;

public class CalculateSalaryLegacyFunction {

    private static final ObjectMapper    mapper    = new ObjectMapper();
    private static final TelemetryClient telemetry = new TelemetryClient();

    private static long getUsedMemoryMB() {
        Runtime rt = Runtime.getRuntime();
        return (rt.totalMemory() - rt.freeMemory()) / 1_048_576L;
    }

    private static final ConcurrentHashMap<String, Optional<CompanySalaryRule>> RULE_CACHE =
        new ConcurrentHashMap<>();

    private static CompanySalaryRule getCompanyRule(String companyId, ExecutionContext context) {
        if (companyId == null || companyId.isBlank()) {
            return null;
        }

        return RULE_CACHE.computeIfAbsent(companyId, id -> {
            String className = "com.function.function.SalaryRules.Company" + id + "Rule";
            try {
                Class<?> clazz = Class.forName(className);
                CompanySalaryRule rule = (CompanySalaryRule) clazz.getDeclaredConstructor().newInstance();
                context.getLogger().info("[RuleLoader] 成功載入客製化規則: " + className);
                return Optional.of(rule);
            } catch (ClassNotFoundException e) {
                return Optional.empty();
            } catch (Exception e) {
                context.getLogger().warning("[RuleLoader] 實例化規則失敗: " + className + ", 錯誤: " + e.getMessage());
                return Optional.empty();
            }
        }).orElse(null);
    }

    public static class BatchResultWrapper {
        public String       employeeId;
        public SalaryResult result;
        public String       error;

        public BatchResultWrapper(String employeeId, SalaryResult result, String error) {
            this.employeeId = employeeId;
            this.result     = result;
            this.error      = error;
        }
    }

    @JsonIgnoreProperties(ignoreUnknown = true)
    private static class SalaryRequestWrapper {

        public EmployeeFact               employee;
        public List<LeaveFact>            leaveFacts;
        public List<OvertimeFact>         overtimeFacts;
        public List<PerformanceFact>      performanceFacts;
        public List<AttendanceFact>       attendanceFacts;
        public List<AllowanceFact>        allowanceFacts;
        public List<ProjectFact>          projectFacts;
        public List<SalaryAdjustmentFact> salaryAdjustmentFacts;

        public String     companyId;
        public String     employeeId;
        public BigDecimal baseSalary;
        public BigDecimal absentDays;
        public Integer    tenureMonths;
        public Integer    seniorityMonths;
        public Integer    workingDaysInMonth;
        public Integer    laborInsuredSalary;
        public Integer    healthInsuredSalary;
        public Integer    pensionSalary;
        public BigDecimal voluntaryPensionRate;
        public String     position;
        public String     department;
        public String     identity;

        @JsonAlias("leaves")
        public List<LeaveFact>            leaves;

        @JsonAlias("overtimes")
        public List<OvertimeFact>         overtimes;

        @JsonAlias("performances")
        public List<PerformanceFact>      performances;

        @JsonAlias("attendances")
        public List<AttendanceFact>       attendances;

        @JsonAlias("allowances")
        public List<AllowanceFact>        allowances;

        @JsonAlias("projects")
        public List<ProjectFact>          projects;

        @JsonAlias("salaryAdjustments")
        public List<SalaryAdjustmentFact> salaryAdjustments;

        public EmployeeFact resolveEmployee() {
            if (employee != null) {
                if (employee.getCompanyId() == null || employee.getCompanyId().isBlank()) {
                    employee.setCompanyId(this.companyId);
                }
                if (employee.getEmployeeId() == null || employee.getEmployeeId().isBlank()) {
                    employee.setEmployeeId(this.employeeId);
                }
                if (employee.getBaseSalary() == null || employee.getBaseSalary().compareTo(BigDecimal.ZERO) == 0) {
                    employee.setBaseSalary(this.baseSalary);
                }
                if (this.absentDays != null) employee.setAbsentDays(this.absentDays);
                if ((employee.getIdentity() == null || employee.getIdentity().isBlank())
                        && this.identity != null) {
                    employee.setIdentity(this.identity);
                }
                return employee;
            }
            EmployeeFact emp = new EmployeeFact();
            emp.setCompanyId(companyId);
            emp.setEmployeeId(employeeId);
            emp.setBaseSalary(baseSalary);
            if (tenureMonths       != null) emp.setTenureMonths(tenureMonths);
            if (seniorityMonths    != null) emp.setSeniorityMonths(seniorityMonths);
            if (workingDaysInMonth != null) emp.setWorkingDaysInMonth(workingDaysInMonth);
            if (position           != null) emp.setPosition(position);
            if (department         != null) emp.setDepartment(department);
            if (identity           != null) emp.setIdentity(identity);
            if (absentDays         != null) emp.setAbsentDays(absentDays);
            return emp;
        }

        public InsuranceFact resolveInsurance() {
            InsuranceFact ins = new InsuranceFact();
            ins.setLaborInsuredSalary(laborInsuredSalary    != null ? laborInsuredSalary   : 0);
            ins.setHealthInsuredSalary(healthInsuredSalary  != null ? healthInsuredSalary  : 0);
            ins.setPensionSalary(pensionSalary              != null ? pensionSalary        : 0);
            ins.setWorkingDaysInMonth(workingDaysInMonth    != null ? workingDaysInMonth   : 22);
            ins.setVoluntaryPensionRate(
                voluntaryPensionRate != null ? voluntaryPensionRate : BigDecimal.ZERO);
            return ins;
        }

        public List<LeaveFact> resolveLeaves() {
            List<LeaveFact> raw = new ArrayList<>();
            if (leaveFacts != null && !leaveFacts.isEmpty()) raw = leaveFacts;
            else if (leaves != null) raw = leaves;

            if (raw.isEmpty()) return raw;

            Map<String, LeaveFact> merged = new LinkedHashMap<>();
            for (LeaveFact lf : raw) {
                if (lf.getLeaveTypeName() == null || lf.getLeaveTypeName().isBlank()) continue;
                merged.merge(lf.getLeaveTypeName(), lf, (existing, newLf) -> {
                    existing.setLeaveHours((existing.getLeaveHours() != null
                        ? existing.getLeaveHours() : BigDecimal.ZERO)
                        .add(newLf.getLeaveHours() != null ? newLf.getLeaveHours() : BigDecimal.ZERO));
                    existing.setLeaveDays((existing.getLeaveDays() != null
                        ? existing.getLeaveDays() : BigDecimal.ZERO)
                        .add(newLf.getLeaveDays() != null ? newLf.getLeaveDays() : BigDecimal.ZERO));
                    return existing;
                });
            }
            return new ArrayList<>(merged.values());
        }

        public List<OvertimeFact> resolveOvertimes() {
            List<OvertimeFact> raw = new ArrayList<>();
            if (overtimeFacts != null && !overtimeFacts.isEmpty()) raw = overtimeFacts;
            else if (overtimes != null) raw = overtimes;

            if (raw.isEmpty()) return raw;

            Map<String, OvertimeFact> merged = new LinkedHashMap<>();
            for (OvertimeFact ot : raw) {
                if (ot.getOvertimeType() == null || ot.getOvertimeType().isBlank()) continue;
                merged.merge(ot.getOvertimeType(), ot, (existing, newOt) -> {
                    existing.setOvertimeHours((existing.getOvertimeHours() != null
                        ? existing.getOvertimeHours() : BigDecimal.ZERO)
                        .add(newOt.getOvertimeHours() != null ? newOt.getOvertimeHours() : BigDecimal.ZERO));
                    return existing;
                });
            }
            return new ArrayList<>(merged.values());
        }

        public List<PerformanceFact> resolvePerformances() {
            List<PerformanceFact> list = new ArrayList<>();
            if (performanceFacts != null && !performanceFacts.isEmpty()) list = performanceFacts;
            else if (performances != null && !performances.isEmpty()) list = performances;

            if (list.isEmpty() && baseSalary != null
                    && !"SALES".equalsIgnoreCase(position)
                    && !"SALES".equalsIgnoreCase(department)) {
                PerformanceFact pf = new PerformanceFact();
                pf.setCompanyId(companyId);
                pf.setEmployeeId(employeeId);
                pf.setConfirmed(true);
                if      (baseSalary.compareTo(new BigDecimal("120000")) >= 0) pf.setGrade("SS+");
                else if (baseSalary.compareTo(new BigDecimal("100000")) >= 0) pf.setGrade("SS");
                else if (baseSalary.compareTo(new BigDecimal("80000"))  >= 0) pf.setGrade("S");
                else if (baseSalary.compareTo(new BigDecimal("60000"))  >= 0) pf.setGrade("A+");
                else if (baseSalary.compareTo(new BigDecimal("50000"))  >= 0) pf.setGrade("A");
                else if (baseSalary.compareTo(new BigDecimal("38000"))  >= 0) pf.setGrade("B+");
                else pf.setGrade("B");
                list.add(pf);
            }
            return list;
        }

        public List<AttendanceFact> resolveAttendances() {
            if (attendanceFacts != null && !attendanceFacts.isEmpty()) return attendanceFacts;
            if (attendances     != null) return attendances;
            return new ArrayList<>();
        }

        public List<AllowanceFact> resolveAllowances() {
            if (allowanceFacts != null && !allowanceFacts.isEmpty()) return allowanceFacts;
            if (allowances     != null) return allowances;
            return new ArrayList<>();
        }

        public List<ProjectFact> resolveProjects() {
            if (projectFacts != null && !projectFacts.isEmpty()) return projectFacts;
            if (projects     != null) return projects;
            return new ArrayList<>();
        }

        public List<SalaryAdjustmentFact> resolveSalaryAdjustments() {
            if (salaryAdjustmentFacts != null && !salaryAdjustmentFacts.isEmpty()) return salaryAdjustmentFacts;
            if (salaryAdjustments     != null) return salaryAdjustments;
            return new ArrayList<>();
        }
    }

    @FunctionName("CheckSalaryLegacy")
    public HttpResponseMessage run(
        @HttpTrigger(
            name = "req",
            methods = { HttpMethod.POST },
            route = "checksalary/legacy",
            authLevel = AuthorizationLevel.ANONYMOUS
        )
        HttpRequestMessage<Optional<String>> request,
        ExecutionContext context
    ) {
        long totalStart   = System.currentTimeMillis();
        long memBefore    = getUsedMemoryMB();
        int  totalCount   = 0;
        int  failureCount = 0;

        String mode = request.getHeaders().getOrDefault("x-mode", "realtime");
        context.getLogger().info("[CheckSalaryLegacy] mode=" + mode);

        try {
            String   body = request.getBody().orElse("");
            JsonNode root = mapper.readTree(body);

            if (root.isArray()) {

                List<SalaryRequestWrapper> reqs = new ArrayList<>(root.size());
                for (JsonNode node : root) {
                    reqs.add(mapper.treeToValue(node, SalaryRequestWrapper.class));
                }
                totalCount = reqs.size();

                context.getLogger().info(
                    "[CheckSalaryLegacy] Batch start: " + totalCount + " 筆");

                // 🚀【對等計時】純計算時間：從已解析的 reqs 開始，到所有員工算完。
                //    不含 JSON 解析與 HTTP，對等於 Drools 的 X-Drools-Pure-Compute-Ms。
                long pureComputeStart  = System.currentTimeMillis();
                List<BatchResultWrapper> results = processBatch(reqs, context);
                long legacyPureCompute = System.currentTimeMillis() - pureComputeStart;

                for (BatchResultWrapper w : results) {
                    if (w.error != null) failureCount++;
                }

                long   totalDuration = System.currentTimeMillis() - totalStart;
                long   memAfter      = getUsedMemoryMB();
                int    successCount  = totalCount - failureCount;
                double successRate   = totalCount > 0
                    ? (successCount * 100.0 / totalCount) : 100.0;
                double avgDuration   = totalCount > 0
                    ? (double) legacyPureCompute / totalCount : 0.0;

                telemetry.trackMetric("CheckSalaryLegacy Count",        totalCount);
                telemetry.trackMetric("CheckSalaryLegacy Successes",     successCount);
                telemetry.trackMetric("CheckSalaryLegacy Failures",      failureCount);
                telemetry.trackMetric("CheckSalaryLegacy SuccessRate",   successRate);
                telemetry.trackMetric("CheckSalaryLegacy AvgDurationMs", avgDuration);
                telemetry.trackMetric("CheckSalaryLegacy PureComputeMs", (double) legacyPureCompute);
                telemetry.trackMetric("CheckSalaryLegacy MaxDurationMs", (double) totalDuration);
                telemetry.trackMetric("CheckSalaryLegacy MinDurationMs", 0.0);
                telemetry.trackMetric("CheckSalaryLegacy MemoryUsedMB",  (double) memAfter);
                telemetry.trackMetric("CheckSalaryLegacy MemoryDeltaMB", (double)(memAfter - memBefore));

                context.getLogger().info(String.format(
                    "[CheckSalaryLegacy] Batch done: %d 筆，成功 %d，失敗 %d，純計算 %d ms，總耗時 %d ms",
                    totalCount, successCount, failureCount, legacyPureCompute, totalDuration));

                return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",             "application/json")
                    .header("X-Execution-Time-Ms",      String.valueOf(totalDuration))
                    .header("X-Legacy-Pure-Compute-Ms", String.valueOf(legacyPureCompute))
                    .header("X-Batch-Count",            String.valueOf(totalCount))
                    .body(mapper.writeValueAsString(results))
                    .build();

            } else {
                SalaryRequestWrapper req =
                    mapper.treeToValue(root, SalaryRequestWrapper.class);
                EmployeeFact emp = req.resolveEmployee();
                totalCount = 1;

                // 🚀【對等計時】單筆純計算時間（不含 JSON 解析）
                long pureComputeStart = System.currentTimeMillis();
                SalaryResult result;
                try {
                    result = calculate(req, emp, context);
                } catch (Exception ex) {
                    failureCount = 1;
                    throw ex;
                }
                long legacyPureCompute = System.currentTimeMillis() - pureComputeStart;

                long   duration    = System.currentTimeMillis() - totalStart;
                long   memAfter    = getUsedMemoryMB();
                double successRate = failureCount == 0 ? 100.0 : 0.0;

                telemetry.trackMetric("CheckSalaryLegacy Count",        1.0);
                telemetry.trackMetric("CheckSalaryLegacy Successes",     failureCount == 0 ? 1.0 : 0.0);
                telemetry.trackMetric("CheckSalaryLegacy Failures",      (double) failureCount);
                telemetry.trackMetric("CheckSalaryLegacy SuccessRate",   successRate);
                telemetry.trackMetric("CheckSalaryLegacy AvgDurationMs", (double) legacyPureCompute);
                telemetry.trackMetric("CheckSalaryLegacy PureComputeMs", (double) legacyPureCompute);
                telemetry.trackMetric("CheckSalaryLegacy MaxDurationMs", (double) duration);
                telemetry.trackMetric("CheckSalaryLegacy MinDurationMs", (double) duration);
                telemetry.trackMetric("CheckSalaryLegacy MemoryUsedMB",  (double) memAfter);
                telemetry.trackMetric("CheckSalaryLegacy MemoryDeltaMB", (double)(memAfter - memBefore));

                context.getLogger().info(String.format(
                    "[Realtime] employeeId=%s 純計算 %dms 耗時 %dms",
                    emp.getEmployeeId(), legacyPureCompute, duration));

                return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type",             "application/json")
                    .header("X-Execution-Time-Ms",      String.valueOf(duration))
                    .header("X-Legacy-Pure-Compute-Ms", String.valueOf(legacyPureCompute))
                    .body(mapper.writeValueAsString(result))
                    .build();
            }

        } catch (Exception e) {
            telemetry.trackMetric("CheckSalaryLegacy Failures",    1.0);
            telemetry.trackMetric("CheckSalaryLegacy SuccessRate", 0.0);
            context.getLogger().severe("[CheckSalaryLegacy] 錯誤：" + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR)
                .body("{\"error\":\"" + e.getMessage() + "\"}")
                .header("Content-Type", "application/json")
                .build();
        }
    }

    private List<BatchResultWrapper> processBatch(
            List<SalaryRequestWrapper> reqs,
            ExecutionContext context) {

        List<BatchResultWrapper> results = new ArrayList<>(reqs.size());

        for (SalaryRequestWrapper req : reqs) {
            EmployeeFact emp       = req.resolveEmployee();
            long         itemStart = System.currentTimeMillis();

            try {
                SalaryResult result = calculate(req, emp, context);
                results.add(new BatchResultWrapper(emp.getEmployeeId(), result, null));
            } catch (Exception ex) {
                context.getLogger().warning(String.format(
                    "[Batch] employeeId=%s 計算失敗: %s",
                    emp.getEmployeeId(), ex.getMessage()));
                results.add(new BatchResultWrapper(emp.getEmployeeId(), null, ex.getMessage()));
            }

            context.getLogger().info(String.format(
                "[Batch] employeeId=%s 耗時 %dms",
                emp.getEmployeeId(), System.currentTimeMillis() - itemStart));
        }

        return results;
    }

    private SalaryResult calculate(
            SalaryRequestWrapper req, EmployeeFact employee, ExecutionContext context) {

        List<LeaveFact>            leaves            = req.resolveLeaves();
        List<OvertimeFact>         overtimes         = req.resolveOvertimes();
        List<PerformanceFact>      performances      = req.resolvePerformances();
        List<AttendanceFact>       attendances       = req.resolveAttendances();
        List<AllowanceFact>        allowances        = req.resolveAllowances();
        List<ProjectFact>          projects          = req.resolveProjects();
        List<SalaryAdjustmentFact> salaryAdjustments = req.resolveSalaryAdjustments();

        SalaryResult result = new SalaryResult();
        result.setEmployeeId(employee.getEmployeeId());
        result.setBaseSalary(employee.getBaseSalary());
        result.setAppliedRule("Legacy-IfElse-Salary");

        int seniorityMonths = employee.getSeniorityMonths();
        int tenureMonths    = employee.getTenureMonths();

        CompanySalaryRule rule = getCompanyRule(employee.getCompanyId(), context);

        calcFullAttendanceExempt(leaves, result);

        boolean hasAbsence;
        if (rule != null && rule.hasCustomLeaveDeduction()) {
            hasAbsence = rule.processLeaveDeductions(employee, leaves, result);
        } else {
            hasAbsence = calcLeaveDeductions(employee, leaves, result);
        }

        hasAbsence = resolveAttendanceAbsence(attendances, result, hasAbsence);

        if (rule != null && rule.hasCustomOvertimeCalc()) {
            rule.processOvertimeBonus(employee, overtimes, result);
        } else {
            calcOvertimeBonus(employee, overtimes, result);
        }

        boolean hasOvertime = result.getOvertimeBonus().compareTo(BigDecimal.ZERO) > 0;

        boolean hasFullAttendance = false;
        if (rule != null && rule.hasCustomFullAttendanceCalc()) {
            hasFullAttendance = rule.processFullAttendance(employee, result, hasAbsence);
        } else {
            // 對齊通用 DRL：標準檔不發全勤獎金（政策性獎金移至公司客製規則）；
            // 仍計算 hasFullAttendance 旗標供公司客製津貼方法使用
            if (tenureMonths >= 1
                    && !result.isFullAttendanceBonusDeducted()
                    && (!hasAbsence || result.isFullAttendancePenaltyExempt())) {
                hasFullAttendance = true;
            }
        }

        BigDecimal adjustedSeniority;
        if (rule != null && rule.hasCustomSeniorityCalc()) {
            adjustedSeniority = rule.processSeniorityBonus(employee, result);
        } else {
            // 對齊通用 DRL：標準檔資歷獎金恆為 0（政策性獎金移至公司客製規則）
            adjustedSeniority = BigDecimal.ZERO;
            result.addRuleDetail("【資歷獎金】通用基準 0（政策性獎金移至公司客製規則，對齊通用 DRL）");
        }

        BigDecimal totalCustomAllowance = BigDecimal.ZERO;
        if (rule != null) {
            Map<String, BigDecimal> companyAllowances;

            // ── 公司95(L5) 使用帶 performances/projects 的方法（五維交叉需要）──
            if (rule instanceof Company95Rule) {
                companyAllowances = ((Company95Rule) rule).getCustomAllowancesL5(
                    employee, hasFullAttendance, hasOvertime, leaves, overtimes,
                    performances, projects, result);
            } else if (rule instanceof Company94Rule) {
                companyAllowances = ((Company94Rule) rule).getCustomAllowancesL4(
                    employee, hasFullAttendance, hasOvertime, leaves, overtimes,
                    performances, projects, result);
            } else if (rule instanceof Company25Rule) {
                companyAllowances = ((Company25Rule) rule).getCustomAllowancesWithOvertimes(
                    employee, hasFullAttendance, hasOvertime, leaves, overtimes, result);
            } else {
                companyAllowances = rule.getCustomAllowances(
                    employee, hasFullAttendance, hasOvertime, leaves, result);
            }

            for (Map.Entry<String, BigDecimal> entry : companyAllowances.entrySet()) {
                totalCustomAllowance = totalCustomAllowance.add(entry.getValue());
                result.addRuleDetail(String.format(
                    "【公司津貼】%s +%s", entry.getKey(), entry.getValue()));
            }
        }

        // 對齊通用 DRL：移除通用績效獎金、核准津貼、專案獎金、完美出勤加成、薪資調整
        // （以上計算均不存在於通用 DRL；如有需要，請於各公司客製規則中實作）

        result.setSeniorityBonus(adjustedSeniority);
        result.setCompanyBonus(totalCustomAllowance);

        // ★ 出勤調整（遲到/早退/完美出勤）— 對齊 DRL Company_94_Attendance_*
        //   必須在 setCompanyBonus 之後，且 finalSalary 要用調整後的值。
        if (rule instanceof Company94Rule) {
            ((Company94Rule) rule).applyAttendanceAdjustments(attendances, result);
        }
        if (rule instanceof Company95Rule) {
            ((Company95Rule) rule).applyAttendanceAdjustments(attendances, result);
        }

        // ★ 用調整後的 companyBonus / leaveDeduction 重算 finalSalary
        //   （完美出勤 +500 進 companyBonus、遲到/早退扣款進 leaveDeduction）
        BigDecimal finalSalary = employee.getBaseSalary()
            .subtract(result.getLeaveDeduction())
            .add(result.getOvertimeBonus())
            .add(adjustedSeniority)
            .add(result.getCompanyBonus())
            .setScale(2, RoundingMode.HALF_UP);

        result.setFinalSalary(finalSalary);
        result.setAppliedRule("Salary - Calculate Final Salary");

        result.addRuleDetail(String.format(
            "【結算】底薪 %s - 請假扣 %s + 加班/全勤 %s + 資歷獎金 %s + 公司津貼 %s = 實領 %s",
            employee.getBaseSalary(),
            result.getLeaveDeduction(),
            result.getOvertimeBonus(),
            adjustedSeniority,
            result.getCompanyBonus(),
            finalSalary));

        result.setMessage(String.format(
            "【員工實領明細】底薪：%s ｜請假扣：-%s ｜加班/全勤：+%s ｜資歷獎金：+%s ｜公司津貼：+%s ｜實領：%s",
            employee.getBaseSalary(),
            result.getLeaveDeduction(),
            result.getOvertimeBonus(),
            adjustedSeniority,
            result.getCompanyBonus(),
            finalSalary));

        return result;
    }

    private void calcFullAttendanceExempt(List<LeaveFact> leaves, SalaryResult result) {
        Set<String> exemptTypes = Set.of(
            "婚假", "喪假", "公傷病假", "公假", "生理假",
            "產假", "陪產假", "產檢假", "家庭照顧假"
        );
        for (LeaveFact leave : leaves) {
            if (leave.getLeaveHours() != null
                    && leave.getLeaveHours().compareTo(BigDecimal.ZERO) > 0
                    && exemptTypes.contains(leave.getLeaveTypeName())) {
                result.setFullAttendancePenaltyExempt(true);
                result.addRuleDetail(
                    "【全勤保障】" + leave.getLeaveTypeName() + "：不得扣發全勤獎金");
            }
        }
    }

    private boolean calcLeaveDeductions(
            EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result) {

        boolean hasAbsence = false;

        for (LeaveFact leave : leaves) {
            BigDecimal leaveHours = leave.getLeaveHours();
            if (leaveHours == null || leaveHours.compareTo(BigDecimal.ZERO) <= 0) continue;

            String type = leave.getLeaveTypeName();

            switch (type) {
                case "事假":
                case "住院病假":
                case "安胎假":
                case "家庭照顧假":
                case "育嬰假":
                case "留職停薪":
                case "天然災害假":
                case "停班": {
                    BigDecimal deduct = employee.calcLeaveDeduction(leaveHours, "1.0");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                    result.addRuleDetail(String.format(
                        "【請假扣薪】%s %s 小時（100%%扣薪），扣薪 -%s",
                        type, leaveHours.stripTrailingZeros().toPlainString(), deduct));
                    break;
                }
                case "曠職": {
                    BigDecimal deduct = employee.calcLeaveDeduction(leaveHours, "1.0");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                    result.setFullAttendanceBonusDeducted(true);
                    hasAbsence = true;
                    result.addRuleDetail(String.format(
                        "【請假扣薪】曠職 %s 小時（100%%扣薪），扣薪 -%s，喪失全勤獎金",
                        leaveHours.stripTrailingZeros().toPlainString(), deduct));
                    break;
                }
                case "普通病假": {
                    BigDecimal deduct = employee.calcLeaveDeduction(leaveHours, "0.5");
                    result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                    result.addRuleDetail(String.format(
                        "【請假扣薪】普通病假 %s 小時（50%%扣薪），扣薪 -%s",
                        leaveHours.stripTrailingZeros().toPlainString(), deduct));
                    break;
                }
                case "生理假": {
                    result.addRuleDetail(String.format(
                        "【給薪假】生理假 %s 小時，不扣薪 $0（性平法第 14 條保障）",
                        leaveHours.stripTrailingZeros().toPlainString()));
                    break;
                }
                case "產假": {
                    if (employee.getTenureMonths() < 6) {
                        BigDecimal deduct = employee.calcLeaveDeduction(leaveHours, "0.5");
                        result.setLeaveDeduction(result.getLeaveDeduction().add(deduct));
                        result.addRuleDetail(String.format(
                            "【請假扣薪】產假（未滿6個月）%s 小時（50%%扣薪），扣薪 -%s",
                            leaveHours.stripTrailingZeros().toPlainString(), deduct));
                    } else {
                        result.addRuleDetail(String.format(
                            "【給薪假】產假（滿6個月）%s 小時，不扣薪 $0",
                            leaveHours.stripTrailingZeros().toPlainString()));
                    }
                    break;
                }
                case "特休":
                case "喪假":
                case "婚假":
                case "公假":
                case "公傷病假":
                case "產檢假":
                case "陪產假":
                case "流產假":
                case "補休":
                case "生日假": {
                    result.addRuleDetail(String.format(
                        "【給薪假】%s %s 小時，不扣薪 $0",
                        type, leaveHours.stripTrailingZeros().toPlainString()));
                    break;
                }
                default: {
                    result.addRuleDetail("【請假扣薪】未知假別：" + type + "，略過");
                    break;
                }
            }
        }
        return hasAbsence;
    }

    private boolean resolveAttendanceAbsence(
            List<AttendanceFact> attendances, SalaryResult result, boolean currentHasAbsence) {

        if (attendances == null || attendances.isEmpty()) return currentHasAbsence;

        boolean hasAbsence = currentHasAbsence;

        for (AttendanceFact att : attendances) {
            if (!att.isHasFullAttendance()) {
                hasAbsence = true;
                result.setFullAttendanceBonusDeducted(true);
                result.addRuleDetail(String.format(
                    "【出勤明細】員工本月未達全勤，實際出勤 %d 天 / 應出勤 %d 天",
                    att.getWorkDays(), att.getRequiredWorkDays()));
            }

            if (att.getLateCount() > 0) {
                result.addRuleDetail(String.format(
                    "【出勤明細】本月遲到 %d 次，累計 %d 分鐘",
                    att.getLateCount(), att.getLateMinutesTotal()));
            }

            if (att.getEarlyLeaveCount() > 0) {
                result.addRuleDetail(String.format(
                    "【出勤明細】本月早退 %d 次，累計 %d 分鐘",
                    att.getEarlyLeaveCount(), att.getEarlyLeaveMinutesTotal()));
            }

            if (att.isPerfectAttendance()) {
                result.addRuleDetail("【出勤明細】完美出勤：零遲到、零早退、零缺勤");
            }
        }

        return hasAbsence;
    }

    // ── 通用加班費計算（非公司25）────────────────────────────────────────
    // ── Company25 走 rule.processOvertimeBonus()，此方法只處理通用路徑 ──
    private void calcOvertimeBonus(
            EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result) {

        BigDecimal baseSalary = employee.getBaseSalary();

        for (OvertimeFact ot : overtimes) {
            BigDecimal otHours = ot.getOvertimeHours();
            if (otHours == null || otHours.compareTo(BigDecimal.ZERO) <= 0) continue;

            BigDecimal bonus;
            String     label;

            switch (ot.getOvertimeType()) {
                case "WEEKDAY": {
                    bonus = employee.calcWeekdayOvertime(otHours);
                    label = "平日加班";
                    break;
                }
                case "REST_DAY": {
                    bonus = employee.calcRestDayOvertime(otHours);
                    label = "休息日加班";
                    break;
                }
                case "NATIONAL_HOLIDAY": {
                    bonus = otHours.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcNationalHolidayOvertimeBase()
                            : employee.calcNationalHolidayOvertimeExtra(otHours);
                    label = "國定假日出勤";
                    break;
                }
                case "STATUTORY_HOLIDAY": {
                    bonus = otHours.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcStatutoryHolidayOvertimeBase()
                            : employee.calcStatutoryHolidayOvertimeExtra(otHours);
                    label = "例假日出勤";
                    break;
                }
                case "ANNUAL_LEAVE_DAY": {
                    bonus = otHours.compareTo(new BigDecimal("8")) <= 0
                            ? employee.calcStatutoryHolidayOvertimeBase()
                            : employee.calcStatutoryHolidayOvertimeExtra(otHours);
                    label = "特休出勤";
                    break;
                }
                default: {
                    result.addRuleDetail(
                        "【加班費】未知加班類型：" + ot.getOvertimeType() + "，略過");
                    continue;
                }
            }

            result.setOvertimeBonus(result.getOvertimeBonus().add(bonus));
            result.addRuleDetail(String.format(
                "【加班費】%s %sH，加給 +%s",
                label, otHours.stripTrailingZeros().toPlainString(), bonus));
        }
    }

    // ════════════════════════════════════════════════════════════════
    // 以下通用政策性/事實驅動計算方法已移除，對齊通用 DRL（salary.drl）：
    //   calcSeniorityBonus / calcPerformanceBonus / calcApprovedAllowances /
    //   calcProjectBonus / calcAttendanceAdjustments / calcSalaryAdjustments
    // 如各公司需要上述加給，請於對應 CompanySalaryRule 實作中提供。
    // ════════════════════════════════════════════════════════════════
}