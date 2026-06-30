export const runTaskNotificationSideEffects = async ({
  notificationService,
  existing = null,
  updated,
}) => {
  if (!updated || !notificationService) return;

  try {
    if (!existing) {
      await notificationService.notifyTaskAssigned({ task: updated });
      return;
    }

    const prevAssigned = existing.assignedTo?.toString?.() || String(existing.assignedTo || '');
    const nextAssigned =
      updated.assignedTo?._id?.toString?.() ||
      updated.assignedTo?.toString?.() ||
      '';

    if (nextAssigned && prevAssigned !== nextAssigned) {
      await notificationService.notifyTaskAssigned({ task: updated });
    }

    const prevScore = existing.rating?.score ?? null;
    const nextScore = updated.rating?.score ?? null;
    if (nextScore && prevScore !== nextScore) {
      await notificationService.notifyTaskReviewed({ task: updated });
    }

    if (existing.status !== updated.status) {
      if (updated.status === 'Completed') {
        await notificationService.notifyTaskCompleted({ task: updated });
      } else {
        await notificationService.notifyTaskStatusChanged({
          task: updated,
          previousStatus: existing.status,
        });
      }
    }
  } catch (error) {
    console.error('Task notification side effect failed:', error?.message || error);
  }
};
