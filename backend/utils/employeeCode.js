/** Company digit in employee ID: EMP{digit}{sequence} e.g. EMP10001, EMP20001 */
export const COMPANY_EMPLOYEE_DIGIT = {
  adsResearchGlobal: 1,
  bangarProperties: 2,
  mahaProperties: 3,
  salesTechReality: 4,
};

export const COMPANY_KEYS = Object.keys(COMPANY_EMPLOYEE_DIGIT);

export const getCompanyEmployeeDigit = (companyKey) => COMPANY_EMPLOYEE_DIGIT[companyKey];

export const getEmployeeCodePrefix = (companyKey) => {
  const digit = getCompanyEmployeeDigit(companyKey);
  if (!digit) return null;
  return `EMP${digit}`;
};

export const buildEmployeeCode = (companyKey, sequence) => {
  const prefix = getEmployeeCodePrefix(companyKey);
  if (!prefix) throw new Error(`Unknown company: ${companyKey}`);
  return `${prefix}${String(sequence).padStart(4, '0')}`;
};

export const employeeCodePattern = (companyKey) => {
  const digit = getCompanyEmployeeDigit(companyKey);
  if (!digit) return null;
  return new RegExp(`^EMP${digit}\\d{4}$`, 'i');
};

export const isValidEmployeeCodeForCompany = (code, companyKey) => {
  if (!code || typeof code !== 'string') return false;
  const pattern = employeeCodePattern(companyKey);
  return pattern ? pattern.test(code.trim()) : false;
};

export const parseEmployeeCodeSequence = (code, companyKey) => {
  const prefix = getEmployeeCodePrefix(companyKey);
  if (!prefix || !code) return null;
  const normalized = code.trim().toUpperCase();
  if (!normalized.startsWith(prefix) || normalized.length !== prefix.length + 4) return null;
  const seq = parseInt(normalized.slice(prefix.length), 10);
  return Number.isNaN(seq) ? null : seq;
};

export async function getMaxEmployeeCodeSequence(Employee, companyKey) {
  const prefix = getEmployeeCodePrefix(companyKey);
  const pattern = employeeCodePattern(companyKey);
  if (!prefix || !pattern) return 0;

  const employees = await Employee.find({ employeeCode: pattern }).select('employeeCode').lean();
  let maxSeq = 0;
  for (const emp of employees) {
    const seq = parseEmployeeCodeSequence(emp.employeeCode, companyKey);
    if (seq != null && seq > maxSeq) maxSeq = seq;
  }
  return maxSeq;
}

export async function generateNextEmployeeCode(Employee, companyKey) {
  const maxSeq = await getMaxEmployeeCodeSequence(Employee, companyKey);
  return buildEmployeeCode(companyKey, maxSeq + 1);
}

const formatCodeError = (companyKey) => {
  const digit = getCompanyEmployeeDigit(companyKey);
  return `Employee ID must match format EMP${digit}0001 (e.g. EMP${digit}0001)`;
};

export async function assignEmployeeCodeOnCreate(Employee, companyKey, payload) {
  const trimmed = (payload.employeeCode || '').trim().toUpperCase();
  if (trimmed) {
    if (!isValidEmployeeCodeForCompany(trimmed, companyKey)) {
      const err = new Error(formatCodeError(companyKey));
      err.status = 400;
      throw err;
    }
    const exists = await Employee.findOne({ employeeCode: trimmed });
    if (exists) {
      const err = new Error('Employee ID already in use');
      err.status = 400;
      throw err;
    }
    payload.employeeCode = trimmed;
    return payload;
  }

  payload.employeeCode = await generateNextEmployeeCode(Employee, companyKey);
  return payload;
}

export async function validateEmployeeCodeOnUpdate(Employee, companyKey, employeeId, payload) {
  const raw = payload.employeeCode;
  if (raw == null || String(raw).trim() === '') {
    delete payload.employeeCode;
    return payload;
  }

  const trimmed = String(raw).trim().toUpperCase();
  if (!isValidEmployeeCodeForCompany(trimmed, companyKey)) {
    const err = new Error(formatCodeError(companyKey));
    err.status = 400;
    throw err;
  }

  const exists = await Employee.findOne({
    employeeCode: trimmed,
    _id: { $ne: employeeId },
  });
  if (exists) {
    const err = new Error('Employee ID already in use');
    err.status = 400;
    throw err;
  }

  payload.employeeCode = trimmed;
  return payload;
}

/** Assign EMP{digit}#### codes to employees missing a valid code (oldest first). */
export async function backfillEmployeeCodes(Employee, companyKey) {
  const pattern = employeeCodePattern(companyKey);
  if (!pattern) throw new Error(`Unknown company: ${companyKey}`);

  const employees = await Employee.find().sort({ createdAt: 1, _id: 1 });
  let maxSeq = await getMaxEmployeeCodeSequence(Employee, companyKey);
  let updated = 0;

  for (const emp of employees) {
    if (pattern.test(emp.employeeCode || '')) continue;
    maxSeq += 1;
    emp.employeeCode = buildEmployeeCode(companyKey, maxSeq);
    await emp.save();
    updated += 1;
  }

  return updated;
}
