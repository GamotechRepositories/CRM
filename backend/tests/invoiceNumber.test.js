import { afterEach, describe, expect, it, jest } from '@jest/globals';
import InvoiceSequence from '../models/invoiceSequence.js';
import { invoiceYearRange, nextInvoiceNumber } from '../utils/invoiceNumber.js';

afterEach(() => jest.restoreAllMocks());

describe('invoice numbers', () => {
  it.each([
    ['2026-01-01T00:00:00Z', '2026-27'],
    ['2026-11-02T00:00:00Z', '2026-27'],
    ['2026-12-31T18:29:59Z', '2026-27'],
    ['2026-12-31T18:30:00Z', '2027-28'],
    ['2099-11-02T00:00:00Z', '2099-00'],
  ])('uses the current Indian calendar year for %s', (date, expected) => {
    expect(invoiceYearRange(new Date(date))).toBe(expected);
  });
  it.each(['ARG', 'BGP', 'MHP', 'STR'])('allocates an unpadded number for %s', async (prefix) => {
    const update = jest.spyOn(InvoiceSequence, 'findOneAndUpdate').mockResolvedValue({ sequence: 1 });
    expect(await nextInvoiceNumber(prefix, new Date('2026-11-02T00:00:00Z'))).toBe(`${prefix}-2026-27-1`);
    expect(update).toHaveBeenCalledWith(
      { _id: `${prefix}-2026-27` }, { $inc: { sequence: 1 } }, { upsert: true, new: true },
    );
  });
  it('preserves sequence values above nine', async () => {
    jest.spyOn(InvoiceSequence, 'findOneAndUpdate').mockResolvedValue({ sequence: 12 });
    expect(await nextInvoiceNumber('ARG', new Date('2026-11-02T00:00:00Z'))).toBe('ARG-2026-27-12');
  });
});
