import SiteVisit from '../../models/mahaProperties/mahaProperties_siteVisit.js';
import { createSiteVisitHandlers } from '../../utils/createSiteVisitHandlers.js';

export const siteVisitHandlers = createSiteVisitHandlers({ SiteVisit });
