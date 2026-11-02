import { afterEach, describe, expect, it, jest } from '@jest/globals';
import mongoose from 'mongoose';

const tenants = ['adsResearchGlobal', 'bangarProperties', 'mahaProperties', 'salesTechReality'];
const clientId = '6a45028700d9d6ed557b9cfd';

afterEach(() => jest.restoreAllMocks());

for (const tenant of tenants) {
  const { syncClientProfile } = await import(`../utils/${tenant}/${tenant}_clientProfileSync.js`);
  const { updateBilling } = await import(`../controllers/${tenant}/${tenant}_billingController.js`);
  const models = {};
  for (const name of ['client', 'project', 'socialMediaCalendar', 'billing', 'task', 'clientProfile']) {
    models[name] = (await import(`../models/${tenant}/${tenant}_${name}.js`)).default;
  }

  describe(`${tenant} client profile sync`, () => {
    it('updates a bill and syncs both clients when the updated client is populated', async () => {
      const previousClientId = '507f1f77bcf86cd799439011';
      const updated = {
        _id: new mongoose.Types.ObjectId(),
        client: new models.client({ _id: clientId, clientName: 'Example client' }),
        projects: [],
        paymentDetails: { amount: 100 },
      };
      jest.spyOn(models.billing, 'findById').mockReturnValue({
        select: async () => ({ client: new mongoose.Types.ObjectId(previousClientId) }),
      });
      jest.spyOn(models.billing, 'findByIdAndUpdate').mockReturnValue({
        populate: () => ({ populate: async () => updated }),
      });
      for (const name of ['project', 'socialMediaCalendar', 'billing', 'task']) {
        jest.spyOn(models[name], 'find').mockReturnValue({
          select: () => ({ lean: async () => [] }),
        });
      }
      jest.spyOn(models.clientProfile, 'findOneAndUpdate').mockResolvedValue({});
      const res = { status: jest.fn().mockReturnThis(), json: jest.fn() };
      await updateBilling({ params: { id: String(updated._id) }, body: { client: clientId } }, res);
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ message: 'Billing updated' }));
      expect(models.project.find).toHaveBeenNthCalledWith(1, { client: previousClientId });
      expect(models.project.find).toHaveBeenNthCalledWith(2, { client: clientId });
    });

    it.each([
      ['string ID', () => clientId],
      ['ObjectId', () => new mongoose.Types.ObjectId(clientId)],
      ['populated document', () => new models.client({ _id: clientId, clientName: 'Example client' })],
      ['plain populated object', () => ({ _id: clientId, clientName: 'Example client' })],
    ])('uses only the client ID for a %s', async (_label, value) => {
      for (const name of ['project', 'socialMediaCalendar', 'billing', 'task']) {
        jest.spyOn(models[name], 'find').mockReturnValue({
          select: () => ({ lean: async () => [] }),
        });
      }
      jest.spyOn(models.clientProfile, 'findOneAndUpdate').mockResolvedValue({ client: clientId });

      await syncClientProfile({ clientId: value() });

      for (const name of ['project', 'socialMediaCalendar', 'billing']) {
        expect(models[name].find).toHaveBeenCalledWith({ client: clientId });
      }
      expect(models.clientProfile.findOneAndUpdate).toHaveBeenCalledWith(
        { client: clientId },
        expect.objectContaining({ $set: expect.objectContaining({ client: clientId }) }),
        expect.objectContaining({ upsert: true }),
      );
    });
  });
}
