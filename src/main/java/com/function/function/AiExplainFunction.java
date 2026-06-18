package com.function.function;

import com.microsoft.azure.functions.*;
import com.microsoft.azure.functions.annotation.*;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.function.function.config.Config;
import com.function.service.DrlStorageService;

import java.io.*;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.*;

public class AiExplainFunction {

    // =========================================================
    // 系統固定的 Fact 欄位字典（給 ai/parse-rule 的 conditions[].field 用）
    // ---------------------------------------------------------
    // 與 GenerateRuleFunction.FIELD_DICTIONARY 概念一致，但這裡只列出
    // 「欄位名稱、型別、可能值」，因為 ai/parse-rule 輸出的是
    // conditions: [{ field, operator, value }] 這種純資料格式，
    // 不是 Java 程式碼，不需要描述 getter/putMeta 等存取方式。
    //
    // 目的：讓 AI 在填寫 conditions[].field 時，優先使用這裡列出的
    // 標準欄位名稱，避免同一個業務概念在不同次呼叫中被翻譯成
    // 不同的英文欄位名（例如 monthlyOvertimeHours 有時被寫成
    // overtimeHoursInMonth，isChildWorker 被寫成 employeeAgeGroup=="童工"）。
    //
    // 這是系統固定知識，之後如需新增欄位，只需要在這裡加一行即可。
    // =========================================================
    private static final String FIELD_DICTIONARY =
        "── 員工基本資料與法規管制欄位（對應 EmployeeFact）──\n" +
        "  position: String（職位，可能值包含 MANAGER/DIRECTOR/VP/C_LEVEL 等管理層級）\n" +
        "  identity: String（身分類別，例如：正職、工讀生）\n" +
        "  baseSalary: number（底薪）\n" +
        "  tenureMonths / seniorityMonths: number（任職月數 / 年資月數）\n" +
        "  monthlyOvertimeHours: number（本月累計加班時數）\n" +
        "  quarterlyOvertimeHours: number（本季累計加班時數）\n" +
        "  laborCouncilAgreed: boolean（是否經勞資會議同意延長工時）\n" +
        "  consecutiveWorkDays: number（連續出勤天數）\n" +
        "  restDaysPerWeek: number（每週休息天數）\n" +
        "  isChildWorker: boolean（是否為童工 — 描述「童工」時請用此欄位 + value:true，"
        + "不要另外發明 employeeAgeGroup 等欄位）\n" +
        "  dailyWorkHours / weeklyWorkHours: number（童工每日/每週工時）\n" +
        "  isPregnantOrNursing: boolean（是否妊娠或哺乳中 — 描述「懷孕或哺乳」時請用此單一欄位 + value:true，"
        + "不要拆成 isPregnant / isNursing 兩個欄位）\n\n" +

        "── 加班相關欄位（對應 OvertimeFact）──\n" +
        "  overtimeType: String（固定列舉值，只能是以下四種英文字串：\n" +
        "    \"WEEKDAY\"（平日）、\"REST_DAY\"（休息日）、\"NATIONAL_HOLIDAY\"（國定假日）、\"REGULAR_DAY_OFF\"（例假日）\n" +
        "    描述「平日/休息日/國定假日」加班時，value 一律填上方對應的英文字串，不要填中文）\n" +
        "  overtimeHours: number（本次加班時數）\n" +
        "  overtimeDate: String\n" +
        "  compensatoryTimeOff: boolean（是否選擇補休）\n" +
        "  compensatoryExpired: boolean（補休是否已過期）\n" +
        "  disasterException: boolean（是否為天災出勤例外 — 描述「天災出勤」「颱風天出勤」等情境時，"
        + "請統一使用此欄位，不要又用 isTyphoonDay 又用 isDisasterDay 等不同名稱表示相同概念）\n\n" +

        "── 出勤打卡相關欄位（對應 TimeCheckFact）──\n" +
        "  late / earlyLeave / earlyArrival: boolean\n" +
        "  totalWorkHours / overtimeHours: number\n" +
        "  lateMinutesCache: number\n" +
        "  distanceToCompany: number（打卡地點與公司距離，單位公尺 — 描述「打卡距離」時請用此欄位名，"
        + "不要寫成 distanceFromCompany）\n\n" +

        "── 請假相關欄位 ──\n" +
        "  leaveTypeName: String（請假類型，例如：事假、病假、婚假 — 描述「請假類型」時，"
        + "value 請保留中文原文，例如 \"事假\"，不要翻譯成英文 \"personal\"）\n" +
        "  leaveDays: number（本次請假天數）\n" +
        "  usedDaysThisYear: number（今年已使用天數）\n" +
        "  （注意：「本次請假天數加上今年已用天數是否超過上限」這種累加比較邏輯，"
        + "請拆成兩個獨立欄位 leaveDays 與 usedDaysThisYear 分別列在 conditions 中，"
        + "不要發明一個「currentYearPersonalLeaveDaysPlusRequested」之類的自動計算欄位）\n\n" +

        "── 自訂業務維度欄位（多角色/多情境拆解規則時常用）──\n" +
        "  employeeRole: String（員工角色，可能值固定為：\"主管\"、\"員工\"、\"工讀生\"，"
        + "請使用這三個中文值，不要翻譯成 MANAGER/EMPLOYEE/PART_TIME 等英文）\n" +
        "  totalProjectBudget: number（員工所屬專案總預算）\n\n" +

        "── 通用結果欄位（outputValue 對應的 key 命名建議）──\n" +
        "  payMultiplier：加班費倍率\n" +
        "  violationType：違規類型描述\n";

    // =========================================================
    // DRL -> Java 轉譯用：API 字典（只准用這些，確保能編譯且與 DRL 對齊）
    // =========================================================
    private static final String JAVA_API_DICTIONARY =
        "【目標介面 CompanySalaryRule（只有 3 個抽象方法必須實作）】\n"
      + "  String getCompanyId();\n"
      + "  double getSeniorityMultiplier(int seniorityMonths);\n"
      + "  Map<String,BigDecimal> getCustomAllowances(EmployeeFact employee, boolean hasFullAttendance, boolean hasOvertime);\n"
      + "  其餘皆為 default，只在 DRL 有對應規則時覆寫：\n"
      + "    default boolean hasCustomOvertimeCalc();\n"
      + "    default void    processOvertimeBonus(EmployeeFact employee, List<OvertimeFact> overtimes, SalaryResult result);\n"
      + "    default boolean hasCustomLeaveDeduction();\n"
      + "    default boolean processLeaveDeductions(EmployeeFact employee, List<LeaveFact> leaves, SalaryResult result);\n\n"
      + "【可用 getter（只准用這些；若與實際 model 不符，請以 model 為準）】\n"
      + "  EmployeeFact: getBaseSalary():BigDecimal, getMonthlyOvertimeHours():BigDecimal, getTenureMonths():int, getSeniorityMonths():int\n"
      + "  OvertimeFact: getOvertimeType():String, getOvertimeHours():BigDecimal\n"
      + "  LeaveFact:    getLeaveTypeName():String, getLeaveHours():BigDecimal, getLeaveDays():BigDecimal\n"
      + "  SalaryResult: getOvertimeBonus():BigDecimal, setOvertimeBonus(BigDecimal), getLeaveDeduction():BigDecimal, setLeaveDeduction(BigDecimal), addRuleDetail(String)\n\n"
      + "【金額計算：保留 DRL then 區出現的 RuleUtils 呼叫原樣，不要自己改公式】\n"
      + "  calcWeekdayOvertime / calcRestDayOvertime / calcNationalHolidayOvertime / calcStatutoryHolidayOvertime\n"
      + "    (BigDecimal baseSalary, BigDecimal overtimeHours):BigDecimal\n"
      + "  calcWeekdayOvertimeByRate(BigDecimal baseSalary, BigDecimal overtimeHours, String rate1, String rate2):BigDecimal\n"
      + "  calcLeaveDeduction(BigDecimal baseSalary, BigDecimal leaveHours, String rate):BigDecimal\n";

    private static final String JAVA_TRANSPILE_SYS =
        "你是 Drools/Java 專家。任務：把一份 DRL 規則檔，等價轉譯成一個可直接編譯的 Java 類別，"
      + "實作 com.function.function.SalaryRules.CompanySalaryRule。語意必須與 DRL 完全相同。\n\n"
      + "【轉譯規則】\n"
      + "1. DRL 的 then(結果區)本來就是 Java：把 $emp->employee、$ot->ot(迴圈變數)、$leave->lv(迴圈變數)、$result->result，"
      + "其中 RuleUtils.xxx(...) 的呼叫【原封不動保留】。\n"
      + "2. DRL 的 when(條件區)：每個 `$ot : OvertimeFact(條件...)` 轉成 `for (OvertimeFact ot : overtimes) { if(條件){...} }`；"
      + "`$leave : LeaveFact(條件...)` 同理用 lv 走訪 leaves；EmployeeFact 與 SalaryResult 是單一的 employee / result 參數。\n"
      + "3. DRL 內 companyId == \"X\" 這種公司守衛可省略（類別本身已是該公司專屬）。\n"
      + "4. DRL 裡所有『加班費類』規則合併進 processOvertimeBonus；所有『請假扣薪類』規則合併進 processLeaveDeductions；"
      + "對應的 hasCustomOvertimeCalc()/hasCustomLeaveDeduction() 回 true。\n"
      + "5. 一定要實作 3 個抽象方法：getCompanyId() 回 \"{ID}\"；getSeniorityMultiplier 回 1.0；getCustomAllowances(3參數) 回 Collections.emptyMap()。\n"
      + "6. 類別名 Company{ID}Rule，package com.function.function.SalaryRules。走訪 List 前做 null 防護。\n"
      + "7. 只輸出純 Java，不要 markdown、不要 ``` 圍欄、不要解說。\n\n"
      + JAVA_API_DICTIONARY;

    // =========================================================
    // ① DRL → 自然語言解讀
    //    POST /api/ai/explain
    //    Body: { "drlContent": "..." }
    // =========================================================
    @FunctionName("AiExplain")
    public HttpResponseMessage explain(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST, HttpMethod.OPTIONS},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "ai/explain")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        if (request.getHttpMethod() == HttpMethod.OPTIONS) return corsPreFlight(request);

        try {
            String apiKey = getApiKey();
            if (apiKey == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "IAI_API_KEY 未設定");

            ObjectMapper mapper = new ObjectMapper();
            @SuppressWarnings("unchecked")
            Map<String, String> reqBody = mapper.readValue(request.getBody().orElse("{}"), Map.class);
            String drlContent = reqBody.getOrDefault("drlContent", "");
            if (drlContent.isBlank()) return errorResponse(request, HttpStatus.BAD_REQUEST, "Missing drlContent");

            String prompt = "你是一位熟悉台灣勞動法規的 HR 系統專家。\n"
                + "請將以下 Drools DRL 規則翻譯成繁體中文的自然語言說明，讓一般 HR 人員可以看懂。\n\n"
                + "格式要求：\n"
                + "1. 用一句話說明「這條規則的目的」\n"
                + "2. 條列「觸發條件」（什麼情況下會套用）\n"
                + "3. 條列「執行結果」（套用後會發生什麼）\n"
                + "4. 如有法條依據，請標注\n\n"
                + "DRL 規則內容：\n```\n" + drlContent + "\n```\n\n"
                + "請直接輸出中文說明，不要加任何程式碼區塊或 markdown 標題。";

            String aiText = callIai(apiKey, mapper, null, prompt);
            if (aiText == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "iAI 回應失敗");

            Map<String, String> resp = new LinkedHashMap<>();
            resp.put("text", aiText);
            return okResponse(request, mapper, resp);

        } catch (Exception e) {
            context.getLogger().severe("[AiExplain] " + e.getMessage());
            return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "Exception: " + e.getMessage());
        }
    }

    // =========================================================
    // ② 自然語言 → 規則參數 JSON（供前端自動填表）
    //    POST /api/ai/parse-rule
    //    Body: { "text": "...", "ruleSet": "...", "companyId": "..." }
    // =========================================================
    @FunctionName("AiParseRule")
    public HttpResponseMessage parseRule(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST, HttpMethod.OPTIONS},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "ai/parse-rule")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        if (request.getHttpMethod() == HttpMethod.OPTIONS) return corsPreFlight(request);

        try {
            String apiKey = getApiKey();
            if (apiKey == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "IAI_API_KEY 未設定");

            ObjectMapper mapper = new ObjectMapper();
            @SuppressWarnings("unchecked")
            Map<String, Object> reqBody = mapper.readValue(request.getBody().orElse("{}"), Map.class);
            String naturalText = (String) reqBody.getOrDefault("text", "");
            String ruleSet     = (String) reqBody.getOrDefault("ruleSet", "timecheck");
            String companyId   = (String) reqBody.getOrDefault("companyId", "");
            @SuppressWarnings("unchecked")
            List<Map<String, String>> history = (List<Map<String, String>>) reqBody.getOrDefault("history", new ArrayList<>());
            if (naturalText.isBlank()) return errorResponse(request, HttpStatus.BAD_REQUEST, "Missing text");

            String systemPrompt =
                "你是一位熟悉台灣勞動法規的 Drools 規則引擎專家。\n"
                + "使用者會用自然語言描述一條或多條 HR 規則，你需要將它解析成結構化 JSON。\n\n"

                + "【★★★ 最重要：何時要拆成多條規則 ★★★】\n"
                + "如果使用者的描述中，同一個條件（例如某個情境、某個時間點）"
                + "依「不同身分／角色／類別」會對應到「不同的數值或結果」，"
                + "你必須將其拆解成『多條獨立的規則』，每一條規則只對應一種身分／角色／類別與其數值，"
                + "絕對不要把多個身分硬塞進同一條規則的 conditions 裡，也不要只挑其中一個身分而漏掉其他的。\n\n"
                + "範例：\n"
                + "使用者輸入：「颱風天如果有出勤加班，主管加班費算4倍，一般員工算2倍，工讀生算1.5倍。」\n"
                + "正確輸出：一個 JSON 陣列，包含 3 個元素：\n"
                + "  [\n"
                + "    { ...規則1：employeeRole == \"主管\"，對應 value 為 4 ... },\n"
                + "    { ...規則2：employeeRole == \"員工\"，對應 value 為 2 ... },\n"
                + "    { ...規則3：employeeRole == \"工讀生\"，對應 value 為 1.5 ... }\n"
                + "  ]\n"
                + "錯誤輸出（禁止）：只回傳 1 條規則、或把 3 個身分塞進同一個 conditions 陣列、"
                + "或用同一個 conditions 陣列但只填一個 value。\n\n"
                + "如果使用者描述的是單一規則（沒有「依身分/角色對應不同數值」的情況），"
                + "仍然要回傳一個只包含 1 個元素的 JSON 陣列，格式保持一致。\n\n"

                + "【★★★ 欄位命名規範 - 非常重要 ★★★】\n"
                + "填寫 conditions[].field 時，請先檢查下方欄位字典中是否有對應的標準欄位名稱與可能值，"
                + "若有，必須使用字典中的名稱與值，不要自行發明替代名稱或翻譯成其他語言。\n"
                + "只有當欄位字典中完全找不到對應概念時，才自行命名新的英文駝峰式欄位名稱。\n\n"
                + FIELD_DICTIONARY + "\n"

                + "【★★★ ruleSet 選擇規則 - 非常重要 ★★★】\n"
                + "系統預先定義了以下六大模組，這六個是固定的 ruleSet 名稱，新規則應優先附加進去：\n\n"
                + "  1. overtime   — 加班「時數」相關：月加班時數上限、休息日加班時數上限、補休、\n"
                + "                  童工/妊娠禁止加班、連假出勤時數限制。\n"
                + "                  ★ overtime 只管「時數有沒有超、能不能加班」，不計算金額。\n"
                + "                  ★ 禁止歸入 overtime：加班費金額、倍率、工資計算——這些全部屬於 salary。\n\n"
                + "  2. salary     — 薪資與「費率/金額」相關：加班費倍率計算（平日1.34倍、休息日1.67倍、\n"
                + "                  國定假日2倍、颱風天主管4倍…）、底薪扣薪、全勤獎金、\n"
                + "                  請假扣薪、各身分/角色對應的薪資加成比率。\n"
                + "                  ★ 只要有「倍率、金額、工資計算」就是 salary，即使情境是加班也一樣。\n"
                + "                  ★ 「颱風天主管4倍/員工2倍/工讀生1.5倍」→ salary，不是 overtime。\n"
                + "                  ★ 「國定假日1.34倍」→ salary。「休息日加班費」→ salary。\n\n"
                + "  3. leave      — 請假審核：假單天數限制、假別條件、病假住院、事假年度上限。\n"
                + "                  ★ 跟「請假、假單、假別、請假天數」有關，歸 leave。\n\n"
                + "  4. scheduling — 排班管理：連續工作天數限制、輪班休息時數、每週休假天數。\n"
                + "                  ★ 跟「連續出勤天數、排班、輪班」有關，歸 scheduling。\n\n"
                + "  5. timecheck  — 出勤時間：遲到、早退、曠職、高溫/颱風免出勤、出勤時間異常。\n"
                + "                  ★ 跟「打卡時間點、遲到早退、是否需要出勤」有關，歸 timecheck。\n\n"
                + "  6. clock      — 打卡記錄：打卡地點異常、補打卡條件、打卡距離超出範圍。\n"
                + "                  ★ 跟「打卡行為本身（地點、距離、補打卡）」有關，歸 clock。\n\n"
                + "【自訂模組（isCustomModule: true）使用條件】\n"
                + "只有明確不屬於以上六大模組時才使用自訂名稱，例如：\n"
                + "  salary_budget_check（低薪高預算檢核）、bonus_calc（獎金計算）、performance（績效評估）\n"
                + "禁止：不要創建 overtime_typhoon、salary_holiday 等「模組的子集」，\n"
                + "      颱風天/假日加班費倍率一律歸 salary，不另開子模組。\n\n"
                + "【★★★ 公司區隔（companyId）— 非常重要 ★★★】\n"
                + "系統支援依公司隔離規則，規則儲存路徑會依是否有 companyId 而不同：\n"
                + "  - 有 companyId → 儲存為 Company_<companyId>_<ruleSet>.drl（只對該公司生效）\n"
                + "  - 無 companyId → 儲存為 <ruleSet>.drl（對所有公司生效的共用規則）\n\n"
                + "因此，如果使用者描述的規則是「某公司特有的」或「針對特定公司的」，\n"
                + "conditions 裡必須加入 companyId 條件：\n"
                + "  { \"field\": \"companyId\", \"operator\": \"==\", \"value\": \"<公司ID>\" }\n"
                + "如果是一般性的勞基法規定（適用所有公司），則不加 companyId 條件。\n\n"
                + "【ruleSet 判斷流程】\n"
                + "第一步：規則涉及「時數上限/能否加班」→ overtime\n"
                + "        規則涉及「費率/金額/倍率/工資」→ salary（即使場景是加班）\n"
                + "        規則涉及「請假天數/假別」→ leave\n"
                + "        規則涉及「連續出勤/排班」→ scheduling\n"
                + "        規則涉及「遲到早退/是否出勤」→ timecheck\n"
                + "        規則涉及「打卡地點/距離/補打卡」→ clock\n"
                + "第二步：以上都不符合 → 自訂模組名稱，isCustomModule: true\n\n"
                + "【各模組可用的動作（action）】\n"
                + "- overtime:   addWarning（警告）、addViolation（記違規）、setAppliedRule（設定套用規則）\n"
                + "- salary:     addWarning、addNote、addRuleDetail、fullAttendanceExempt、addLeaveDeduction、addOvertimeBonus\n"
                + "\n【★★★ salary 計算參數必須填入 actionWarning（非常重要）★★★】\n"
                + "對 salary 模組的這兩個計算動作，實際被引擎拿去計算的『參數』一律填入 actionWarning 欄位，\n"
                + "不可只寫在 actionNote 文字裡（actionNote 只是給人看的說明，不會被計算）：\n"
                + "  - action = addLeaveDeduction（請假扣薪）：actionWarning 必須填『扣薪比率』數字字串。\n"
                + "      全額扣薪填 \"1.0\"、半薪填 \"0.5\"、三成填 \"0.3\"。\n"
                + "      範例：使用者說「事假只扣一半薪水」→ action:\"addLeaveDeduction\", actionWarning:\"0.5\"。\n"
                + "      若使用者明確給了比率（如 0.5），務必把該數字放進 actionWarning，不要漏填或填成 1.0。\n"
                + "  - action = addOvertimeBonus（加班費）：actionWarning 必須填『計算方法名稱』，\n"
                + "      可用值：calcWeekdayOvertime（平日法定1.34/1.67倍）、calcRestDayOvertime（休息日）、\n"
                + "      calcNationalHolidayOvertime（國定假日）、calcStatutoryHolidayOvertime（例假日/特休）。\n"
                + "      範例：平日加班(法定) → action:\"addOvertimeBonus\", actionWarning:\"calcWeekdayOvertime\"。\n"
                + "      ★ 若使用者指定『自訂平日加班倍率』(非法定)，例如「前兩小時2倍、超過兩小時4倍」，\n"
                + "        actionWarning 填 \"calcWeekdayOvertimeByRate:<前2H倍率>:<超過2H倍率>\"，\n"
                + "        例：「前兩小時2倍、超過兩小時4倍」→ actionWarning:\"calcWeekdayOvertimeByRate:2:4\"。\n"
                + "        並把兩個倍率數字也寫進 actionNote（例如「前兩小時2倍、超過兩小時4倍」）。\n"
                + "actionNote 仍可填中文說明（會顯示在規則明細），但真正的計算參數一定要同時填進 actionWarning。\n"
                + "- leave:      addWarning（如需審核）、addNote（備註）、addViolation（違規）\n"
                + "- scheduling: addViolation（記違規）、addWarning（警告）、addNote（備註）\n"
                + "- timecheck:  exemptAll（免出勤）、exemptLate（免遲到）、exemptEarlyLeave（免早退）、addViolation\n"
                + "- clock:      addNote（備註）、addWarning（警告）、addViolation\n"
                + "- 自訂模組:   addWarning、addViolation、addNote、setValue（設定自訂值）\n\n"
                + "【其他重要提醒】\n"
                + "- companyId 條件代表公司限定規則，必須保留在 conditions 中\n"
                + "- 自訂欄位（不在預設清單的欄位）可以直接使用，後端透過 getMetaDouble/getMetaString/getMetaBool 讀取\n"
                + "- 若拆解成多條規則，每條規則的 ruleName 請加上不同的後綴以區分（例如 typhoon_salary_manager、"
                + "typhoon_salary_employee、typhoon_salary_parttime），activationGroup 可以共用同一個群組名稱\n\n"

                + "你必須只回傳一個 JSON 陣列（即使只有 1 條規則也要用陣列包起來），"
                + "不要加任何說明文字、markdown 或程式碼區塊。陣列中每個元素的格式如下：\n"
                + "{\n"
                + "  \"understood\": \"用一句話複述你理解的這一條規則內容（繁體中文）\",\n"
                + "  \"ruleSet\": \"規則集名稱（標準模組或自訂模組英文名稱）\",\n"
                + "  \"isCustomModule\": true/false（是否為自訂通用模組）,\n"
                + "  \"ruleName\": \"英文規則名稱（無空格，用底線）\",\n"
                + "  \"activationGroup\": \"群組標籤（英文）\",\n"
                + "  \"priority\": 數字,\n"
                + "  \"action\": \"動作類型\",\n"
                + "  \"actionNote\": \"備註訊息（中文）\",\n"
                + "  \"actionWarning\": \"addWarning 時填警告訊息；salary 的 addLeaveDeduction 填扣薪比率(如 0.5)、addOvertimeBonus 填計算方法名稱(如 calcWeekdayOvertime)\",\n"
                + "  \"conditions\": [\n"
                + "    { \"field\": \"欄位名稱\", \"operator\": \"==/!=/>/>=/</<=\", \"value\": 值 }\n"
                + "  ],\n"
                + "  \"outputValue\": 數值或字串（此規則對應的計算結果，例如倍率4、2、1.5；若規則不涉及輸出數值則填 null）,\n"
                + "  \"questions\": [\"如果有不確定的地方，列出需要使用者確認的問題（繁體中文），無則空陣列\"]\n"
                + "}\n\n"
                + "整個回應的最外層必須是 [ ... ]，陣列中包含 1 條或多條上述格式的規則物件。";

            String userPrompt = "規則集建議：" + ruleSet
                + (companyId.isBlank()
                    ? "\n公司範圍：無（此規則適用所有公司，conditions 中不要加 companyId 條件）"
                    : "\n公司 ID：" + companyId + "（此規則只對此公司生效，conditions 中必須加入 companyId == \"" + companyId + "\" 條件）")
                + "\n\n使用者描述：" + naturalText;

            // ★ 帶入對話歷史（多輪對話）
            List<Map<String, Object>> messages = new ArrayList<>();
            // 加入歷史訊息（排除最後一條，最後一條就是本次 userPrompt）
            for (int i = 0; i < history.size() - 1; i++) {
                Map<String, String> h = history.get(i);
                Map<String, Object> hMsg = new LinkedHashMap<>();
                hMsg.put("role", h.getOrDefault("role", "user"));
                hMsg.put("content", h.getOrDefault("content", ""));
                messages.add(hMsg);
            }
            // 加入本次使用者訊息
            Map<String, Object> userMsg = new LinkedHashMap<>();
            userMsg.put("role", "user");
            userMsg.put("content", userPrompt);
            messages.add(userMsg);

            String aiText = callIaiWithMessages(apiKey, mapper, systemPrompt, messages);
            if (aiText == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "iAI 回應失敗");

            // 清理 AI 可能包住的 ```json ``` 區塊
            String cleaned = aiText.trim()
                .replaceAll("(?s)^```(?:json)?\\s*", "")
                .replaceAll("(?s)\\s*```$", "")
                .trim();

            // 驗證是否合法 JSON
            Object parsed = mapper.readValue(cleaned, Object.class);

            // 防呆：理論上 system prompt 已要求一律回傳陣列，
            // 但若模型仍回傳單一物件，自動包成只有 1 個元素的陣列，
            // 確保前端與後續流程永遠拿到 List<RuleJson> 的結構
            List<Object> rulesArray;
            if (parsed instanceof List) {
                @SuppressWarnings("unchecked")
                List<Object> list = (List<Object>) parsed;
                rulesArray = list;
            } else {
                rulesArray = new ArrayList<>();
                rulesArray.add(parsed);
            }

            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json")
                    .header("Access-Control-Allow-Origin", "*")
                    .body(mapper.writeValueAsString(rulesArray))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("[AiParseRule] " + e.getMessage());
            return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "Exception: " + e.getMessage());
        }
    }

    // =========================================================
    // ③ 語義一致性評分（Round-Trip Semantic Consistency）
    //    POST /api/ai/score-consistency
    //    Body: { "originalText": "...", "backTranslation": "..." }
    //
    //    用途：
    //    originalText    = 使用者原始的自然語言需求描述
    //    backTranslation = 由 /api/ai/explain 對「自然語言轉換出的DRL」
    //                       反向解釋出來的中文說明
    //    回傳：AI 判斷這兩段文字語義是否一致的評分結果，
    //          用於量化「自然語言轉DRL過程是否誤解原意」。
    // =========================================================
    @FunctionName("AiScoreConsistency")
    public HttpResponseMessage scoreConsistency(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST, HttpMethod.OPTIONS},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "ai/score-consistency")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        if (request.getHttpMethod() == HttpMethod.OPTIONS) return corsPreFlight(request);

        try {
            String apiKey = getApiKey();
            if (apiKey == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "IAI_API_KEY 未設定");

            ObjectMapper mapper = new ObjectMapper();
            @SuppressWarnings("unchecked")
            Map<String, String> reqBody = mapper.readValue(request.getBody().orElse("{}"), Map.class);
            String originalText    = reqBody.getOrDefault("originalText", "");
            String backTranslation = reqBody.getOrDefault("backTranslation", "");

            if (originalText.isBlank())    return errorResponse(request, HttpStatus.BAD_REQUEST, "Missing originalText");
            if (backTranslation.isBlank()) return errorResponse(request, HttpStatus.BAD_REQUEST, "Missing backTranslation");

            String systemPrompt =
                "你是一個語義一致性評估專家，負責評估「自然語言需求」與「規則引擎反向解釋說明」之間的語義一致程度。\n\n"

                + "【評分原則：語義等價 vs 核心詞彙錯誤】\n\n"

                + "★ 以下情況「不扣分」（語義等價，可接受）：\n"
                + "1. 反向說明補充了原文沒提到的「法條依據」或「法律條號」\n"
                + "   → 這是系統知識補充，不代表語義不一致，不應列入 missing_points 或 incorrect_points\n"
                + "2. 反向說明補充了「後續處理流程」（如「通知HR」、「啟動稽核」）\n"
                + "   → 屬合理延伸，原文沒說但也沒有矛盾\n"
                + "3. 同義詞替換、語義等價的表達：\n"
                + "   - 「工讀生」≈ 「工讀生或兼職員工」（語義包含，不算錯）\n"
                + "   - 「月加班超時」≈ 「月加班超時違規」（語義相同，不算錯）\n"
                + "   - 「有問題」≈ 「異常」（同義表達，不算錯）\n"
                + "   - 「算違規」≈ 「標記違規」（同義動作，不算錯）\n"
                + "4. 反向說明使用了更正式的專業用語表達相同概念\n\n"

                + "★ 以下情況「必須扣分」（核心業務詞彙錯誤或遺漏）：\n"
                + "1. 原文要求「標記為 X 字串」，反向說明用了完全不同的字串\n"
                + "   例：原文要求標記「打卡地點超出公司範圍500公尺」\n"
                + "       反向說明寫成「打卡地點異常」→ 核心標記文字錯誤，必須扣分\n"
                + "2. 原文提到多個身分/角色對應不同數值，反向說明漏掉其中某個身分或寫錯其倍率/數值\n"
                + "   例：原文說主管4倍、員工2倍、工讀生1.5倍，但反向說明只提到2種 → 必須扣分\n"
                + "3. 觸發條件被改變或遺漏（例如原文說「超過46小時且勞資會議未同意」，反向說明漏掉其中一個條件）\n"
                + "4. 反向說明新增了與原文矛盾的邏輯（例如原文說「不算違規」，反向說明卻標記為違規）\n"
                + "5. 數值錯誤（例如原文說14天，反向說明寫成7天）\n\n"

                + "【評分標準】\n"
                + "- 95~100：核心邏輯、觸發條件、執行結果、所有數值完全一致，允許語義等價的用詞差異\n"
                + "- 85~94：有微小細節差異但不影響業務邏輯的正確執行\n"
                + "- 70~84：有 1~2 個核心業務點遺漏或用詞錯誤（如標記文字被替換）\n"
                + "- 50~69：有多個核心點錯誤或重要觸發條件被遺漏\n"
                + "- 0~49：反向說明與原始需求在業務邏輯上嚴重不符\n\n"

                + "你必須只回傳以下格式的 JSON，不要加任何說明文字、markdown 或程式碼區塊：\n"
                + "{\n"
                + "  \"score\": 0~100 的整數，代表語義一致程度,\n"
                + "  \"missing_points\": [\"原文有但反向說明遺漏的核心業務邏輯點（排除法條補充、流程補充等合理延伸）\"],\n"
                + "  \"incorrect_points\": [\"反向說明中數值錯誤、核心標記文字被替換、或與原文矛盾的地方\"],\n"
                + "  \"reasoning\": \"簡短說明評分理由（繁體中文），重點說明哪些是核心業務差異、哪些是可接受的語義等價\"\n"
                + "}";

            String userPrompt =
                "【原始需求描述】\n" + originalText + "\n\n"
                + "【規則引擎反向解釋出來的說明】\n" + backTranslation;

            String aiText = callIai(apiKey, mapper, systemPrompt, userPrompt);
            if (aiText == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "iAI 回應失敗");

            // 清理 AI 可能包住的 ```json ``` 區塊
            String cleaned = aiText.trim()
                .replaceAll("(?s)^```(?:json)?\\s*", "")
                .replaceAll("(?s)\\s*```$", "")
                .trim();

            // 驗證是否合法 JSON，成功就直接回傳
            Object parsed = mapper.readValue(cleaned, Object.class);
            return request.createResponseBuilder(HttpStatus.OK)
                    .header("Content-Type", "application/json")
                    .header("Access-Control-Allow-Origin", "*")
                    .body(mapper.writeValueAsString(parsed))
                    .build();

        } catch (Exception e) {
            context.getLogger().severe("[AiScoreConsistency] " + e.getMessage());
            return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "Exception: " + e.getMessage());
        }
    }

    // =========================================================
    // ④ DRL → Java 轉譯（規則引擎規則 → 硬編碼對照組）
    //    POST /api/ai/generate-java
    //    Body（三選一）：
    //      { "companyId":"10" }                                  // 伺服器查 DRL 後轉譯（主要用法）
    //      { "companyId":"10", "drl":"<DRL內容>" }               // 直接給 DRL 轉譯
    //      { "companyId":"10", "previousCode":"...", "compileError":"..." } // 修復編譯錯誤
    //    回應： { companyId, className, javaCode, sourceDrlChars }
    // =========================================================
    @FunctionName("AiGenerateJava")
    public HttpResponseMessage generateJava(
            @HttpTrigger(
                name = "req",
                methods = {HttpMethod.POST, HttpMethod.OPTIONS},
                authLevel = AuthorizationLevel.ANONYMOUS,
                route = "ai/generate-java")
            HttpRequestMessage<Optional<String>> request,
            final ExecutionContext context) {

        if (request.getHttpMethod() == HttpMethod.OPTIONS) return corsPreFlight(request);

        try {
            String apiKey = getApiKey();
            if (apiKey == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "IAI_API_KEY 未設定");

            ObjectMapper mapper = new ObjectMapper();
            @SuppressWarnings("unchecked")
            Map<String, Object> reqBody = mapper.readValue(request.getBody().orElse("{}"), Map.class);
            String companyId = str(reqBody.get("companyId"));
            String drl       = str(reqBody.get("drl"));
            String prevCode  = str(reqBody.get("previousCode"));
            String compileEr = str(reqBody.get("compileError"));
            if (companyId.isBlank()) return errorResponse(request, HttpStatus.BAD_REQUEST, "Missing companyId");

            String sys = JAVA_TRANSPILE_SYS.replace("{ID}", companyId);
            String userPrompt;
            int srcChars = 0;

            if (!compileEr.isBlank() && !prevCode.isBlank()) {
                // 修復模式：把編譯錯誤丟回去要 AI 改
                userPrompt = "以下 Java 編譯失敗，請修正後重新輸出完整類別（只輸出純 Java）：\n\n"
                           + "=== 編譯錯誤 ===\n" + compileEr + "\n\n=== 目前程式碼 ===\n" + prevCode;
            } else {
                // 查詢 DRL：未直接帶 drl 就用 companyId 去 Blob 查
                if (drl.isBlank()) {
                    String blobKey = "Salary/Company_" + companyId + "_Salary.drl";
                    drl = new DrlStorageService().downloadDrl(blobKey);
                    if (drl == null || drl.isBlank())
                        return errorResponse(request, HttpStatus.BAD_REQUEST,
                            "查不到 DRL: " + blobKey + "（請先用 NL->DRL 寫入該公司規則）");
                }
                srcChars = drl.length();
                userPrompt = "公司 ID：" + companyId + "\n以下是要轉譯的 DRL：\n\n" + drl
                           + "\n\n請輸出 Company" + companyId + "Rule 的完整 Java 原始碼。";
            }

            String aiText = callIai(apiKey, mapper, sys, userPrompt);
            if (aiText == null) return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "iAI 回應失敗");

            // 清掉 AI 可能多包的 ```java ... ``` 圍欄
            String javaCode = aiText.trim()
                .replaceAll("(?s)^```(?:java)?\\s*", "")
                .replaceAll("(?s)\\s*```$", "")
                .trim() + "\n";

            Map<String, Object> resp = new LinkedHashMap<>();
            resp.put("companyId", companyId);
            resp.put("className", "Company" + companyId + "Rule");
            resp.put("javaCode",  javaCode);
            resp.put("sourceDrlChars", srcChars);
            return okResponse(request, mapper, resp);

        } catch (Exception e) {
            context.getLogger().severe("[AiGenerateJava] " + e.getMessage());
            return errorResponse(request, HttpStatus.INTERNAL_SERVER_ERROR, "Exception: " + e.getMessage());
        }
    }

    // null 安全轉字串（generateJava 用）
    private static String str(Object o) { return o == null ? "" : o.toString(); }

    // =========================================================
    // 共用：呼叫高科 iAI（帶預建 messages list，支援多輪對話）
    // =========================================================
    private String callIaiWithMessages(String apiKey, ObjectMapper mapper,
                                        String systemPrompt,
                                        List<Map<String, Object>> messages) throws Exception {
        List<Map<String, Object>> allMessages = new ArrayList<>();
        if (systemPrompt != null && !systemPrompt.isBlank()) {
            Map<String, Object> sys = new LinkedHashMap<>();
            sys.put("role", "system");
            sys.put("content", systemPrompt);
            allMessages.add(sys);
        }
        allMessages.addAll(messages);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", Config.IAI_MODEL);
        body.put("messages", allMessages);

        return callIaiRaw(apiKey, mapper, body);
    }

    // =========================================================
    // 共用：呼叫高科 iAI（簡單 system + user 版本）
    // =========================================================
    private String callIai(String apiKey, ObjectMapper mapper,
                            String systemPrompt, String userPrompt) throws Exception {
        List<Map<String, Object>> messages = new ArrayList<>();
        if (systemPrompt != null && !systemPrompt.isBlank()) {
            Map<String, Object> sys = new LinkedHashMap<>();
            sys.put("role", "system");
            sys.put("content", systemPrompt);
            messages.add(sys);
        }
        Map<String, Object> user = new LinkedHashMap<>();
        user.put("role", "user");
        user.put("content", userPrompt);
        messages.add(user);

        Map<String, Object> body = new LinkedHashMap<>();
        body.put("model", Config.IAI_MODEL);
        body.put("messages", messages);
        return callIaiRaw(apiKey, mapper, body);
    }

    private String callIaiRaw(String apiKey, ObjectMapper mapper,
                               Map<String, Object> iaiBody) throws Exception {
        String requestJson = mapper.writeValueAsString(iaiBody);
        URL url = new URL(Config.IAI_API_URL);
        HttpURLConnection conn = (HttpURLConnection) url.openConnection();
        conn.setRequestMethod("POST");
        conn.setRequestProperty("Content-Type", "application/json");
        conn.setRequestProperty("Authorization", "Bearer " + apiKey);
        conn.setDoOutput(true);
        conn.setConnectTimeout(15000);
        conn.setReadTimeout(60000);

        try (OutputStream os = conn.getOutputStream()) {
            os.write(requestJson.getBytes(StandardCharsets.UTF_8));
        }

        int statusCode = conn.getResponseCode();
        InputStream is = statusCode >= 400 ? conn.getErrorStream() : conn.getInputStream();
        String responseBody;
        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line).append("\n");
            responseBody = sb.toString();
        }

        if (statusCode != 200) return null;

        @SuppressWarnings("unchecked")
        Map<String, Object> iaiData = mapper.readValue(responseBody, Map.class);
        @SuppressWarnings("unchecked")
        List<Map<String, Object>> choices = (List<Map<String, Object>>) iaiData.get("choices");
        if (choices == null || choices.isEmpty()) return null;
        @SuppressWarnings("unchecked")
        Map<String, Object> msg = (Map<String, Object>) choices.get(0).get("message");
        return msg != null ? (String) msg.get("content") : null;
    }

    // =========================================================
    // 共用工具方法
    // =========================================================
    private String getApiKey() {
        String key = Config.IAI_API_KEY;
        return (key == null || key.isBlank()) ? null : key;
    }

    private HttpResponseMessage corsPreFlight(HttpRequestMessage<Optional<String>> request) {
        return request.createResponseBuilder(HttpStatus.NO_CONTENT)
                .header("Access-Control-Allow-Origin",  "*")
                .header("Access-Control-Allow-Methods", "POST, OPTIONS")
                .header("Access-Control-Allow-Headers", "Content-Type")
                .build();
    }

    private HttpResponseMessage okResponse(HttpRequestMessage<Optional<String>> request,
                                            ObjectMapper mapper, Object body) throws Exception {
        return request.createResponseBuilder(HttpStatus.OK)
                .header("Content-Type", "application/json")
                .header("Access-Control-Allow-Origin", "*")
                .body(mapper.writeValueAsString(body))
                .build();
    }

    private HttpResponseMessage errorResponse(HttpRequestMessage<Optional<String>> request,
                                               HttpStatus status, String message) {
        try {
            ObjectMapper mapper = new ObjectMapper();
            Map<String, String> err = new LinkedHashMap<>();
            err.put("error", message);
            return request.createResponseBuilder(status)
                    .header("Content-Type", "application/json")
                    .header("Access-Control-Allow-Origin", "*")
                    .body(mapper.writeValueAsString(err))
                    .build();
        } catch (Exception e) {
            return request.createResponseBuilder(status)
                    .header("Access-Control-Allow-Origin", "*")
                    .body("{\"error\":\"" + message + "\"}")
                    .build();
        }
    }
}