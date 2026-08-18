class SalaryLine {
  const SalaryLine({required this.code, required this.name, required this.amount});

  final String code;
  final String name;
  final double amount;
}

class SalaryStructure {
  const SalaryStructure({
    required this.components,
    required this.grossSalary,
    required this.deductions,
    required this.totalDeductions,
    required this.netSalary,
    required this.employerContributions,
    required this.monthlyCTC,
    required this.annualCTC,
  });

  final List<SalaryLine> components;
  final double grossSalary;
  final List<SalaryLine> deductions;
  final double totalDeductions;
  final double netSalary;
  final List<SalaryLine> employerContributions;
  final double monthlyCTC;
  final double annualCTC;
}

/// Mirrors web/backend CTC-based salary structure.
SalaryStructure getSalaryStructure(dynamic salaryRecordOrCtc) {
  Map<String, dynamic> data;
  if (salaryRecordOrCtc is Map) {
    data = Map<String, dynamic>.from(salaryRecordOrCtc);
  } else {
    data = {'monthlyCTC': _num(salaryRecordOrCtc, 0)};
  }

  final payroll = data['salaryPayroll'] is Map
      ? Map<String, dynamic>.from(data['salaryPayroll'] as Map)
      : const <String, dynamic>{};
  final src = {...payroll, ...data};

  var components = _lines(src['components']);
  var employerContributions = _lines(src['employerContributions']);
  var deductions = _lines(src['deductions']);
  if (deductions.isEmpty) deductions = _lines(src['deductionsList']);

  final monthlyCtcInput = _round(
    src['monthlyCTC'] ?? src['ctc'] ?? src['amount'] ?? src['salary'] ?? src['grossSalary'],
  );

  if (components.isEmpty) {
    final ctc = monthlyCtcInput < 0 ? 0.0 : monthlyCtcInput;
    final basic = _explicit(src['basicSalary']) ? _round(src['basicSalary']) : _round(ctc * 0.4);
    final da = _explicit(src['da']) ? _round(src['da']) : _round(ctc * 0.1);
    final hra = _explicit(src['hra']) ? _round(src['hra']) : _round(ctc * 0.2);
    final conveyance = _explicit(src['conveyance']) ? _round(src['conveyance']) : _round(ctc * 0.05);
    final medical = _explicit(src['medicalAllowance'] ?? src['medical'])
        ? _round(src['medicalAllowance'] ?? src['medical'])
        : _round(ctc * 0.05);
    final employerPf = _explicit(src['employerPf'] ?? src['employerPfAmount'])
        ? _round(src['employerPf'] ?? src['employerPfAmount'])
        : (basic * 0.12).roundToDouble().clamp(0, 1800).toDouble();
    final special = _explicit(src['specialAllowance'])
        ? _round(src['specialAllowance'])
        : (ctc - basic - da - hra - conveyance - medical - employerPf).clamp(0, double.infinity).toDouble();

    components = [
      SalaryLine(code: 'BASIC', name: 'Basic Salary', amount: basic),
      SalaryLine(code: 'DA', name: 'Dearness Allowance', amount: da),
      SalaryLine(code: 'HRA', name: 'House Rent Allowance', amount: hra),
      SalaryLine(code: 'CONVEYANCE', name: 'Conveyance Allowance', amount: conveyance),
      SalaryLine(code: 'SPECIAL', name: 'Special Allowance', amount: special),
      SalaryLine(code: 'MEDICAL', name: 'Medical Allowance', amount: medical),
    ];

    if (employerContributions.isEmpty) {
      employerContributions = [
        SalaryLine(code: 'PF', name: 'Employer PF Contribution', amount: employerPf),
      ];
    }
  }

  final grossSalary = components.fold<double>(0, (s, c) => s + c.amount);
  final basicComp = components.where((c) => c.code == 'BASIC').fold<double>(0, (s, c) => s + c.amount);
  var employerPfAmt = employerContributions.where((e) => e.code == 'PF').fold<double>(0, (s, e) => s + e.amount);
  if (employerPfAmt == 0 && _explicit(src['employerPf'] ?? src['employerPfAmount'])) {
    employerPfAmt = _round(src['employerPf'] ?? src['employerPfAmount']);
  }
  if (employerPfAmt == 0) {
    employerPfAmt = (basicComp * 0.12).roundToDouble().clamp(0, 1800).toDouble();
  }

  if (employerContributions.isEmpty) {
    employerContributions = [
      SalaryLine(code: 'PF', name: 'Employer PF Contribution', amount: employerPfAmt),
    ];
  }

  if (deductions.isEmpty) {
    final employeePf = _explicit(src['employeePf'] ?? src['pfAmount'] ?? src['pf'])
        ? _round(src['employeePf'] ?? src['pfAmount'] ?? src['pf'])
        : employerPfAmt;
    final pt = _explicit(src['pt'] ?? src['ptAmount'] ?? src['professionalTax'])
        ? _round(src['pt'] ?? src['ptAmount'] ?? src['professionalTax'])
        : (grossSalary > 15000 ? 200.0 : 0.0);
    final tds = _explicit(src['tds'] ?? src['incomeTax']) ? _round(src['tds'] ?? src['incomeTax']) : 0.0;
    deductions = [
      SalaryLine(code: 'PF', name: 'Employee PF', amount: employeePf),
      SalaryLine(code: 'PT', name: 'Professional Tax', amount: pt),
      SalaryLine(code: 'TDS', name: 'Income Tax (TDS)', amount: tds),
    ];
  }

  final totalDeductions = deductions.fold<double>(0, (s, d) => s + d.amount);
  final netSalary = _explicit(src['netSalary'])
      ? _round(src['netSalary'])
      : (grossSalary - totalDeductions).clamp(0, double.infinity).toDouble();
  final totalEmployerContrib = employerContributions.fold<double>(0, (s, e) => s + e.amount);
  final monthlyCTC = _explicit(src['monthlyCTC'] ?? src['ctc'])
      ? _round(src['monthlyCTC'] ?? src['ctc'])
      : grossSalary + totalEmployerContrib;
  final annualCTC = _explicit(src['annualCTC']) ? _round(src['annualCTC']) : monthlyCTC * 12;

  return SalaryStructure(
    components: components,
    grossSalary: grossSalary,
    deductions: deductions,
    totalDeductions: totalDeductions,
    netSalary: netSalary,
    employerContributions: employerContributions,
    monthlyCTC: monthlyCTC,
    annualCTC: annualCTC,
  );
}

List<SalaryLine> _lines(dynamic raw) {
  if (raw is! List || raw.isEmpty) return [];
  final out = <SalaryLine>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final name = (item['name'] ?? '').toString().trim();
    final code = (item['code'] ?? '').toString();
    if (name.isEmpty && code.isEmpty) continue;
    out.add(SalaryLine(code: code, name: name.isEmpty ? code : name, amount: _num(item['amount'], 0)));
  }
  return out;
}

bool _explicit(dynamic v) {
  if (v == null) return false;
  if (v is String && v.trim().isEmpty) return false;
  return _tryNum(v) != null;
}

double _round(dynamic v) => (_tryNum(v) ?? 0).roundToDouble();

double _num(dynamic v, [double fallback = 0]) => _tryNum(v) ?? fallback;

double? _tryNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}
