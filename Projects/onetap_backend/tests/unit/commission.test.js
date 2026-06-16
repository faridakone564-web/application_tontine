const { calculerCommission } = require('../../controllers/commissionController');

describe('commissionController.calculerCommission', () => {
  test('returns 0% platform commission and 5% creator commission', () => {
    const montant = 10000;
    const res = calculerCommission(montant);
    expect(res.commission_plateforme).toBe(0);
    expect(res.commission_createur).toBeCloseTo(500.00, 2);
    expect(res.montant_net).toBeCloseTo(10000.00, 2);
  });

  test('handles small amounts correctly', () => {
    const montant = 1234.56;
    const res = calculerCommission(montant);
    expect(res.commission_plateforme).toBe(0);
    expect(res.commission_createur).toBeCloseTo(Number((montant * 0.05).toFixed(2)), 2);
    expect(res.montant_net).toBeCloseTo(Number(montant.toFixed(2)), 2);
  });
});
