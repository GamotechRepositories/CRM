import Order from '../../models/bangarProperties/bangarProperties_order.js';

/** Financial year (India: Apr–Mar). Returns ending year e.g. 2026 for FY 2025-26 */
function getFinancialYearEnd(date = new Date()) {
  const year = date.getFullYear();
  const month = date.getMonth(); // 0-indexed: Jan=0, Apr=3
  return month >= 3 ? year + 1 : year;
}

/** Distribute payment amount across projects (first first), return projects with dynamic remainingCost */
export function withDynamicRemainingCost(order) {
  const doc = order.toObject ? order.toObject() : { ...order };
  const paymentAmount = Number(doc.paymentDetails?.amount) || 0;
  const projects = Array.isArray(doc.projects) ? doc.projects : [];
  if (paymentAmount <= 0) {
    doc.projects = projects.map((p) => ({
      ...p,
      remainingCost: Math.max(0, Number(p.projectCost) || 0),
    }));
    return doc;
  }
  let remainingToDistribute = paymentAmount;
  doc.projects = projects.map((p) => {
    const cost = Number(p.projectCost) || 0;
    const amountPaid = Math.min(cost, Math.max(0, remainingToDistribute));
    remainingToDistribute -= amountPaid;
    const remainingCost = Math.max(0, cost - amountPaid);
    return { ...p, remainingCost };
  });
  return doc;
}

/** For a list of orders, compute per-project: total project cost (max), total paid (sum of distributed amount), remaining */
export function computeTracking(orders) {
  const byProject = new Map();
  for (const b of orders) {
    const doc = b.toObject ? b.toObject() : b;
    const paymentAmount = Number(doc.paymentDetails?.amount) || 0;
    const projects = Array.isArray(doc.projects) ? doc.projects : [];
    let remainingToDistribute = paymentAmount;
    for (const p of projects) {
      const projectId = (p.project?._id || p.project)?.toString?.() || p.project;
      if (!projectId) continue;
      const cost = Number(p.projectCost) || 0;
      const amountPaid = paymentAmount <= 0 ? 0 : Math.min(cost, Math.max(0, remainingToDistribute));
      if (paymentAmount > 0) remainingToDistribute -= amountPaid;
      if (!byProject.has(projectId)) {
        byProject.set(projectId, {
          project: p.project,
          projectCost: cost,
          totalPaid: 0,
        });
      }
      const entry = byProject.get(projectId);
      entry.projectCost = Math.max(entry.projectCost, cost);
      entry.totalPaid += amountPaid;
    }
  }
  return Array.from(byProject.values()).map((entry) => ({
    ...entry,
    remaining: Math.max(0, entry.projectCost - entry.totalPaid),
  }));
}

export const createOrder = async (req, res) => {
  try {
    const fy = getFinancialYearEnd();
    const prefix = `BGP-ORD-${fy}-`;
    const count = await Order.countDocuments({ orderNumber: new RegExp(`^BGP-ORD-${fy}-`) });
    const seq = count + 1;
    const orderNumber = `${prefix}${String(seq).padStart(3, '0')}`;
    const order = new Order({ ...req.body, orderNumber });
    await order.save();
    const populated = await Order.findById(order._id)
      .populate('client')
      .populate('projects.project');
    res.status(201).json({ message: 'Order created', order: withDynamicRemainingCost(populated) });
  } catch (error) {
    res.status(500).json({ message: 'Error creating order', error });
  }
};

export const getOrders = async (req, res) => {
  try {
    const { clientId, billType } = req.query;
    const filter = {};
    if (clientId) filter.client = clientId;
    if (billType) filter.billType = billType;
    const orders = await Order.find(filter)
      .populate('client')
      .populate('projects.project')
      .sort({ createdAt: -1 });
    res.status(200).json(orders.map((b) => withDynamicRemainingCost(b)));
  } catch (error) {
    res.status(500).json({ message: 'Error fetching orders', error });
  }
};

export const getOrderById = async (req, res) => {
  try {
    const order = await Order.findById(req.params.id)
      .populate('client')
      .populate('projects.project');
    if (!order) return res.status(404).json({ message: 'Order not found' });
    const result = withDynamicRemainingCost(order);
    const clientId = (order.client?._id || order.client)?.toString?.();
    if (clientId) {
      const allForClient = await Order.find({ client: clientId })
        .populate('projects.project')
        .sort({ createdAt: 1 });
      result.tracking = computeTracking(allForClient);
    }
    res.status(200).json(result);
  } catch (error) {
    res.status(500).json({ message: 'Error fetching order', error });
  }
};

/** GET /order/tracking/:clientId - cumulative paid and remaining per project for a client */
export const getOrderTracking = async (req, res) => {
  try {
    const { clientId } = req.params;
    const orders = await Order.find({ client: clientId })
      .populate('projects.project')
      .sort({ createdAt: 1 });
    const tracking = computeTracking(orders);
    res.status(200).json({ clientId, tracking });
  } catch (error) {
    res.status(500).json({ message: 'Error fetching order tracking', error });
  }
};

export const updateOrder = async (req, res) => {
  try {
    const updated = await Order.findByIdAndUpdate(req.params.id, req.body, {
      new: true,
      runValidators: true,
    })
      .populate('client')
      .populate('projects.project');
    if (!updated) return res.status(404).json({ message: 'Order not found' });
    res.status(200).json({ message: 'Order updated', order: withDynamicRemainingCost(updated) });
  } catch (error) {
    res.status(500).json({ message: 'Error updating order', error });
  }
};

export const deleteOrder = async (req, res) => {
  try {
    const deleted = await Order.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ message: 'Order not found' });
    res.status(200).json({ message: 'Order deleted' });
  } catch (error) {
    res.status(500).json({ message: 'Error deleting order', error });
  }
};
