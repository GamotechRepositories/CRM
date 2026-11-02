import { afterEach, describe, expect, it, jest } from '@jest/globals';

const tenants = ['adsResearchGlobal', 'bangarProperties', 'mahaProperties', 'salesTechReality'];
const clientId = '507f1f77bcf86cd799439011';
const id = '6a45028700d9d6ed557b9cfd';
const query = (result) => ({
  populate() { return this; }, sort() { return this; },
  then(resolve, reject) { return Promise.resolve(result).then(resolve, reject); },
});
afterEach(() => jest.restoreAllMocks());

for (const tenant of tenants) {
  const { default: Order } = await import(`../models/${tenant}/${tenant}_order.js`);
  const { default: Billing } = await import(`../models/${tenant}/${tenant}_billing.js`);
  const { default: Profile } = await import(`../models/${tenant}/${tenant}_clientProfile.js`);
  const { default: router } = await import(`../routes/${tenant}/${tenant}_orderRoute.js`);
  // Dispatch through registered handlers without opening a network port.
  const invoke = async (method, path, body = {}) => {
    const url = new URL(path, 'http://localhost');
    const layer = router.stack.find(({ route }) => route?.methods[method]
      && new RegExp('^' + route.path.replace(/:[^/]+/g, '[^/]+') + '$').test(url.pathname));
    if (!layer) throw new Error(`Missing route: ${method} ${path}`);
    const params = {};
    layer.route.path.split('/').forEach((part, index) => {
      if (part.startsWith(':')) params[part.slice(1)] = url.pathname.split('/')[index];
    });
    const res = { status(code) { this.statusCode = code; return this; }, json(value) { this.body = value; return this; } };
    await layer.route.stack[0].handle({ params, query: Object.fromEntries(url.searchParams), body }, res);
    return { status: res.statusCode, body: JSON.parse(JSON.stringify(res.body)) };
  };
  const input = { billType: 'GST', client: clientId, orderDate: '2026-11-02', items: [{ name: 'Custom service', description: 'My description', hsnSac: '998313', serviceName: 'IT consulting', quantity: 2, price: 100, gstRate: 18 }], paymentDetails: { amount: 50 }, authorizedSignature: 'https://example.test/signature.png' };

  describe(`${tenant} sales orders`, () => {
    it('creates an independently numbered order without changing invoices or billing summaries', async () => {
      let saved;
      const invoiceSave = jest.spyOn(Billing.prototype, 'save');
      const profileUpdate = jest.spyOn(Profile, 'findOneAndUpdate');
      jest.spyOn(Order, 'countDocuments').mockResolvedValue(0);
      jest.spyOn(Order.prototype, 'save').mockImplementation(async function () { saved = this.toObject(); return this; });
      jest.spyOn(Order, 'findById').mockImplementation(() => query(saved));
      const res = await invoke('post', '/order', input);
      expect(res.status).toBe(201);
      expect(res.body.order.orderNumber).toMatch(/^(ARG|BGP|MHP|STR)-ORD-\d{4}-001$/);
      expect(res.body.order.items[0]).toMatchObject(input.items[0]);
      expect(res.body.order.authorizedSignature).toBe(input.authorizedSignature);
      expect(Order.collection.name).not.toBe(Billing.collection.name);
      expect(invoiceSave).not.toHaveBeenCalled();
      expect(profileUpdate).not.toHaveBeenCalled();
    });
    it('lists only order records with client and type filters', async () => {
      const find = jest.spyOn(Order, 'find').mockReturnValue(query([{ ...input, _id: id }]));
      const res = await invoke('get', `/order?clientId=${clientId}&billType=GST`);
      expect(res.status).toBe(200);
      expect(find).toHaveBeenCalledWith({ client: clientId, billType: 'GST' });
      expect(res.body).toHaveLength(1);
    });
    it('updates an order with a populated client', async () => {
      jest.spyOn(Order, 'findByIdAndUpdate').mockReturnValue(query({ ...input, _id: id, client: { _id: clientId, clientName: 'Client' } }));
      const res = await invoke('put', `/order/${id}`, input);
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Order updated');
      expect(res.body.order.client._id).toBe(clientId);
    });
    it('deletes an order', async () => {
      jest.spyOn(Order, 'findByIdAndDelete').mockResolvedValue({ _id: id });
      const res = await invoke('delete', `/order/${id}`);
      expect(res.status).toBe(200);
      expect(res.body.message).toBe('Order deleted');
    });
    it('returns 404 for missing orders', async () => {
      jest.spyOn(Order, 'findById').mockReturnValue(query(null));
      const res = await invoke('get', `/order/${id}`);
      expect(res.status).toBe(404);
    });
  });
}
