import SiteVisit from '../../models/salesTechReality/salesTechReality_siteVisit.js';
import Expense from '../../models/salesTechReality/salesTechReality_expense.js';
import TravelJourney from '../../models/salesTechReality/salesTechReality_travelJourney.js';
import { createSiteVisitHandlers } from '../../utils/createSiteVisitHandlers.js';

export const siteVisitHandlers = createSiteVisitHandlers({ SiteVisit, Expense, TravelJourney });
