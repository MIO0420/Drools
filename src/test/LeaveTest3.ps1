# ============================================================
# 請假計算效能比較：4 種情境（多公司版 COMPANY_A / B / C）
#   情境1：Drools  單筆 × 140 次請求（循序）
#   情境2：Drools  批次 140 筆 × 1 次請求
#   情境3：Legacy  單筆 × 140 次請求（循序）
#   情境4：Legacy  批次 140 筆 × 1 次請求
# ============================================================

$baseUrl        = "https://droolshr-c5gca3e8acgfczab.eastus-01.azurewebsites.net/api"
$droolsSingle   = "$baseUrl/calculateleave"
$droolsBatch    = "$baseUrl/calculateleave/batch"
$legacySingle   = "$baseUrl/calculateleavelegacy"
$legacyBatch    = "$baseUrl/calculateleavelegacy/batch"

# ══════════════════════════════════════════════════════════════
# 140 筆測試資料（原 101 筆 COMPANY_A + 新增 39 筆 COMPANY_B/C）
# ══════════════════════════════════════════════════════════════
$testCases = @(
    # ──────────────────────────────────────────────────────────
    # COMPANY_A（原始 101 筆）
    # ──────────────────────────────────────────────────────────

    # MARRIAGE (10筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E001"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MARRIAGE"; leaveDays=3; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E002"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="MARRIAGE"; leaveDays=5; leaveHours=0; usedDaysThisYear=2;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E003"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MARRIAGE"; leaveDays=8; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E004"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="MARRIAGE"; leaveDays=9; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E005"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="MARRIAGE"; leaveDays=1; leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E006"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="MARRIAGE"; leaveDays=2; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E007"; baseSalary=28000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="MARRIAGE"; leaveDays=3; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E008"; baseSalary=55000; tenureMonths=72; seniorityMonths=72; leaveTypeName="MARRIAGE"; leaveDays=4; leaveHours=0; usedDaysThisYear=3;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E009"; baseSalary=42000; tenureMonths=18; seniorityMonths=18; leaveTypeName="MARRIAGE"; leaveDays=6; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E010"; baseSalary=38000; tenureMonths=30; seniorityMonths=30; leaveTypeName="MARRIAGE"; leaveDays=7; leaveHours=0; usedDaysThisYear=1;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # BEREAVEMENT (10筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E011"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="BEREAVEMENT"; leaveDays=3; leaveHours=0; usedDaysThisYear=0; bereavementRelation="SPOUSE";          deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E012"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="BEREAVEMENT"; leaveDays=8; leaveHours=0; usedDaysThisYear=0; bereavementRelation="PARENT";          deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E013"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="BEREAVEMENT"; leaveDays=9; leaveHours=0; usedDaysThisYear=0; bereavementRelation="PARENT";          deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E014"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="BEREAVEMENT"; leaveDays=6; leaveHours=0; usedDaysThisYear=0; bereavementRelation="GRANDPARENT";     deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E015"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="BEREAVEMENT"; leaveDays=7; leaveHours=0; usedDaysThisYear=0; bereavementRelation="GRANDPARENT";     deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E016"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="BEREAVEMENT"; leaveDays=3; leaveHours=0; usedDaysThisYear=0; bereavementRelation="SIBLING";         deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E017"; baseSalary=28000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="BEREAVEMENT"; leaveDays=4; leaveHours=0; usedDaysThisYear=0; bereavementRelation="SIBLING";         deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E018"; baseSalary=55000; tenureMonths=72; seniorityMonths=72; leaveTypeName="BEREAVEMENT"; leaveDays=5; leaveHours=0; usedDaysThisYear=0; bereavementRelation="CHILD";           deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E019"; baseSalary=42000; tenureMonths=18; seniorityMonths=18; leaveTypeName="BEREAVEMENT"; leaveDays=2; leaveHours=0; usedDaysThisYear=0; bereavementRelation="SPOUSE_PARENT";   deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E020"; baseSalary=38000; tenureMonths=30; seniorityMonths=30; leaveTypeName="BEREAVEMENT"; leaveDays=1; leaveHours=0; usedDaysThisYear=0; bereavementRelation="ADOPTIVE_PARENT"; deductionRate=0; publicHolidayDays=0 }
    # PERSONAL (10筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E021"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PERSONAL"; leaveDays=3;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E022"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PERSONAL"; leaveDays=5;  leaveHours=0; usedDaysThisYear=8;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E023"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PERSONAL"; leaveDays=14; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E024"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="PERSONAL"; leaveDays=10; leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E025"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="PERSONAL"; leaveDays=2;  leaveHours=0; usedDaysThisYear=13; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E026"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="PERSONAL"; leaveDays=1;  leaveHours=0; usedDaysThisYear=14; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E027"; baseSalary=28000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="PERSONAL"; leaveDays=7;  leaveHours=0; usedDaysThisYear=3;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E028"; baseSalary=55000; tenureMonths=72; seniorityMonths=72; leaveTypeName="PERSONAL"; leaveDays=4;  leaveHours=0; usedDaysThisYear=10; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E029"; baseSalary=42000; tenureMonths=18; seniorityMonths=18; leaveTypeName="PERSONAL"; leaveDays=6;  leaveHours=0; usedDaysThisYear=7;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E030"; baseSalary=38000; tenureMonths=30; seniorityMonths=30; leaveTypeName="PERSONAL"; leaveDays=3;  leaveHours=0; usedDaysThisYear=11; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # SICK (10筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E031"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="SICK"; leaveDays=3;  leaveHours=0; usedDaysThisYear=0;   bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E032"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="SICK"; leaveDays=5;  leaveHours=0; usedDaysThisYear=25;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E033"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="SICK"; leaveDays=30; leaveHours=0; usedDaysThisYear=0;   bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E034"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="SICK"; leaveDays=10; leaveHours=0; usedDaysThisYear=21;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E035"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="SICK"; leaveDays=2;  leaveHours=0; usedDaysThisYear=28;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E036"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="SICK"; leaveDays=1;  leaveHours=0; usedDaysThisYear=10;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$true  }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E037"; baseSalary=28000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="SICK"; leaveDays=7;  leaveHours=0; usedDaysThisYear=20;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$true  }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E038"; baseSalary=55000; tenureMonths=72; seniorityMonths=72; leaveTypeName="SICK"; leaveDays=4;  leaveHours=0; usedDaysThisYear=31;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$true  }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E039"; baseSalary=42000; tenureMonths=18; seniorityMonths=18; leaveTypeName="SICK"; leaveDays=6;  leaveHours=0; usedDaysThisYear=0;   bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$true  }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E040"; baseSalary=38000; tenureMonths=30; seniorityMonths=30; leaveTypeName="SICK"; leaveDays=3;  leaveHours=0; usedDaysThisYear=360; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$true  }
    # ANNUAL (10筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E041"; baseSalary=40000; tenureMonths=6;   seniorityMonths=6;   leaveTypeName="ANNUAL"; leaveDays=2;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E042"; baseSalary=35000; tenureMonths=12;  seniorityMonths=12;  leaveTypeName="ANNUAL"; leaveDays=5;  leaveHours=0; usedDaysThisYear=2;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E043"; baseSalary=50000; tenureMonths=24;  seniorityMonths=24;  leaveTypeName="ANNUAL"; leaveDays=3;  leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E044"; baseSalary=45000; tenureMonths=36;  seniorityMonths=36;  leaveTypeName="ANNUAL"; leaveDays=7;  leaveHours=0; usedDaysThisYear=7;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E045"; baseSalary=30000; tenureMonths=60;  seniorityMonths=60;  leaveTypeName="ANNUAL"; leaveDays=10; leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E046"; baseSalary=60000; tenureMonths=84;  seniorityMonths=84;  leaveTypeName="ANNUAL"; leaveDays=8;  leaveHours=0; usedDaysThisYear=7;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E047"; baseSalary=28000; tenureMonths=120; seniorityMonths=120; leaveTypeName="ANNUAL"; leaveDays=5;  leaveHours=0; usedDaysThisYear=10; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E048"; baseSalary=55000; tenureMonths=144; seniorityMonths=144; leaveTypeName="ANNUAL"; leaveDays=6;  leaveHours=0; usedDaysThisYear=11; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E049"; baseSalary=42000; tenureMonths=180; seniorityMonths=180; leaveTypeName="ANNUAL"; leaveDays=4;  leaveHours=0; usedDaysThisYear=20; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E050"; baseSalary=38000; tenureMonths=240; seniorityMonths=240; leaveTypeName="ANNUAL"; leaveDays=3;  leaveHours=0; usedDaysThisYear=27; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # PATERNITY (5筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E051"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PATERNITY"; leaveDays=3; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E052"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PATERNITY"; leaveDays=7; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E053"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PATERNITY"; leaveDays=8; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E054"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="PATERNITY"; leaveDays=5; leaveHours=0; usedDaysThisYear=2; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E055"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="PATERNITY"; leaveDays=2; leaveHours=0; usedDaysThisYear=5; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # MATERNITY (5筆 + 1筆複合)
    @{ companyId="COMPANY_A"; position="STAFF";   employeeId="E056"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MATERNITY"; leaveDays=56; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF";   employeeId="E057"; baseSalary=35000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="MATERNITY"; leaveDays=56; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF";   employeeId="E058"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MATERNITY"; leaveDays=60; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF";   employeeId="E059"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="MATERNITY"; leaveDays=28; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF";   employeeId="E060"; baseSalary=30000; tenureMonths=4;  seniorityMonths=4;  leaveTypeName="MATERNITY"; leaveDays=42; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="MANAGER"; employeeId="E101"; baseSalary=80000; tenureMonths=72; seniorityMonths=72; leaveTypeName="MATERNITY"; leaveDays=10; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=2 }
    # MENSTRUAL (5筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E061"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MENSTRUAL"; leaveDays=1; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E062"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="MENSTRUAL"; leaveDays=1; leaveHours=0; usedDaysThisYear=2;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E063"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MENSTRUAL"; leaveDays=1; leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E064"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="MENSTRUAL"; leaveDays=2; leaveHours=0; usedDaysThisYear=3;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E065"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="MENSTRUAL"; leaveDays=1; leaveHours=0; usedDaysThisYear=12; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # FAMILY_CARE (5筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E066"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="FAMILY_CARE"; leaveDays=2; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E067"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="FAMILY_CARE"; leaveDays=5; leaveHours=0; usedDaysThisYear=2; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E068"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="FAMILY_CARE"; leaveDays=7; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E069"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="FAMILY_CARE"; leaveDays=3; leaveHours=0; usedDaysThisYear=5; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E070"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="FAMILY_CARE"; leaveDays=4; leaveHours=0; usedDaysThisYear=4; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # PARENTAL (5筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E071"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PARENTAL"; leaveDays=180; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E072"; baseSalary=35000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="PARENTAL"; leaveDays=90;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E073"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PARENTAL"; leaveDays=730; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E074"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="PARENTAL"; leaveDays=731; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E075"; baseSalary=30000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PARENTAL"; leaveDays=365; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # 其他假別
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E076"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="OFFICIAL";            leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E077"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="OFFICIAL";            leaveDays=3;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E078"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="COMPENSATORY";        leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E079"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="COMPENSATORY";        leaveDays=2;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E080"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="NATURAL_DISASTER";    leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E081"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="NATURAL_DISASTER";    leaveDays=2;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E082"; baseSalary=28000; tenureMonths=3;  seniorityMonths=3;  leaveTypeName="BIRTHDAY";            leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E083"; baseSalary=55000; tenureMonths=72; seniorityMonths=72; leaveTypeName="BIRTHDAY";            leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E084"; baseSalary=42000; tenureMonths=18; seniorityMonths=18; leaveTypeName="UNPAID";              leaveDays=5;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E085"; baseSalary=38000; tenureMonths=30; seniorityMonths=30; leaveTypeName="UNPAID";              leaveDays=10;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E086"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="ABSENCE";             leaveDays=1;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E087"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="WORK_SUSPENSION";     leaveDays=2;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E088"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="OCCUPATIONAL_INJURY"; leaveDays=5;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    # MISCARRIAGE (6筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E089"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MISCARRIAGE"; leaveDays=5;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=8  }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E090"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="MISCARRIAGE"; leaveDays=6;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=10 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E091"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MISCARRIAGE"; leaveDays=14; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=15 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E092"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="MISCARRIAGE"; leaveDays=20; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=18 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E093"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="MISCARRIAGE"; leaveDays=42; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=25 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E094"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="MISCARRIAGE"; leaveDays=50; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; pregnancyWeeks=30 }
    # PRENATAL (6筆)
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E095"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PRENATAL_CHECKUP"; leaveDays=2;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E096"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PRENATAL_CHECKUP"; leaveDays=7;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E097"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PRENATAL_CHECKUP"; leaveDays=8;   leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E098"; baseSalary=45000; tenureMonths=6;  seniorityMonths=6;  leaveTypeName="PRENATAL_REST";    leaveDays=30;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E099"; baseSalary=30000; tenureMonths=48; seniorityMonths=48; leaveTypeName="PRENATAL_REST";    leaveDays=90;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_A"; position="STAFF"; employeeId="E100"; baseSalary=60000; tenureMonths=60; seniorityMonths=60; leaveTypeName="PRENATAL_REST";    leaveDays=365; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # ──────────────────────────────────────────────────────────
    # COMPANY_B（新增 20 筆）
    # 差異規則：婚假10天、年假+1天、生日假2天、事假同A(14天)
    # ──────────────────────────────────────────────────────────

    # MARRIAGE - CompanyB 上限10天（vs A的8天）
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E102"; baseSalary=45000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MARRIAGE"; leaveDays=8;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E103"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MARRIAGE"; leaveDays=10; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E104"; baseSalary=38000; tenureMonths=12; seniorityMonths=12; leaveTypeName="MARRIAGE"; leaveDays=11; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E105"; baseSalary=42000; tenureMonths=48; seniorityMonths=48; leaveTypeName="MARRIAGE"; leaveDays=5;  leaveHours=0; usedDaysThisYear=4; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # ANNUAL - CompanyB 每段+1天
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E106"; baseSalary=40000; tenureMonths=6;   seniorityMonths=6;   leaveTypeName="ANNUAL"; leaveDays=4;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E107"; baseSalary=35000; tenureMonths=12;  seniorityMonths=12;  leaveTypeName="ANNUAL"; leaveDays=8;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E108"; baseSalary=50000; tenureMonths=24;  seniorityMonths=24;  leaveTypeName="ANNUAL"; leaveDays=11; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E109"; baseSalary=45000; tenureMonths=60;  seniorityMonths=60;  leaveTypeName="ANNUAL"; leaveDays=16; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E110"; baseSalary=60000; tenureMonths=120; seniorityMonths=120; leaveTypeName="ANNUAL"; leaveDays=7;  leaveHours=0; usedDaysThisYear=10; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # BIRTHDAY - CompanyB 有生日假2天（CompanyA無）
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E111"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="BIRTHDAY"; leaveDays=2; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E112"; baseSalary=55000; tenureMonths=60; seniorityMonths=60; leaveTypeName="BIRTHDAY"; leaveDays=1; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # PERSONAL - CompanyB 同A上限14天
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E113"; baseSalary=38000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PERSONAL"; leaveDays=7;  leaveHours=0; usedDaysThisYear=5;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E114"; baseSalary=42000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PERSONAL"; leaveDays=14; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E115"; baseSalary=45000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PERSONAL"; leaveDays=5;  leaveHours=0; usedDaysThisYear=10; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # FAMILY_CARE - CompanyB 同A上限7天
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E116"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="FAMILY_CARE"; leaveDays=3; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E117"; baseSalary=35000; tenureMonths=12; seniorityMonths=12; leaveTypeName="FAMILY_CARE"; leaveDays=8; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # SICK - CompanyB 同勞基法
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E118"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="SICK"; leaveDays=5;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E119"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="SICK"; leaveDays=10; leaveHours=0; usedDaysThisYear=22; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }

    # PATERNITY - CompanyB 同勞基法
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E120"; baseSalary=45000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PATERNITY"; leaveDays=7; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_B"; position="STAFF"; employeeId="E121"; baseSalary=38000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PATERNITY"; leaveDays=8; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # ──────────────────────────────────────────────────────────
    # COMPANY_C（新增 19 筆）
    # 差異規則：事假17天、家庭照顧假10天、生日假1天、婚假同A(8天)
    # ──────────────────────────────────────────────────────────

    # PERSONAL - CompanyC 上限17天（vs A的14天）
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E122"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PERSONAL"; leaveDays=14; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E123"; baseSalary=45000; tenureMonths=36; seniorityMonths=36; leaveTypeName="PERSONAL"; leaveDays=17; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E124"; baseSalary=38000; tenureMonths=12; seniorityMonths=12; leaveTypeName="PERSONAL"; leaveDays=18; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E125"; baseSalary=50000; tenureMonths=48; seniorityMonths=48; leaveTypeName="PERSONAL"; leaveDays=5;  leaveHours=0; usedDaysThisYear=12; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E126"; baseSalary=42000; tenureMonths=60; seniorityMonths=60; leaveTypeName="PERSONAL"; leaveDays=3;  leaveHours=0; usedDaysThisYear=14; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # FAMILY_CARE - CompanyC 上限10天（vs A的7天）
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E127"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="FAMILY_CARE"; leaveDays=7;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E128"; baseSalary=45000; tenureMonths=36; seniorityMonths=36; leaveTypeName="FAMILY_CARE"; leaveDays=10; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E129"; baseSalary=38000; tenureMonths=12; seniorityMonths=12; leaveTypeName="FAMILY_CARE"; leaveDays=11; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E130"; baseSalary=50000; tenureMonths=48; seniorityMonths=48; leaveTypeName="FAMILY_CARE"; leaveDays=4;  leaveHours=0; usedDaysThisYear=6; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # BIRTHDAY - CompanyC 有生日假1天（CompanyA無）
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E131"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="BIRTHDAY"; leaveDays=1; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E132"; baseSalary=55000; tenureMonths=60; seniorityMonths=60; leaveTypeName="BIRTHDAY"; leaveDays=2; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # MARRIAGE - CompanyC 同A上限8天
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E133"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="MARRIAGE"; leaveDays=8;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E134"; baseSalary=45000; tenureMonths=36; seniorityMonths=36; leaveTypeName="MARRIAGE"; leaveDays=9;  leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # ANNUAL - CompanyC 同A
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E135"; baseSalary=40000; tenureMonths=12;  seniorityMonths=12;  leaveTypeName="ANNUAL"; leaveDays=7;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E136"; baseSalary=50000; tenureMonths=60;  seniorityMonths=60;  leaveTypeName="ANNUAL"; leaveDays=15; leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E137"; baseSalary=45000; tenureMonths=120; seniorityMonths=120; leaveTypeName="ANNUAL"; leaveDays=6;  leaveHours=0; usedDaysThisYear=10; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }

    # SICK - CompanyC 同勞基法
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E138"; baseSalary=40000; tenureMonths=24; seniorityMonths=24; leaveTypeName="SICK"; leaveDays=5;  leaveHours=0; usedDaysThisYear=0;  bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E139"; baseSalary=50000; tenureMonths=36; seniorityMonths=36; leaveTypeName="SICK"; leaveDays=10; leaveHours=0; usedDaysThisYear=22; bereavementRelation=""; deductionRate=0; publicHolidayDays=0; hospitalized=$false }

    # PATERNITY - CompanyC 同勞基法
    @{ companyId="COMPANY_C"; position="STAFF"; employeeId="E140"; baseSalary=45000; tenureMonths=24; seniorityMonths=24; leaveTypeName="PATERNITY"; leaveDays=7; leaveHours=0; usedDaysThisYear=0; bereavementRelation=""; deductionRate=0; publicHolidayDays=0 }
)

$totalCases = $testCases.Count   # 140

# ══════════════════════════════════════════════════════════════
# 輔助：單筆 POST
# ══════════════════════════════════════════════════════════════
function Invoke-Single {
    param([string]$Url, [hashtable]$Payload)

    $json      = $Payload | ConvertTo-Json -Depth 10
    $startTime = Get-Date

    try {
        $resp = Invoke-WebRequest -Uri $Url -Method POST `
                    -ContentType "application/json" `
                    -Body $json `
                    -UseBasicParsing

        $endTime  = Get-Date
        $ms       = ($endTime - $startTime).TotalMilliseconds

        $serverMs = ($resp.Headers["X-Execution-Time-Ms"] | Select-Object -First 1)
        if (-not $serverMs) { $serverMs = "N/A" }

        $networkMs = if ($serverMs -and $serverMs -ne "N/A" -and $serverMs -match '^\d+$') {
            [math]::Round($ms - [double]$serverMs, 1)
        } else { "N/A" }

        if ($ms -gt 3000) {
            Write-Host "  ⚠️  異常延遲偵測！" -ForegroundColor Red
            Write-Host "      總耗時    : $([math]::Round($ms,1)) ms" -ForegroundColor Red
            Write-Host "      伺服器端  : $serverMs ms" -ForegroundColor Yellow
            Write-Host "      網路延遲  : $networkMs ms" -ForegroundColor Yellow
            Write-Host "      發生時間  : $($startTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Yellow
            Write-Host "      URL       : $Url" -ForegroundColor Yellow
        }

        return [PSCustomObject]@{
            Ms        = [math]::Round($ms, 1)
            ServerMs  = $serverMs
            NetworkMs = $networkMs
            StartTime = $startTime.ToString("HH:mm:ss.fff")
            Body      = $resp.Content
            Result    = $resp.Content | ConvertFrom-Json
        }

    } catch {
        $endTime = Get-Date
        $ms      = ($endTime - $startTime).TotalMilliseconds
        Write-Host "  ❌ 請求失敗！耗時 $([math]::Round($ms,1)) ms" -ForegroundColor Red
        Write-Host "      錯誤訊息 : $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "      發生時間 : $($startTime.ToString('HH:mm:ss.fff'))" -ForegroundColor Red
        return [PSCustomObject]@{
            Ms        = [math]::Round($ms, 1)
            ServerMs  = "ERROR"
            NetworkMs = "ERROR"
            StartTime = $startTime.ToString("HH:mm:ss.fff")
            Body      = $null
            Result    = $null
        }
    }
}

# ══════════════════════════════════════════════════════════════
# 輔助：批次 POST
# ══════════════════════════════════════════════════════════════
function Invoke-Batch {
    param([string]$Url, [object[]]$Payloads)
    $json = $Payloads | ConvertTo-Json -Depth 5 -Compress
    $sw   = [System.Diagnostics.Stopwatch]::StartNew()
    try {
        $resp = Invoke-RestMethod -Method POST -Uri $Url `
                    -ContentType "application/json" -Body $json -ErrorAction Stop
    } catch { $resp = @() }
    $sw.Stop()
    return @{ Results = $resp; Ms = $sw.Elapsed.TotalMilliseconds }
}

# ══════════════════════════════════════════════════════════════
# 情境 1：Drools 單筆 × 140 次
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 情境1：Drools 單筆 × $totalCases 次請求 ==========" -ForegroundColor Cyan

$s1_times      = @()
$s1_results    = @()
$s1_serverMs   = @()
$s1_networkMs  = @()

for ($i = 0; $i -lt $testCases.Count; $i++) {
    $r = Invoke-Single -Url $droolsSingle -Payload $testCases[$i]
    $s1_times     += $r.Ms
    $s1_results   += $r.Result
    $s1_serverMs  += $r.ServerMs
    $s1_networkMs += $r.NetworkMs
    Write-Progress -Activity "情境1 Drools 單筆" -Status "$($i+1)/$totalCases" `
        -PercentComplete (($i+1)*100/$totalCases)
}

# ══════════════════════════════════════════════════════════════
# 情境 2：Drools 批次 140 筆 × 1 次
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 情境2：Drools 批次 $totalCases 筆 × 1 次請求 ==========" -ForegroundColor Cyan

$s2 = Invoke-Batch -Url $droolsBatch -Payloads $testCases
$s2_results = $s2.Results
$s2_totalMs = $s2.Ms

# ══════════════════════════════════════════════════════════════
# 情境 3：Legacy 單筆 × 140 次
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 情境3：Legacy 單筆 × $totalCases 次請求 ==========" -ForegroundColor Cyan

$s3_times      = @()
$s3_results    = @()
$s3_serverMs   = @()
$s3_networkMs  = @()

for ($i = 0; $i -lt $testCases.Count; $i++) {
    $r = Invoke-Single -Url $legacySingle -Payload $testCases[$i]
    $s3_times     += $r.Ms
    $s3_results   += $r.Result
    $s3_serverMs  += $r.ServerMs
    $s3_networkMs += $r.NetworkMs
    Write-Progress -Activity "情境3 Legacy 單筆" -Status "$($i+1)/$totalCases" `
        -PercentComplete (($i+1)*100/$totalCases)
}

# ══════════════════════════════════════════════════════════════
# 情境 4：Legacy 批次 140 筆 × 1 次
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 情境4：Legacy 批次 $totalCases 筆 × 1 次請求 ==========" -ForegroundColor Cyan

$s4 = Invoke-Batch -Url $legacyBatch -Payloads $testCases
$s4_results = $s4.Results
$s4_totalMs = $s4.Ms

# ══════════════════════════════════════════════════════════════
# 情境5：大批次壓力測試（1400 筆 × 1 次）
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 情境5：大批次壓力測試 1400 筆 × 1 次 ==========" -ForegroundColor Cyan

$stressCases = $testCases * 10

$s5 = Invoke-Batch -Url $droolsBatch -Payloads $stressCases
$s6 = Invoke-Batch -Url $legacyBatch -Payloads $stressCases

Write-Host "  Drools 1400筆批次：$([math]::Round($s5.Ms,1)) ms"
Write-Host "  Legacy 1400筆批次：$([math]::Round($s6.Ms,1)) ms"
$stressDiff = [math]::Round($s5.Ms - $s6.Ms, 1)
$stressPct  = [math]::Round(($s5.Ms - $s6.Ms) / $s6.Ms * 100, 1)
Write-Host "  差距：$stressDiff ms ($stressPct%)" -ForegroundColor Yellow

# ══════════════════════════════════════════════════════════════
# 逐筆比對：情境1 vs 情境3
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 逐筆正確性比對（情境1 vs 情境3）==========" -ForegroundColor Yellow

$detailRows    = @()
$mismatchCount = 0

for ($i = 0; $i -lt $testCases.Count; $i++) {
    $tc = $testCases[$i]
    $d  = $s1_results[$i]
    $l  = $s3_results[$i]

    $match = $null -ne $d -and $null -ne $l -and
             ($d.approved      -eq $l.approved) -and
             ($d.remainingDays -eq $l.remainingDays)

    if (-not $match) { $mismatchCount++ }

    $detailRows += [PSCustomObject]@{
        "#"              = $i + 1
        employeeId       = $tc.employeeId
        companyId        = $tc.companyId
        leaveType        = $tc.leaveTypeName
        leaveDays        = $tc.leaveDays
        position         = $tc.position
        publicHoliday    = $tc.publicHolidayDays
        "S1_Drools(ms)"  = [math]::Round($s1_times[$i], 1)
        "S1_Server(ms)"  = $s1_serverMs[$i]
        "S1_Network(ms)" = $s1_networkMs[$i]
        "S3_Legacy(ms)"  = [math]::Round($s3_times[$i], 1)
        "S3_Server(ms)"  = $s3_serverMs[$i]
        "S3_Network(ms)" = $s3_networkMs[$i]
        "Diff(ms)"       = [math]::Round($s1_times[$i] - $s3_times[$i], 1)
        D_approved       = $d.approved
        L_approved       = $l.approved
        D_remaining      = $d.remainingDays
        L_remaining      = $l.remainingDays
        D_rule           = $d.appliedRule
        L_rule           = $l.appliedRule
        Match            = if ($match) { "✅" } else { "❌" }
    }
}

$detailRows | Format-Table "#", employeeId, companyId, leaveType, leaveDays,
    "S1_Drools(ms)", "S3_Legacy(ms)", "Diff(ms)",
    D_approved, L_approved, D_remaining, L_remaining, Match -AutoSize

# ══════════════════════════════════════════════════════════════
# 批次正確性比對：情境2 vs 情境4
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 批次正確性比對（情境2 vs 情境4）==========" -ForegroundColor Yellow

$batchMismatch = 0
$batchDetail   = @()

for ($i = 0; $i -lt $testCases.Count; $i++) {
    $tc = $testCases[$i]
    $d  = if ($s2_results -is [array]) { $s2_results[$i] } else { $s2_results }
    $l  = if ($s4_results -is [array]) { $s4_results[$i] } else { $s4_results }

    $match = $null -ne $d -and $null -ne $l -and
             ($d.approved      -eq $l.approved) -and
             ($d.remainingDays -eq $l.remainingDays)

    if (-not $match) { $batchMismatch++ }

    $batchDetail += [PSCustomObject]@{
        "#"           = $i + 1
        employeeId    = $tc.employeeId
        companyId     = $tc.companyId
        leaveType     = $tc.leaveTypeName
        position      = $tc.position
        publicHoliday = $tc.publicHolidayDays
        D_approved    = $d.approved
        L_approved    = $l.approved
        D_remaining   = $d.remainingDays
        L_remaining   = $l.remainingDays
        Match         = if ($match) { "✅" } else { "❌" }
    }
}

$batchDetail | Format-Table -AutoSize

# ══════════════════════════════════════════════════════════════
# 效能統計摘要
# ══════════════════════════════════════════════════════════════
function Get-Stats([double[]]$arr) {
    return @{
        Avg   = [math]::Round(($arr | Measure-Object -Average).Average, 2)
        Min   = [math]::Round(($arr | Measure-Object -Minimum).Minimum, 2)
        Max   = [math]::Round(($arr | Measure-Object -Maximum).Maximum, 2)
        Total = [math]::Round(($arr | Measure-Object -Sum).Sum, 2)
        P95   = [math]::Round(($arr | Sort-Object)[[math]::Floor($arr.Count * 0.95)], 2)
    }
}

$st1 = Get-Stats $s1_times
$st3 = Get-Stats $s3_times

Write-Host "`n========== 效能統計摘要 ==========" -ForegroundColor Green
Write-Host ""
Write-Host "  ┌─────────────────────────────────────────────────────────────────┐"
Write-Host "  │         單筆循序模式（情境1 vs 情境3）                           │"
Write-Host "  ├──────────────┬────────────┬────────────┬────────────┬───────────┤"
Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "指標","情境1 Drools","情境3 Legacy","差距(ms)","差距%")
Write-Host "  ├──────────────┼────────────┼────────────┼────────────┼───────────┤"

$diffAvg = [math]::Round($st1.Avg - $st3.Avg, 2)
$diffPct = if ($st3.Avg -ne 0) { [math]::Round(($st1.Avg - $st3.Avg) / $st3.Avg * 100, 1) } else { 0 }
$diffTot = [math]::Round($st1.Total - $st3.Total, 2)

Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "平均(ms)",$st1.Avg,$st3.Avg,$diffAvg,"$diffPct%")
Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "最小(ms)",$st1.Min,$st3.Min,"-","-")
Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "最大(ms)",$st1.Max,$st3.Max,"-","-")
Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "P95(ms)",$st1.P95,$st3.P95,"-","-")
Write-Host ("  │ {0,-12} │ {1,10} │ {2,10} │ {3,10} │ {4,9} │" -f "總計(ms)",$st1.Total,$st3.Total,$diffTot,"-")
Write-Host "  └──────────────┴────────────┴────────────┴────────────┴───────────┘"

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────────┐"
Write-Host "  │              批次模式（情境2 vs 情境4）                           │"
Write-Host "  ├──────────────────────┬──────────────────────┬────────────────────┤"
Write-Host ("  │ {0,-22} │ {1,-22} │ {2,-20} │" -f "情境2 Drools Batch","情境4 Legacy Batch","差距(ms)")
Write-Host "  ├──────────────────────┼──────────────────────┼────────────────────┤"
$batchDiff = [math]::Round($s2_totalMs - $s4_totalMs, 2)
$batchPct  = if ($s4_totalMs -ne 0) { [math]::Round(($s2_totalMs - $s4_totalMs) / $s4_totalMs * 100, 1) } else { 0 }
Write-Host ("  │ {0,-22} │ {1,-22} │ {2,-20} │" -f "$([math]::Round($s2_totalMs,1)) ms (1次請求)","$([math]::Round($s4_totalMs,1)) ms (1次請求)","$batchDiff ms ($batchPct%)")
Write-Host "  └──────────────────────┴──────────────────────┴────────────────────┘"

Write-Host ""
Write-Host "  ┌──────────────────────────────────────────────────────────────────┐"
Write-Host "  │         跨情境比較（總處理 $totalCases 筆的時間）                        │"
Write-Host "  ├──────────────────────────────────┬──────────────────────────────┤"
Write-Host ("  │ {0,-34} │ {1,-28} │" -f "情境","總耗時(ms)")
Write-Host "  ├──────────────────────────────────┼──────────────────────────────┤"
Write-Host ("  │ {0,-34} │ {1,-28} │" -f "情境1：Drools 單筆×$totalCases 次",$st1.Total)
Write-Host ("  │ {0,-34} │ {1,-28} │" -f "情境2：Drools 批次×1次",[math]::Round($s2_totalMs,1))
Write-Host ("  │ {0,-34} │ {1,-28} │" -f "情境3：Legacy 單筆×$totalCases 次",$st3.Total)
Write-Host ("  │ {0,-34} │ {1,-28} │" -f "情境4：Legacy 批次×1次",[math]::Round($s4_totalMs,1))
Write-Host "  └──────────────────────────────────┴──────────────────────────────┘"

# ══════════════════════════════════════════════════════════════
# 各公司分組效能統計
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 各公司分組效能統計 ==========" -ForegroundColor Cyan

foreach ($company in @("COMPANY_A", "COMPANY_B", "COMPANY_C")) {
    $indices = @()
    for ($i = 0; $i -lt $testCases.Count; $i++) {
        if ($testCases[$i].companyId -eq $company) { $indices += $i }
    }
    $compS1 = $indices | ForEach-Object { $s1_times[$_] }
    $compS3 = $indices | ForEach-Object { $s3_times[$_] }
    $avgS1  = [math]::Round(($compS1 | Measure-Object -Average).Average, 2)
    $avgS3  = [math]::Round(($compS3 | Measure-Object -Average).Average, 2)
    $diff   = [math]::Round($avgS1 - $avgS3, 2)
    $pct    = if ($avgS3 -ne 0) { [math]::Round($diff / $avgS3 * 100, 1) } else { 0 }
    Write-Host ("  {0,-12} | 筆數:{1,3} | Drools平均:{2,8} ms | Legacy平均:{3,8} ms | 差距:{4,7} ms ({5}%)" `
        -f $company, $indices.Count, $avgS1, $avgS3, $diff, $pct)
}

# ══════════════════════════════════════════════════════════════
# 正確性總結
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== 正確性總結 ==========" -ForegroundColor Cyan
Write-Host "  [單筆] 情境1 vs 情境3：一致 $($totalCases - $mismatchCount)/$totalCases 筆 $(if($mismatchCount -eq 0){'🎉 全部正確'}else{"❌ $mismatchCount 筆不一致"})"
Write-Host "  [批次] 情境2 vs 情境4：一致 $($totalCases - $batchMismatch)/$totalCases 筆 $(if($batchMismatch -eq 0){'🎉 全部正確'}else{"❌ $batchMismatch 筆不一致"})"

# ══════════════════════════════════════════════════════════════
# E101 複合情境專項驗證
# ══════════════════════════════════════════════════════════════
Write-Host "`n========== E101 複合情境專項驗證 ==========" -ForegroundColor Magenta

$e101_idx = 0
for ($i = 0; $i -lt $testCases.Count; $i++) {
    if ($testCases[$i].employeeId -eq "E101") { $e101_idx = $i; break }
}

$e101_d = $s1_results[$e101_idx]
$e101_l = $s3_results[$e101_idx]

Write-Host "  Drools 結果："
Write-Host "    approved     : $($e101_d.approved)"
Write-Host "    appliedRule  : $($e101_d.appliedRule)"
Write-Host "    remainingDays: $($e101_d.remainingDays)"
Write-Host "    message      : $($e101_d.message)"
Write-Host ""
Write-Host "  Legacy 結果："
Write-Host "    approved     : $($e101_l.approved)"
Write-Host "    appliedRule  : $($e101_l.appliedRule)"
Write-Host "    remainingDays: $($e101_l.remainingDays)"
Write-Host "    message      : $($e101_l.message)"

$e101_match = $null -ne $e101_d -and $null -ne $e101_l -and
              ($e101_d.approved -eq $e101_l.approved) -and
              ($e101_d.remainingDays -eq $e101_l.remainingDays)

Write-Host ""
if ($e101_match) {
    Write-Host "  E101 Drools vs Legacy：✅ 結果一致" -ForegroundColor Green
} else {
    Write-Host "  E101 Drools vs Legacy：❌ 結果不一致" -ForegroundColor Red
}

$expectedRule = "Maternity Leave Full Pay With Public Holiday - Senior Manager"
if ($e101_d.appliedRule -eq $expectedRule) {
    Write-Host "  Drools appliedRule：✅ 正確觸發複合規則" -ForegroundColor Green
} else {
    Write-Host "  Drools appliedRule：❌ 未觸發複合規則，實際為：$($e101_d.appliedRule)" -ForegroundColor Red
}
if ($e101_l.appliedRule -eq $expectedRule) {
    Write-Host "  Legacy appliedRule：✅ 正確觸發複合規則" -ForegroundColor Green
} else {
    Write-Host "  Legacy appliedRule：❌ 未觸發複合規則，實際為：$($e101_l.appliedRule)" -ForegroundColor Red
}

if ($mismatchCount -gt 0) {
    Write-Host "`n  ── 單筆不一致明細 ──" -ForegroundColor Red
    $detailRows | Where-Object { $_.Match -eq "❌" } |
        Format-Table "#", employeeId, companyId, leaveType, position, publicHoliday,
            D_approved, L_approved, D_remaining, L_remaining, D_rule, L_rule -AutoSize
}
if ($batchMismatch -gt 0) {
    Write-Host "`n  ── 批次不一致明細 ──" -ForegroundColor Red
    $batchDetail | Where-Object { $_.Match -eq "❌" } |
        Format-Table "#", employeeId, companyId, leaveType, position, publicHoliday,
            D_approved, L_approved, D_remaining, L_remaining -AutoSize
}

# ══════════════════════════════════════════════════════════════
# 輸出 CSV
# ══════════════════════════════════════════════════════════════
$ts = Get-Date -Format 'yyyyMMdd_HHmmss'

$detailRows  | Export-Csv -Path "$PSScriptRoot\bench_single_$ts.csv"  -NoTypeInformation -Encoding UTF8
$batchDetail | Export-Csv -Path "$PSScriptRoot\bench_batch_$ts.csv"   -NoTypeInformation -Encoding UTF8

$summaryRows = @(
    [PSCustomObject]@{ 情境="情境1 Drools單筆×$totalCases次"; 總耗時ms=$st1.Total; 平均ms=$st1.Avg; 最小ms=$st1.Min; 最大ms=$st1.Max; P95ms=$st1.P95; 請求次數=$totalCases }
    [PSCustomObject]@{ 情境="情境2 Drools批次×1次";           總耗時ms=[math]::Round($s2_totalMs,1); 平均ms="N/A"; 最小ms="N/A"; 最大ms="N/A"; P95ms="N/A"; 請求次數=1 }
    [PSCustomObject]@{ 情境="情境3 Legacy單筆×$totalCases次"; 總耗時ms=$st3.Total; 平均ms=$st3.Avg; 最小ms=$st3.Min; 最大ms=$st3.Max; P95ms=$st3.P95; 請求次數=$totalCases }
    [PSCustomObject]@{ 情境="情境4 Legacy批次×1次";           總耗時ms=[math]::Round($s4_totalMs,1); 平均ms="N/A"; 最小ms="N/A"; 最大ms="N/A"; P95ms="N/A"; 請求次數=1 }
)
$summaryRows | Export-Csv -Path "$PSScriptRoot\bench_summary_$ts.csv" -NoTypeInformation -Encoding UTF8

$e101Detail = @(
    [PSCustomObject]@{
        employeeId      = "E101"
        leaveType       = "MATERNITY"
        position        = "MANAGER"
        seniorityMonths = 72
        publicHoliday   = 2
        leaveDays       = 10
        D_approved      = $e101_d.approved
        D_appliedRule   = $e101_d.appliedRule
        D_remaining     = $e101_d.remainingDays
        D_message       = $e101_d.message
        L_approved      = $e101_l.approved
        L_appliedRule   = $e101_l.appliedRule
        L_remaining     = $e101_l.remainingDays
        L_message       = $e101_l.message
        Match           = if ($e101_match) { "✅" } else { "❌" }
    }
)
$e101Detail | Export-Csv -Path "$PSScriptRoot\bench_e101_$ts.csv" -NoTypeInformation -Encoding UTF8

Write-Host "`n📄 單筆明細 CSV  ：$PSScriptRoot\bench_single_$ts.csv"  -ForegroundColor Gray
Write-Host "📄 批次明細 CSV  ：$PSScriptRoot\bench_batch_$ts.csv"    -ForegroundColor Gray
Write-Host "📄 統計摘要 CSV  ：$PSScriptRoot\bench_summary_$ts.csv"  -ForegroundColor Gray
Write-Host "📄 E101專項 CSV  ：$PSScriptRoot\bench_e101_$ts.csv`n"   -ForegroundColor Gray
