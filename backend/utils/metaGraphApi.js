/**
 * Meta Graph API v26.0 integration client for fetching campaigns and leads.
 * Standard endpoints:
 *   Ad Account:     GET /{apiVersion}/act_{ad_account_id}
 *   Campaigns:      GET /{apiVersion}/act_{ad_account_id}/campaigns
 *   Ads:            GET /{apiVersion}/act_{ad_account_id}/ads
 *   Ad Leads:       GET /{apiVersion}/{ad_id}/leads
 *   Form Leads:     GET /{apiVersion}/{form_id}/leads
 *   Lead Detail:    GET /{apiVersion}/{leadgen_id}
 */

export const DEFAULT_META_API_VERSION = 'v26.0';

/** Normalizes ad account ID to ensure it starts with 'act_'. */
export const formatAdAccountId = (rawId = '') => {
  const clean = String(rawId || '').trim();
  if (!clean) return '';
  return clean.startsWith('act_') ? clean : `act_${clean}`;
};

/** Executes a GET request against the Meta Graph API with error handling. */
export const metaFetch = async (endpoint, accessToken, queryParams = {}, apiVersion = DEFAULT_META_API_VERSION) => {
  if (!accessToken) {
    const error = new Error('Meta access token is required');
    error.status = 400;
    throw error;
  }

  const cleanVersion = (apiVersion || DEFAULT_META_API_VERSION).replace(/^v?/, 'v');
  const cleanEndpoint = endpoint.replace(/^\//, '');
  const url = new URL(`https://graph.facebook.com/${cleanVersion}/${cleanEndpoint}`);

  url.searchParams.set('access_token', accessToken);
  for (const [key, value] of Object.entries(queryParams)) {
    if (value !== undefined && value !== null && value !== '') {
      url.searchParams.set(key, String(value));
    }
  }

  const response = await fetch(url.toString(), {
    method: 'GET',
    headers: {
      Accept: 'application/json',
    },
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok || data?.error) {
    const metaError = data?.error || {};
    const message = metaError.message || `Meta Graph API error HTTP ${response.status}`;
    const err = new Error(message);
    err.status = response.status || 400;
    err.code = metaError.code;
    err.errorSubcode = metaError.error_subcode;
    err.type = metaError.type;
    err.details = data;
    throw err;
  }

  return data;
};

/** Validates credentials by checking Ad Account metadata. */
export const testMetaConnection = async ({
  adAccountId,
  accessToken,
  appId = '',
  apiVersion = DEFAULT_META_API_VERSION,
}) => {
  const formattedId = formatAdAccountId(adAccountId);
  if (!formattedId) {
    const error = new Error('Meta Ads Account ID is required');
    error.status = 400;
    throw error;
  }

  const accountData = await metaFetch(
    formattedId,
    accessToken,
    { fields: 'id,name,account_status,currency,timezone_name,amount_spent,business_name' },
    apiVersion
  );

  return {
    success: true,
    account: {
      id: accountData.id,
      name: accountData.name || 'Meta Ad Account',
      accountStatus: accountData.account_status,
      currency: accountData.currency || 'INR',
      timezone: accountData.timezone_name,
      amountSpent: accountData.amount_spent,
      businessName: accountData.business_name || '',
      appId: appId || undefined,
      apiVersion: (apiVersion || DEFAULT_META_API_VERSION).replace(/^v?/, 'v'),
    },
  };
};

/** Fetches all campaigns for an Ad Account (with pagination). */
export const fetchMetaAdAccountCampaigns = async ({
  adAccountId,
  accessToken,
  apiVersion = DEFAULT_META_API_VERSION,
  maxPages = 5,
}) => {
  const formattedId = formatAdAccountId(adAccountId);
  if (!formattedId) {
    throw new Error('Meta Ads Account ID is required');
  }

  const campaigns = [];
  let nextUrl = null;
  let page = 0;

  const fields = [
    'id',
    'name',
    'status',
    'objective',
    'start_time',
    'stop_time',
    'daily_budget',
    'lifetime_budget',
    'budget_remaining',
    'created_time',
    'updated_time',
    'insights.date_preset(maximum){impressions,clicks,spend,reach,actions}',
  ].join(',');

  do {
    page += 1;
    let data;
    if (nextUrl) {
      const res = await fetch(nextUrl);
      data = await res.json().catch(() => ({}));
      if (!res.ok || data?.error) {
        throw new Error(data?.error?.message || 'Failed to fetch next campaign page');
      }
    } else {
      data = await metaFetch(
        `${formattedId}/campaigns`,
        accessToken,
        { fields, limit: 100 },
        apiVersion
      );
    }

    const items = Array.isArray(data?.data) ? data.data : [];
    for (const c of items) {
      const insight = c.insights?.data?.[0] || {};
      const spend = Number(insight.spend || 0);
      const impressions = Number(insight.impressions || 0);
      const clicks = Number(insight.clicks || 0);
      const reach = Number(insight.reach || 0);

      // Meta returns currency sub-units (e.g. 100000 = 1000 INR/USD) for budgets
      const dailyBudget = c.daily_budget ? Number(c.daily_budget) / 100 : 0;
      const lifetimeBudget = c.lifetime_budget ? Number(c.lifetime_budget) / 100 : 0;
      const budgetRemaining = c.budget_remaining ? Number(c.budget_remaining) / 100 : 0;

      campaigns.push({
        campaignId: c.id,
        name: c.name || `Campaign ${c.id}`,
        status: c.status || 'UNKNOWN',
        objective: c.objective || '',
        adAccountId: formattedId,
        dailyBudget,
        lifetimeBudget,
        budgetRemaining,
        spend,
        impressions,
        clicks,
        reach,
        startTime: c.start_time ? new Date(c.start_time) : null,
        stopTime: c.stop_time ? new Date(c.stop_time) : null,
        createdTime: c.created_time ? new Date(c.created_time) : null,
        updatedTime: c.updated_time ? new Date(c.updated_time) : null,
        metaRaw: c,
      });
    }

    nextUrl = data?.paging?.next || null;
  } while (nextUrl && page < maxPages);

  return campaigns;
};

/** Fetches all ads across the ad account. */
export const fetchMetaAdAccountAds = async ({
  adAccountId,
  accessToken,
  apiVersion = DEFAULT_META_API_VERSION,
  maxPages = 5,
}) => {
  const formattedId = formatAdAccountId(adAccountId);
  const ads = [];
  let nextUrl = null;
  let page = 0;

  const fields = 'id,name,status,campaign_id,campaign{id,name},leadgen_form_id,creative{id,name,title,body}';

  do {
    page += 1;
    let data;
    if (nextUrl) {
      const res = await fetch(nextUrl);
      data = await res.json().catch(() => ({}));
      if (!res.ok || data?.error) break;
    } else {
      try {
        data = await metaFetch(
          `${formattedId}/ads`,
          accessToken,
          { fields, limit: 100 },
          apiVersion
        );
      } catch (err) {
        console.warn(`[MetaGraph] Could not fetch account-level ads: ${err.message}`);
        break;
      }
    }

    const items = Array.isArray(data?.data) ? data.data : [];
    for (const ad of items) {
      ads.push({
        adId: ad.id,
        name: ad.name || `Ad ${ad.id}`,
        status: ad.status,
        campaignId: ad.campaign_id || ad.campaign?.id || '',
        campaignName: ad.campaign?.name || '',
        formId: ad.leadgen_form_id || '',
      });
    }

    nextUrl = data?.paging?.next || null;
  } while (nextUrl && page < maxPages);

  return ads;
};

/** Fetches leads for a specific Ad ID. */
export const fetchMetaAdLeads = async ({
  adId,
  accessToken,
  apiVersion = DEFAULT_META_API_VERSION,
  limit = 100,
}) => {
  if (!adId) return [];
  const leads = [];
  try {
    const data = await metaFetch(
      `${adId}/leads`,
      accessToken,
      {
        fields: 'id,created_time,field_data,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic',
        limit,
      },
      apiVersion
    );
    return Array.isArray(data?.data) ? data.data : [];
  } catch (err) {
    // If an ad doesn't have leadgen or lacks permission, continue gracefully
    console.warn(`[MetaGraph] Failed fetching leads for ad ${adId}: ${err.message}`);
    return [];
  }
};

/** Fetches leads for a specific LeadGen Form ID. */
export const fetchMetaFormLeads = async ({
  formId,
  accessToken,
  apiVersion = DEFAULT_META_API_VERSION,
  limit = 100,
}) => {
  if (!formId) return [];
  try {
    const data = await metaFetch(
      `${formId}/leads`,
      accessToken,
      {
        fields: 'id,created_time,field_data,ad_id,ad_name,adset_id,adset_name,campaign_id,campaign_name,form_id,is_organic',
        limit,
      },
      apiVersion
    );
    return Array.isArray(data?.data) ? data.data : [];
  } catch (err) {
    console.warn(`[MetaGraph] Failed fetching leads for form ${formId}: ${err.message}`);
    return [];
  }
};

/** Normalizes raw key string for matching. */
const normalizeKey = (key = '') =>
  String(key)
    .toLowerCase()
    .replace(/[^a-z0-9]/g, '');

const PHONE_KEYS = new Set([
  'phone',
  'phonenumber',
  'mobile',
  'mobilenumber',
  'contact',
  'contactnumber',
  'userphone',
  'telephone',
  'whatsapp',
  'contactno',
  'mobileno',
]);

const NAME_KEYS = new Set([
  'name',
  'fullname',
  'username',
  'contactname',
  'leadname',
  'customername',
]);

const FIRST_NAME_KEYS = new Set(['firstname', 'first', 'givenname']);
const LAST_NAME_KEYS = new Set(['lastname', 'last', 'surname', 'familyname']);
const EMAIL_KEYS = new Set(['email', 'emailaddress', 'useremail', 'mail']);
const CITY_KEYS = new Set(['city', 'town', 'location']);
const STATE_KEYS = new Set(['state', 'province', 'region']);
const ADDRESS_KEYS = new Set(['address', 'streetaddress', 'street', 'fulladdress']);
const COMPANY_KEYS = new Set([
  'company',
  'companyname',
  'business',
  'businessname',
  'organization',
  'organisation',
]);

/** Extracts structured lead fields from Meta field_data. */
export const parseMetaLeadFields = (leadRaw = {}) => {
  const fieldData = Array.isArray(leadRaw?.field_data) ? leadRaw.field_data : [];
  let firstName = '';
  let lastName = '';
  const mapped = {
    name: '',
    contactNumber: '',
    email: '',
    city: '',
    state: '',
    address: '',
    businessName: '',
  };

  const customAnswers = [];

  for (const item of fieldData) {
    const rawKey = item?.name || item?.column_name || '';
    const normKey = normalizeKey(rawKey);
    const rawValues = item?.values ?? item?.value ?? item?.string_value;
    const value = Array.isArray(rawValues) ? rawValues[0] : rawValues;
    const text = value !== undefined && value !== null ? String(value).trim() : '';
    if (!text) continue;

    let matched = false;
    if (PHONE_KEYS.has(normKey) && !mapped.contactNumber) {
      mapped.contactNumber = text;
      matched = true;
    } else if (EMAIL_KEYS.has(normKey) && !mapped.email) {
      mapped.email = text;
      matched = true;
    } else if (CITY_KEYS.has(normKey) && !mapped.city) {
      mapped.city = text;
      matched = true;
    } else if (STATE_KEYS.has(normKey) && !mapped.state) {
      mapped.state = text;
      matched = true;
    } else if (ADDRESS_KEYS.has(normKey) && !mapped.address) {
      mapped.address = text;
      matched = true;
    } else if (COMPANY_KEYS.has(normKey) && !mapped.businessName) {
      mapped.businessName = text;
      matched = true;
    } else if (NAME_KEYS.has(normKey) && !mapped.name) {
      mapped.name = text;
      matched = true;
    } else if (FIRST_NAME_KEYS.has(normKey) && !firstName) {
      firstName = text;
      matched = true;
    } else if (LAST_NAME_KEYS.has(normKey) && !lastName) {
      lastName = text;
      matched = true;
    }

    // Capture non-standard questions (e.g. budget, preferred location, requirements)
    if (!matched || customAnswers.length < 10) {
      customAnswers.push(`${rawKey}: ${text}`);
    }
  }

  if (!mapped.name && (firstName || lastName)) {
    mapped.name = `${firstName} ${lastName}`.trim();
  }

  // Fallback phone regex match if standard phone keys missed it
  if (!mapped.contactNumber) {
    for (const item of fieldData) {
      const rawValues = item?.values ?? item?.value;
      const text = Array.isArray(rawValues) ? String(rawValues[0]) : String(rawValues || '');
      if (/^\+?[0-9\s-]{8,16}$/.test(text.trim())) {
        mapped.contactNumber = text.trim();
        break;
      }
    }
  }

  return {
    ...mapped,
    customAnswers,
  };
};

/**
 * Orchestrator: Fetches all campaigns and all corresponding leads
 * from the Meta Ad Account using Graph API v26.0.
 */
export const fetchAllMetaCampaignsAndLeads = async ({
  adAccountId,
  accessToken,
  appId = '',
  apiVersion = DEFAULT_META_API_VERSION,
}) => {
  const formattedId = formatAdAccountId(adAccountId);

  // 1. Fetch campaigns
  const campaigns = await fetchMetaAdAccountCampaigns({
    adAccountId: formattedId,
    accessToken,
    apiVersion,
  });

  const campaignMap = new Map();
  for (const c of campaigns) {
    campaignMap.set(c.campaignId, {
      ...c,
      leadsCount: 0,
    });
  }

  // 2. Fetch all ads belonging to this ad account
  const ads = await fetchMetaAdAccountAds({
    adAccountId: formattedId,
    accessToken,
    apiVersion,
  });

  const adMap = new Map();
  const formIds = new Set();
  for (const ad of ads) {
    adMap.set(ad.adId, ad);
    if (ad.formId) formIds.add(ad.formId);
  }

  // 3. Collect leads from ads and forms
  const allLeadsMap = new Map(); // Keyed by lead ID to avoid duplicates

  // Fetch leads for each ad
  for (const ad of ads) {
    const rawLeads = await fetchMetaAdLeads({
      adId: ad.adId,
      accessToken,
      apiVersion,
    });

    for (const lead of rawLeads) {
      if (!lead?.id) continue;
      const effectiveCampaignId = lead.campaign_id || ad.campaignId || '';
      const effectiveCampaignName = lead.campaign_name || ad.campaignName || campaignMap.get(effectiveCampaignId)?.name || '';

      allLeadsMap.set(lead.id, {
        raw: lead,
        leadId: lead.id,
        createdTime: lead.created_time ? new Date(lead.created_time) : new Date(),
        campaignId: effectiveCampaignId,
        campaignName: effectiveCampaignName,
        adId: lead.ad_id || ad.adId,
        adName: lead.ad_name || ad.name,
        formId: lead.form_id || ad.formId,
      });
    }
  }

  // Also query distinct lead forms to catch any form leads
  for (const formId of formIds) {
    const formLeads = await fetchMetaFormLeads({
      formId,
      accessToken,
      apiVersion,
    });

    for (const lead of formLeads) {
      if (!lead?.id || allLeadsMap.has(lead.id)) continue;
      const effectiveCampaignId = lead.campaign_id || '';
      const effectiveCampaignName = lead.campaign_name || campaignMap.get(effectiveCampaignId)?.name || '';

      allLeadsMap.set(lead.id, {
        raw: lead,
        leadId: lead.id,
        createdTime: lead.created_time ? new Date(lead.created_time) : new Date(),
        campaignId: effectiveCampaignId,
        campaignName: effectiveCampaignName,
        adId: lead.ad_id || '',
        adName: lead.ad_name || '',
        formId: lead.form_id || formId,
      });
    }
  }

  // Count leads per campaign
  const leadsList = Array.from(allLeadsMap.values());
  for (const item of leadsList) {
    if (item.campaignId && campaignMap.has(item.campaignId)) {
      const c = campaignMap.get(item.campaignId);
      c.leadsCount = (c.leadsCount || 0) + 1;
    }
  }

  return {
    campaigns: Array.from(campaignMap.values()),
    leads: leadsList,
    totalCampaigns: campaignMap.size,
    totalLeads: leadsList.length,
  };
};
