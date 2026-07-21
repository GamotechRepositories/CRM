import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import connectDB from './config/db.js';
import { getFirebaseAdmin } from './config/firebase.js';
import { startNotificationWorker } from './worker/notification.worker.js';
import { startMeetingReminderJob } from './jobs/meetingReminder.job.js';
import { cleanupOrphanTokens } from './utils/pushTokenStore.js';
import { mountSwaggerDocs } from './config/swagger.js';

dotenv.config();

// Eager Firebase init (validates credentials at startup)
getFirebaseAdmin();

const app = express();
const PORT = process.env.PORT || 5011;
const companies = ['adsResearchGlobal', 'bangarProperties', 'mahaProperties', 'salesTechReality'];

// Connect Database
await connectDB();

// Background job: auto check-out previous day's open sessions
const runAttendanceSweeper = async () => {
  for (const company of companies) {
    try {
      const attendanceUtil = await import(`./utils/${company}/${company}_attendanceAutoCheckout.js`);
      const { updated } = await attendanceUtil.autoCheckoutPreviousDays();
      if (updated) console.log(`[${company}] Auto checked-out ${updated} attendance record(s)`);
    } catch (e) {
      console.error(`[${company}] Attendance auto-checkout job failed:`, e?.message || e);
    }
  }
};
runAttendanceSweeper();

// Daily 11:59 PM auto checkout for users who forgot to check out
const scheduleDailyAttendanceAutoCheckout = () => {
  const now = new Date();
  const runAt = new Date(now);
  runAt.setHours(23, 59, 0, 0);
  if (runAt <= now) runAt.setDate(runAt.getDate() + 1);

  const delay = runAt.getTime() - now.getTime();
  setTimeout(async () => {
    for (const company of companies) {
      try {
        const attendanceUtil = await import(`./utils/${company}/${company}_attendanceAutoCheckout.js`);
        const { updated } = await attendanceUtil.autoCheckoutForDay(new Date());
        if (updated) console.log(`[${company}] 11:59 PM auto checked-out ${updated} attendance record(s)`);
      } catch (e) {
        console.error(`[${company}] 11:59 PM attendance auto-checkout failed:`, e?.message || e);
      }
    }
    scheduleDailyAttendanceAutoCheckout();
  }, delay);
};
scheduleDailyAttendanceAutoCheckout();

// Auto task scheduler: generate recurring tasks from templates
const runRecurringTaskScheduler = async () => {
  for (const company of companies) {
    try {
      const recurringUtil = await import(`./utils/${company}/${company}_recurringTaskScheduler.js`);
      const { processedTemplates, generatedCount } = await recurringUtil.processRecurringTasks();
      if (processedTemplates > 0 || generatedCount > 0) {
        console.log(`[${company}] Recurring tasks processed: ${processedTemplates}, generated: ${generatedCount}`);
      }
    } catch (e) {
      console.error(`[${company}] Recurring task scheduler failed:`, e?.message || e);
    }
  }
};

runRecurringTaskScheduler();
setInterval(runRecurringTaskScheduler, 10 * 60 * 1000);

const DEFAULT_CORS_ORIGINS = [
  'https://crm-mauve-mu.vercel.app',
  'https://www.dmcrms.in',
  'https://dmcrms.in',
  'http://localhost:5173',
  'http://localhost:5174',
  'http://localhost:5175',
  'http://localhost:5176',
  'http://localhost:5177',
];

const corsOrigins = (process.env.CORS_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const corsOptions = {
  origin: corsOrigins.length ? corsOrigins : DEFAULT_CORS_ORIGINS,
  methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
  credentials: true,
};

app.use(cors(corsOptions));
app.options(/.*/, cors(corsOptions));
// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// OpenAPI 3.1 documentation (Swagger UI)
mountSwaggerDocs(app);

// Health route
app.get('/', (req, res) => {
  res.send('Welcome to the CRM API');
});

// Company-specific routes mounted as: /api/v1/<company>/*
const routeFiles = [
  'designationRoute',
  'employeeRoute',
  'clientRoute',
  'projectRoute',
  'salaryRoute',
  'attendanceRoute',
  'leadRoute',
  'socialMediaCalendarRoute',
  'authRoute',
  'taskRoute',
  'collaboratorRoute',
  'leaveRoute',
  'billingRoute',
  'quotationRoute',
  'documentRoute',
  'companyRoute',
  'expenseRoute',
  'clientProfileRoute',
  'locationRoute',
  'chatRoute',
  'assetRoute',
  'notificationRoute',
  'announcementRoute',
];

for (const company of companies) {
  for (const routeFile of routeFiles) {
    const routeModule = await import(`./routes/${company}/${company}_${routeFile}.js`);
    app.use(`/api/v1/${company}`, routeModule.default);
  }
}

// Property listings, site visits & ads lead webhooks — real-estate tenants only
const PROPERTY_TENANTS = ['bangarProperties', 'mahaProperties', 'salesTechReality'];
for (const company of PROPERTY_TENANTS) {
  const propertyRoute = await import(`./routes/${company}/${company}_propertyRoute.js`);
  app.use(`/api/v1/${company}`, propertyRoute.default);
  const siteVisitRoute = await import(`./routes/${company}/${company}_siteVisitRoute.js`);
  app.use(`/api/v1/${company}`, siteVisitRoute.default);
  const adsWebhookRoute = await import(`./routes/${company}/${company}_adsWebhookRoute.js`);
  app.use(`/api/v1/${company}`, adsWebhookRoute.default);
}

// Centralized admin panel: /api/v1/admin/*
const centralAdminRoute = await import('./routes/centralAdminRoute.js');
app.use('/api/v1/admin', centralAdminRoute.default);

// Push notifications (FCM device registration + history)
const notificationRoutes = await import('./routes/notification.routes.js');
app.use('/api', notificationRoutes.default);

// Background: FCM worker + meeting reminder cron + token cleanup
startNotificationWorker();
startMeetingReminderJob();
cleanupOrphanTokens().catch((e) =>
  console.warn('[PushToken] Orphan token cleanup skipped:', e?.message),
);

// Server start
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running on port ${PORT}`);
});