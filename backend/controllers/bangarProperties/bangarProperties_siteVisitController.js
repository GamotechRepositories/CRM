import SiteVisit from '../../models/bangarProperties/bangarProperties_siteVisit.js';
import { createSiteVisitHandlers } from '../../utils/createSiteVisitHandlers.js';

export const siteVisitHandlers = createSiteVisitHandlers({ SiteVisit });
