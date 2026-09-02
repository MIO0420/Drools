# Drools 規則引擎（Azure Functions）

以 [Drools](https://www.drools.org/) 規則引擎為核心，並以 **Java + Maven** 開發、部署於 **Azure Functions** 的規則運算服務。

---

## 目錄

- [專案簡介](#專案簡介)
- [功能列表（API Endpoints）](#功能列表api-endpoints)
- [技術架構](#技術架構)
- [專案結構](#專案結構)
- [環境需求](#環境需求)
- [本機開發與執行](#本機開發與執行)
- [編譯指令](#編譯指令)
- [部署到 Azure 雲端](#部署到-azure-雲端)
- [設定說明](#設定說明)
- [常見問題](#常見問題)

---

## 專案簡介

本專案將 Drools 規則引擎封裝成 Azure Functions，透過 HTTP 觸發器（HTTP Trigger）接收請求、載入 DRL 規則、執行規則運算後回傳結果，適合作為無伺服器（Serverless）架構下的規則判斷服務。

系統以**台灣勞動基準法（勞基法）**為主要應用場景，涵蓋薪資、加班、請假、排班、出勤打卡等 HR 規則運算，並支援依 `companyId` 隔離的**公司客製化規則**，以及透過 AI 產生／解讀 DRL 規則的功能。

---

## 功能列表（API Endpoints）

所有 Function 皆為 **HTTP Trigger**、`authLevel` 為 `ANONYMOUS`，本機路徑前綴為 `http://localhost:7071/api/`，雲端則為 `https://<你的FunctionApp>.azurewebsites.net/api/`。

### 規則運算（核心業務）

| 功能 | 方法 | 路由 | 說明 |
|------|------|------|------|
| **CalculateSalary** | POST | `calculatesalary` | 薪資計算主流程。彙整員工、出勤、加班、請假、津貼、保險、績效、專案等多種 Fact 進行綜合薪資運算，支援大量資料分批（chunk）處理，並透過 Application Insights 上報記憶體與效能。 |
| **CalculateOvertime** | POST | `calculateovertime` | 加班費與加班合規檢查。依勞基法第 32、32-1、36、47、50~51 條，處理平日／休息日／國定假日／例假日加班、月季時數上限、連續出勤、補休、天災例外、童工與妊娠哺乳保護等規則。 |
| **CalculateLeave** | POST | `calculateleave` | 請假審核與扣薪計算。依 `companyId` 載入對應規則集，判斷假別（事假、病假、婚假、喪假等）、天數上限、住院、妊娠週數等條件並決定是否核准。 |
| **CheckScheduling** | POST | `checkscheduling` | 排班合規檢查（單筆／批次）。檢查連續工作天數、每週休假天數、輪班休息時數等排班規則。 |
| **CheckSchedulingCrossDay** | POST | `checkscheduling/crossday` | 跨日排班合規檢查，處理跨日班別的相關規則。 |
| **CheckTime** | POST | `checktime` | 出勤時間檢查（單筆／批次）。以 DRL 計算遲到、早退、早到、總工時、加班時數等，計算邏輯全數交由規則引擎處理。 |
| **CheckClock** | POST | `checkclock` | 打卡地點檢查。後端以 Haversine 公式計算打卡座標與公司座標的距離（不信任前端傳入距離），再交由規則引擎判斷打卡是否合規。 |
| **EvaluateUniversal** | POST | `evaluate/{moduleName}` | 通用規則評估入口。依路徑 `moduleName` 動態載入規則模組，並優先套用公司客製規則、找不到時 fallback 至通用規則。 |

### 規則管理

| 功能 | 方法 | 路由 | 說明 |
|------|------|------|------|
| **QueryRules** | GET | `rules/{*ruleSet}` | 查詢指定規則集目前的 DRL 內容（支援 CORS 預檢）。 |
| **UpdateRules** | POST | `updaterules` | 新增／更新規則。可接收結構化條件（conditions/action）自動組成 DRL，或直接接收 `rawDrl`，並可選擇是否持久化存檔；支援公司客製規則。 |

### AI 輔助（產生／解讀規則）

| 功能 | 方法 | 路由 | 說明 |
|------|------|------|------|
| **GenerateRule** | POST | `generaterule` | 以自然語言透過 **Google Gemini** 產生 Drools DRL 規則，可選 `autoApply` 直接編譯套用。需設定環境變數 `GEMINI_API_KEY`。 |
| **AiExplain** | POST | `ai/explain` | 將 DRL 規則翻譯成繁體中文自然語言說明，方便 HR 人員閱讀。 |
| **AiParseRule** | POST | `ai/parse-rule` | 將自然語言需求解析為結構化規則資料（module、conditions、action 等），供 `UpdateRules` 使用。 |
| **AiScoreConsistency** | POST | `ai/score-consistency` | 評估規則的一致性／衝突程度並給出評分。 |
| **AiGenerateJava** | POST | `ai/generate-java` | 將 DRL 規則轉譯為可編譯的 Java 類別（實作 `CompanySalaryRule` 介面）。 |

> AI 相關功能需設定對應的 API 金鑰環境變數（`GEMINI_API_KEY`、`IAI_API_KEY` 等），詳見[設定說明](#設定說明)。

### 系統維運

| 功能 | 方法 | 路由 | 說明 |
|------|------|------|------|
| **triggerGC** | GET / POST | `gc` | 手動觸發 JVM 垃圾回收，用於觀察／釋放記憶體。 |
| **BenchmarkDrools** | POST | `benchmark/drools` | 效能測試：以 Drools 規則網路（Rete）執行員工／專案／關聯資料的聚合比對，回傳耗時與觸發規則數。 |
| **BenchmarkLegacy** | POST | `benchmark/legacy` | 效能測試對照組：以傳統巢狀迴圈（O(N³)）執行相同聚合邏輯，用來與 Drools 版本比較效能。 |
| **CheckSalaryLegacy** | POST | `checksalary/legacy` | 薪資檢查的傳統（非規則引擎）實作版本，作為對照。 |

---

## 技術架構

| 項目 | 說明 |
|------|------|
| 語言 | Java 17 |
| 建置工具 | Maven（含 `maven-shade-plugin`，故有 `dependency-reduced-pom.xml`）|
| 規則引擎 | Drools |
| 運算平台 | Azure Functions |
| 開發環境 | Visual Studio Code（`.vscode`）|

---

## 專案結構

```
Drools/
├── .mvn/                        # Maven Wrapper 設定
├── .vscode/                     # VS Code 開發環境設定
├── src/                         # 原始碼（Function 進入點與 Drools 規則）
├── target/                      # Maven 建置輸出目錄
├── host.json                    # Azure Functions 主機設定
├── local.settings.json          # 本機執行設定（勿上傳機密資訊）
├── pom.xml                      # Maven 專案設定與相依套件
├── dependency-reduced-pom.xml   # shade plugin 產生的精簡 pom
└── README.md
```

---

## 環境需求

請先在本機安裝下列工具：

| 工具 | 建議版本 | 說明 |
|------|----------|------|
| [JDK](https://learn.microsoft.com/azure/developer/java/fundamentals/) | 17 | 對應 `pom.xml` 與 Azure Function App runtime 版本 |
| [Maven](https://maven.apache.org/) | 3.6+ | 或使用專案內建的 `mvnw` |
| [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local) | v4 | 本機執行與部署 |
| [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) | 最新版 | 登入與資源管理 |

檢查安裝是否成功：

```bash
java -version
mvn -version
func --version
az --version
```

---

## 本機開發與執行

1. 複製專案：

   ```bash
   git clone https://github.com/MIO0420/Drools.git
   cd Drools
   ```

2. 於本機執行（先編譯再啟動 Functions 執行環境）：

   ```bash
   mvn clean package
   mvn azure-functions:run
   ```

   或使用 Core Tools 直接啟動已編譯的產物：

   ```bash
   func start
   ```

3. 服務啟動後，預設會顯示 HTTP Trigger 的本機網址，例如：

   ```
   http://localhost:7071/api/{FunctionName}
   ```

---

## 編譯指令

> 使用系統已安裝的 Maven；若要使用專案內建的 Maven Wrapper，將指令中的 `mvn` 換成 `./mvnw`（Windows 為 `mvnw.cmd`）即可。

清除舊產物並重新編譯打包：

```bash
mvn clean package
```

僅編譯（不打包）：

```bash
mvn clean compile
```

跳過測試以加速打包：

```bash
mvn clean package -DskipTests
```

編譯完成後，Azure Functions 的部署產物會輸出到：

```
target/azure-functions/<function-app-name>/
```

---

## 部署到 Azure 雲端

### 方法一：使用 Maven Plugin 部署（推薦）

Azure Functions 的 Maven 外掛（`azure-functions-maven-plugin`）通常已設定於 `pom.xml`，可直接一鍵部署。

1. 登入 Azure：

   ```bash
   az login
   ```

2. （若有多個訂用帳戶）指定要使用的訂用帳戶：

   ```bash
   az account set --subscription "<你的訂用帳戶名稱或 ID>"
   ```

3. 編譯並部署：

   ```bash
   mvn clean package
   mvn azure-functions:deploy
   ```

   部署完成後，終端機會顯示雲端上的 Function URL。

> 部署所需的資源群組、Function App 名稱、地區等設定，會讀取自 `pom.xml` 中 `azure-functions-maven-plugin` 的 `<configuration>` 區塊。

---

### 方法二：使用 Azure Functions Core Tools 部署

若 Azure 上已先建立好 Function App，也可用 Core Tools 直接發佈。

1. 登入 Azure：

   ```bash
   az login
   ```

2. 先在雲端建立資源（若尚未建立過，可參考以下範例）：

   ```bash
   # 建立資源群組
   az group create --name <資源群組名稱> --location eastasia

   # 建立儲存體帳戶
   az storage account create \
     --name <儲存體帳戶名稱> \
     --resource-group <資源群組名稱> \
     --location eastasia \
     --sku Standard_LRS

   # 建立 Function App（Java 執行環境）
   az functionapp create \
     --resource-group <資源群組名稱> \
     --consumption-plan-location eastasia \
     --runtime java \
     --runtime-version 17 \
     --functions-version 4 \
     --name <FunctionApp名稱> \
     --storage-account <儲存體帳戶名稱>
   ```

3. 編譯後發佈到指定的 Function App：

   ```bash
   mvn clean package
   func azure functionapp publish <FunctionApp名稱> --java
   ```

---

## 設定說明

### `host.json`

Azure Functions 主機層級的設定檔，控制 logging、擴充套件版本等全域行為。

### `local.settings.json`

**僅供本機執行使用**，包含連線字串等環境變數。此檔案不應包含正式環境機密，且建議加入 `.gitignore` 避免外洩。範例：

```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "java",
    "GEMINI_API_KEY": "<你的 Google Gemini API 金鑰>",
    "IAI_API_KEY": "<AI 服務金鑰（AiExplain 等功能使用）>"
  }
}
```

### 環境變數說明

| 變數名稱 | 用途 | 使用的功能 |
|----------|------|------------|
| `AzureWebJobsStorage` | Azure Functions 執行所需的儲存體連線字串；DRL 規則檔亦存放於此 Blob Storage | 全部；規則存取（QueryRules / UpdateRules 等）|
| `FUNCTIONS_WORKER_RUNTIME` | 固定為 `java` | 全部 |
| `GEMINI_API_KEY` | Google Gemini API 金鑰 | GenerateRule |
| `IAI_API_KEY` | AI 服務金鑰（規則解讀／轉譯）| AiExplain、AiParseRule、AiScoreConsistency、AiGenerateJava |

> 若未設定對應金鑰，相關 AI 功能會回傳錯誤（例如「環境變數 GEMINI_API_KEY 未設定」），但不影響其他規則運算功能。

部署到雲端後，正式環境的環境變數請改在 Azure 入口網站的
**Function App → 設定 → 環境變數（Application settings）** 中設定，**切勿**將金鑰寫入 `local.settings.json` 後上傳到 GitHub。

---

## 常見問題

**Q：`mvn azure-functions:deploy` 找不到部署目標？**
A：請確認 `pom.xml` 內 `azure-functions-maven-plugin` 的 `<configuration>` 已填入正確的 `<appName>`、`<resourceGroup>`、`<region>`。

**Q：部署後呼叫 API 回傳 401？**
A：檢查該 Function 的 `authLevel`。若設為 `function`，呼叫時需帶上 function key（`?code=<金鑰>`）。

**Q：Java 版本不符導致啟動失敗？**
A：請讓本機 JDK、`pom.xml` 的編譯版本、以及 Azure Function App 的 `runtime-version` 三者一致（例如皆為 17）。

---

## 授權

本專案為個人開發之規則引擎範例，如需商業使用請自行評估 Drools 與相關套件之授權條款。
