import mongoose from 'mongoose';
import Task from '../../models/bangarProperties/bangarProperties_task.js';
import SocialMediaCalendar from '../../models/bangarProperties/bangarProperties_socialMediaCalendar.js';
import { syncClientProfileByProjectId } from '../../utils/bangarProperties/bangarProperties_clientProfileSync.js';
import { getNextRecurringDate } from '../../utils/bangarProperties/bangarProperties_recurringTaskScheduler.js';

const normalizeDateStart = (value) => {
  const d = new Date(value);
  d.setHours(0, 0, 0, 0);
  return d;
};

const shouldCreateRecurringTemplate = (payload) =>
  payload?.recurrenceEnabled === true || payload?.isRecurring === true;

export const createTask = async (req, res) => {
  try {
    const {
      project,
      title,
      description,
      assignedTo,
      assignedBy,
      status,
      priority,
      dueDate,
      recurrenceEnabled,
      recurrenceType,
      recurrenceInterval,
      recurrenceStartDate,
      recurrenceEndDate,
      isRecurring,
    } = req.body;

    if (!project || !title || !assignedTo || !assignedBy) {
      return res.status(400).json({ message: 'Project, title, assignedTo, and assignedBy are required' });
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

      const firstTask = new Task({
        project,
        title,
        description,
        assignedTo,
        assignedBy,
        status: 'Pending',
        priority: priority || 'Medium',
        dueDate: firstRunDate,
        isRecurringTemplate: false,
        recurrenceEnabled: false,
        recurringScheduledFor: firstRunDate,
      });
      await firstTask.save();

      const templateTask = new Task({
        project,
        title,
        description,
        assignedTo,
        assignedBy,
        status: status || 'Pending',
        priority: priority || 'Medium',
        dueDate: firstRunDate,
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

      await syncClientProfileByProjectId(project);

      const populated = await Task.findById(firstTask._id)
        .populate('project')
        .populate('assignedTo')
        .populate('assignedBy');

      return res.status(201).json({
        message: 'Auto task created successfully',
        task: populated,
        recurringTemplateId: templateTask._id,
      });
    }

    const initialStatus = status || 'Pending';
    const task = new Task({
      project,
      title,
      description,
      assignedTo,
      assignedBy,
      status: initialStatus,
      priority: priority || 'Medium',
      dueDate: dueDate ? new Date(dueDate) : undefined,
      completedAt: initialStatus === 'Completed' ? new Date() : null,
      isRecurringTemplate: false,
      recurrenceEnabled: false,
    });
    await task.save();
    await syncClientProfileByProjectId(project);
    const populated = await Task.findById(task._id)
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy');
    return res.status(201).json({ message: 'Task assigned successfully', task: populated });
  } catch (error) {
    res.status(500).json({ message: 'Error creating task', error });
  }
};

const socialStatusToTaskStatus = (status) => {
  if (status === 'Published') return 'Completed';
  if (status === 'Cancelled') return 'Cancelled';
  return 'Pending'; // Scheduled, Draft
};

export const getTasks = async (req, res) => {
  try {
    const { projectId, employeeId } = req.query;
    const filter = { isRecurringTemplate: { $ne: true } };
    if (projectId) filter.project = projectId;
    if (employeeId) filter.assignedTo = employeeId;

    const tasks = await Task.find(filter)
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy')
      .sort({ createdAt: -1 });

    let result = [...tasks];
    const includeSocialMedia = !projectId || projectId === 'social-media';

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
      .populate('assignedBy');
    if (!task) return res.status(404).json({ message: 'Task not found' });
    res.status(200).json(task);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching task', error });
  }
};

export const updateTask = async (req, res) => {
  try {
    const existing = await Task.findById(req.params.id).select('project status');
    if (!existing) return res.status(404).json({ message: 'Task not found' });

    const nextStatus = req.body.status !== undefined ? req.body.status : existing.status;
    const payload = { ...req.body };
    if (nextStatus === 'Completed' && existing.status !== 'Completed') {
      payload.completedAt = payload.completedAt || new Date();
    } else if (nextStatus !== 'Completed' && existing.status === 'Completed') {
      payload.completedAt = null;
    }

    const updated = await Task.findByIdAndUpdate(req.params.id, payload, { new: true })
      .populate('project')
      .populate('assignedTo')
      .populate('assignedBy');
    await syncClientProfileByProjectId(existing.project);
    await syncClientProfileByProjectId(updated?.project?._id || updated?.project || req.body?.project);
    res.status(200).json({ message: 'Task updated', task: updated });
  } catch (error) {
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
