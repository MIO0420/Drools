// package com.function.benchmark;

// import com.function.legacy.LeaveCalculatorLegacy;
// import com.function.model.EmployeeFact;
// import com.function.model.LeaveFact;
// import com.function.model.LeaveResult;
// import com.function.service.KieSessionService;
// import org.junit.jupiter.api.BeforeAll;
// import org.junit.jupiter.api.DisplayName;
// import org.junit.jupiter.api.Test;
// import org.kie.api.command.Command;
// import org.kie.api.runtime.StatelessKieSession;
// import org.kie.internal.command.CommandFactory;

// import java.math.BigDecimal;
// import java.util.ArrayList;
// import java.util.List;

// import static org.junit.jupiter.api.Assertions.*;

// @DisplayName("請假計算：規則引擎 vs if-else 正確率驗證")
// class LeaveAccuracyTest {

//     private static EmployeeFact emp;
//     private static LeaveCalculatorLegacy legacy;
//     private static StatelessKieSession kieSession;

//     @BeforeAll
//     static void setup() {
//         emp = new EmployeeFact();
//         emp.setEmployeeId("E001");
//         emp.setBaseSalary(new BigDecimal("30000"));
//         emp.setTenureMonths(12);
//         emp.setSeniorityMonths(36);

//         legacy     = new LeaveCalculatorLegacy();
//         kieSession = new KieSessionService().getStatelessKieSession("leave", null);
//     }

//     // ══════════════════════════════════════════════
//     // 婚假 Marriage Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("婚假 3 天（正常核准）")
//     void test_MarriageLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("MARRIAGE", 3, 24, 0, null);
//         LeaveFact legacyLeave = buildLeave("婚假",     3, 24, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准婚假");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准婚假");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 婚假不應扣薪");
//         assertEquals(0, ifelse.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Legacy 婚假不應扣薪");

//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Marriage Leave - Approved"),
//                 "Drools appliedRule 應包含 Marriage Leave - Approved，實際=" + drools.getAppliedRule());
//         assertTrue(ifelse.getAppliedRule() != null
//                 && ifelse.getAppliedRule().contains("Marriage Leave - Approved"),
//                 "Legacy appliedRule 應包含 Marriage Leave - Approved，實際=" + ifelse.getAppliedRule());
//     }

//     @Test
//     @DisplayName("婚假 10 天（超過上限）")
//     void test_MarriageLeave_Exceeds() {
//         LeaveFact droolsLeave = buildLeave("MARRIAGE", 10, 80, 0, null);
//         LeaveFact legacyLeave = buildLeave("婚假",     10, 80, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertFalse(drools.isApproved(), "Drools 應拒絕婚假超限，實際=" + drools.isApproved());
//         assertFalse(ifelse.isApproved(), "Legacy 應拒絕婚假超限，實際=" + ifelse.isApproved());

//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Marriage Leave - Exceeds Limit"),
//                 "Drools appliedRule 應包含 Marriage Leave - Exceeds Limit，實際=" + drools.getAppliedRule());
//         assertTrue(ifelse.getAppliedRule() != null
//                 && ifelse.getAppliedRule().contains("Marriage Leave - Exceeds Limit"),
//                 "Legacy appliedRule 應包含 Marriage Leave - Exceeds Limit，實際=" + ifelse.getAppliedRule());
//     }

//     // ══════════════════════════════════════════════
//     // 喪假 Bereavement Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("喪假 父母 6 天（正常核准）")
//     void test_BereavementLeave_Parents_Approved() {
//         LeaveFact droolsLeave = buildLeave("BEREAVEMENT", 6, 48, 0, "PARENT");
//         LeaveFact legacyLeave = buildLeave("喪假",        6, 48, 0, "父母");

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准喪假（父母）");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准喪假（父母）");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 喪假不應扣薪");
//         assertEquals(0, ifelse.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Legacy 喪假不應扣薪");

//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Bereavement Leave - Spouse or Parents - Approved"),
//                 "Drools appliedRule 應包含 Bereavement Leave - Spouse or Parents - Approved，實際=" + drools.getAppliedRule());
//         assertTrue(ifelse.getAppliedRule() != null
//                 && ifelse.getAppliedRule().contains("Bereavement Leave - Spouse or Parents - Approved"),
//                 "Legacy appliedRule 應包含 Bereavement Leave - Spouse or Parents - Approved，實際=" + ifelse.getAppliedRule());
//     }

//     @Test
//     @DisplayName("喪假 父母 9 天（超過上限）")
//     void test_BereavementLeave_Parents_Exceeds() {
//         LeaveFact droolsLeave = buildLeave("BEREAVEMENT", 9, 72, 0, "PARENT");
//         LeaveFact legacyLeave = buildLeave("喪假",        9, 72, 0, "父母");

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertFalse(drools.isApproved(), "Drools 應拒絕喪假（父母）超限，實際=" + drools.isApproved());
//         assertFalse(ifelse.isApproved(), "Legacy 應拒絕喪假（父母）超限，實際=" + ifelse.isApproved());

//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Bereavement Leave - Spouse or Parents - Exceeds Limit"),
//                 "Drools appliedRule 應包含 Exceeds Limit，實際=" + drools.getAppliedRule());
//         assertTrue(ifelse.getAppliedRule() != null
//                 && ifelse.getAppliedRule().contains("Bereavement Leave - Spouse or Parents - Exceeds Limit"),
//                 "Legacy appliedRule 應包含 Exceeds Limit，實際=" + ifelse.getAppliedRule());
//     }

//     @Test
//     @DisplayName("喪假 兄弟姊妹 3 天（正常核准）")
//     void test_BereavementLeave_Siblings_Approved() {
//         LeaveFact droolsLeave = buildLeave("BEREAVEMENT", 3, 24, 0, "SIBLING");
//         LeaveFact legacyLeave = buildLeave("喪假",        3, 24, 0, "兄弟姊妹");

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准喪假（兄弟姊妹）");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准喪假（兄弟姊妹）");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 喪假不應扣薪");
//         assertEquals(0, ifelse.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Legacy 喪假不應扣薪");
//     }

//     // ══════════════════════════════════════════════
//     // 事假 Personal Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("事假 2 天（正常核准，DRL 不扣薪）")
//     void test_PersonalLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("PERSONAL", 2, 16, 0, null);
//         LeaveFact legacyLeave = buildLeave("事假",     2, 16, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准事假");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准事假");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 事假 deductAmount 應為 0，實際=" + drools.getDeductAmount());
//     }

//     @Test
//     @DisplayName("事假 超過年度上限（14 天已用完）")
//     void test_PersonalLeave_Exceeds() {
//         LeaveFact droolsLeave = buildLeave("PERSONAL", 3, 24, 14, null);
//         LeaveFact legacyLeave = buildLeave("事假",     3, 24, 14, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertFalse(drools.isApproved(), "Drools 應拒絕事假超限，實際=" + drools.isApproved());
//         assertFalse(ifelse.isApproved(), "Legacy 應拒絕事假超限，實際=" + ifelse.isApproved());
//     }

//     // ══════════════════════════════════════════════
//     // 普通傷病假 Sick Leave（門診）
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("普通傷病假 5 天（門診，正常核准）")
//     void test_SickLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("SICK", 5, 40, 0, null);
//         droolsLeave.setHospitalized(false);

//         LeaveResult drools = executeDrools(droolsLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准普通傷病假（門診）");
//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 普通傷病假 deductAmount=" + drools.getDeductAmount());
//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Sick Leave Outpatient - Approved"),
//                 "Drools appliedRule 應包含 Sick Leave Outpatient - Approved，實際=" + drools.getAppliedRule());
//     }

//     // ══════════════════════════════════════════════
//     // 特別休假 Annual Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("特別休假 3 天（年資 3 年，全薪不扣）")
//     void test_AnnualLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("ANNUAL", 3, 24, 2, null);

//         LeaveResult drools = executeDrools(droolsLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准特別休假");
//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "特別休假不應扣薪");
//         assertEquals(9, drools.getRemainingDays(),
//                 "14 - 2(used) - 3(apply) = 9 日，實際=" + drools.getRemainingDays());
//     }

//     // ══════════════════════════════════════════════
//     // 產假 Maternity Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("產假 56 天（年資 3 年，全薪核准）")
//     void test_MaternityLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("MATERNITY", 56, 448, 0, null);
//         LeaveFact legacyLeave = buildLeave("產假",      56, 448, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准產假");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准產假");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 產假不應扣薪");

//         assertTrue(drools.getAppliedRule() != null
//                 && drools.getAppliedRule().contains("Maternity Leave"),
//                 "Drools appliedRule 應包含 Maternity Leave，實際=" + drools.getAppliedRule());
//         assertTrue(ifelse.getAppliedRule() != null
//                 && ifelse.getAppliedRule().contains("Maternity Leave"),
//                 "Legacy appliedRule 應包含 Maternity Leave，實際=" + ifelse.getAppliedRule());
//     }

//     // ══════════════════════════════════════════════
//     // 陪產假 Paternity Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("陪產假 7 天（正常核准）")
//     void test_PaternityLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("PATERNITY", 7, 56, 0, null);
//         LeaveFact legacyLeave = buildLeave("陪產假",    7, 56, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准陪產假");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准陪產假");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 陪產假不應扣薪");

//         assertEquals("Paternity Leave - Approved", drools.getAppliedRule(),
//                 "Drools appliedRule 應為 Paternity Leave - Approved，實際=" + drools.getAppliedRule());
//         assertEquals("Paternity Leave - Approved", ifelse.getAppliedRule(),
//                 "Legacy appliedRule 應為 Paternity Leave - Approved，實際=" + ifelse.getAppliedRule());
//     }

//     // ══════════════════════════════════════════════
//     // 公假 Official Leave
//     // ══════════════════════════════════════════════

//     @Test
//     @DisplayName("公假 2 天（全薪，不扣全勤）")
//     void test_OfficialLeave_Approved() {
//         LeaveFact droolsLeave = buildLeave("OFFICIAL", 2, 16, 0, null);
//         LeaveFact legacyLeave = buildLeave("公假",     2, 16, 0, null);

//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);

//         assertTrue(drools.isApproved(), "Drools 應核准公假");
//         assertTrue(ifelse.isApproved(), "Legacy 應核准公假");

//         assertEquals(0, drools.getDeductAmount().compareTo(BigDecimal.ZERO),
//                 "Drools 公假不應扣薪");

//         assertEquals("Official Leave - Approved", drools.getAppliedRule(),
//                 "Drools appliedRule 應為 Official Leave - Approved，實際=" + drools.getAppliedRule());
//         assertEquals("Official Leave - Approved", ifelse.getAppliedRule(),
//                 "Legacy appliedRule 應為 Official Leave - Approved，實際=" + ifelse.getAppliedRule());
//     }

//     // ══════════════════════════════════════════════
//     // 工具方法
//     // ══════════════════════════════════════════════

//     private void assertApprovedMatch(LeaveFact droolsLeave, LeaveFact legacyLeave) {
//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);
//         assertEquals(drools.isApproved(), ifelse.isApproved(),
//                 "approved 不一致：Drools=" + drools.isApproved()
//                 + " Legacy=" + ifelse.isApproved());
//     }

//     private void assertDeductMatch(LeaveFact droolsLeave, LeaveFact legacyLeave) {
//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);
//         assertEquals(0, drools.getDeductAmount().compareTo(ifelse.getDeductAmount()),
//                 "deductAmount 不一致：Drools=" + drools.getDeductAmount()
//                 + " Legacy=" + ifelse.getDeductAmount());
//     }

//     private void assertBothRejected(LeaveFact droolsLeave, LeaveFact legacyLeave) {
//         LeaveResult drools = executeDrools(droolsLeave);
//         LeaveResult ifelse = legacy.calculate(emp, legacyLeave);
//         assertFalse(drools.isApproved(), "Drools 應拒絕，實際=" + drools.isApproved());
//         assertFalse(ifelse.isApproved(), "Legacy 應拒絕，實際=" + ifelse.isApproved());
//     }

//     private LeaveResult executeDrools(LeaveFact leave) {
//         LeaveResult result = new LeaveResult();
//         result.setEmployeeId(emp.getEmployeeId());
//         result.setApproved(true);

//         List<Command> cmds = new ArrayList<>();
//         cmds.add(CommandFactory.newInsert(emp));
//         cmds.add(CommandFactory.newInsert(leave));
//         cmds.add(CommandFactory.newInsert(result));
//         cmds.add(CommandFactory.newFireAllRules());
//         kieSession.execute(CommandFactory.newBatchExecution(cmds));
//         return result;
//     }

//     private LeaveFact buildLeave(String type, int days, int hours,
//                                   int usedDays, String relation) {
//         LeaveFact lf = new LeaveFact();
//         lf.setLeaveTypeName(type);   // ✅ 修正：setLeaveType → setLeaveTypeName
//         lf.setLeaveDays(new BigDecimal(String.valueOf(days)));
//         lf.setLeaveHours(new BigDecimal(String.valueOf(hours)));
//         lf.setUsedDaysThisYear(usedDays);
//         if (relation != null) lf.setBereavementRelation(relation);
//         return lf;
//     }
// }
