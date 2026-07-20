import { buildAutoTaskRating } from './taskStarRating.js';

/**
 * When a task is marked Completed, auto-set star rating from completion time
 * unless the client explicitly sent a rating payload (manual override).
 * When reopened / cancelled, clear auto ratings.
 */
export const applyAutoTaskStarRating = ({
  existing,
  payload,
  nextStatus,
  ratingProvidedInRequest,
}) => {
  const result = { ...payload };

  if (ratingProvidedInRequest) {
    // Manual rating wins; ensure auto flag is false unless client set it
    if (result.rating && typeof result.rating === 'object' && result.rating.auto === undefined) {
      result.rating = { ...result.rating, auto: false };
    }
    return result;
  }

  const becomingCompleted = nextStatus === 'Completed' && existing?.status !== 'Completed';
  const leavingCompleted = nextStatus !== 'Completed' && existing?.status === 'Completed';

  if (becomingCompleted) {
    const completedAt = result.completedAt || new Date();
    result.completedAt = completedAt;

    const startedAt = result.startedAt || existing?.startedAt || null;
    // If never started, treat completion moment as start only when no schedule either —
    // prefer scheduledStartAt for duration vs estimate window.
    const autoRating = buildAutoTaskRating({
      status: 'Completed',
      estimatedDurationMinutes:
        result.estimatedDurationMinutes !== undefined
          ? result.estimatedDurationMinutes
          : existing?.estimatedDurationMinutes,
      startedAt,
      scheduledStartAt:
        result.scheduledStartAt !== undefined
          ? result.scheduledStartAt
          : existing?.scheduledStartAt,
      completedAt,
    });

    if (autoRating) {
      result.rating = {
        score: autoRating.score,
        comments: autoRating.comments,
        ratedBy: null,
        ratedAt: autoRating.ratedAt,
        auto: true,
      };
      // Persist startedAt if it was missing so duration remains auditable
      if (!startedAt && !existing?.startedAt) {
        result.startedAt =
          result.scheduledStartAt ||
          existing?.scheduledStartAt ||
          completedAt;
      }
    }
  } else if (leavingCompleted) {
    result.completedAt = null;
    if (existing?.rating?.auto || !existing?.rating?.score) {
      result.rating = { score: null, comments: '', ratedBy: null, ratedAt: null, auto: false };
    }
  } else if (nextStatus === 'Cancelled' && existing?.rating?.auto) {
    result.rating = { score: null, comments: '', ratedBy: null, ratedAt: null, auto: false };
  }

  return result;
};
