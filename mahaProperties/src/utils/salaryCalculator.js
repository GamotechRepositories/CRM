export const getSalaryStructure = (salaryRecordOrGross) => {
  if (!salaryRecordOrGross) {
    return getSalaryStructure(20000);
  }

  let data = typeof salaryRecordOrGross === 'object' ? salaryRecordOrGross : { grossSalary: Number(salaryRecordOrGross) };

  let gross = Number(
    data.grossSalary ?? data.amount ?? data.salary ?? data.salaryPayroll?.ctc ?? 20000
  );
  if (isNaN(gross) || gross < 0) gross = 20000;

  let components = Array.isArray(data.components) && data.components.length > 0
    ? data.components.map((c) => ({ code: String(c.code), name: String(c.name), amount: Number(c.amount || 0) }))
    : null;

  if (!components) {
    const basic = Number(data.basicSalary ?? Math.round(gross * 0.55));
    const da = Number(data.da ?? Math.round(gross * 0.2035));
    const hra = Number(data.hra ?? Math.round(gross * 0.055));
    const conveyance = Number(data.conveyance ?? Math.round(gross * 0.07));
    const attendanceIncentive = Number(data.attendanceIncentive ?? 0);
    const allocated = basic + da + hra + conveyance + attendanceIncentive;
    const special = Number(data.specialAllowance ?? Math.max(0, gross - allocated));

    components = [
      { code: 'BASIC', name: 'Basic Salary', amount: basic },
      { code: 'DA', name: 'Dearness Allowance', amount: da },
      { code: 'HRA', name: 'House Rent Allowance', amount: hra },
      { code: 'CONVEYANCE', name: 'Conveyance Allowance', amount: conveyance },
      { code: 'SPECIAL', name: 'Special Allowance', amount: special },
      { code: 'ATTENDANCE_INCENTIVE', name: 'Attendance Incentive', amount: attendanceIncentive },
    ];
  }

  const calculatedGross = components.reduce((sum, c) => sum + (Number(c.amount) || 0), 0);
  const grossSalary = calculatedGross > 0 ? calculatedGross : gross;

  let deductions = Array.isArray(data.deductions) && data.deductions.length > 0
    ? data.deductions.map((d) => ({ code: String(d.code), name: String(d.name), amount: Number(d.amount || 0) }))
    : Array.isArray(data.deductionsList) && data.deductionsList.length > 0
    ? data.deductionsList.map((d) => ({ code: String(d.code), name: String(d.name), amount: Number(d.amount || 0) }))
    : null;

  if (!deductions) {
    const basicComp = components.find((c) => c.code === 'BASIC')?.amount || 0;
    const pf = Number(data.pfAmount ?? data.pf ?? (grossSalary >= 20000 ? 1800 : Math.min(1800, Math.round(basicComp * 0.12))));
    const esic = Number(data.esicAmount ?? data.esic ?? 0);
    const pt = Number(data.ptAmount ?? data.pt ?? (grossSalary > 15000 ? 200 : 0));

    deductions = [
      { code: 'PF', name: 'Provident Fund', amount: pf },
      { code: 'ESIC', name: 'ESIC', amount: esic },
      { code: 'PT', name: 'Professional Tax', amount: pt },
    ];
  }

  const totalDeductions = deductions.reduce((sum, d) => sum + (Number(d.amount) || 0), 0);
  const netSalary = data.netSalary != null && !isNaN(data.netSalary) ? Number(data.netSalary) : Math.max(0, grossSalary - totalDeductions);

  let employerContributions = Array.isArray(data.employerContributions) && data.employerContributions.length > 0
    ? data.employerContributions.map((e) => ({ code: String(e.code), name: String(e.name), amount: Number(e.amount || 0) }))
    : null;

  if (!employerContributions) {
    const pfDeduction = deductions.find((d) => d.code === 'PF')?.amount || 0;
    const esicDeduction = deductions.find((d) => d.code === 'ESIC')?.amount || 0;
    const empPf = Number(data.employerPfAmount ?? data.employerPf ?? pfDeduction);
    const empEsic = Number(data.employerEsicAmount ?? data.employerEsic ?? esicDeduction);

    employerContributions = [
      { code: 'PF', name: 'Employer Provident Fund', amount: empPf },
      { code: 'ESIC', name: 'Employer ESIC', amount: empEsic },
    ];
  }

  const totalEmployerContrib = employerContributions.reduce((sum, e) => sum + (Number(e.amount) || 0), 0);
  const monthlyCTC = data.monthlyCTC != null && !isNaN(data.monthlyCTC) ? Number(data.monthlyCTC) : (grossSalary + totalEmployerContrib);
  const annualCTC = data.annualCTC != null && !isNaN(data.annualCTC) ? Number(data.annualCTC) : (monthlyCTC * 12);

  return {
    components,
    grossSalary,
    deductions,
    totalDeductions,
    netSalary,
    employerContributions,
    monthlyCTC,
    annualCTC,
  };
};
