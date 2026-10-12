import MetaConfig from '../models/metaConfig.js';
import {
  DEFAULT_META_API_VERSION,
  fetchAllMetaCampaignsAndLeads,
  formatAdAccountId,
  parseMetaLeadFields,
  testMetaConnection as runTestMetaConnection,
} from './metaGraphApi.js';

const TENANT_ENV = {
  bangarProperties: {
    ownerEmail: 'BANGAR_ADS_LEAD_OWNER_EMAIL',
    ownerId: 'BANGAR_ADS_LEAD_OWNER_ID',
    metaToken: 'BANGAR_META_PAGE_ACCESS_TOKEN',
    metaAppId: 'BANGAR_META_APP_ID',
    metaAdAccountId: 'BANGAR_META_ADS_ACCOUNT_ID',
  },
  mahaProperties: {
    ownerEmail: 'MAHA_ADS_LEAD_OWNER_EMAIL',
    ownerId: 'MAHA_ADS_LEAD_OWNER_ID',
    metaToken: 'MAHA_META_PAGE_ACCESS_TOKEN',
    metaAppId: 'MAHA_META_APP_ID',
    metaAdAccountId: 'MAHA_META_ADS_ACCOUNT_ID',
  },
  salesTechReality: {
    ownerEmail: 'SALESTECH_ADS_LEAD_OWNER_EMAIL',
    ownerId: 'SALESTECH_ADS_LEAD_OWNER_ID',
    metaToken: 'SALESTECH_META_PAGE_ACCESS_TOKEN',
    metaAppId: 'SALESTECH_META_APP_ID',
    metaAdAccountId: 'SALESTECH_META_ADS_ACCOUNT_ID',
  },
  adsResearchGlobal: {
    ownerEmail: 'ADSRESEARCH_ADS_LEAD_OWNER_EMAIL',
    ownerId: 'ADSRESEARCH_ADS_LEAD_OWNER_ID',
    metaToken: 'ADSRESEARCH_META_PAGE_ACCESS_TOKEN',
    metaAppId: 'ADSRESEARCH_META_APP_ID',
    metaAdAccountId: 'ADSRESEARCH_META_ADS_ACCOUNT_ID',
  },
};

const pick = (...values) => {
  for (const v of values) {
    if (v !== undefined && v !== null) {
      const s = String(v).trim();
      if (s) return s;
    }
  }
  return '';
};

export function createCampaignHandlers({ Lead, Employee, Campaign, tenantKey }) {
  const envKeys = TENANT_ENV[tenantKey] || {};

  /** Helper to find or resolve active employee to assign newly created leads to */
  const resolveOwnerId = async () => {
    const ownerId = pick(process.env[envKeys.ownerId]);
    if (ownerId) return ownerId;

    const ownerEmail = pick(process.env[envKeys.ownerEmail]);
    if (ownerEmail) {
      const byEmail = await Employee.findOne({
        email: new RegExp(`^${ownerEmail.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}$`, 'i'),
        status: 'Active',
      }).select('_id');
      if (byEmail) return byEmail._id;
    }

    const fallback = await Employee.findOne({ status: 'Active' })
      .sort({ createdAt: 1 })
      .select('_id');
    if (fallback?._id) return fallback._id;

    // Any employee fallback
    const anyEmployee = await Employee.findOne().select('_id');
    return anyEmployee?._id || null;
  };

  /** Resolves credentials from DB or Environment variables */
  const resolveCredentials = async (override = {}) => {
    const dbConfig = await MetaConfig.findOne({ tenantKey }).lean();

    const appId = pick(
      override.appId,
      dbConfig?.appId,
      process.env[envKeys.metaAppId],
      process.env.META_APP_ID
    );

    const adAccountId = pick(
      override.adAccountId,
      dbConfig?.adAccountId,
      process.env[envKeys.metaAdAccountId],
      process.env.META_ADS_ACCOUNT_ID
    );

    const systemUserToken = pick(
      override.systemUserToken,
      override.accessToken,
      dbConfig?.systemUserToken,
      process.env[envKeys.metaToken],
      process.env.META_PAGE_ACCESS_TOKEN,
      process.env.META_SYSTEM_USER_TOKEN
    );

    const apiVersion = pick(
      override.apiVersion,
      dbConfig?.apiVersion,
      process.env.META_API_VERSION,
      DEFAULT_META_API_VERSION
    );

    return {
      appId,
      adAccountId,
      systemUserToken,
      apiVersion,
      dbConfig,
    };
  };

  /** Mask secret token for display */
  const maskToken = (token = '') => {
    if (!token) return '';
    if (token.length <= 10) return '••••••••••';
    return `${token.slice(0, 6)}••••••••${token.slice(-4)}`;
  };

  /** GET /api/v1/:company/campaigns/meta/config */
  const getMetaConfig = async (req, res) => {
    try {
      const creds = await resolveCredentials();
      const dbConfig = creds.dbConfig || {};

      return res.status(200).json({
        config: {
          tenantKey,
          appId: creds.appId || '',
          adAccountId: creds.adAccountId || '',
          hasToken: Boolean(creds.systemUserToken),
          maskedToken: maskToken(creds.systemUserToken),
          apiVersion: creds.apiVersion || DEFAULT_META_API_VERSION,
          lastSyncedAt: dbConfig.lastSyncedAt || null,
          lastSyncStatus: dbConfig.lastSyncStatus || '',
          lastSyncMessage: dbConfig.lastSyncMessage || '',
          lastSyncStats: dbConfig.lastSyncStats || {
            campaignsCount: 0,
            leadsFetchedCount: 0,
            newLeadsCount: 0,
            existingLeadsCount: 0,
          },
        },
      });
    } catch (error) {
      console.error(`[${tenantKey}] getMetaConfig error:`, error);
      return res.status(500).json({ message: error.message || 'Failed to get Meta configuration' });
    }
  };

  /** POST /api/v1/:company/campaigns/meta/config */
  const saveMetaConfig = async (req, res) => {
    try {
      const { appId, adAccountId, systemUserToken, apiVersion } = req.body || {};

      let config = await MetaConfig.findOne({ tenantKey });
      if (!config) {
        config = new MetaConfig({ tenantKey });
      }

      if (appId !== undefined) config.appId = String(appId).trim();
      if (adAccountId !== undefined) config.adAccountId = String(adAccountId).trim();
      if (apiVersion !== undefined) config.apiVersion = String(apiVersion || DEFAULT_META_API_VERSION).trim();

      // Only update token if user sent an actual new token (not masked)
      if (systemUserToken && !systemUserToken.includes('••••')) {
        config.systemUserToken = String(systemUserToken).trim();
      }

      await config.save();

      return res.status(200).json({
        message: 'Meta configuration saved successfully',
        config: {
          tenantKey,
          appId: config.appId,
          adAccountId: config.adAccountId,
          hasToken: Boolean(config.systemUserToken),
          maskedToken: maskToken(config.systemUserToken),
          apiVersion: config.apiVersion,
          lastSyncedAt: config.lastSyncedAt,
          lastSyncStatus: config.lastSyncStatus,
          lastSyncMessage: config.lastSyncMessage,
        },
      });
    } catch (error) {
      console.error(`[${tenantKey}] saveMetaConfig error:`, error);
      return res.status(500).json({ message: error.message || 'Failed to save Meta configuration' });
    }
  };

  /** POST /api/v1/:company/campaigns/meta/test */
  const testMetaConnection = async (req, res) => {
    try {
      const creds = await resolveCredentials(req.body || {});

      if (!creds.adAccountId) {
        return res.status(400).json({ message: 'Meta Ads Account ID is required' });
      }
      if (!creds.systemUserToken) {
        return res.status(400).json({ message: 'Meta Page Token of System User is required' });
      }

      const result = await runTestMetaConnection({
        adAccountId: creds.adAccountId,
        accessToken: creds.systemUserToken,
        appId: creds.appId,
        apiVersion: creds.apiVersion,
      });

      return res.status(200).json({
        message: `Successfully connected to Meta Ad Account "${result.account.name}" (${result.account.id})`,
        account: result.account,
      });
    } catch (error) {
      console.error(`[${tenantKey}] testMetaConnection error:`, error);
      return res.status(error.status || 400).json({
        message: error.message || 'Failed to connect to Meta Graph API',
        details: error.details,
      });
    }
  };

  /** POST /api/v1/:company/campaigns/meta/sync */
  const syncMetaCampaignsAndLeads = async (req, res) => {
    try {
      const creds = await resolveCredentials(req.body || {});

      if (!creds.adAccountId) {
        return res.status(400).json({
          message:
            'Meta Ads Account ID is missing. Please configure it in Settings or pass adAccountId in request.',
        });
      }
      if (!creds.systemUserToken) {
        return res.status(400).json({
          message:
            'Meta Page Token of System User is missing. Please configure it in Settings or pass systemUserToken in request.',
        });
      }

      // Mark config as running
      await MetaConfig.updateOne(
        { tenantKey },
        {
          $set: {
            appId: creds.appId,
            adAccountId: creds.adAccountId,
            apiVersion: creds.apiVersion,
            lastSyncStatus: 'running',
            lastSyncMessage: 'Syncing campaigns and leads from Meta Graph API v26.0...',
          },
        },
        { upsert: true }
      );

      // Fetch from Meta Graph API v26
      const { campaigns, leads } = await fetchAllMetaCampaignsAndLeads({
        adAccountId: creds.adAccountId,
        accessToken: creds.systemUserToken,
        appId: creds.appId,
        apiVersion: creds.apiVersion,
      });

      // 1. Upsert Campaigns in CRM
      for (const c of campaigns) {
        await Campaign.findOneAndUpdate(
          { campaignId: c.campaignId },
          {
            $set: {
              name: c.name,
              status: c.status,
              objective: c.objective,
              adAccountId: c.adAccountId,
              dailyBudget: c.dailyBudget,
              lifetimeBudget: c.lifetimeBudget,
              budgetRemaining: c.budgetRemaining,
              spend: c.spend,
              impressions: c.impressions,
              clicks: c.clicks,
              reach: c.reach,
              leadsCount: c.leadsCount,
              startTime: c.startTime,
              stopTime: c.stopTime,
              lastSyncedAt: new Date(),
              metaRaw: c.metaRaw,
            },
          },
          { upsert: true, new: true }
        );
      }

      // 2. Upsert Leads in CRM
      const ownerId = await resolveOwnerId();
      let newLeadsCount = 0;
      let existingLeadsCount = 0;

      for (const item of leads) {
        const externalLeadId = item.leadId;
        const existing = await Lead.findOne({ externalLeadId, adPlatform: 'meta' });

        if (existing) {
          existingLeadsCount += 1;
          // Refresh campaign & ad metadata if missing
          const updateFields = {};
          if (!existing.campaignId && item.campaignId) updateFields.campaignId = item.campaignId;
          if (!existing.campaignName && item.campaignName) updateFields.campaignName = item.campaignName;
          if (!existing.adId && item.adId) updateFields.adId = item.adId;
          if (!existing.adName && item.adName) updateFields.adName = item.adName;
          if (!existing.formId && item.formId) updateFields.formId = item.formId;

          if (Object.keys(updateFields).length > 0) {
            await Lead.updateOne({ _id: existing._id }, { $set: updateFields });
          }
          continue;
        }

        const mapped = parseMetaLeadFields(item.raw);
        const contactNumber = mapped.contactNumber || 'N/A';
        const name = mapped.name || 'Meta Lead';

        const descriptionParts = [
          mapped.email ? `Email: ${mapped.email}` : '',
          item.campaignName ? `Campaign: ${item.campaignName} (ID: ${item.campaignId})` : '',
          item.adName ? `Ad: ${item.adName} (ID: ${item.adId})` : '',
          item.formId ? `Form ID: ${item.formId}` : '',
          mapped.customAnswers?.length ? `Answers:\n  • ${mapped.customAnswers.join('\n  • ')}` : '',
          'Imported from Meta Ads Graph API v26.0',
        ].filter(Boolean);

        try {
          await Lead.create({
            name,
            businessName: mapped.businessName || name,
            contactNumber,
            email: mapped.email || '',
            address: mapped.address || '',
            city: mapped.city || '',
            state: mapped.state || '',
            leadSource: 'Meta Ads',
            adPlatform: 'meta',
            externalLeadId,
            campaignId: item.campaignId || '',
            campaignName: item.campaignName || '',
            adId: item.adId || '',
            adName: item.adName || '',
            formId: item.formId || '',
            description: descriptionParts.join('\n'),
            status: 'Call not Received',
            generatedBy: ownerId,
            adsRawPayload: item.raw,
          });
          newLeadsCount += 1;
        } catch (leadErr) {
          console.warn(`[${tenantKey}] Error creating lead ${externalLeadId}:`, leadErr.message);
        }
      }

      // Recount leads per campaign directly from Lead collection
      for (const c of campaigns) {
        const liveCount = await Lead.countDocuments({
          $or: [{ campaignId: c.campaignId }, { campaignName: c.name }],
        });
        await Campaign.updateOne(
          { campaignId: c.campaignId },
          { $set: { leadsCount: liveCount } }
        );
      }

      const syncStats = {
        campaignsCount: campaigns.length,
        leadsFetchedCount: leads.length,
        newLeadsCount,
        existingLeadsCount,
      };

      const syncMsg = `Successfully synced ${campaigns.length} campaigns and ${newLeadsCount} new leads (${existingLeadsCount} existing) from Meta Graph API v26.0`;

      await MetaConfig.updateOne(
        { tenantKey },
        {
          $set: {
            lastSyncedAt: new Date(),
            lastSyncStatus: 'success',
            lastSyncMessage: syncMsg,
            lastSyncStats: syncStats,
          },
        }
      );

      // Return refreshed campaigns
      const updatedCampaigns = await Campaign.find().sort({ lastSyncedAt: -1, createdAt: -1 }).lean();

      return res.status(200).json({
        message: syncMsg,
        stats: syncStats,
        campaigns: updatedCampaigns,
      });
    } catch (error) {
      console.error(`[${tenantKey}] syncMetaCampaignsAndLeads error:`, error);
      await MetaConfig.updateOne(
        { tenantKey },
        {
          $set: {
            lastSyncStatus: 'failed',
            lastSyncMessage: error.message || 'Sync failed',
          },
        }
      );
      return res.status(error.status || 500).json({
        message: error.message || 'Failed to sync Meta campaigns and leads',
        details: error.details,
      });
    }
  };

  /** GET /api/v1/:company/campaigns */
  const getCampaigns = async (req, res) => {
    try {
      const { search, status, sort } = req.query || {};
      const query = {};

      if (status && status !== 'ALL') {
        query.status = status;
      }

      if (search && String(search).trim()) {
        const term = String(search).trim();
        query.$or = [
          { name: { $regex: term, $options: 'i' } },
          { campaignId: { $regex: term, $options: 'i' } },
          { objective: { $regex: term, $options: 'i' } },
        ];
      }

      let sortOption = { lastSyncedAt: -1, createdAt: -1 };
      if (sort === 'leads') sortOption = { leadsCount: -1 };
      else if (sort === 'spend') sortOption = { spend: -1 };
      else if (sort === 'name') sortOption = { name: 1 };

      const campaigns = await Campaign.find(query).sort(sortOption).lean();

      // Aggregate high-level stats across all campaigns
      const allCampaigns = await Campaign.find().lean();
      const totalCampaigns = allCampaigns.length;
      const activeCampaigns = allCampaigns.filter((c) => c.status === 'ACTIVE').length;
      const totalSpend = allCampaigns.reduce((acc, c) => acc + (c.spend || 0), 0);
      const totalImpressions = allCampaigns.reduce((acc, c) => acc + (c.impressions || 0), 0);
      const totalClicks = allCampaigns.reduce((acc, c) => acc + (c.clicks || 0), 0);

      // Total leads with adPlatform meta
      const totalMetaLeads = await Lead.countDocuments({
        $or: [{ adPlatform: 'meta' }, { leadSource: 'Meta Ads' }],
      });

      const config = await MetaConfig.findOne({ tenantKey }).lean();

      return res.status(200).json({
        campaigns,
        stats: {
          totalCampaigns,
          activeCampaigns,
          totalMetaLeads,
          totalSpend,
          totalImpressions,
          totalClicks,
        },
        metaConfig: {
          isConfigured: Boolean(config?.adAccountId && config?.systemUserToken),
          adAccountId: config?.adAccountId || '',
          lastSyncedAt: config?.lastSyncedAt || null,
          lastSyncStatus: config?.lastSyncStatus || '',
          lastSyncMessage: config?.lastSyncMessage || '',
        },
      });
    } catch (error) {
      console.error(`[${tenantKey}] getCampaigns error:`, error);
      return res.status(500).json({ message: error.message || 'Failed to get campaigns' });
    }
  };

  /** GET /api/v1/:company/campaigns/:campaignId */
  const getCampaignById = async (req, res) => {
    try {
      const { campaignId } = req.params;
      const campaign = await Campaign.findOne({
        $or: [{ campaignId }, { _id: campaignId.match(/^[0-9a-fA-F]{24}$/) ? campaignId : null }],
      }).lean();

      if (!campaign) {
        return res.status(404).json({ message: 'Campaign not found' });
      }

      const leads = await Lead.find({
        $or: [{ campaignId: campaign.campaignId }, { campaignName: campaign.name }],
      })
        .sort({ createdAt: -1 })
        .limit(100)
        .lean();

      return res.status(200).json({
        campaign,
        leads,
        leadsCount: leads.length,
      });
    } catch (error) {
      console.error(`[${tenantKey}] getCampaignById error:`, error);
      return res.status(500).json({ message: error.message || 'Failed to get campaign' });
    }
  };

  /** GET /api/v1/:company/campaigns/:campaignId/leads */
  const getCampaignLeads = async (req, res) => {
    try {
      const { campaignId } = req.params;
      const { search } = req.query || {};

      const query = {
        $or: [{ campaignId }, { campaignName: campaignId }],
      };

      if (search && String(search).trim()) {
        const s = String(search).trim();
        query.$and = [
          {
            $or: [
              { name: { $regex: s, $options: 'i' } },
              { contactNumber: { $regex: s, $options: 'i' } },
              { email: { $regex: s, $options: 'i' } },
            ],
          },
        ];
      }

      const leads = await Lead.find(query).sort({ createdAt: -1 }).lean();
      return res.status(200).json({ leads, count: leads.length });
    } catch (error) {
      console.error(`[${tenantKey}] getCampaignLeads error:`, error);
      return res.status(500).json({ message: error.message || 'Failed to get campaign leads' });
    }
  };

  return {
    getMetaConfig,
    saveMetaConfig,
    testMetaConnection,
    syncMetaCampaignsAndLeads,
    getCampaigns,
    getCampaignById,
    getCampaignLeads,
  };
}
