import mongoose from 'mongoose';
import Task from '../../models/adsResearchGlobal/adsResearchGlobal_task.js';
import Employee from '../../models/adsResearchGlobal/adsResearchGlobal_employee.js';
import Company from '../../models/adsResearchGlobal/adsResearchGlobal_company.js';
import Notification from '../../models/adsResearchGlobal/adsResearchGlobal_notification.js';
import SocialMediaCalendar from '../../models/adsResearchGlobal/adsResearchGlobal_socialMediaCalendar.js';
import { syncClientProfileByProjectId } from '../../utils/adsResearchGlobal/adsResearchGlobal_clientProfileSync.js';
import { getNextRecurringDate } from '../../utils/adsResearchGlobal/adsResearchGlobal_recurringTaskScheduler.js';
import { normalizeTaskPayload } from '../../utils/normalizeTaskPayload.js';
import { createNotificationService } from '../../utils/notificationService.js';
import { runTaskNotificationSideEffects } from '../../utils/taskNotificationHooks.js';
import { applyTaskStatusTiming, assertEmployeeAvailableForTask } from '../../utils/taskTiming.js';
import { applyAutoTaskStarRating } from '../../utils/applyAutoTaskStarRating.js';
import { assertValidTaskSchedule } from '../../utils/validateTaskSchedule.js';
import { normalizeTaskStatus, socialStatusToTaskStatus } from '../../utils/taskStatus.js';

const notificationService = createNotificationService({ Notification });

const normalizeDateStart = (value) => {
  const d = new Date(value);
  d.setHours(0, 0, 0, 0);
  return d;
};

const shouldCreateRecurringTemplate = (payload) =>
  payload?.recurrenceEnabled === true || payload?.isRecurring === true;

const resolveAssigneeIds = (body = {}) => {
  const rawList = Array.isArray(body.assignedToList)
    ? body.assignedToList
    : Array.isArray(body.assignedTo)
      ? body.assignedTo
      : [body.assignedTo];
  return [...new Set(rawList.map((id) => String(id || '').trim()).filter(Boolean))];
};

export const createTask = async (req, res) => {
  try {
    const body = normalizeTaskPayload(req.body);
    const {
      project,
      title,
      description,
      assignedTo,
      assignedToList,
      assignedBy,
      status,
      priority,
      dueDate,
      estimatedDurationMinutes,
      scheduledStartAt,
      scheduledEndAt,
      recurrenceEnabled,
      recurrenceType,
      recurrenceInterval,
      recurrenceStartDate,
      recurrenceEndDate,
      isRecurring,
    } = body;

    const assigneeIds = resolveAssigneeIds({ assignedTo, assignedToList });

    if (!project || !title || !assignedBy || !assigneeIds.length) {
      return res.status(400).json({ message: 'Project, title, assignedTo, and assignedBy are required' });
    }

    await Promise.all(assigneeIds.map((employeeId) => assertEmployeeAvailableForTask(Task, employeeId)));

    for (const employeeId of assigneeIds) {
      await assertValidTaskSchedule({
        Task,
        Employee,
        Company,
        assigneeId: employeeId,
        scheduledStartAt,
        scheduledEndAt,
        estimatedDurationMinutes,
      });
    }

    if (shouldCreateRecurringTemplate({ recurrenceEnabled, isRecurring })) {
      if (!recurrenceType || !['daily', 'weekly', 'monthly'].includes(recurrenceType)) {
        return res.status(400).json({ message: 'Valid recurrenceType is required for auto task' });
      }

      const interval = Math.max(1, Number(recurrenceInterval) || 1);
      const firstRunDate = normalizeDateStart(recurrenceStartDate || dueDate || new Date());
      const endDate = recurrenceEndDate ? normalizeDateStart(recurrenceEndDate) : null;

      if (endDate && endDate < firstRunDate) {
        return res.status(400).json({ message: 'recurrenceEndDate must be on or after recurrenceStartDate' });
      }

      const createdTasks = [];
      const recurringTemplateIds = [];
      for (const employeeId of assigneeIds) {
        const firstTask = new Task({
          project,
          title,
          description,
          assignedTo: employeeId,
          assignedBy,
          status: 'Pending',
          priority: priority || 'Medium',
          dueDate: firstRunDate,
          estimatedDurationMinutes: estimatedDurationMinutes || null,
          scheduledStartAt: scheduledStartAt || undefined,
          scheduledEndAt: scheduledEndAt || undefined,
          isRecurringTemplate: false,
          recurrenceEnabled: false,
          recurringScheduledFor: firstRunDate,
          startedAt: null,
        });
        await firstTask.save();
        createdTasks.push(firstTask);

        const templateTask = new Task({
          project,
          title,
          description,
          assignedTo: employeeId,
          assignedBy,
          status: status || 'Pending',
          priority: priority || 'Medium',
          dueDate: firstRunDate,
          estimatedDurationMinutes: estimatedDurationMinutes || null,
          scheduledStartAt: scheduledStartAt || undefined,
          scheduledEndAt: scheduledEndAt || undefined,
          isRecurringTemplate: true,
          recurrenceEnabled: true,
          recurrenceType,
          recurrenceInterval: interval,
          recurrenceStartDate: firstRunDate,
          recurrenceEndDate: endDate || undefined,
          nextRunAt: getNextRecurringDate(firstRunDate, recurrenceType, interval),
          lastGeneratedAt: new Date(),
        });
        await templateTask.save();
        recurringTemplateIds.push(templateTask._id);
      }

      await syncClientProfileByProjectId(project);

      const populatedTasks = await Task.find({ _id: { $in: createdTasks.map((t) => t._id) } })
        .populate('project')
        .populate('assignedTo')
        .populate('assignedBy')
        .sort({ createdAt: -1 });
      await Promise.all(
        populatedTasks.map((task) => runTaskNotificationSideEffects({ notificationService, updated: task }))
      );
      const firstCreated = populatedTasks[0] || null;

      return res.status(201).json({
        message: assigneeIds.length > 1 ? 'Auto tasks created successfully' : 'Auto task created successfully',
        task: firstCreated,
        tasks: populatedTasks,
        recurringTemplateIds,
      });
    }

    const initialStatus = status || 'Pending';
    const createdTasks = [];
    for (const employeeId of assigneeIds) {
      const task = new Task({
        project,
        title,
        description,
        assignedTo: employeeId,
        assignedBy,
        status: initialStatus,
        priority: priority || 'Medium',
        dueDate: dueDate ? new Date(dueDate) : undefined,
        scheduledStartAt: scheduledStartAt || undefined,
        scheduledEndAt: scheduledEndAt || undefined,
        estimatedDurationMinutes: estimatedDurationMinutes || null,
        completedAt: initialStatus === 'Completed' ? new Date() : null,
        isRecurringTemplate: false,
        recurrenceEnabled: false,
        ...applyTaskStatusTiming({ existingStatus: null, nextStatus: initialStatus }),
      });
      await task.save();
      createdTasks.push(task);
    }
    await syncClientProfileByProjectId(project);
    const populatedTasks = await Task.find({ _id: { $in: createdTasks.map((t) => t._id) } })
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy')
      .sort({ createdAt: -1 });
    await Promise.all(
      populatedTasks.map((task) => runTaskNotificationSideEffects({ notificationService, updated: task }))
    );
    return res.status(201).json({
      message: assigneeIds.length > 1 ? 'Tasks assigned successfully' : 'Task assigned successfully',
      task: populatedTasks[0] || null,
      tasks: populatedTasks,
    });
  } catch (error) {
    if (error?.statusCode === 400 || error?.statusCode === 409) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    res.status(500).json({ message: 'Error creating task', error });
  }
};


export const getTasks = async (req, res) => {
  try {
    const { projectId, employeeId, assignedBy } = req.query;
    const filter = { isRecurringTemplate: { $ne: true } };
    if (projectId) filter.project = projectId;
    if (employeeId) filter.assignedTo = employeeId;
    if (assignedBy) filter.assignedBy = assignedBy;

    const tasks = await Task.find(filter)
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy')
      .populate('rating.ratedBy', 'name designation')
      .sort({ createdAt: -1 });

    let result = [...tasks];
    const includeSocialMedia = !assignedBy && (!projectId || projectId === 'social-media');

    if (includeSocialMedia) {
      const socialQuery = employeeId ? { 'posts.assignedTo': employeeId } : {};
      const calendars = await SocialMediaCalendar.find(socialQuery)
        .populate('client')
        .populate('posts.assignedTo');

      const socialTasks = [];
      for (const cal of calendars) {
        for (const post of cal.posts) {
          const assignees = post.assignedTo || [];
          if (!assignees.length) continue;
          for (const emp of assignees) {
            const empId = emp?._id || emp;
            const empIdStr = empId?.toString?.() || empId;
            if (employeeId && empIdStr !== employeeId) continue;
            socialTasks.push({
              _id: `social-media-${cal._id}-${post._id}-${empIdStr || 'unassigned'}`,
              source: 'social_media',
              clientId: (cal.client?._id || cal.client)?.toString?.() || cal.client,
              postId: post._id,
              calendarId: cal._id,
              title: post.title,
              description: post.description,
              project: { projectName: 'Social Media', _id: 'social-media' },
              clientName: cal.client?.clientName,
              assignedTo: typeof emp === 'object' && emp?.name ? emp : { _id: empId, name: empIdStr === employeeId ? 'You' : '—' },
              assignedBy: { _id: 'social-calendar-system', name: 'Social Media Calendar' },
              status: socialStatusToTaskStatus(post.status),
              socialPostStatus: post.status || 'Scheduled',
              priority: 'Medium',
              dueDate: post.scheduledTime,
              createdAt: post.createdAt || cal.createdAt || new Date(),
              updatedAt: post.updatedAt || cal.updatedAt || new Date(),
              platform: post.platform,
              contentType: post.contentType,
              subject: post.subject || '',
              description: post.description || '',
              carouselItems: Array.isArray(post.carouselItems) ? post.carouselItems : [],
              referenceLink: post.referenceLink || '',
              referenceUpload: post.referenceUpload || { fileName: '', mimeType: '', dataUrl: '' },
              clientReviewStatus: post.clientReviewStatus || 'Pending',
              clientNote: post.clientNote || '',
              uploadedLinks: Array.isArray(post.uploadedLinks) ? post.uploadedLinks : [],
            });
          }
        }
      }
      result = [...tasks, ...socialTasks].sort((a, b) => {
        const dateA = a.dueDate ? new Date(a.dueDate) : new Date(0);
        const dateB = b.dueDate ? new Date(b.dueDate) : new Date(0);
        return dateB - dateA;
      });
    }

    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching tasks', error });
  }
};

export const getTaskById = async (req, res) => {
  try {
    const task = await Task.findById(req.params.id)
      .populate({
        path: 'project',
        populate: { path: 'client', select: 'clientName clientNumber mailId businessType' },
      })
      .populate('assignedTo')
      .populate('assignedBy')
      .populate('rating.ratedBy', 'name designation');
    if (!task) return res.status(404).json({ message: 'Task not found' });
    res.status(200).json(task);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching task', error });
  }
};

export const updateTask = async (req, res) => {
  try {
    const existing = await Task.findById(req.params.id).select(
      'project status assignedTo assignedBy title rating scheduledStartAt scheduledEndAt estimatedDurationMinutes startedAt completedAt createdAt'
    );
    if (!existing) return res.status(404).json({ message: 'Task not found' });

    const nextStatus = req.body.status !== undefined
      ? normalizeTaskStatus(req.body.status)
      : existing.status;
    const payload = normalizeTaskPayload(req.body);
    if (req.body.status !== undefined) {
      payload.status = nextStatus;
    }
    Object.assign(
      payload,
      applyTaskStatusTiming({ existingStatus: existing.status, nextStatus, payload })
    );

    const nextAssignee = payload.assignedTo ?? existing.assignedTo;
    const mergedScheduledStart =
      payload.scheduledStartAt !== undefined ? payload.scheduledStartAt : existing.scheduledStartAt;
    const mergedScheduledEnd =
      payload.scheduledEndAt !== undefined ? payload.scheduledEndAt : existing.scheduledEndAt;
    const mergedDuration =
      payload.estimatedDurationMinutes !== undefined
        ? payload.estimatedDurationMinutes
        : existing.estimatedDurationMinutes;

    // Only re-validate schedule when the client is actually changing schedule fields.
    // Status-only updates (e.g. mark Completed) must not fail "Cannot schedule in the past".
    const isRescheduling =
      Object.prototype.hasOwnProperty.call(req.body || {}, 'scheduledStartAt') ||
      Object.prototype.hasOwnProperty.call(req.body || {}, 'scheduledEndAt') ||
      Object.prototype.hasOwnProperty.call(req.body || {}, 'estimatedDurationMinutes') ||
      Object.prototype.hasOwnProperty.call(req.body || {}, 'estimatedDurationHours');
    if (mergedScheduledStart && isRescheduling) {
      await assertValidTaskSchedule({
        Task,
        Employee,
        Company,
        assigneeId: nextAssignee,
        scheduledStartAt: mergedScheduledStart,
        scheduledEndAt: mergedScheduledEnd,
        estimatedDurationMinutes: mergedDuration,
        excludeTaskId: req.params.id,
        existingScheduledStartAt: existing.scheduledStartAt,
        skipPastCheck: false,
      });
    }

    const assigneeChanged =
      nextAssignee &&
      String(nextAssignee) !== String(existing.assignedTo?._id || existing.assignedTo || '');
    if (assigneeChanged) {
      await assertEmployeeAvailableForTask(Task, nextAssignee, req.params.id);
    }

    const ratingProvidedInRequest = Object.prototype.hasOwnProperty.call(req.body || {}, 'rating');
    Object.assign(
      payload,
      applyAutoTaskStarRating({
        existing,
        payload,
        nextStatus,
        ratingProvidedInRequest,
      })
    );

    const updated = await Task.findByIdAndUpdate(req.params.id, payload, { new: true, runValidators: true })
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy')
      .populate('rating.ratedBy', 'name designation');
    await runTaskNotificationSideEffects({ notificationService, existing, updated });
    await syncClientProfileByProjectId(existing.project);
    await syncClientProfileByProjectId(updated?.project?._id || updated?.project || req.body?.project);
    res.status(200).json({ message: 'Task updated', task: updated });
  } catch (error) {
    if (error?.statusCode === 400 || error?.statusCode === 409) {
      return res.status(error.statusCode).json({ message: error.message });
    }
    res.status(500).json({ message: 'Error updating task', error });
  }
};

export const deleteTask = async (req, res) => {
  try {
    const deleted = await Task.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Task not found' });
    await syncClientProfileByProjectId(deleted.project);
    res.status(200).json({ message: 'Task deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting task', error });
  }
};
