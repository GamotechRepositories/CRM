/**
 * Per-tenant chat integration settings.
 * Each client frontend uses the same chat API under /api/v1/{company}/chat/*
 * but can enable different bots, webhooks, or branding via this config.
 */
export const CHAT_INTEGRATIONS = {
  bangarProperties: {
    tenantId: 'bangarProperties',
    displayName: 'Bangar Properties',
    features: {
      directMessages: true,
      groupChat: false,
      fileSharing: false,
      botEnabled: false,
    },
    bot: {
      name: 'Bangar Assistant',
      welcomeMessage: 'Welcome to Bangar Properties team chat.',
      webhookUrl: process.env.BANGAR_CHAT_WEBHOOK_URL || '',
    },
    pollingIntervalMs: 5000,
  },
  mahaProperties: {
    tenantId: 'mahaProperties',
    displayName: 'Maha Properties',
    features: {
      directMessages: true,
      groupChat: false,
      fileSharing: false,
      botEnabled: false,
    },
    bot: {
      name: 'Maha Assistant',
      welcomeMessage: 'Welcome to Maha Properties team chat.',
      webhookUrl: process.env.MAHA_CHAT_WEBHOOK_URL || '',
    },
    pollingIntervalMs: 5000,
  },
  adsResearchGlobal: {
    tenantId: 'adsResearchGlobal',
    displayName: 'Ads Research Global',
    features: {
      directMessages: true,
      groupChat: false,
      fileSharing: false,
      botEnabled: false,
    },
    bot: {
      name: 'ARG Assistant',
      welcomeMessage: 'Welcome to Ads Research Global team chat.',
      webhookUrl: process.env.ARG_CHAT_WEBHOOK_URL || '',
    },
    pollingIntervalMs: 5000,
  },
  salesTechReality: {
    tenantId: 'salesTechReality',
    displayName: 'Sales Tech Reality',
    features: {
      directMessages: true,
      groupChat: false,
      fileSharing: false,
      botEnabled: false,
    },
    bot: {
      name: 'STR Assistant',
      welcomeMessage: 'Welcome to Sales Tech Reality team chat.',
      webhookUrl: process.env.STR_CHAT_WEBHOOK_URL || '',
    },
    pollingIntervalMs: 5000,
  },
};

export const getChatIntegration = (tenantId) =>
  CHAT_INTEGRATIONS[tenantId] || {
    tenantId,
    displayName: tenantId,
    features: { directMessages: true, groupChat: false, fileSharing: false, botEnabled: false },
    bot: { name: 'Assistant', welcomeMessage: 'Welcome to team chat.', webhookUrl: '' },
    pollingIntervalMs: 5000,
  };
