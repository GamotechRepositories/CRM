import mongoose from 'mongoose';
import Task from '../../models/salesTechReality/salesTechReality_task.js';
import Attendance from '../../models/salesTechReality/salesTechReality_attendance.js';
import Employee from '../../models/salesTechReality/salesTechReality_employee.js';
import Company from '../../models/salesTechReality/salesTechReality_company.js';
import Notification from '../../models/salesTechReality/salesTechReality_notification.js';
import SocialMediaCalendar from '../../models/salesTechReality/salesTechReality_socialMediaCalendar.js';
import { syncClientProfileByProjectId } from '../../utils/salesTechReality/salesTechReality_clientProfileSync.js';
import { getNextRecurringDate } from '../../utils/salesTechReality/salesTechReality_recurringTaskScheduler.js';
import { normalizeTaskPayload } from '../../utils/normalizeTaskPayload.js';
import { createNotificationService } from '../../utils/notificationService.js';
import { runTaskNotificationSideEffects } from '../../utils/taskNotificationHooks.js';
import { applyTaskStatusTiming, assertEmployeeAvailableForTask } from '../../utils/taskTiming.js';
import { applyAutoTaskStarRating } from '../../utils/applyAutoTaskStarRating.js';
import { assertValidTaskSchedule } from '../../utils/validateTaskSchedule.js';
import { assertForwardOnlyStatusTransition, normalizeTaskStatus, socialStatusToTaskStatus } from '../../utils/taskStatus.js';
import {
  assertCanStartOrResumeTask,
  assertEmployeeCanPause,
  handleUrgentTaskAssigned,
  handleUrgentTaskCompleted,
} from '../../utils/urgentTaskInterrupt.js';
import { cacheKey, withCache, invalidateTenantCache, CACHE_TTL } from '../../utils/cache.js';
import { canEmployeeAssignTasks } from '../../utils/designationFields.js';
import { emitTaskChanged } from '../../services/realtimeNotification.service.js';

const notificationService = createNotificationService({ Notification });

const COMPANY_KEY = 'salesTechReality';

const toId = (value) => {
  if (!value) return '';
  if (typeof value === 'object' && value._id) return String(value._id);
  return String(value);
};

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

    const assigner = await Employee.findById(assignedBy).populate('designation');
    const isManagerOrAdmin = Boolean(assigner && canEmployeeAssignTasks(assigner));

    const isAssigningToOthers = assigneeIds.some((id) => String(id) !== String(assignedBy));
    if (isAssigningToOthers && !isManagerOrAdmin) {
      return res.status(403).json({
        message: 'Only Team Leaders, Managers, Admin, and Super Admin have the authority to assign tasks to other employees.',
      });
    }

    const requiresApproval = !isManagerOrAdmin;

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
        await handleUrgentTaskAssigned({ Task, task: firstTask });

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

    const initialStatus = requiresApproval ? 'Pending' : (status || 'Pending');
    const createdTasks = [];
    for (const employeeId of assigneeIds) {
      if (initialStatus === 'In Progress') {
        await assertCanStartOrResumeTask({
          Task,
          Attendance,
          task: { assignedTo: employeeId, priority: priority || 'Medium' },
          nextStatus: initialStatus,
        });
      }
      const task = new Task({
        project,
        title,
        description,
        assignedTo: employeeId,
        assignedBy,
        status: initialStatus,
        approvalStatus: requiresApproval ? 'Pending' : 'None',
        priority: priority || 'Medium',
        dueDate: dueDate ? new Date(dueDate) : undefined,
        scheduledStartAt: scheduledStartAt || undefined,
        scheduledEndAt: scheduledEndAt || undefined,
        estimatedDurationMinutes: estimatedDurationMinutes || null,
        completedAt: !requiresApproval && initialStatus === 'Completed' ? new Date() : null,
        isRecurringTemplate: false,
        recurrenceEnabled: false,
        ...applyTaskStatusTiming({ existingStatus: null, nextStatus: initialStatus }),
      });
      await task.save();
      createdTasks.push(task);
      if (!requiresApproval) {
        await handleUrgentTaskAssigned({ Task, task });
      }
    }
    await syncClientProfileByProjectId(project);
    const populatedTasks = await Task.find({ _id: { $in: createdTasks.map((t) => t._id) } })
      .populate('project')
      .populate({
        path: 'assignedTo',
        select: 'name email phone department designation reportingManager employeeCode profilePhoto',
        populate: [{ path: 'designation' }, { path: 'reportingManager', select: 'name email' }],
      })
      .populate('assignedBy')
      .populate('approvedBy', 'name designation')
      .sort({ createdAt: -1 });

    if (requiresApproval) {
      try {
        const assignerDoc = await Employee.findById(assignedBy).select('name reportingManager');
        const assigneeDocs = await Employee.find({ _id: { $in: assigneeIds } }).select('name reportingManager');
        const allEmployees = await Employee.find({ status: 'Active' }).populate('designation');
        const empById = new Map(allEmployees.map((emp) => [toId(emp._id), emp]));

        const approverIds = new Set();
        const addManagerChain = (startMgrId) => {
          let currId = toId(startMgrId);
          const visited = new Set();
          while (currId && !visited.has(currId)) {
            visited.add(currId);
            approverIds.add(currId);
            const mgrEmp = empById.get(currId);
            currId = toId(mgrEmp?.reportingManager);
          }
        };

        if (assignerDoc?.reportingManager) {
          addManagerChain(assignerDoc.reportingManager);
        }
        for (const aDoc of assigneeDocs) {
          if (aDoc?.reportingManager) {
            addManagerChain(aDoc.reportingManager);
          }
        }
        for (const emp of allEmployees) {
          if (canEmployeeAssignTasks(emp)) {
            approverIds.add(toId(emp._id));
          }
        }
        approverIds.delete(toId(assignedBy));

        const firstPopulated = populatedTasks[0] || null;
        const employeeName =
          firstPopulated?.assignedTo?.name ||
          assigneeDocs[0]?.name ||
          assignerDoc?.name ||
          'Employee';
        const projectName = firstPopulated?.project?.projectName || '';

        const approverList = Array.from(approverIds).filter(Boolean);
        if (approverList.length > 0) {
          emitTaskChanged(approverList, {
            reason: 'approval_required',
            taskId: createdTasks[0]?._id,
            title,
            employeeName,
            assignedByName: assignerDoc?.name || employeeName,
            projectName,
            approvalStatus: 'Pending',
            status: initialStatus,
            assignedBy,
            assignedTo: assigneeIds,
          });

          await Promise.all(
            approverList.map((approverId) =>
              notificationService.notifyEmployee({
                employeeId: approverId,
                type: 'task_approval_required',
                title: 'New Task Pending Approval',
                message: `${assignerDoc?.name || 'An employee'} created task "${title}" that requires your approval.`,
                link: '/task-approvals',
                priority: 'high',
                metadata: {
                  entityType: 'task',
                  entityId: createdTasks[0]?._id,
                  extra: { approvalStatus: 'Pending' },
                },
              }).catch(() => {})
            )
          );
        }
      } catch (err) {
        console.warn('Failed to notify approvers:', err?.message);
      }
    }

    await Promise.all(
      populatedTasks.map((task) => runTaskNotificationSideEffects({ notificationService, updated: task }))
    );
    await invalidateTenantCache(COMPANY_KEY, 'tasks', 'dashboard');
    return res.status(201).json({
      message: requiresApproval
        ? 'Task submitted for manager approval. Timer will start once approved.'
        : assigneeIds.length > 1
          ? 'Tasks assigned successfully'
          : 'Task assigned successfully',
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
    const { projectId, employeeId, assignedBy, approvalStatus } = req.query;
    const key = cacheKey(COMPANY_KEY, 'tasks', {
      projectId: String(projectId || ''),
      employeeId: String(employeeId || ''),
      assignedBy: String(assignedBy || ''),
      approvalStatus: String(approvalStatus || ''),
    });
    const { data } = await withCache(key, CACHE_TTL.tasks, async () => {
    const filter = { isRecurringTemplate: { $ne: true } };
    if (projectId) filter.project = projectId;
    if (employeeId) filter.assignedTo = employeeId;
    if (assignedBy) filter.assignedBy = assignedBy;
    if (approvalStatus) {
      if (approvalStatus.includes(',')) {
        filter.approvalStatus = { $in: approvalStatus.split(',').map((s) => s.trim()) };
      } else {
        filter.approvalStatus = approvalStatus;
      }
    }

    const tasks = await Task.find(filter)
      .populate('project')
      .populate({
        path: 'assignedTo',
        select: 'name email phone department designation reportingManager employeeCode profilePhoto',
        populate: [{ path: 'designation' }, { path: 'reportingManager', select: 'name email' }],
      })
      .populate('assignedBy')
      .populate('approvedBy', 'name designation')
      .populate('rating.ratedBy', 'name designation')
      .sort({ createdAt: -1 })
      .lean();

    let result = [...tasks];
    const includeSocialMedia = !assignedBy && (!projectId || projectId === 'social-media');

    if (includeSocialMedia) {
      const socialQuery = employeeId ? { 'posts.assignedTo': employeeId } : {};
      const calendars = await SocialMediaCalendar.find(socialQuery)
        .populate('client')
        .populate('posts.assignedTo')
        .lean();

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

    return result;
    });
    res.status(200).json(data);
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
      .populate({
        path: 'assignedTo',
        select: 'name email phone department designation reportingManager employeeCode profilePhoto',
        populate: [{ path: 'designation' }, { path: 'reportingManager', select: 'name email' }],
      })
      .populate('assignedBy')
      .populate('approvedBy', 'name designation')
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
      'project status priority assignedTo assignedBy title rating scheduledStartAt scheduledEndAt estimatedDurationMinutes startedAt pausedAt pausedByUrgentTask completedAt createdAt approvalStatus'
    );
    if (!existing) return res.status(404).json({ message: 'Task not found' });

    const nextStatus = req.body.status !== undefined
      ? normalizeTaskStatus(req.body.status)
      : existing.status;
    const payload = normalizeTaskPayload(req.body);

    if (existing.approvalStatus === 'Pending' && nextStatus === 'In Progress' && payload.approvalStatus !== 'Approved') {
      return res.status(400).json({
        message: 'This task is awaiting review & approval by your reporting manager before the timer can start.',
      });
    }

    if (req.body.status !== undefined) {
      payload.status = nextStatus;
      assertForwardOnlyStatusTransition(existing.status, nextStatus);
    }

    await assertEmployeeCanPause({ Task, task: existing, nextStatus });
    await assertCanStartOrResumeTask({
      Task,
      Attendance,
      task: { ...existing.toObject(), ...payload },
      nextStatus,
    });

    Object.assign(
      payload,
      applyTaskStatusTiming({
        existingStatus: existing.status,
        nextStatus,
        payload: {
          ...payload,
          startedAt: payload.startedAt !== undefined ? payload.startedAt : existing.startedAt,
          pausedAt: payload.pausedAt !== undefined ? payload.pausedAt : existing.pausedAt,
        },
      })
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

    const nextPriority = updated?.priority || existing.priority;
    const becameUrgent =
      String(nextPriority) === 'Urgent' &&
      (String(existing.priority) !== 'Urgent' || assigneeChanged);
    if (becameUrgent || (String(nextPriority) === 'Urgent' && assigneeChanged)) {
      await handleUrgentTaskAssigned({ Task, task: updated });
    }

    const resumed = await handleUrgentTaskCompleted({
      Task,
      task: updated,
      previousStatus: existing.status,
    });

    await runTaskNotificationSideEffects({ notificationService, existing, updated });
    await syncClientProfileByProjectId(existing.project);
    await syncClientProfileByProjectId(updated?.project?._id || updated?.project || req.body?.project);
    await invalidateTenantCache(COMPANY_KEY, 'tasks', 'dashboard');
    res.status(200).json({
      message: 'Task updated',
      task: updated,
      resumedTasks: resumed.map((t) => t._id),
    });
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
    await invalidateTenantCache(COMPANY_KEY, 'tasks', 'dashboard');
    if (!deleted) return res.status(404).json({ message: 'Task not found' });
    await syncClientProfileByProjectId(deleted.project);
    res.status(200).json({ message: 'Task deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting task', error });
  }
};

export const approveTask = async (req, res) => {
  try {
    const { id } = req.params;
    const body = normalizeTaskPayload(req.body);
    const {
      estimatedDurationMinutes,
      estimatedDurationHours,
      scheduledStartAt,
      scheduledEndAt,
      approvedBy,
    } = body;

    const task = await Task.findById(id).populate('assignedTo');
    if (!task) return res.status(404).json({ message: 'Task not found' });

    const approverId = approvedBy || req.user?._id;
    if (approverId) {
      const approver = await Employee.findById(approverId).populate('designation');
      if (approver && !canEmployeeAssignTasks(approver)) {
        return res.status(403).json({
          message: 'Only Team Leaders, Managers, Admin, and Super Admin have authority to approve tasks.',
        });
      }
    }

    let duration = task.estimatedDurationMinutes;
    if (estimatedDurationMinutes !== undefined && estimatedDurationMinutes !== null) {
      duration = Math.max(1, Number(estimatedDurationMinutes));
    } else if (estimatedDurationHours !== undefined && estimatedDurationHours !== null) {
      duration = Math.max(1, Math.round(Number(estimatedDurationHours) * 60));
    }

    const previousStatus = task.status;
    task.approvalStatus = 'Approved';
    task.approvedBy = approverId || null;
    task.approvedAt = new Date();
    task.rejectionReason = '';
    if (duration != null) task.estimatedDurationMinutes = duration;
    if (scheduledStartAt) task.scheduledStartAt = new Date(scheduledStartAt);
    if (scheduledEndAt) task.scheduledEndAt = new Date(scheduledEndAt);

    // Approval approved: keep status as 'Pending' so the employee accepts first before timer starts
    task.status = 'Pending';
    task.startedAt = null;
    task.pausedAt = null;
    task.pausedByUrgentTask = null;
    task.pausedByMeeting = false;
    task.pausedByBreak = false;

    await task.save();

    const populated = await Task.findById(id)
      .populate('project')
      .populate({
        path: 'assignedTo',
        select: 'name email phone department designation reportingManager employeeCode profilePhoto',
        populate: [{ path: 'designation' }, { path: 'reportingManager', select: 'name email' }],
      })
      .populate('assignedBy')
      .populate('approvedBy', 'name designation')
      .populate('rating.ratedBy', 'name designation');

    await runTaskNotificationSideEffects({
      notificationService,
      existing: { status: previousStatus, approvalStatus: 'Pending' },
      updated: populated,
    });

    try {
      const assigneeId = toId(task.assignedTo);
      const assignerId = toId(task.assignedBy);
      const approverIdStr = toId(approverId);
      const recipientIds = new Set([assigneeId, assignerId].filter(Boolean));
      if (approverIdStr) {
        recipientIds.delete(approverIdStr);
      }

      for (const recId of recipientIds) {
        emitTaskChanged(recId, {
          reason: 'approved',
          taskId: populated._id,
          status: populated.status,
          title: populated.title,
          approvalStatus: 'Approved',
        });
        await notificationService.notifyEmployee({
          employeeId: recId,
          type: 'task_approved',
          title: 'Task Approved',
          message: `Your task "${task.title}" has been approved! Please accept the task to start the timer.`,
          link: `/tasks/${task._id}`,
          metadata: {
            entityType: 'task',
            entityId: task._id,
            extra: { approvalStatus: 'Approved' },
          },
        }).catch(() => {});
      }
    } catch (err) {
      console.warn('Failed to notify employee on approval:', err?.message);
    }

    await invalidateTenantCache(COMPANY_KEY, 'tasks', 'dashboard');

    return res.status(200).json({
      message: 'Task approved successfully. Waiting for employee acceptance to start timer.',
      task: populated,
    });
  } catch (error) {
    res.status(500).json({ message: 'Error approving task', error });
  }
};

export const rejectTask = async (req, res) => {
  try {
    const { id } = req.params;
    const { rejectionReason, rejectedBy } = req.body;
    const task = await Task.findById(id).populate('assignedTo');
    if (!task) return res.status(404).json({ message: 'Task not found' });

    task.approvalStatus = 'Rejected';
    task.rejectionReason = rejectionReason || 'Rejected by reporting manager';
    task.approvedBy = rejectedBy || req.user?._id || null;
    task.approvedAt = new Date();
    task.status = 'Cancelled';
    task.startedAt = null;
    task.pausedAt = null;

    await task.save();

    const populated = await Task.findById(id)
      .populate('project')
      .populate({
        path: 'assignedTo',
        select: 'name email phone department designation reportingManager employeeCode profilePhoto',
        populate: [{ path: 'designation' }, { path: 'reportingManager', select: 'name email' }],
      })
      .populate('assignedBy')
      .populate('approvedBy', 'name designation');

    try {
      const assigneeId = toId(task.assignedTo);
      const assignerId = toId(task.assignedBy);
      const rejecterId = toId(rejectedBy || req.user?._id);
      const recipientIds = new Set([assigneeId, assignerId].filter(Boolean));
      if (rejecterId) {
        recipientIds.delete(rejecterId);
      }

      for (const recId of recipientIds) {
        emitTaskChanged(recId, {
          reason: 'rejected',
          taskId: populated._id,
          status: populated.status,
          title: populated.title,
          approvalStatus: 'Rejected',
          rejectionReason: task.rejectionReason,
        });
        await notificationService.notifyEmployee({
          employeeId: recId,
          type: 'task_rejected',
          title: 'Task Rejected',
          message: `Your task "${task.title}" was not approved. Reason: ${task.rejectionReason}`,
          link: `/tasks/${task._id}`,
          metadata: {
            entityType: 'task',
            entityId: task._id,
            extra: { approvalStatus: 'Rejected', rejectionReason: task.rejectionReason },
          },
        }).catch(() => {});
      }
    } catch (err) {
      console.warn('Failed to notify employee on rejection:', err?.message);
    }

    await invalidateTenantCache(COMPANY_KEY, 'tasks', 'dashboard');
    return res.status(200).json({
      message: 'Task rejected',
      task: populated,
    });
  } catch (error) {
    res.status(500).json({ message: 'Error rejecting task', error });
  }
};
