/**
 * Auto star rating from completion speed vs estimated duration.
 *
 * For a 60‑minute estimate (same % bands for any estimate):
 *   ≤ 90% of estimate (≥10% time left)     → 5
 *   > 90% and ≤ 100% (<10% time left)      → 4
 *   > 100% and ≤ 125% (late up to 25%)     → 3
 *   > 125% and ≤ 150% (late up to 50%)     → 2
 *   > 150% (more than 50% late)            → 1
 *   Not completed                          → null (UI shows ❌)
 */

export const TASK_STAR_BANDS = [
  { maxRatio: 0.9, score: 5, label: 'Finished with ≥10% time left' },
  { maxRatio: 1.0, score: 4, label: 'Finished with <10% time left' },
  { maxRatio: 1.25, score: 3, label: 'Late by up to 25%' },
  { maxRatio: 1.5, score: 2, label: 'Late by up to 50%' },
  { maxRatio: Infinity, score: 1, label: 'More than 50% late' },
];

export const getActualTaskDurationMinutes = ({
  startedAt,
  scheduledStartAt,
  completedAt,
  status,
} = {}) => {
  if (String(status || '').trim() !== 'Completed' || !completedAt) return null;

  const endMs = new Date(completedAt).getTime();
  if (Number.isNaN(endMs)) return null;

  const startCandidate = startedAt || scheduledStartAt;
  if (!startCandidate) return null;

  const startMs = new Date(startCandidate).getTime();
  if (Number.isNaN(startMs) || endMs < startMs) return null;

  return Math.max(0, Math.round((endMs - startMs) / 60000));
};

export const computeTaskStarScore = (estimatedDurationMinutes, actualDurationMinutes) => {
  const estimated = Number(estimatedDurationMinutes);
  const actual = Number(actualDurationMinutes);
  if (!Number.isFinite(estimated) || estimated <= 0) return null;
  if (!Number.isFinite(actual) || actual < 0) return null;

  const ratio = actual / estimated;
  const band = TASK_STAR_BANDS.find((b) => ratio <= b.maxRatio) || TASK_STAR_BANDS[TASK_STAR_BANDS.length - 1];
  return band.score;
};

export const getTaskStarBandLabel = (score) => {
  const band = TASK_STAR_BANDS.find((b) => b.score === Number(score));
  return band?.label || '';
};

export const buildAutoTaskRating = ({
  status,
  estimatedDurationMinutes,
  startedAt,
  scheduledStartAt,
  completedAt,
  now = new Date(),
} = {}) => {
  if (String(status || '').trim() !== 'Completed') {
    return {
      score: null,
      comments: '',
      ratedBy: null,
      ratedAt: null,
      auto: true,
    };
  }

  const actualMinutes = getActualTaskDurationMinutes({
    startedAt,
    scheduledStartAt,
    completedAt: completedAt || now,
    status: 'Completed',
  });
  const score = computeTaskStarScore(estimatedDurationMinutes, actualMinutes);
  if (score == null) return null;

  const label = getTaskStarBandLabel(score);
  return {
    score,
    comments: `Auto-rated from completion time (${actualMinutes} min vs ${estimatedDurationMinutes} min estimate). ${label}.`,
    ratedBy: null,
    ratedAt: now,
    auto: true,
  };
};
