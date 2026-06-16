Changes made:

- Centralized join-request handling in `controllers/membersController.js` (removed duplicate `rejoindreGroupe` from `controllers/groupsController.js`).
- Added end-to-end test script `tests/e2e_join_test.js`.
- Added unit tests:
  - `tests/unit/commission.test.js`
  - `tests/unit/members.test.js`
- Added Jest devDependency and test script in `package.json`.

Notes:
- Platform commission is set to 0%; organizer commission fixed to 5%.
- Deprecated route `POST /api/groups/rejoindre` continues to return 410.
