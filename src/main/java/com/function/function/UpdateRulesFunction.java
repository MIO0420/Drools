package com.function.function;

import com.function.service.DrlStorageService;
import com.function.service.KieSessionService;
import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;

import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.*;
import java.util.function.Function;

public class UpdateRulesFunction {

    private final DrlStorageService storageService = new DrlStorageService();

    private static final Set<String> EMPLOYEE_FIELDS = new HashSet<>(Arrays.asList(
        "monthlyovertimehours", "monthly_overtime_hours",
        "quarterlyovertimehours", "quarterly_overtime_hours",
        "laborcouncilagreed", "labor_council_agreed",
        "consecutiveworkdays", "consecutive_work_days",
        "restdaysperweek", "rest_days_per_week",
        "ischildworker", "is_child_worker", "childworker", "child_worker",
        "ispregnantornursing", "is_pregnant_or_nursing", "pregnantornursing", "pregnant_or_nursing",
        "dailyworkhours", "daily_work_hours",
        "weeklyworkhours", "weekly_work_hours",
        "tenuremonths", "tenure_months",
        "companyid", "company_id"
    ));

    private static final Set<String> LEAVE_FIELDS = new HashSet<>(Arrays.asList(
        "leavetypename", "leave_type_name", "leavetype", "leave_type",
        "leavehours", "leave_hours",
        "leavedays", "leave_days",
        "deductionrate", "deduction_rate",
        "affectfullattendance", "affect_full_attendance",
        "hospitalized", "pregnancyweeks", "pregnancy_weeks"
    ));

    public static class RuleCondition {
        public String field;
        public String operator;
        public Object value;
        public Map<String, Object> params;
    }

    public static class UpdateRuleRequest {
        public String  ruleName;
        public String  activationGroup;   // ★ 新增：群組標籤（留空則自動使用 ruleName）
        public String  author;
        public int     version       = 1;
        public int     priority      = 8;
        public boolean persistToFile = true;
        public List<RuleCondition> conditions;
        public String  action;
        public String  actionNote;
        public String  actionViolation;
        public String  actionWarning;
        public String  ruleSet       = "timecheck";
        public String  rawDrl;
        public String  companyId;
        public String  companyFileName;
    }

    @FunctionName("UpdateRules")
    public HttpResponseMessage run(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "updaterules")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        try {
            String body = request.getBody().orElse("{}");
            com.fasterxml.jackson.databind.ObjectMapper mapper =
                new com.fasterxml.jackson.databind.ObjectMapper();
            UpdateRuleRequest req = mapper.readValue(body, UpdateRuleRequest.class);

            String ruleSet = (req.ruleSet != null && !req.ruleSet.isBlank())
                    ? req.ruleSet.toLowerCase() : "timecheck";

            boolean isSalaryModule = "salary".equals(ruleSet);
            boolean hasCompany     = req.companyId != null && !req.companyId.isBlank();
            boolean isCompSalary   = isSalaryModule && hasCompany;

            String targetFileName;
            String blobReadKey;

            if (isCompSalary) {
                targetFileName = resolveCompanyFileName(req);
                blobReadKey    = "Salary/" + targetFileName;
            } else if (isSalaryModule) {
                targetFileName = "salary.drl";
                blobReadKey    = "Salary/salary.drl";
            } else if (hasCompany) {
                targetFileName = "Company_" + req.companyId + "_" + ruleSet + ".drl";
                blobReadKey    = ruleSet + "/" + targetFileName;
            } else {
                targetFileName = ruleSet + ".drl";
                blobReadKey    = ruleSet + "/" + targetFileName;
            }

            // ══════════════════════════════════════════════════
            // 路徑 A：rawDrl 模式
            // ══════════════════════════════════════════════════
            if (req.rawDrl != null && !req.rawDrl.isBlank()) {
                context.getLogger().info("[UpdateRules] rawDrl 附加模式，目標路徑: " + blobReadKey);

                String oldDrl;
                if (hasCompany) {
                    oldDrl = storageService.downloadDrl(blobReadKey);
                    if (oldDrl == null || oldDrl.isBlank()) oldDrl = buildDrlHeader(ruleSet);
                } else {
                    oldDrl = storageService.downloadDrl(blobReadKey);
                    if (oldDrl == null || oldDrl.isBlank()) oldDrl = storageService.downloadDrl(ruleSet + ".drl");
                    if (oldDrl == null || oldDrl.isBlank()) oldDrl = storageService.downloadDrl(ruleSet);
                    if (oldDrl == null || oldDrl.isBlank()) oldDrl = buildDrlHeader(ruleSet);
                }

                String timestamp   = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
                String author      = (req.author != null && !req.author.isBlank()) ? req.author : "API_RawDrl";
                String combinedDrl = oldDrl
                        + "\n\n// ── [rawDrl 動態附加] " + (req.ruleName != null ? req.ruleName : "未命名")
                        + "\n// ── 時間：" + timestamp + "  作者：" + author + "\n"
                        + req.rawDrl + "\n";

                String result = persistRules(req, ruleSet, isSalaryModule, isCompSalary, hasCompany, targetFileName, combinedDrl);

                if ("SUCCESS".equals(result)) {
                    Map<String, Object> resp = new LinkedHashMap<>();
                    resp.put("status",    "success");
                    resp.put("ruleSet",   ruleSet);
                    resp.put("mode",      "rawDrl_Append");
                    resp.put("persisted", true);
                    if (hasCompany) resp.put("companyId", req.companyId);
                    resp.put("blobPath",  blobReadKey);
                    return request.createResponseBuilder(HttpStatus.OK)
                            .header("Content-Type", "application/json")
                            .body(mapper.writeValueAsString(resp)).build();
                } else {
                    return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("Error: " + result).build();
                }
            }

            // ══════════════════════════════════════════════════
            // 路徑 B：條件式動態規則產生模式
            // ══════════════════════════════════════════════════
            if (req.ruleName == null || req.ruleName.isBlank())
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("Missing ruleName").build();
            if (req.conditions == null || req.conditions.isEmpty())
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("Missing conditions").build();
            if (req.action == null || req.action.isBlank())
                return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("Missing action").build();

            String newRuleBlock = buildDrl(req, ruleSet);

            String existingDrl;
            if (hasCompany) {
                existingDrl = storageService.downloadDrl(blobReadKey);
                if (existingDrl == null || existingDrl.isBlank()) {
                    existingDrl = buildDrlHeader(ruleSet);
                    context.getLogger().info("[UpdateRules] 客製化新檔，初始化 Header: " + blobReadKey);
                } else {
                    context.getLogger().info("[UpdateRules] 讀取客製化舊檔，附加: " + blobReadKey);
                }
            } else {
                existingDrl = storageService.downloadDrl(blobReadKey);
                if (existingDrl == null || existingDrl.isBlank()) existingDrl = storageService.downloadDrl(ruleSet + ".drl");
                if (existingDrl == null || existingDrl.isBlank()) existingDrl = storageService.downloadDrl(ruleSet);
                if (existingDrl == null || existingDrl.isBlank()) {
                    existingDrl = buildDrlHeader(ruleSet);
                    context.getLogger().info("[UpdateRules] 找不到舊檔，初始化新 Header: " + blobReadKey);
                } else {
                    context.getLogger().info("[UpdateRules] 成功讀取舊檔，附加: " + blobReadKey);
                }
            }

            String timestamp   = LocalDateTime.now().format(DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss"));
            String author      = (req.author != null && !req.author.isBlank()) ? req.author : "API";
            // 回應中顯示實際使用的群組標籤
            String usedGroup   = resolveActivationGroup(req);
            String appendBlock = "\n\n// ── [動態新增] " + req.ruleName + "_v" + req.version + "\n"
                               + "// ── 時間：" + timestamp + "  作者：" + author
                               + "  群組：" + usedGroup + "\n"
                               + newRuleBlock + "\n";
            String fullDrl = existingDrl + appendBlock;

            String result = persistRules(req, ruleSet, isSalaryModule, isCompSalary, hasCompany, targetFileName, fullDrl);

            if (req.persistToFile) {
                if (result.startsWith("BLOB_PERSIST_ERROR"))
                    return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR).body("儲存失敗：" + result).build();
                if (!"SUCCESS".equals(result))
                    return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("DRL 編譯失敗：" + result).build();
                return buildSuccessResponse(request, mapper, req, ruleSet, newRuleBlock, true, "已成功附加新規則並儲存");
            } else {
                if (!"SUCCESS".equals(result) && !result.startsWith("BLOB_PERSIST_ERROR"))
                    return request.createResponseBuilder(HttpStatus.BAD_REQUEST).body("DRL 編譯失敗：" + result).build();
                return buildSuccessResponse(request, mapper, req, ruleSet, newRuleBlock, false, "僅記憶體載入 (未儲存至檔案)");
            }

        } catch (Exception e) {
            context.getLogger().severe("Exception: " + e.getMessage());
            return request.createResponseBuilder(HttpStatus.INTERNAL_SERVER_ERROR).body("Exception: " + e.getMessage()).build();
        }
    }

    // =========================================================
    // ★ 解析最終使用的群組標籤
    //   有填 activationGroup → 用它
    //   沒填 → 預設用 ruleName（原本行為）
    // =========================================================
    private String resolveActivationGroup(UpdateRuleRequest req) {
        if (req.activationGroup != null && !req.activationGroup.isBlank())
            return req.activationGroup;
        return req.ruleName;
    }

    // =========================================================
    // ★ 統一持久化入口
    // =========================================================
    private String persistRules(UpdateRuleRequest req,
                                 String ruleSet,
                                 boolean isSalaryModule,
                                 boolean isCompSalary,
                                 boolean hasCompany,
                                 String targetFileName,
                                 String drlContent) {
        if (isCompSalary) {
            return KieSessionService.updateCompanySalaryRules(req.companyId, targetFileName, drlContent);
        } else if (isSalaryModule) {
            Map<String, String> files = new HashMap<>();
            files.put("salary.drl", drlContent);
            return KieSessionService.updateSalaryRules(files);
        } else if (hasCompany) {
            try {
                storageService.uploadDrl(ruleSet + "/" + targetFileName, drlContent);
            } catch (Exception e) {
                return "BLOB_PERSIST_ERROR: " + e.getMessage();
            }
            KieSessionService.invalidateContainerCache(ruleSet, null);
            return "SUCCESS";
        } else {
            return KieSessionService.updateDynamicRules(ruleSet, drlContent);
        }
    }

    private String resolveCompanyFileName(UpdateRuleRequest req) {
        if (req.companyFileName != null && !req.companyFileName.isBlank()) return req.companyFileName;
        return "Company_" + req.companyId + "_Salary.drl";
    }

    private HttpResponseMessage buildSuccessResponse(
            HttpRequestMessage<Optional<String>> request,
            com.fasterxml.jackson.databind.ObjectMapper mapper,
            UpdateRuleRequest req, String ruleSet,
            String generatedDrl, boolean persisted, String message) throws Exception {
        Map<String, Object> resp = new LinkedHashMap<>();
        resp.put("status",          "success");
        resp.put("ruleSet",         ruleSet);
        resp.put("ruleName",        req.ruleName);
        resp.put("activationGroup", resolveActivationGroup(req));   // ★ 回應中顯示實際群組
        resp.put("version",         req.version);
        resp.put("persisted",       persisted);
        resp.put("message",         message);
        if (req.companyId != null && !req.companyId.isBlank()) {
            resp.put("companyId",       req.companyId);
            resp.put("companyFileName", resolveCompanyFileName(req));
        }
        resp.put("generatedDrl", generatedDrl);
        return request.createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .body(mapper.writeValueAsString(resp)).build();
    }

    private String buildDrlHeader(String ruleSet) {
        switch (ruleSet) {
            case "timecheck":
                return "package rules.timecheck\n\nimport com.function.model.TimeCheckFact\nimport com.function.model.TimeCheckResult\nimport static com.function.util.RuleUtils.*\n\n";
            case "clock":
                return "package rules.clock\n\nimport com.function.model.ClockFact\nimport static com.function.util.RuleUtils.*\n\n";
            case "leave":
                return "package rules.leave\n\nimport com.function.model.LeaveFact\nimport static com.function.util.RuleUtils.*\n\n";
            case "overtime":
                return "package rules.overtime\n\nimport com.function.model.EmployeeFact\nimport com.function.model.OvertimeFact\nimport com.function.model.OvertimeResult\nimport java.math.BigDecimal\nimport static com.function.util.RuleUtils.*\n\n";
            case "salary":
                return "package rules.salary\n\nimport java.math.BigDecimal\nimport java.math.RoundingMode\nimport com.function.model.EmployeeFact\nimport com.function.model.LeaveFact\nimport com.function.model.OvertimeFact\nimport com.function.model.InsuranceFact\nimport com.function.model.SalaryResult\nimport static com.function.util.RuleUtils.calcLeaveDeduction\nimport static com.function.util.RuleUtils.calcWeekdayOvertime\nimport static com.function.util.RuleUtils.calcRestDayOvertime\nimport static com.function.util.RuleUtils.calcNationalHolidayOvertime\nimport static com.function.util.RuleUtils.calcStatutoryHolidayOvertime\n\n";
            case "scheduling":
                return "package rules.schedule\n\nimport com.function.model.SchedulingFact\nimport com.function.model.SchedulingResult\nimport java.math.BigDecimal\nimport static com.function.util.RuleUtils.*\n\n";
            default:
                return "package rules." + ruleSet + "\n\nimport com.function.model.UniversalFact\nimport com.function.model.UniversalResult\nimport static com.function.util.RuleUtils.*\n\n";
        }
    }

    private boolean isEmployeeFactField(String field) { return field != null && EMPLOYEE_FIELDS.contains(field.toLowerCase()); }
    private boolean isLeaveFactField(String field)     { return field != null && LEAVE_FIELDS.contains(field.toLowerCase()); }

    private void appendConditions(StringBuilder sb, List<RuleCondition> conditions, Function<RuleCondition, String> builder) {
        boolean first = true;
        for (RuleCondition cond : conditions) {
            if (!first) sb.append(",\n");
            sb.append("            ").append(builder.apply(cond));
            first = false;
        }
    }

    private void line(StringBuilder sb, String code) { sb.append("        ").append(code).append(";\n"); }

    private void appendIfNotBlank(StringBuilder sb, String value, String prefix, String suffix) {
        if (value != null && !value.isBlank()) sb.append(prefix).append(value.replace("\"", "\\\"")).append(suffix);
    }

    private void applyExemptLate(StringBuilder sb) {
        line(sb, "$f.setEffectiveClockIn($f.getScheduleStartTime())");
        line(sb, "$f.getResult().setEffectiveClockIn($f.getScheduleStartTime().toString())");
        line(sb, "$f.setLate(false)");
        line(sb, "$f.getResult().setLate(false)");
        line(sb, "$f.getResult().setLateMinutes(0)");
        line(sb, "$f.getResult().setStatus(\"NORMAL\")");
    }

    private void applyExemptEarlyLeave(StringBuilder sb) {
        line(sb, "$f.setEffectiveClockOut($f.getScheduleEndTime())");
        line(sb, "$f.getResult().setEffectiveClockOut($f.getScheduleEndTime().toString())");
        line(sb, "$f.setEarlyLeave(false)");
        line(sb, "$f.getResult().setEarlyLeave(false)");
        line(sb, "$f.getResult().setEarlyLeaveMinutes(0)");
        line(sb, "$f.getResult().setStatus(\"NORMAL\")");
    }

    private String buildDrl(UpdateRuleRequest req, String ruleSet) {
        StringBuilder sb = new StringBuilder();
        // ★ 使用 resolveActivationGroup 決定群組標籤
        String group    = resolveActivationGroup(req);
        int    salience = req.priority + req.version;

        // ★★ 公司客製規則「取代」通用規則（單份，不疊加）★★
        //   通用 salary.drl：加班用 activation-group "OVERTIME_<TYPE>" salience 100；
        //   事假等用 LeaveProcessed 守衛 salience 100。
        //   公司規則對齊同群組、salience 設 110（壓過通用），請假則補插 LeaveProcessed，
        //   使通用對應規則不再觸發 → 只算一次。
        boolean salaryLeaveReplace = false;
        if ("salary".equals(ruleSet) && req.conditions != null) {
            String  otType   = null;
            boolean hasLeave = false;
            for (RuleCondition c : req.conditions) {
                if (c == null || c.field == null) continue;
                String f = c.field.toLowerCase();
                if (("overtimetype".equals(f) || "overtime_type".equals(f)) && c.value != null)
                    otType = c.value.toString().trim().toUpperCase();
                if (isLeaveFactField(c.field)) hasLeave = true;
            }
            if (otType != null) {              // 加班規則 → 對齊通用加班群組、壓過通用
                group    = "OVERTIME_" + otType;
                salience = 110;
            } else if (hasLeave) {             // 請假規則 → 壓過通用 + 補插 LeaveProcessed 守衛
                salience = 110;
                salaryLeaveReplace = true;
            }
        }

        sb.append("rule \"").append(req.ruleName).append("_v").append(req.version).append("\"\n");
        sb.append("    salience ").append(salience).append("\n");
        sb.append("    activation-group \"").append(group).append("\"\n");
        sb.append("    no-loop true\n");
        sb.append("    when\n");

        switch (ruleSet) {
            case "scheduling": {
                sb.append("        $sch    : SchedulingFact(\n");
                appendConditions(sb, req.conditions, this::buildSchedulingCondition);
                sb.append("\n        )\n");
                sb.append("        $result : SchedulingResult()\n");
                break;
            }
            case "overtime": {
                List<RuleCondition> otConds = new ArrayList<>(), empConds = new ArrayList<>();
                for (RuleCondition c : req.conditions) (isEmployeeFactField(c.field) ? empConds : otConds).add(c);
                sb.append("        $ot     : OvertimeFact(\n");
                if (otConds.isEmpty()) sb.append("            overtimeHours >= 0B");
                else appendConditions(sb, otConds, this::buildOvertimeCondition);
                sb.append("\n        )\n");
                if (!empConds.isEmpty()) {
                    sb.append("        $emp    : EmployeeFact(\n");
                    appendConditions(sb, empConds, this::buildEmployeeCondition);
                    sb.append("\n        )\n");
                }
                sb.append("        $result : OvertimeResult()\n");
                break;
            }
            case "salary": {
                List<RuleCondition> leaveConds = new ArrayList<>(), empConds = new ArrayList<>(), otConds = new ArrayList<>();
                for (RuleCondition c : req.conditions) {
                    if (isEmployeeFactField(c.field)) empConds.add(c);
                    else if (isLeaveFactField(c.field)) leaveConds.add(c);
                    else otConds.add(c);
                }
                if (!leaveConds.isEmpty()) { sb.append("        $leave  : LeaveFact(\n"); appendConditions(sb, leaveConds, this::buildLeaveCondition); sb.append("\n        )\n"); }
                if (!otConds.isEmpty())    { sb.append("        $ot     : OvertimeFact(\n"); appendConditions(sb, otConds, this::buildOvertimeCondition); sb.append("\n        )\n"); }
                sb.append("        $emp    : EmployeeFact(");
                if (!empConds.isEmpty()) { sb.append("\n"); appendConditions(sb, empConds, this::buildEmployeeCondition); sb.append("\n        )\n"); }
                else sb.append(")\n");
                sb.append("        $result : SalaryResult()\n");
                break;
            }
            case "timecheck": {
                sb.append("        $f : TimeCheckFact(\n");
                sb.append("            toleranceResolved == true");
                for (RuleCondition cond : req.conditions) sb.append(",\n            ").append(buildTimeCheckCondition(cond));
                sb.append("\n        )\n");
                break;
            }
            default: {
                sb.append("        $fact   : UniversalFact(\n");
                sb.append("            companyId != null");
                for (RuleCondition cond : req.conditions) sb.append(",\n            ").append(buildUniversalCondition(cond));
                sb.append("\n        )\n");
                sb.append("        $result : UniversalResult()\n");
                break;
            }
        }

        sb.append("    then\n");
        sb.append(buildAction(req, ruleSet));
        if (salaryLeaveReplace) {
            // 插入守衛旗標，使通用 salary.drl 同假別規則的 not LeaveProcessed(...) 不成立 → 不重複扣薪
            sb.append("        insert(new LeaveProcessed($leave));\n");
        }
        sb.append("end");
        return sb.toString();
    }

    private String buildUniversalCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field;
        String op    = cond.operator != null ? cond.operator : "==";
        Object val   = cond.value;
        if ("companyId".equalsIgnoreCase(field) || "company_id".equalsIgnoreCase(field)) return "companyId == \"" + val + "\"";
        if ("employeeId".equalsIgnoreCase(field) || "employee_id".equalsIgnoreCase(field)) return "employeeId == \"" + val + "\"";
        if (val instanceof Boolean) return "getValue(\"" + field + "\") == " + val;
        if (val instanceof String) {
            if ("==".equals(op)) return "getValue(\"" + field + "\") != null, getValue(\"" + field + "\").toString().equals(\"" + val + "\")";
            if ("!=".equals(op)) return "getValue(\"" + field + "\") != null, !getValue(\"" + field + "\").toString().equals(\"" + val + "\")";
        }
        return "getValue(\"" + field + "\") != null, eval( ((Number) $fact.getValue(\"" + field + "\")).doubleValue() " + op + " " + val + " )";
    }

    private String buildLeaveCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field; String op = cond.operator; Object val = cond.value;
        switch (field.toLowerCase()) {
            case "leavetypename": case "leave_type_name": case "leavetype": case "leave_type": return "leaveTypeName == \"" + val + "\"";
            case "leavehours":  case "leave_hours":   return "leaveHours " + op + " new BigDecimal(\"" + val + "\")";
            case "leavedays":   case "leave_days":    return "leaveDays " + op + " new BigDecimal(\"" + val + "\")";
            case "deductionrate": case "deduction_rate": return "deductionRate " + op + " new BigDecimal(\"" + val + "\")";
            case "affectfullattendance": case "affect_full_attendance": return "affectFullAttendance == " + val;
            case "hospitalized": return "hospitalized == " + val;
            case "pregnancyweeks": case "pregnancy_weeks": return "pregnancyWeeks " + op + " " + val;
            default: if (val instanceof String) return "leaveTypeName == \"" + val + "\""; if (val instanceof Boolean) return field + " == " + val; return field + " " + op + " " + val;
        }
    }

    private String buildOvertimeCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field; String op = cond.operator; Object val = cond.value;
        switch (field.toLowerCase()) {
            case "overtimetype": case "overtime_type": return "overtimeType == \"" + val + "\"";
            case "overtimehours": case "overtime_hours": return "overtimeHours " + op + " " + val + "B";
            case "disasterexception": case "disaster_exception": return "disasterException == " + val;
            case "compensatorytimeoff": case "compensatory_time_off": return "compensatoryTimeOff == " + val;
            case "compensatoryexpired": case "compensatory_expired": return "compensatoryExpired == " + val;
            case "overtimedate": case "overtime_date": return "overtimeDate == \"" + val + "\"";
            default: if (val instanceof String && "==".equals(op)) return "overtimeType == \"" + val + "\""; if (val instanceof Boolean) return field + " == " + val; return "overtimeHours " + op + " " + val + "B";
        }
    }

    private String buildEmployeeCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field; String op = cond.operator; Object val = cond.value;
        switch (field.toLowerCase()) {
            case "companyid": case "company_id": return "companyId == \"" + val + "\"";
            case "monthlyovertimehours": case "monthly_overtime_hours": return "monthlyOvertimeHours " + op + " " + val;
            case "quarterlyovertimehours": case "quarterly_overtime_hours": return "quarterlyOvertimeHours " + op + " " + val;
            case "laborcouncilagreed": case "labor_council_agreed": return "laborCouncilAgreed == " + val;
            case "consecutiveworkdays": case "consecutive_work_days": return "consecutiveWorkDays " + op + " " + val;
            case "restdaysperweek": case "rest_days_per_week": return "restDaysPerWeek " + op + " " + val;
            case "ischildworker": case "is_child_worker": case "childworker": case "child_worker": return "childWorker == " + val;
            case "ispregnantornursing": case "is_pregnant_or_nursing": case "pregnantornursing": case "pregnant_or_nursing": return "pregnantOrNursing == " + val;
            case "dailyworkhours": case "daily_work_hours": return "dailyWorkHours " + op + " " + val;
            case "weeklyworkhours": case "weekly_work_hours": return "weeklyWorkHours " + op + " " + val;
            case "tenuremonths": case "tenure_months": return "tenureMonths " + op + " " + val;
            default:
                if (val instanceof String) { if ("==".equals(op)) return "getMetaString(\"" + field + "\").equals(\"" + val + "\")"; if ("!=".equals(op)) return "!getMetaString(\"" + field + "\").equals(\"" + val + "\")"; }
                if (val instanceof Boolean) return "getMetaBool(\"" + field + "\") == " + val;
                return "getMetaDouble(\"" + field + "\") " + op + " " + val;
        }
    }

    private String buildTimeCheckCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field; String op = cond.operator; Object val = cond.value;
        switch (field.toLowerCase()) {
            case "lateminutes": case "late_minutes": return "lateMinutes " + op + " " + val;
            case "earlyleaveminutes": case "early_leave_minutes": return "earlyLeaveMinutes " + op + " " + val;
            case "islate": case "is_late": case "late": return "late == " + val;
            case "isearlyleave": case "is_early_leave": case "earlyleave": case "early_leave": return "earlyLeave == " + val;
            case "isabsent": case "is_absent": case "absent": return "absent == " + val;
            case "shifttype": case "shift_type": return "shiftType == \"" + val + "\"";
            case "companyid": case "company_id": return "companyId == \"" + val + "\"";
            default:
                if (val instanceof String) { if ("==".equals(op)) return "getMetaString(\"" + field + "\").equals(\"" + val + "\")"; if ("!=".equals(op)) return "!getMetaString(\"" + field + "\").equals(\"" + val + "\")"; }
                if (val instanceof Boolean) return field + " == " + val;
                return field + " " + op + " " + val;
        }
    }

    private String buildSchedulingCondition(RuleCondition cond) {
        String field = cond.field == null ? "" : cond.field; String op = cond.operator; Object val = cond.value;
        switch (field.toLowerCase()) {
            case "compensatoryleavexpired": case "compensatory_leave_expired": return "compensatoryLeaveExpired == " + val;
            case "compensatoryleavehours": case "compensatory_leave_hours": return "compensatoryLeaveHours " + op + " new java.math.BigDecimal(\"" + val + "\")";
            case "shiftworker": case "shift_worker": return "shiftWorker == " + val;
            case "shiftchangeresthours": case "shift_change_rest_hours": return "shiftChangeRestHours " + op + " " + val;
            case "continuousworkhours": case "continuous_work_hours": return "continuousWorkHours " + op + " " + val;
            case "breakminutes": case "break_minutes": return "breakMinutes " + op + " " + val;
            case "mandatorydayoffperweek": case "mandatory_day_off_per_week": return "mandatoryDayOffPerWeek == " + val;
            case "restdayperweek": case "rest_day_per_week": return "restDayPerWeek == " + val;
            case "mandatorydayoffscheduledaswork": case "mandatory_day_off_scheduled_as_work": return "mandatoryDayOffScheduledAsWork == " + val;
            case "legalexceptionformandatorydayoff": case "legal_exception_for_mandatory_day_off": return "legalExceptionForMandatoryDayOff == " + val;
            case "restdayworked": case "rest_day_worked": return "restDayWorked == " + val;
            case "restdayovertimepaid": case "rest_day_overtime_paid": return "restDayOvertimePaid == " + val;
            case "nationalholidayscheduledwork": case "nationalholidayscheduled": case "national_holiday_scheduled_as_work": case "nationalholidayscheduledas_work": return "nationalHolidayScheduledAsWork == " + val;
            case "nationalholidayadjustagreed": case "national_holiday_adjust_agreed": return "nationalHolidayAdjustAgreed == " + val;
            case "annualleavedeniedbyemployer": case "annual_leave_denied_by_employer": return "annualLeaveDeniedByEmployer == " + val;
            case "annualleaveadjustmentagreed": case "annual_leave_adjustment_agreed": return "annualLeaveAdjustmentAgreed == " + val;
            default:
                if (val instanceof String) { if ("==".equals(op)) return "getMetaString(\"" + field + "\").equals(\"" + val + "\")"; if ("!=".equals(op)) return "!getMetaString(\"" + field + "\").equals(\"" + val + "\")"; }
                if (val instanceof Boolean) return "getMetaBool(\"" + field + "\") == " + val;
                return "getMetaDouble(\"" + field + "\") " + op + " " + val;
        }
    }

    private String buildAction(UpdateRuleRequest req, String ruleSet) {
        StringBuilder sb = new StringBuilder();
        String action  = req.action.toLowerCase();
        String mathOp  = (req.actionWarning  != null && !req.actionWarning.isBlank())  ? req.actionWarning.toLowerCase() : "multiply";
        String mathVal = (req.actionViolation != null && !req.actionViolation.isBlank()) ? req.actionViolation : "1.0";

        switch (ruleSet) {
            case "scheduling":
                if ("custommath".equals(action)) {
                    sb.append("        double baseVal = $sch.getContinuousWorkHours();\n");
                    sb.append("        double finalVal = com.function.util.RuleUtils.").append(mathOp).append("(baseVal, ").append(toDouble(mathVal)).append(");\n");
                    sb.append("        $sch.setContinuousWorkHours(finalVal);\n");
                } else {
                    if ("addviolation".equals(action) && req.actionViolation != null && !req.actionViolation.isBlank())
                        sb.append("        $result.addViolation(\n            \"Dynamic - ").append(req.ruleName.replace("\"","\\\"")).append("\",\n            \"").append(req.actionViolation.replace("\"","\\\"")).append("\"\n        );\n");
                    if ("addwarning".equals(action)) appendIfNotBlank(sb, req.actionWarning, "        $result.addWarning(\"", "\");\n");
                }
                appendIfNotBlank(sb, req.actionNote, "        $result.addNote(\"", "\");\n");
                break;

            case "overtime":
                if ("custommath".equals(action)) {
                    sb.append("        BigDecimal baseVal = $ot.getOvertimeHours();\n");
                    if      ("add".equals(mathOp))      sb.append("        BigDecimal bonus = baseVal.add(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    else if ("subtract".equals(mathOp)) sb.append("        BigDecimal bonus = baseVal.subtract(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    else if ("divide".equals(mathOp))   sb.append("        BigDecimal bonus = baseVal.divide(new BigDecimal(\"").append(mathVal).append("\"), 2, java.math.RoundingMode.HALF_UP);\n");
                    else                                sb.append("        BigDecimal bonus = baseVal.multiply(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    sb.append("        $ot.setOvertimeHours(bonus);\n");
                } else {
                    if ("addwarning".equals(action))   { appendIfNotBlank(sb, req.actionWarning, "        $result.addWarning(\"", "\");\n"); line(sb, "$result.setViolated(true)"); }
                    else if ("addviolation".equals(action)) { if (req.actionViolation != null && !req.actionViolation.isBlank()) sb.append("        $result.addWarning(\"Dynamic - ").append(req.ruleName.replace("\"","\\\"")).append(": ").append(req.actionViolation.replace("\"","\\\"")).append("\");\n"); line(sb, "$result.setViolated(true)"); }
                    else if ("setappliedrule".equals(action)) appendIfNotBlank(sb, req.actionNote, "        $result.setAppliedRule(\"", "\");\n");
                }
                if (!"setappliedrule".equals(action)) appendIfNotBlank(sb, req.actionNote, "        $result.addNote(\"", "\");\n");
                break;

            case "salary":
                if ("custommath".equals(action)) {
                    sb.append("        BigDecimal baseVal = $emp.getDailyRate();\n");
                    if      ("add".equals(mathOp))      sb.append("        BigDecimal bonus = baseVal.add(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    else if ("subtract".equals(mathOp)) sb.append("        BigDecimal bonus = baseVal.subtract(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    else if ("divide".equals(mathOp))   sb.append("        BigDecimal bonus = baseVal.divide(new BigDecimal(\"").append(mathVal).append("\"), 2, java.math.RoundingMode.HALF_UP);\n");
                    else                                sb.append("        BigDecimal bonus = baseVal.multiply(new BigDecimal(\"").append(mathVal).append("\"));\n");
                    line(sb, "$result.setOvertimeBonus($result.getOvertimeBonus().add(bonus))");
                    appendIfNotBlank(sb, req.actionNote, "        $result.addRuleDetail(\"", " +\" + bonus);\n");
                } else {
                    switch (action) {
                        case "addwarning":         appendIfNotBlank(sb, req.actionWarning, "        $result.addWarning(\"", "\");\n"); break;
                        case "addnote":            appendIfNotBlank(sb, req.actionNote,    "        $result.addNote(\"",    "\");\n"); break;
                        case "addruledetail":      appendIfNotBlank(sb, req.actionNote,    "        $result.addRuleDetail(\"", "\");\n"); break;
                        case "fullattendanceexempt": line(sb, "$result.setFullAttendancePenaltyExempt(true)"); appendIfNotBlank(sb, req.actionNote, "        $result.addRuleDetail(\"", "\");\n"); break;
                        case "addleavededuction": {
                            String rate = (req.actionWarning != null && !req.actionWarning.isBlank()) ? req.actionWarning : "1.0";
                            sb.append("        BigDecimal deduct = com.function.util.RuleUtils.calcLeaveDeduction(\n            $emp.getBaseSalary(), $leave.getLeaveHours(), \"").append(rate).append("\");\n");
                            line(sb, "$result.setLeaveDeduction($result.getLeaveDeduction().add(deduct))");
                            appendIfNotBlank(sb, req.actionNote, "        $result.addRuleDetail(\"", " -\" + deduct);\n"); break;
                        }
                        case "addovertimebonus": {
                            String spec = (req.actionWarning != null && !req.actionWarning.isBlank()) ? req.actionWarning.trim() : "calcWeekdayOvertime";
                            String method = spec;
                            String rate1 = null, rate2 = null;
                            // 格式一：actionWarning = "calcWeekdayOvertimeByRate:2:4"
                            if (spec.contains(":")) {
                                String[] parts = spec.split(":");
                                method = parts[0];
                                if (parts.length >= 3) { rate1 = parts[1].trim(); rate2 = parts[2].trim(); }
                            }
                            // 兜底：若方法是自訂倍率但沒帶到倍率，嘗試從 actionNote 文字抓「X倍…Y倍」
                            if (rate1 == null && method.equalsIgnoreCase("calcWeekdayOvertimeByRate")) {
                                java.util.regex.Matcher m = java.util.regex.Pattern
                                    .compile("([0-9]+(?:\\.[0-9]+)?)\\s*倍").matcher(req.actionNote == null ? "" : req.actionNote);
                                java.util.List<String> rs = new java.util.ArrayList<>();
                                while (m.find()) rs.add(m.group(1));
                                if (rs.size() >= 2) { rate1 = rs.get(0); rate2 = rs.get(1); }
                                else if (rs.size() == 1) { rate1 = rs.get(0); rate2 = rs.get(0); }
                            }
                            if (rate1 != null && rate2 != null) {
                                sb.append("        BigDecimal bonus = com.function.util.RuleUtils.calcWeekdayOvertimeByRate($emp.getBaseSalary(), $ot.getOvertimeHours(), \"")
                                  .append(rate1).append("\", \"").append(rate2).append("\");\n");
                            } else {
                                sb.append("        BigDecimal bonus = com.function.util.RuleUtils.").append(method)
                                  .append("($emp.getBaseSalary(), $ot.getOvertimeHours());\n");
                            }
                            line(sb, "$result.setOvertimeBonus($result.getOvertimeBonus().add(bonus))");
                            appendIfNotBlank(sb, req.actionNote, "        $result.addRuleDetail(\"", " +\" + bonus);\n"); break;
                        }
                    }
                }
                break;

            case "timecheck":
                if ("custommath".equals(action)) {
                    sb.append("        double baseVal = $f.getLateMinutes();\n");
                    sb.append("        double finalVal = com.function.util.RuleUtils.").append(mathOp).append("(baseVal, ").append(toDouble(mathVal)).append(");\n");
                    sb.append("        $f.getResult().setLateMinutes((int)finalVal);\n");
                } else {
                    switch (action) {
                        case "exemptall":      applyExemptLate(sb); applyExemptEarlyLeave(sb); break;
                        case "exemptlate":     applyExemptLate(sb); break;
                        case "exemptearlyleave": case "exemptearlyLeave": applyExemptEarlyLeave(sb); break;
                        case "addviolation":
                            if (req.actionViolation != null && !req.actionViolation.isBlank())
                                sb.append("        $f.getResult().addViolation(\"Dynamic\", \"").append(req.actionViolation.replace("\"","\\\"")).append("\");\n");
                            break;
                    }
                }
                appendIfNotBlank(sb, req.actionNote, "        $f.getResult().addNote(\"", "\");\n");
                break;

            default:
                if ("custommath".equals(action)) {
                    sb.append("        Object raw = $fact.getValue(\"score\");\n");
                    sb.append("        double baseVal = raw != null ? ((Number) raw).doubleValue() : 0.0;\n");
                    sb.append("        double finalVal = com.function.util.RuleUtils.").append(mathOp).append("(baseVal, ").append(toDouble(mathVal)).append(");\n");
                    sb.append("        $result.setValue(\"computedScore\", finalVal);\n");
                } else {
                    switch (action) {
                        case "setvalue":
                            if (req.actionNote != null && req.actionViolation != null)
                                sb.append("        $result.setValue(\"").append(req.actionNote.replace("\"","\\\"")).append("\", \"").append(req.actionViolation.replace("\"","\\\"")).append("\");\n");
                            break;
                        case "addviolation":
                            if (req.actionViolation != null && !req.actionViolation.isBlank())
                                sb.append("        $result.setValue(\"violation\", \"").append(req.actionViolation.replace("\"","\\\"")).append("\");\n");
                            line(sb, "$result.setSuccess(false)");
                            break;
                        case "addwarning":
                            if (req.actionWarning != null && !req.actionWarning.isBlank())
                                sb.append("        $result.setValue(\"warning\", \"").append(req.actionWarning.replace("\"","\\\"")).append("\");\n");
                            break;
                        default:
                            if (req.actionNote != null && !req.actionNote.isBlank() && req.actionViolation != null && !req.actionViolation.isBlank())
                                sb.append("        $result.setValue(\"").append(req.actionNote.replace("\"","\\\"")).append("\", \"").append(req.actionViolation.replace("\"","\\\"")).append("\");\n");
                            break;
                    }
                }
                appendIfNotBlank(sb, req.actionNote, "        $result.setValue(\"note\", \"", "\");\n");
                break;
        }
        return sb.toString();
    }

    private double toDouble(Object obj) {
        if (obj == null) return 0.0;
        if (obj instanceof Number) return ((Number) obj).doubleValue();
        try { return Double.parseDouble(obj.toString()); } catch (Exception e) { return 0.0; }
    }
}