import SiteVisit from '../../models/bangarProperties/bangarProperties_siteVisit.js';
import Expense from '../../models/bangarProperties/bangarProperties_expense.js';
import TravelJourney from '../../models/bangarProperties/bangarProperties_travelJourney.js';
import { createSiteVisitHandlers } from '../../utils/createSiteVisitHandlers.js';

export const siteVisitHandlers = createSiteVisitHandlers({ SiteVisit, Expense, TravelJourney });
