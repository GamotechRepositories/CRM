import mongoose from 'mongoose';

export const HOLIDAY_TYPES = [
  'Public Holiday',
  'Company Holiday',
  'Optional Holiday',
  'Company Off',
];

export const HOLIDAY_SCOPES = [
  'all_company',
  'department',
];

/** Shared holiday schema fields per company. */
export const getHolidayFields = (companyRef) => ({
  title: {
    type: String,
    required: true,
    trim: true,
  },
  date: {
    type: Date,
    required: true,
    index: true,
  },
  endDate: {
    type: Date,
    default: null,
  },
  type: {
    type: String,
    enum: HOLIDAY_TYPES,
    default: 'Public Holiday',
  },
  description: {
    type: String,
    default: '',
    trim: true,
  },
  year: {
    type: Number,
    required: true,
    index: true,
  },
  month: {
    type: Number, // 1 to 12
    required: true,
    index: true,
  },
  scope: {
    type: String,
    enum: HOLIDAY_SCOPES,
    default: 'all_company',
  },
  department: {
    type: String,
    default: '',
  },
  createdBy: {
    type: mongoose.Schema.Types.ObjectId,
    ref: companyRef ? `${companyRef}_Employee` : 'Employee',
    default: null,
  },
  createdByName: {
    type: String,
    default: '',
  },
  createdByRole: {
    type: String,
    default: '',
  },
});
