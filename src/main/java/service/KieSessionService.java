package com.function.service;

import com.microsoft.azure.functions.ExecutionContext;
import org.kie.api.KieServices;
import org.kie.api.builder.KieBuilder;
import org.kie.api.builder.KieFileSystem;
import org.kie.api.builder.Message;
import org.kie.api.command.Command;
import org.kie.api.runtime.KieContainer;
import org.kie.api.runtime.KieSession;
import org.kie.api.runtime.StatelessKieSession;
import org.kie.internal.command.CommandFactory;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.logging.Logger;

public class KieSessionService {

    private static final Logger LOG = Logger.getLogger(KieSessionService.class.getName());

    // ─────────────────────────────────────────────────────────────────────────────
    // 靜態 Classpath Container（timecheck / clock / leave / overtime / scheduling）
    // ─────────────────────────────────────────────────────────────────────────────
    private static final KieContainer CLASSPATH_CONTAINER;

    static {
        KieContainer container = null;
        try {
            container = KieServices.Factory.get().getKieClasspathContainer();
            LOG.info("[KieSessionService] 靜態 Classpath Container 初始化成功");
        } catch (Exception e) {
            LOG.severe("[KieSessionService] 靜態 Classpath Container 初始化失敗: " + e.getMessage());
        }
        CLASSPATH_CONTAINER = container;
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 動態 Container 快取
    // key 格式：{moduleName}_company_{companyId}
    // 每間公司獨立一個 KieContainer，只載入該公司需要的規則
    // ─────────────────────────────────────────────────────────────────────────────
    private static final ConcurrentHashMap<String, KieContainer> DYNAMIC_CONTAINERS = new ConcurrentHashMap<>();

    // ─────────────────────────────────────────────────────────────────────────────
    // 取得或建立動態 KieContainer
    //
    // 【修改重點】每間公司只載入自己需要的規則：
    //   ① 有公司客製化規則（Company_{companyId}_Salary.drl）→ 只載入該檔案
    //   ② 無客製化規則（如公司3）→ 只載入通用規則（salary.drl + LeaveRules.drl 等非 Company_ 開頭檔案）
    //
    // 改前：所有公司規則全部塞進同一個 KieContainer（Rete 樹包含所有公司）
    // 改後：每個 KieContainer 只含該公司需要的規則（Rete 樹精簡）
    // ─────────────────────────────────────────────────────────────────────────────
    public static KieContainer getOrCreateDynamicContainer(String moduleName, String companyId) {
        if (moduleName == null || moduleName.isBlank()) {
            LOG.severe("[Drools] 模組名稱不可為空");
            return null;
        }

        String cleanModuleName = moduleName.trim().toLowerCase();
        String cleanCompanyId  = (companyId != null && !companyId.isBlank())
                ? companyId.trim().toLowerCase() : "default";
        String containerKey    = cleanModuleName + "_company_" + cleanCompanyId;

        return DYNAMIC_CONTAINERS.computeIfAbsent(containerKey, key -> {
            LOG.info("[Drools] 快取未命中，建置模組 [" + moduleName + "] 公司 [" + companyId + "]");

            // 一次讀取整個 Salary/ 資料夾（大寫 S，與 Blob Storage 一致）
            Map<String, String> allFiles;
            try {
                allFiles = DrlStorageService.readRules("Salary");
                LOG.info("[Drools] Salary/ 資料夾共找到 " + allFiles.size() + " 個 DRL: " + allFiles.keySet());
            } catch (Exception e) {
                LOG.severe("[Blob] 讀取 Salary/ 資料夾失敗: " + e.getMessage());
                allFiles = new HashMap<>();
            }

            Map<String, String> fileNameToContent = new HashMap<>();

            // ① 通用法定規則：永遠載入（非 Company_ 開頭的所有檔案）
            //    作為所有公司共用的法定底線（請假扣薪、加班費、全勤保障、結算）
            for (Map.Entry<String, String> entry : allFiles.entrySet()) {
                String fileName = entry.getKey();
                if (!fileName.startsWith("Company_")) {
                    fileNameToContent.put(fileName, entry.getValue());
                    LOG.info("[Drools] 載入通用法定規則: Salary/" + fileName);
                }
            }
            if (fileNameToContent.isEmpty() && allFiles.containsKey("salary.drl")) {
                fileNameToContent.put("salary.drl", allFiles.get("salary.drl"));
                LOG.info("[Drools] 找到通用規則 fallback: Salary/salary.drl");
            }

            // ② 公司客製化規則：Company_{companyId}_Salary.drl
            //    額外「疊加」在通用法定規則之上（同一 KieBase）
            //    隔離由規則內的 companyId 守衛保證：A 客製只對 A 員工觸發
            if (companyId != null && !companyId.isBlank()) {
                String companyFileName = "Company_" + companyId.trim() + "_Salary.drl";
                if (allFiles.containsKey(companyFileName)) {
                    fileNameToContent.put(companyFileName, allFiles.get(companyFileName));
                    LOG.info("[Drools] 疊加公司客製化規則: Salary/" + companyFileName);
                } else {
                    LOG.info("[Drools] 公司 [" + companyId + "] 無客製化規則，僅套用通用法定規則");
                }
            }

            if (fileNameToContent.isEmpty()) {
                LOG.severe("[Drools] 模組 [" + moduleName + "] 公司 [" + companyId
                        + "] 找不到任何 DRL（已掃描 Salary/ 資料夾），建置中止");
                return null;
            }

            LOG.info("[Drools] 公司 [" + companyId + "] 最終載入規則: " + fileNameToContent.keySet());

            // 編譯
            KieServices ks  = KieServices.Factory.get();
            KieFileSystem kfs = ks.newKieFileSystem();
            for (Map.Entry<String, String> entry : toVirtualPaths(moduleName, fileNameToContent).entrySet()) {
                kfs.write(entry.getKey(), entry.getValue());
                LOG.info("[Drools] 已寫入虛擬路徑: " + entry.getKey());
            }

            KieBuilder kb = ks.newKieBuilder(kfs);
            kb.buildAll();
            if (kb.getResults().hasMessages(Message.Level.ERROR)) {
                LOG.severe("[Drools] 動態編譯失敗: " + kb.getResults().getMessages().toString());
                return null;
            }

            LOG.info("[Drools] 模組 [" + moduleName + "] 公司 [" + companyId + "] KieContainer 建置成功");
            return ks.newKieContainer(ks.getRepository().getDefaultReleaseId());
        });
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 清除快取（規則更新後必須呼叫）
    // ─────────────────────────────────────────────────────────────────────────────
    public static void invalidateContainerCache(String moduleName, String companyId) {
        String cleanModuleName = moduleName != null ? moduleName.trim().toLowerCase() : "";
        String cleanCompanyId  = (companyId != null && !companyId.isBlank())
                ? companyId.trim().toLowerCase() : "default";
        String containerKey    = cleanModuleName + "_company_" + cleanCompanyId;
        if (DYNAMIC_CONTAINERS.remove(containerKey) != null)
            LOG.info("[Drools] 已清除快取 Key: " + containerKey);
    }

    // ─────────────────────────────────────────────────────────────────────────────
    // 執行通用動態規則（批次 facts 版本）
    // ─────────────────────────────────────────────────────────────────────────────
    public static void executeUniversalRules(String moduleName, String companyId, List<Object> facts) {
        KieContainer container = getOrCreateDynamicContainer(moduleName, companyId);
        if (container == null) { LOG.severe("[Drools] KieContainer 取得失敗"); return; }
        KieSession kieSession = container.newKieSession();
        try {
            for (Object fact : facts) if (fact != null) kieSession.insert(fact);
            int fired = kieSession.fireAllRules();
            LOG.info("[Drools] 模組 [" + moduleName + "] 觸發 " + fired + " 條規則");
        } finally { kieSession.dispose(); }
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ Classpath 靜態 Session
    // ══════════════════════════════════════════════════════════════════

    public static KieSession getTimeCheckSession() { return CLASSPATH_CONTAINER.newKieSession("TimeCheckSession"); }
    public static KieSession getClockSession()     { return CLASSPATH_CONTAINER.newKieSession("ClockSession"); }

    public static KieSession getLeaveSession(String companyId) {
        LOG.info("[KieLeaveSession] companyId=" + companyId);
        return CLASSPATH_CONTAINER.newKieSession("LeaveSession");
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ Salary 動態 Session
    // ══════════════════════════════════════════════════════════════════

    public static KieSession getSalarySession(String companyId) {
        KieContainer container = getOrCreateDynamicContainer("salary", companyId);
        if (container == null)
            throw new RuntimeException("[KieSession] salary 規則尚未載入，請確認 Blob Storage 有對應規則檔案");
        return container.newKieSession();
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ 通用動態 Session（EvaluateUniversalFunction 使用）
    // ══════════════════════════════════════════════════════════════════

    public static KieSession getDynamicSession(String moduleName, String companyId) {
        KieContainer container = getOrCreateDynamicContainer(moduleName, null);
        if (container == null) return null;
        return container.newKieSession();
    }

    /** 向下相容：無 companyId 版本 */
    public static KieSession getDynamicSession(String moduleName) {
        return getDynamicSession(moduleName, null);
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ CalculateOvertimeFunction instance 方法
    // ══════════════════════════════════════════════════════════════════

    public KieSession getKieSession(String ruleSet, ExecutionContext context) {
        if (context != null) context.getLogger().info("[KieSession] getKieSession() ruleSet=" + ruleSet);
        return switch (ruleSet == null ? "" : ruleSet.toLowerCase()) {
            case "timecheck"  -> getTimeCheckSession();
            case "clock"      -> getClockSession();
            case "leave"      -> getLeaveSession(null);
            case "overtime"   -> CLASSPATH_CONTAINER.newKieSession("OvertimeSession");
            case "scheduling" -> CLASSPATH_CONTAINER.newKieSession("SchedulingSession");
            case "salary"     -> getSalarySession(null);
            default -> throw new IllegalArgumentException("未知的 ruleSet: " + ruleSet);
        };
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ CheckSchedulingFunction 排班規則執行
    // ══════════════════════════════════════════════════════════════════

    public static void executeStateless(String ruleSet, ExecutionContext context,
                                        com.function.model.SchedulingFact fact,
                                        com.function.model.SchedulingResult result) {
        if (context != null) context.getLogger().info("[KieStateless] ruleSet=" + ruleSet);
        StatelessKieSession session = CLASSPATH_CONTAINER.newStatelessKieSession("SchedulingStatelessSession");
        List<Command> commands = new ArrayList<>();
        commands.add(CommandFactory.newInsert(fact));
        commands.add(CommandFactory.newInsert(result));
        commands.add(CommandFactory.newFireAllRules());
        session.execute(CommandFactory.newBatchExecution(commands));
    }

    public static void executeStatefulGroup(String ruleSet, ExecutionContext context,
                                            List<com.function.model.SchedulingFact> facts,
                                            com.function.model.SchedulingResult result) {
        if (context != null) context.getLogger().info("[KieStateful] ruleSet=" + ruleSet + " facts=" + facts.size());
        KieSession session = null;
        try {
            session = CLASSPATH_CONTAINER.newKieSession("SchedulingSession");
            session.insert(result);
            facts.stream().sorted(Comparator.comparingInt(f -> f.getMetaInt("dayIndex"))).forEach(session::insert);
            int fired = session.fireAllRules();
            if (context != null) context.getLogger().info("[KieStateful] rulesFired=" + fired);
        } catch (Exception e) {
            LOG.severe("[KieStateful] 執行失敗：" + e.getMessage());
            result.addViolation("SYSTEM_ERROR", "跨日規則執行異常：" + e.getMessage());
        } finally {
            if (session != null) try { session.dispose(); } catch (Exception ex) { LOG.warning("[KieStateful] dispose 失敗：" + ex.getMessage()); }
        }
    }

    // ══════════════════════════════════════════════════════════════════
    // ★ 規則更新方法
    // ══════════════════════════════════════════════════════════════════

    /** Salary + 公司 */
    public static String updateCompanySalaryRules(String companyId, String fileName, String drlContent) {
        if (companyId  == null || companyId.isBlank())   return "ERROR: companyId must not be null or blank.";
        if (fileName   == null || fileName.isBlank())    return "ERROR: fileName must not be null or blank.";
        if (drlContent == null || drlContent.isBlank())  return "ERROR: drlContent must not be null or blank.";
        try {
            new DrlStorageService().uploadDrl("Salary/" + fileName, drlContent);
            LOG.info("[Blob] 公司 [" + companyId + "] Salary 規則已上傳: Salary/" + fileName);
        } catch (Exception e) { return "BLOB_PERSIST_ERROR: " + e.getMessage(); }
        invalidateContainerCache("salary", companyId);
        return "SUCCESS";
    }

    /** Salary 通用（不分公司） */
    public static String updateSalaryRules(Map<String, String> fileNameToContent) {
        if (fileNameToContent == null || fileNameToContent.isEmpty())
            return "ERROR: fileNameToContent must not be null or empty.";
        try {
            DrlStorageService storage = new DrlStorageService();
            for (Map.Entry<String, String> entry : fileNameToContent.entrySet()) {
                if (entry.getValue() == null || entry.getValue().isBlank())
                    return "ERROR: content for '" + entry.getKey() + "' must not be blank.";
                storage.uploadDrl("Salary/" + entry.getKey(), entry.getValue());
            }
            LOG.info("[Blob] Salary 通用規則已儲存: " + fileNameToContent.keySet());
        } catch (Exception e) { return "BLOB_PERSIST_ERROR: " + e.getMessage(); }
        invalidateContainerCache("salary", null);
        return "SUCCESS";
    }

    /**
     * 非 Salary 通用規則（無公司）
     */
    public static String updateDynamicRules(String ruleSet, String drlContent) {
        if (ruleSet    == null || ruleSet.isBlank())    return "ERROR: ruleSet must not be null or blank.";
        if (drlContent == null || drlContent.isBlank()) return "ERROR: drlContent must not be null or blank.";
        try {
            DrlStorageService storage = new DrlStorageService();
            storage.uploadDrl(ruleSet + "/" + ruleSet + ".drl", drlContent);
            LOG.info("[Blob] 通用動態規則已儲存: " + ruleSet);
        } catch (Exception e) { return "BLOB_PERSIST_ERROR: " + e.getMessage(); }
        invalidateContainerCache(ruleSet, null);
        invalidateContainerCache(ruleSet, "default");
        return "SUCCESS";
    }

    /**
     * 非 Salary 公司客製化規則（有公司）
     */
    public static String updateDynamicRules(String ruleSet, String companyId, String drlContent) {
        if (ruleSet    == null || ruleSet.isBlank())    return "ERROR: ruleSet must not be null or blank.";
        if (companyId  == null || companyId.isBlank())  return "ERROR: companyId must not be null or blank.";
        if (drlContent == null || drlContent.isBlank()) return "ERROR: drlContent must not be null or blank.";
        try {
            String blobPath = ruleSet + "/" + companyId + "/" + ruleSet + ".drl";
            new DrlStorageService().uploadDrl(blobPath, drlContent);
            LOG.info("[Blob] 公司 [" + companyId + "] 動態規則已儲存: " + blobPath);
        } catch (Exception e) { return "BLOB_PERSIST_ERROR: " + e.getMessage(); }
        invalidateContainerCache(ruleSet, companyId);
        return "SUCCESS";
    }

    // ══════════════════════════════════════════════════════════════════
    // 私有工具方法
    // ══════════════════════════════════════════════════════════════════

    private static String buildCompanyContainerKey(String companyId) {
        return "salary_company_" + companyId.toLowerCase();
    }

    private static String extractCompanyId(String fileName) {
        if (fileName == null || !fileName.startsWith("Company_")) return null;
        String[] parts = fileName.split("_", 3);
        if (parts.length < 3) return null;
        return parts[1];
    }

    private static Map<String, String> toVirtualPaths(String moduleName, Map<String, String> fileNameToContent) {
        Map<String, String> result = new HashMap<>();
        String cleanModuleName = moduleName.trim().toLowerCase();
        for (Map.Entry<String, String> entry : fileNameToContent.entrySet())
            result.put("src/main/resources/rules/" + cleanModuleName + "/" + entry.getKey(), entry.getValue());
        return result;
    }

    private static Map<String, String> toVirtualPaths(Map<String, String> fileNameToContent) {
        return toVirtualPaths("salary", fileNameToContent);
    }

    private static String stripPackageAndImports(String drl) {
        StringBuilder sb = new StringBuilder();
        for (String line : drl.split("\n")) {
            String trimmed = line.stripLeading();
            if (trimmed.startsWith("package ") || trimmed.startsWith("import ") || trimmed.startsWith("global ")) continue;
            sb.append(line).append("\n");
        }
        return sb.toString();
    }
}