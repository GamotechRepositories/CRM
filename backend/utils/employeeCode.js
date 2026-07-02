/** Employee ID format: EMP + sequence (min 3 digits), e.g. EMP001, EMP002 */
export const EMPLOYEE_CODE_PREFIX = 'EMP';
const EMPLOYEE_SEQUENCE_MIN_DIGITS = 3;

export const COMPANY_KEYS = [
  'adsResearchGlobal',
  'bangarProperties',
  'mahaProperties',
  'salesTechReality',
];

export const buildEmployeeCode = (_companyKey, sequence) =>
  `${EMPLOYEE_CODE_PREFIX}${String(sequence).padStart(EMPLOYEE_SEQUENCE_MIN_DIGITS, '0')}`;

export const employeeCodePattern = () =>
  new RegExp(`^${EMPLOYEE_CODE_PREFIX}\\d{${EMPLOYEE_SEQUENCE_MIN_DIGITS},}$`, 'i');

export const isValidEmployeeCodeForCompany = (code) => {
  if (!code || typeof code !== 'string') return false;
  return employeeCodePattern().test(code.trim());
};

export const parseEmployeeCodeSequence = (code) => {
  if (!code) return null;
  const normalized = code.trim().toUpperCase();
  if (
    !normalized.startsWith(EMPLOYEE_CODE_PREFIX)
    || normalized.length < EMPLOYEE_CODE_PREFIX.length + EMPLOYEE_SEQUENCE_MIN_DIGITS
  ) return null;
  const seq = parseInt(normalized.slice(EMPLOYEE_CODE_PREFIX.length), 10);
  return Number.isNaN(seq) ? null : seq;
};

export async function getMaxEmployeeCodeSequence(Employee) {
  const pattern = employeeCodePattern();
  const employees = await Employee.find({ employeeCode: pattern }).select('employeeCode').lean();
  let maxSeq = 0;
  for (const emp of employees) {
    const seq = parseEmployeeCodeSequence(emp.employeeCode);
    if (seq != null && seq > maxSeq) maxSeq = seq;
  }
  return maxSeq;
}

export async function generateNextEmployeeCode(Employee, companyKey) {
  void companyKey;
  const maxSeq = await getMaxEmployeeCodeSequence(Employee);
  return buildEmployeeCode(companyKey, maxSeq + 1);
}

const formatCodeError = () =>
  'Employee ID must match format EMP001 or higher (e.g. EMP001, EMP002)';

export async function assignEmployeeCodeOnCreate(Employee, companyKey, payload) {
  const trimmed = (payload.employeeCode || '').trim().toUpperCase();
  if (trimmed) {
    if (!isValidEmployeeCodeForCompany(trimmed)) {
      const err = new Error(formatCodeError());
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
  void companyKey;
  const raw = payload.employeeCode;
  if (raw == null || String(raw).trim() === '') {
    delete payload.employeeCode;
    return payload;
  }

  const trimmed = String(raw).trim().toUpperCase();
  if (!isValidEmployeeCodeForCompany(trimmed)) {
    const err = new Error(formatCodeError());
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

/** Renumber all employees to EMP001, EMP002, … (oldest first). */
export async function backfillEmployeeCodes(Employee, companyKey) {
  void companyKey;
  const employees = await Employee.find().sort({ createdAt: 1, _id: 1 });
  let updated = 0;

  for (let index = 0; index < employees.length; index += 1) {
    const emp = employees[index];
    const nextCode = buildEmployeeCode(companyKey, index + 1);
    if (emp.employeeCode !== nextCode) {
      emp.employeeCode = nextCode;
      await emp.save();
      updated += 1;
    }
  }

  return updated;
}
