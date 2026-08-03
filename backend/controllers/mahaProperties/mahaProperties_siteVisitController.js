import SiteVisit from '../../models/mahaProperties/mahaProperties_siteVisit.js';
import Expense from '../../models/mahaProperties/mahaProperties_expense.js';
import TravelJourney from '../../models/mahaProperties/mahaProperties_travelJourney.js';
import { createSiteVisitHandlers } from '../../utils/createSiteVisitHandlers.js';

export const siteVisitHandlers = createSiteVisitHandlers({ SiteVisit, Expense, TravelJourney });
