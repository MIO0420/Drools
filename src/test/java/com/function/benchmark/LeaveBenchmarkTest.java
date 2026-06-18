// package com.function.benchmark;

// import com.function.legacy.LeaveCalculatorLegacy;
// import com.function.model.EmployeeFact;
// import com.function.model.LeaveFact;
// import com.function.model.LeaveResult;
// import com.function.service.KieSessionService;
// import org.kie.api.command.Command;
// import org.kie.api.runtime.StatelessKieSession;
// import org.kie.internal.command.CommandFactory;
// import org.openjdk.jmh.annotations.*;
// import org.openjdk.jmh.runner.Runner;
// import org.openjdk.jmh.runner.options.Options;
// import org.openjdk.jmh.runner.options.OptionsBuilder;

// import java.math.BigDecimal;
// import java.util.ArrayList;
// import java.util.List;
// import java.util.concurrent.TimeUnit;

// @BenchmarkMode(Mode.AverageTime)
// @OutputTimeUnit(TimeUnit.MILLISECONDS)
// @State(Scope.Benchmark)
// @Warmup(iterations = 5, time = 1, timeUnit = TimeUnit.SECONDS)
// @Measurement(iterations = 10, time = 1, timeUnit = TimeUnit.SECONDS)
// @Fork(value = 2, jvmArgs = {"-Xms512m", "-Xmx1024m"})
// public class LeaveBenchmarkTest {

//     private EmployeeFact emp;
//     private LeaveCalculatorLegacy legacy;
//     private StatelessKieSession kieSession;

//     private LeaveFact singleLeave;
//     private List<LeaveFact> multiLeaves;
//     private List<LeaveFact> bulkLeaves;

//     @Setup(Level.Trial)
//     public void setup() {
//         emp = new EmployeeFact();
//         emp.setEmployeeId("E001");
//         emp.setBaseSalary(new BigDecimal("30000"));
//         emp.setTenureMonths(12);

//         legacy     = new LeaveCalculatorLegacy();
//         kieSession = new KieSessionService()
//                          .getStatelessKieSession("leave", null);

//         singleLeave = buildLeave("婚假", 3, 24, 0, null);

//         multiLeaves = new ArrayList<>();
//         multiLeaves.add(buildLeave("婚假",   3,  24, 0, null));
//         multiLeaves.add(buildLeave("事假",   2,  16, 0, null));
//         multiLeaves.add(buildLeave("病假",   5,  40, 0, null));
//         multiLeaves.add(buildLeave("特休",   3,  24, 2, null));
//         multiLeaves.add(buildLeave("喪假",   6,  48, 0, "父母"));
//         multiLeaves.add(buildLeave("陪產假", 5,  40, 0, null));

//         bulkLeaves = generateBulkLeaves(1000);
//     }

//     @Benchmark
//     public LeaveResult scene1_Drools_Single() {
//         return executeDrools(singleLeave);
//     }

//     @Benchmark
//     public LeaveResult scene1_Legacy_Single() {
//         return legacy.calculate(emp, singleLeave);
//     }

//     @Benchmark
//     public List<LeaveResult> scene2_Drools_Multi() {
//         List<LeaveResult> results = new ArrayList<>();
//         for (LeaveFact lf : multiLeaves) results.add(executeDrools(lf));
//         return results;
//     }

//     @Benchmark
//     public List<LeaveResult> scene2_Legacy_Multi() {
//         List<LeaveResult> results = new ArrayList<>();
//         for (LeaveFact lf : multiLeaves) results.add(legacy.calculate(emp, lf));
//         return results;
//     }

//     @Benchmark
//     public List<LeaveResult> scene3_Drools_Bulk() {
//         List<LeaveResult> results = new ArrayList<>();
//         for (LeaveFact lf : bulkLeaves) results.add(executeDrools(lf));
//         return results;
//     }

//     @Benchmark
//     public List<LeaveResult> scene3_Legacy_Bulk() {
//         List<LeaveResult> results = new ArrayList<>();
//         for (LeaveFact lf : bulkLeaves) results.add(legacy.calculate(emp, lf));
//         return results;
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

//     private List<LeaveFact> generateBulkLeaves(int count) {
//         String[] types     = {"婚假", "事假", "病假", "特休", "喪假", "陪產假", "產假", "公假"};
//         String[] relations = {"父母", "配偶", "祖父母", "兄弟姊妹"};
//         List<LeaveFact> list = new ArrayList<>();
//         for (int i = 0; i < count; i++) {
//             String type = types[i % types.length];
//             int days    = (i % 5) + 1;
//             String rel  = "喪假".equals(type) ? relations[i % relations.length] : null;
//             list.add(buildLeave(type, days, days * 8, i % 3, rel));
//         }
//         return list;
//     }

//     public static void main(String[] args) throws Exception {
//         Options opt = new OptionsBuilder()
//                 .include(LeaveBenchmarkTest.class.getSimpleName())
//                 .build();
//         new Runner(opt).run();
//     }
// }
