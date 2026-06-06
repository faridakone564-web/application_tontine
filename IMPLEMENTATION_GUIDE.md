# Guide d'Implémentation - Fonctionnalités Professionnelles de Tontine

## 📋 Résumé des modifications

Cette implémentation ajoute deux fonctionnalités professionnelles à l'application OneTap Tontine:
1. **Verrouillage de la tontine au démarrage** 
2. **Gestion des places disponibles en temps réel**

---

## 1️⃣ VERROUILLAGE DE LA TONTINE AU DÉMARRAGE

### Backend Modifications

#### 1.1 Structure de données (index.js)
```sql
-- Colonnes ajoutées à la table `groups`:
status ENUM('en_attente','active','terminee') NOT NULL DEFAULT 'en_attente'
start_date TIMESTAMP NULL DEFAULT NULL
```

**Migrations auto-appliquées:** Les colonnes sont créées/ajoutées automatiquement au démarrage du serveur.

#### 1.2 Contrôleurs modifiés

**File: controllers/dashboardController.js**
- `getMesGroupes()`: Retourne maintenant `status`, `startDate`, `maxMembers`, `currentMembers`, `availableSlots`
- `getGroupDetails()`: Ajoute les champs `status`, `startDate`, `isLocked`, `currentMembers`, `availableSlots`

**File: controllers/membersController.js**
- `rejoindre()`: Vérifie maintenant si la tontine est `active` avant d'accepter une adhésion
  - Message d'erreur: "Cette tontine a déjà démarré. Les inscriptions sont fermées."

**File: controllers/yengaController.js**
- `payerCotisation()`: À la première cotisation validée, met automatiquement à jour le statut du groupe:
  - `status` → `'active'`
  - `start_date` → `NOW()`

**File: controllers/groupsController.js (NOUVEAU)**
- `updateGroupStatus()`: Endpoint pour activer/terminer manuellement une tontine
  - Route: `PUT /api/groups/status/:groupId`
  - Paramètres: `{ status: 'en_attente' | 'active' | 'terminee' }`
  - Seul le propriétaire du groupe peut utiliser cette fonction

#### 1.3 Routes

**File: routes/groups.js**
```javascript
router.put('/status/:groupId', authMiddleware, groupsController.updateGroupStatus);
```

---

## 2️⃣ GESTION DES PLACES DISPONIBLES

### Backend

Tous les calculs des places sont effectués dans `dashboardController.js`:

```javascript
const [memberCountRows] = await db.query(
  'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut = ?',
  [groupId, 'approuvé']
);
const currentMembers = memberCountRows[0].count || 0;
const maxMembers = group.max_membres || 10;
const availableSlots = Math.max(0, maxMembers - currentMembers);
```

**Données retournées par les APIs:**
- `currentMembers`: Nombre de membres approuvés
- `maxMembers`: Nombre maximum de membres
- `availableSlots`: Nombre de places restantes
- `isFull`: Booléen si le groupe est plein (calculé côté client)

---

### Frontend Flutter Modifications

#### 2.1 Modèle (lib/models/group_model.dart)

```dart
class GroupModel {
  final int maxMembers;
  final int currentMembers;
  final int availableSlots;
  final String status;
  final DateTime? startDate;
  
  bool get isLocked => status == 'active';
  bool get isFull => availableSlots <= 0;
  bool get canJoin => !isLocked && !isFull;
}
```

#### 2.2 Services API (lib/services/api_service.dart)

**Méthode ajoutée:**
```dart
static Future<Map<String, dynamic>> updateGroupStatus({
  required int groupId,
  required String status,
}) async
```

#### 2.3 Écrans modifiés

##### MesGroupsScreen
- Affiche une **barre de progression** pour chaque groupe
- Badge **"Verrouillée"** en rouge si `status == 'active'`
- Badge **"COMPLET"** en rouge si `isFull`
- Affiche "👥 X/Y membres" et "✅ Z places disponibles"
- Statut en badge orange/vert

**Exemple visuel:**
```
┌─────────────────────────────────┐
│ Mon Tontine        🔒 COMPLET   │
│ 2000 FCFA · Mensuel             │
│ 👥 15/15 membres   ✅ 0 places  │
│ ████████████████░░ 100%         │
│ Status: Active                  │
└─────────────────────────────────┘
```

##### GroupDetailScreen
- **Carte de verrouillage** si `status == 'active'`:
  - Message: "🔒 Tontine verrouillée"
  - Sous-message: "Cette tontine a déjà démarré. Les inscriptions sont fermées."
  - Date de démarrage affichée

- **Carte "Membres et Places"** si non verrouillée:
  - Affiche: "Membres actuels" et "Places disponibles"
  - Barre de progression colorée (rouge si plein, vert sinon)
  - Badge "COMPLET" en rouge si `isFull`

- **Bouton "Payer ma cotisation"**: Toujours disponible
- **Messages d'avertissement** si groupe plein ou verrouillé

**Exemple visuel:**
```
┌──────────────────────────────────┐
│ 🔒 Tontine verrouillée           │
│ Cette tontine a déjà démarré.    │
│ Les inscriptions sont fermées.   │
│ Démarrée le: 2026-06-02         │
└──────────────────────────────────┘

┌──────────────────────────────────┐
│ 👥 Membres et Places    COMPLET  │
│ Membres actuels  Places dispo    │
│     20/20             0          │
│ ████████████████████████ 100%   │
└──────────────────────────────────┘
```

##### JoinGroupScreen
- Messages d'erreur améliorés:
  - "Cette tontine a déjà démarré. Les inscriptions sont fermées."
  - "Ce groupe a atteint le nombre maximum de membres."
- Gestion correcte des exceptions du backend

---

## 📊 Données retournées par les APIs

### GET /api/groups/mes-groupes/:userId
```json
[
  {
    "id": 1,
    "nom": "Tontine Quartier",
    "montant": 2000,
    "frequence": "mensuel",
    "isActive": true,
    "status": "active",
    "startDate": "2026-06-01T10:30:00.000Z",
    "maxMembers": 20,
    "currentMembers": 15,
    "availableSlots": 5,
    "prochainBeneficiaire": { "nom": "...", "telephone": "..." }
  }
]
```

### GET /api/groups/details/:groupId
```json
{
  "id": 1,
  "nom": "Tontine Quartier",
  "montant": 2000,
  "frequence": "mensuel",
  "maxMembres": 20,
  "currentMembers": 15,
  "availableSlots": 5,
  "codeInvitation": "ABC12345",
  "isActive": true,
  "status": "active",
  "startDate": "2026-06-01T10:30:00.000Z",
  "createdAt": "2026-05-01T...",
  "isOwner": true,
  "isLocked": true,
  "prochainBeneficiaire": { ... }
}
```

---

## 🔧 Scénarios d'utilisation

### Scénario 1: Création et démarrage d'une tontine

1. **Propriétaire crée la tontine** → `status = 'en_attente'`
2. **Autres membres rejoignent** → Possible car non verrouillée
3. **Première cotisation est payée** → 
   - `status` passe automatiquement à `'active'`
   - `start_date` est enregistrée
4. **Nouveau membre essaie de rejoindre** →
   - ❌ Erreur: "Cette tontine a déjà démarré"

### Scénario 2: Groupe plein

1. Groupe a max 20 membres
2. 20 membres sont déjà inscrits → `availableSlots = 0`
3. Nouveau membre essaie de rejoindre →
   - ❌ Erreur: "Ce groupe a atteint le nombre maximum"
   - Badge "COMPLET" affiché

### Scénario 3: Activation manuelle (propriétaire)

Propriétaire peut mettre à jour manuellement le statut:
```bash
curl -X PUT http://localhost:3000/api/groups/status/1 \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"status": "active"}'
```

---

## ✅ Validation et Contrôles Backend

Les validations suivantes sont effectuées côté serveur pour éviter le contournement:

1. **Adhésion à un groupe verrouillé**: ❌ Rejetée
2. **Adhésion à un groupe plein**: ❌ Rejetée
3. **Paiement d'une cotisation**: ✅ Acceptée (même si verrouillé)
4. **Mise à jour du statut**: Seul le propriétaire peut
5. **Changement de `start_date`**: Impossible après activation

---

## 🎨 Thème et Couleurs

- **Badge Verrouillé**: `Color(0xFFFFEBEE)` avec icône rouge
- **Badge Complet**: `Color(0xFFFFEBEE)` avec texte rouge
- **Barre de progression normale**: Vert (`AppColors.primaryGreen`)
- **Barre de progression pleine**: Rouge (`Color(0xFFD32F2F)`)
- **Statut "en_attente"**: Vert
- **Statut "active"**: Orange (`AppColors.accentOrange`)

---

## 📝 Fichiers modifiés

### Backend (Node.js/Express)
- ✅ `index.js` - Ajout des colonnes `status` et `start_date`
- ✅ `controllers/dashboardController.js` - Retour des infos places/statut
- ✅ `controllers/membersController.js` - Vérification du statut
- ✅ `controllers/yengaController.js` - Activation auto à la première cotisation
- ✅ `controllers/groupsController.js` - Nouvel endpoint `updateGroupStatus()`
- ✅ `routes/groups.js` - Route `PUT /api/groups/status/:groupId`

### Frontend (Flutter)
- ✅ `lib/models/group_model.dart` - Nouveaux champs et getters
- ✅ `lib/services/api_service.dart` - Méthode `updateGroupStatus()`
- ✅ `lib/screens/mes_groups_screen.dart` - Affichage places et badges
- ✅ `lib/screens/group_detail_screen.dart` - Cartes de verrouillage et places
- ✅ `lib/screens/join_group_screen.dart` - Meilleurs messages d'erreur

---

## 🚀 Déploiement

### 1. Backend
```bash
cd onetap_backend
npm install  # Si nouvelles dépendances
node index.js  # Démarre le serveur
```

Les migrations SQL se feront automatiquement au démarrage.

### 2. Frontend
```bash
cd onetap_frontend
flutter pub get
flutter run
```

Ou pour une build complète:
```bash
flutter build apk --release
```

---

## 🔍 Tests recommandés

### Test 1: Adhésion avant et après activation
1. Créer un groupe
2. Adhérer au groupe → ✅ Succès
3. Enregistrer une cotisation → Statut devient "active"
4. Essayer de rejoindre → ❌ Erreur

### Test 2: Groupe plein
1. Créer un groupe avec max_membres = 3
2. Ajouter 3 membres → ✅
3. Essayer d'en ajouter un 4e → ❌ "Groupe complet"

### Test 3: Affichage temps réel
1. Ouvrir MesGroupsScreen
2. Approuver un nouveau membre depuis le backend
3. Recharger l'écran → Nombre de membres mis à jour

---

## ⚠️ Notes importantes

1. **Pas de "déverrouillage"**: Une fois activée, une tontine ne peut pas revenir à "en_attente"
2. **Statut "terminee"**: Peut être utilisé ultérieurement pour les tontines terminées
3. **Performances**: Les requêtes de comptage sont optimisées avec des index sur `group_id`
4. **Sauvegardes**: La `start_date` est enregistrée une seule fois, lors de l'activation
5. **Compatibilité**: Code compatible avec MySQL 5.7+ et flutter 3.0+

---

## 🆘 Troubleshooting

### Problème: Badge "Verrouillée" ne s'affiche pas
**Solution**: Vérifier que `status` est bien retourné par l'API. Forcer la mise à jour:
```dart
await ApiService.updateGroupStatus(groupId: groupId, status: 'active');
```

### Problème: Barre de progression ne s'affiche pas
**Solution**: Vérifier que `currentMembers` et `maxMembers` sont non-nuls.

### Problème: Erreur "Tontine démarrée" lors de l'adhésion
**Solution**: C'est le comportement attendu! La tontine est active.

---

## 📞 Support

Pour toute question ou bug, veuillez vérifier:
1. Les logs du serveur Node.js
2. L'onglet Network dans les DevTools Flutter
3. La base de données (vérifier les colonnes status et start_date)

