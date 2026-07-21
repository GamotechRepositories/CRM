import mongoose from 'mongoose';
import { pushNotificationEntrySchema } from '../../utils/pushNotificationFields.js';
import { notificationPreferencesSchema } from '../../utils/notificationPreferencesFields.js';

export const CENTRAL_TENANTS = [
  'adsResearchGlobal',
  'bangarProperties',
  'mahaProperties',
  'salesTechReality',
];

/** Root owner role — only for seeded platform owner (the boss) */
export const CENTRAL_ROOT_ROLE = 'CEO';

/**
 * CEO support team roles — create & manage meetings for the boss
 * across all company CRMs.
 */
export const CENTRAL_TEAM_ROLES = [
  'Executive Assistant',
  'Meeting Coordinator',
  'Scheduler',
  'Chief of Staff',
  'Secretary',
];

export const CENTRAL_ROLES = [CENTRAL_ROOT_ROLE, ...CENTRAL_TEAM_ROLES];

const centralAdminUserSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: true,
      trim: true,
    },
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    password: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: CENTRAL_ROLES,
      default: 'Executive Assistant',
    },
    /** Primary root account seeded for platform ownership (the boss) */
    isRoot: {
      type: Boolean,
      default: false,
    },
    /** Companies this team member can operate across for the CEO */
    tenants: {
      type: [
        {
          type: String,
          enum: CENTRAL_TENANTS,
        },
      ],
      default: () => [...CENTRAL_TENANTS],
    },
    status: {
      type: String,
      enum: ['Active', 'Inactive'],
      default: 'Active',
    },
    phone: {
      type: String,
      default: '',
    },
    /** FCM device tokens — multiple devices per user, no duplicates. */
    notifications: {
      type: [pushNotificationEntrySchema],
      default: [],
    },
    /** Push notification channel preferences. */
    notificationPreferences: {
      type: notificationPreferencesSchema,
      default: () => ({}),
    },
  },
  { timestamps: true }
);

const CentralAdminUser = mongoose.model('CentralAdminUser', centralAdminUserSchema);

export default CentralAdminUser;
