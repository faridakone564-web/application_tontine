const membersController = require('../../controllers/membersController');
const db = require('../../config/db');

jest.mock('../../config/db', () => ({
  query: jest.fn(),
}));

function mockRes() {
  const res = {};
  res.status = jest.fn().mockReturnValue(res);
  res.json = jest.fn().mockReturnValue(res);
  return res;
}

describe('membersController', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  test('rejoindre returns 400 when no codeInvitation or groupId', async () => {
    const req = { body: {}, user: { userId: 1 } };
    const res = mockRes();

    await membersController.rejoindre(req, res);

    expect(res.status).toHaveBeenCalledWith(400);
    expect(res.json).toHaveBeenCalledWith({ message: "Code d'invitation ou identifiant de groupe requis" });
  });

  test('rejoindre inserts en_attente for public group', async () => {
    // Setup: group exists and is public
    db.query.mockImplementation((sql, params) => {
      if (sql.includes('SELECT id, user_id, nom, max_membres, status, type, code_invitation FROM `groups` WHERE id = ?')) {
        return Promise.resolve([[{ id: 10, user_id: 2, nom: 'G', max_membres: 5, status: 'recrutement', type: 'public', code_invitation: 'C' }]]);
      }
      if (sql.startsWith('SELECT statut_paiement')) {
        return Promise.resolve([[]]);
      }
      if (sql.startsWith('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?')) {
        return Promise.resolve([[]]);
      }
      if (sql.startsWith('SELECT COUNT(*) as count FROM group_members')) {
        return Promise.resolve([[{ count: 1 }]]);
      }
      if (sql.startsWith('INSERT INTO group_members')) {
        return Promise.resolve([{ insertId: 123 }]);
      }
      // default
      return Promise.resolve([[]]);
    });

    const req = { body: { groupId: 10 }, user: { userId: 3 } };
    const res = mockRes();

    await membersController.rejoindre(req, res);

    expect(db.query).toHaveBeenCalled();
    expect(res.json).toHaveBeenCalledWith({ message: "Votre demande d'adhésion a été envoyée (en attente d'approbation)" });
  });

  test('getEnAttente returns 403 if caller not owner', async () => {
    // group owner is 2, caller is 3 and not member
    db.query.mockImplementation((sql, params) => {
      if (sql.startsWith('SELECT user_id FROM `groups` WHERE id = ?')) {
        return Promise.resolve([[{ user_id: 2 }]]);
      }
      if (sql.startsWith('SELECT id FROM group_members WHERE group_id = ? AND user_id = ?')) {
        return Promise.resolve([[]]);
      }
      return Promise.resolve([[]]);
    });

    const req = { params: { groupId: '10' }, user: { userId: 3 } };
    const res = mockRes();

    await membersController.getEnAttente(req, res);

    expect(res.status).toHaveBeenCalledWith(403);
    expect(res.json).toHaveBeenCalledWith({ message: 'Accès refusé' });
  });

  test('approuver approves a member when called by owner', async () => {
    // member exists, group owner matches caller
    db.query.mockImplementation((sql, params) => {
      if (sql.startsWith('SELECT * FROM group_members WHERE id = ?')) {
        return Promise.resolve([[{ id: 50, group_id: 20, user_id: 30 }]]);
      }
      if (sql.startsWith('SELECT user_id, nom FROM `groups` WHERE id = ?')) {
        return Promise.resolve([[{ user_id: 2, nom: 'Groupe' }]]);
      }
      if (sql.startsWith("UPDATE group_members SET statut = 'approuvé'")) {
        return Promise.resolve();
      }
      if (sql.startsWith("SELECT id FROM group_members WHERE group_id = ? AND statut = ?")) {
        return Promise.resolve([[{ id: 50 }]]);
      }
      if (sql.startsWith('SELECT gm.user_id')) {
        return Promise.resolve([[]]);
      }
      if (sql.startsWith('INSERT INTO beneficiaries')) {
        return Promise.resolve();
      }
      return Promise.resolve([[]]);
    });

    const req = { params: { memberId: '50' }, user: { userId: 2 } };
    const res = mockRes();

    await membersController.approuver(req, res);

    expect(res.json).toHaveBeenCalledWith(expect.objectContaining({ message: 'Membre approuvé' }));
  });

});
