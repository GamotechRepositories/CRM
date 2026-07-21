import { requireAuth } from './auth.middleware.js';
import { CENTRAL_ROOT_ROLE } from '../models/centralAdmin/centralAdmin_user.js';

/**
 * Restrict route to platform admins (CEO / root).
 */
export const requireAdmin = (req, res, next) => {
  if (!req.auth?.sub) {
    return res.status(401).json({ success: false, message: 'Authentication required' });
  }

  const isAdmin =
    Boolean(req.auth.isRoot) ||
    String(req.auth.role || '').toUpperCase() === CENTRAL_ROOT_ROLE.toUpperCase() ||
    String(req.auth.role || '').trim() === 'Meeting Coordinator';

  if (!isAdmin) {
    return res.status(403).json({ success: false, message: 'Admin access required' });
  }

  return next();
};

export { requireAuth };
