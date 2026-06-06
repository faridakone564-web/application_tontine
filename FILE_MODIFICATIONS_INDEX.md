# 📑 INDEX DES MODIFICATIONS - Fichier par Fichier

## 🗂️ Structure des Changements

### Backend (Node.js/Express)

---

## 📄 onetap_backend/index.js

**Type**: Modification - Migrations SQL  
**Lignes affectées**: ~50  
**Changement**: Ajout des colonnes `status` et `start_date` au tableau `groups`

**Avant:**
```javascript
CREATE TABLE IF NOT EXISTS `groups` (
  id INT PRIMARY KEY AUTO_INCREMENT,
  nom VARCHAR(100),
  montant DECIMAL(10,2),
  frequence VARCHAR(20)
  // ... autres colonnes
)
```

**Après:**
```javascript
CREATE TABLE IF NOT EXISTS `groups` (
  id INT PRIMARY KEY AUTO_INCREMENT,
  nom VARCHAR(100),
  montant DECIMAL(10,2),
  frequence VARCHAR(20),
  status ENUM('en_attente','active','terminee') NOT NULL DEFAULT 'en_attente',
  start_date TIMESTAMP NULL DEFAULT NULL
  // ... autres colonnes
)
```

**Migrations auto-appliquées:**
```sql
ALTER TABLE `groups` ADD COLUMN `status` ENUM(...) DEFAULT 'en_attente';
ALTER TABLE `groups` ADD COLUMN `start_date` TIMESTAMP NULL DEFAULT NULL;
```

**Raison**: Tracker l'état de la tontine et son date de démarrage

---

## 📄 onetap_backend/controllers/dashboardController.js

**Type**: Modification - Logique de comptage  
**Lignes affectées**: ~40  
**Changement**: Ajout de calculs de membres et places disponibles

**Fonctions modifiées:**
1. `getMesGroupes()` - Ajoute les infos de membres pour chaque groupe
2. `getGroupDetails()` - Ajoute calculs de places et comptage

**Avant:**
```javascript
async getMesGroupes(req, res) {
  // Retournait uniquement les infos de base du groupe
}
```

**Après:**
```javascript
async getMesGroupes(req, res) {
  // Pour chaque groupe:
  // 1. Compter les membres approuvés
  // 2. Calculer maxMembers
  // 3. Calculer availableSlots = max - current
  // 4. Retourner ces infos
}
```

**Nouvelles données retournées:**
- `status`: État de la tontine
- `startDate`: Date de démarrage (si active)
- `currentMembers`: Nombre de membres approuvés
- `maxMembers`: Nombre maximum
- `availableSlots`: Places disponibles

**Raison**: Fournir données temps réel pour l'UI

---

## 📄 onetap_backend/controllers/membersController.js

**Type**: Modification - Validation prédéploiement  
**Lignes affectées**: ~15  
**Changement**: Ajout de vérification `status !== 'active'`

**Fonction modifiée:** `rejoindre()`

**Avant:**
```javascript
async rejoindre(req, res) {
  // Récupérer le groupe
  const groupe = ...
  
  // Insert directement
  await db.query('INSERT INTO group_members ...');
}
```

**Après:**
```javascript
async rejoindre(req, res) {
  // Récupérer le groupe
  const groupe = ...
  
  // [NOUVEAU] Vérifier que la tontine n'est pas active
  if (groupe.status === 'active') {
    return res.status(403).json({
      error: 'Cette tontine a déjà démarré. Les inscriptions sont fermées.'
    });
  }
  
  // Insert seulement si validation OK
  await db.query('INSERT INTO group_members ...');
}
```

**Raison**: Bloquer l'accès au niveau serveur (sécurisé)

---

## 📄 onetap_backend/controllers/yengaController.js

**Type**: Modification - Auto-activation  
**Lignes affectées**: ~20  
**Changement**: Ajout d'auto-activation après première cotisation

**Fonction modifiée:** `payerCotisation()`

**Avant:**
```javascript
async payerCotisation(req, res) {
  // Insérer le paiement
  await db.query('INSERT INTO payments ...');
  res.json({ message: 'Paiement enregistré' });
}
```

**Après:**
```javascript
async payerCotisation(req, res) {
  // Insérer le paiement
  await db.query('INSERT INTO payments ...');
  
  // [NOUVEAU] Vérifier si c'est la 1ère cotisation
  const [count] = await db.query(
    'SELECT COUNT(*) from payments WHERE group_id = ? AND statut = ?',
    [groupId, 'VALIDEE']
  );
  
  // Si c'est la première, activer le groupe
  if (count[0].count === 1) {
    await db.query(
      'UPDATE groups SET status = ?, start_date = NOW() WHERE id = ?',
      ['active', groupId]
    );
    console.log(`[AUTO-ACTIVATION] Groupe ${groupId} activé`);
  }
  
  res.json({ message: 'Paiement enregistré' });
}
```

**Raison**: Automatiser l'activation sans intervention manuelle

---

## 📄 onetap_backend/controllers/groupsController.js

**Type**: Modification - Nouvel endpoint  
**Lignes affectées**: ~60 (code ajouté)  
**Changement**: Ajout de fonction `updateGroupStatus()`

**Nouvelle fonction:**
```javascript
async updateGroupStatus(req, res) {
  // Paramètres: groupId, status
  
  // 1. Valider le statut
  if (!['en_attente', 'active', 'terminee'].includes(status)) {
    return res.status(400).json({ error: 'Statut invalide' });
  }
  
  // 2. Vérifier existence du groupe
  const groupe = ...
  
  // 3. Vérifier propriétaire
  if (groupe.owner_id !== userId) {
    return res.status(403).json({ error: 'Pas propriétaire' });
  }
  
  // 4. Mettre à jour avec start_date si activation
  if (status === 'active' && groupe.status !== 'active') {
    await db.query(
      'UPDATE groups SET status = ?, start_date = NOW() WHERE id = ?',
      [status, groupId]
    );
  } else {
    await db.query(
      'UPDATE groups SET status = ? WHERE id = ?',
      [status, groupId]
    );
  }
  
  res.json({ message: 'Statut mis à jour' });
}
```

**Raison**: Permettre activation manuelle si nécessaire

---

## 📄 onetap_backend/routes/groups.js

**Type**: Modification - Enregistrement route  
**Lignes affectées**: ~2  
**Changement**: Ajout route `PUT /status/:groupId`

**Avant:**
```javascript
router.get('/mes-groupes/:userId', ...);
router.get('/details/:groupId', ...);
router.post('/creer', ...);
```

**Après:**
```javascript
router.get('/mes-groupes/:userId', ...);
router.get('/details/:groupId', ...);
router.post('/creer', ...);
router.put('/status/:groupId', authMiddleware, groupsController.updateGroupStatus); // [NOUVEAU]
```

**Raison**: Exposer l'endpoint de mise à jour manuelle

---

### Frontend (Flutter/Dart)

---

## 📄 onetap_frontend/lib/models/group_model.dart

**Type**: Modification - Modèle de données  
**Lignes affectées**: ~40  
**Changement**: Ajout de 5 nouveaux champs et 3 getters calculés

**Nouveaux champs:**
```dart
final String status;           // 'en_attente', 'active', 'terminee'
final DateTime? startDate;
final int maxMembers;
final int currentMembers;
final int availableSlots;
```

**Nouveaux getters:**
```dart
bool get isLocked => status == 'active';
bool get isFull => availableSlots <= 0;
bool get canJoin => !isLocked && !isFull;
```

**Mise à jour factory:**
```dart
factory GroupModel.fromJson(Map<String, dynamic> json) {
  return GroupModel(
    // ... champs existants ...
    status: json['status'] ?? 'en_attente',
    startDate: json['startDate'] != null 
      ? DateTime.parse(json['startDate']) 
      : null,
    maxMembers: json['maxMembers'] ?? 10,
    currentMembers: json['currentMembers'] ?? 0,
    availableSlots: json['availableSlots'] ?? 10,
  );
}
```

**Raison**: Supporter les nouvelles données d'API

---

## 📄 onetap_frontend/lib/services/api_service.dart

**Type**: Modification - Service API  
**Lignes affectées**: ~15  
**Changement**: Ajout de méthode `updateGroupStatus()`

**Nouvelle méthode:**
```dart
static Future<Map<String, dynamic>> updateGroupStatus({
  required int groupId,
  required String status,
}) async {
  try {
    final String url = '${ApiService.baseUrl}/api/groups/status/$groupId';
    final response = await http.put(
      Uri.parse(url),
      headers: await authHeaders(),
      body: jsonEncode({ 'status': status }),
    );

    if (response.statusCode == 200) {
      return _parseResponse(response);
    } else {
      throw Exception('Erreur: ${response.body}');
    }
  } catch (error) {
    throw Exception('Erreur mise à jour statut: $error');
  }
}
```

**Raison**: Permettre appels API pour activation manuelle

---

## 📄 onetap_frontend/lib/screens/mes_groups_screen.dart

**Type**: Modification - Redesign complet UI  
**Lignes affectées**: ~120  
**Changement**: Affichage badges, progress bar, compteurs

**Ajouts visuels:**

1. **Badge "Verrouillée"** (si `groupe.isLocked`):
```dart
if (groupe.isLocked)
  Container(
    decoration: BoxDecoration(color: Color(0xFFFFEBEE)),
    child: Row(
      children: [
        Icon(Icons.lock, color: Color(0xFFD32F2F)),
        Text('Verrouillée', style: red),
      ],
    ),
  ),
```

2. **Badge "COMPLET"** (si `groupe.isFull`):
```dart
if (groupe.isFull)
  Container(
    decoration: BoxDecoration(color: Color(0xFFFFEBEE)),
    child: Text('COMPLET', style: red),
  ),
```

3. **Compteurs:**
```dart
Text('👥 ${groupe.currentMembers}/${groupe.maxMembers} membres'),
Text('✅ ${groupe.availableSlots} places', style: green),
```

4. **Barre de progression:**
```dart
LinearProgressIndicator(
  value: groupe.currentMembers / groupe.maxMembers,
  valueColor: AlwaysStoppedAnimation<Color>(
    groupe.isFull ? Color(0xFFD32F2F) : AppColors.primaryGreen,
  ),
),
```

5. **Statut badge:**
```dart
Container(
  color: groupe.status == 'active' ? orange : green,
  child: Text(groupe.status == 'active' ? 'Active' : 'En attente'),
),
```

**Raison**: Afficher informations complètes du groupe à l'utilisateur

---

## 📄 onetap_frontend/lib/screens/group_detail_screen.dart

**Type**: Modification - Ajout cartes verrouillage et places  
**Lignes affectées**: ~150  
**Changement**: Nouveaux widgets de présentation du statut

**Ajouts:**

1. **Carte Verrouillage** (si `isLocked`):
```dart
if (isLocked)
  CustomCard(
    backgroundColor: Color(0xFFFFEBEE),
    child: Column(
      children: [
        Icon(Icons.lock, color: Color(0xFFD32F2F)),
        Text('Tontine verrouillée'),
        Text('Cette tontine a déjà démarré...'),
        if (startDate != null) Text('Démarrée le: ...'),
      ],
    ),
  ),
```

2. **Carte Membres et Places** (si non verrouillé):
```dart
if (!isLocked)
  CustomCard(
    child: Column(
      children: [
        Text('👥 Membres et Places'),
        if (isFull) Text('COMPLET', style: red),
        Row(
          children: [
            Column(children: [Text('Membres actuels'), Text('$currentMembers/$maxMembers')]),
            Column(children: [Text('Places dispo'), Text('$availableSlots')]),
          ],
        ),
        LinearProgressIndicator(...),
      ],
    ),
  ),
```

3. **Messages d'avertissement:**
```dart
if (isFull)
  CustomCard(
    backgroundColor: Color(0xFFFFEBEE),
    child: Text('🚫 Ce groupe est complet...'),
  ),
if (isLocked)
  CustomCard(
    backgroundColor: Color(0xFFFFEBEE),
    child: Text('Cette tontine a déjà démarré...'),
  ),
```

**Raison**: Afficher statut et places de manière prominente et claire

---

## 📄 onetap_frontend/lib/screens/join_group_screen.dart

**Type**: Modification - Amélioration gestion d'erreur  
**Lignes affectées**: ~20  
**Changement**: Messages d'erreur personnalisés pour statut et places

**Avant:**
```dart
catch (error) {
  setState(() {
    _errorMessage = 'Erreur de connexion au serveur';
  });
}
```

**Après:**
```dart
catch (error) {
  final errorMsg = error.toString();
  if (errorMsg.contains('déjà démarré')) {
    setState(() {
      _errorMessage = 'Cette tontine a déjà démarré. Les inscriptions sont fermées.';
    });
  } else if (errorMsg.contains('atteint le nombre maximum')) {
    setState(() {
      _errorMessage = 'Ce groupe a atteint le nombre maximum de membres.';
    });
  } else {
    setState(() {
      _errorMessage = 'Erreur de connexion au serveur';
    });
  }
}
```

**Raison**: Feedback utilisateur spécifique au type d'erreur

---

## 📊 Résumé des Fichiers

| Fichier | Type | Lignes | Raison |
|---------|------|--------|--------|
| index.js | Backend | +50 | Migrations SQL |
| dashboardController.js | Backend | +40 | Comptage temps réel |
| membersController.js | Backend | +15 | Validation statut |
| yengaController.js | Backend | +20 | Auto-activation |
| groupsController.js | Backend | +60 | Nouvel endpoint |
| routes/groups.js | Backend | +2 | Enregistrement route |
| group_model.dart | Frontend | +40 | Nouveaux champs |
| api_service.dart | Frontend | +15 | Nouvelle méthode |
| mes_groups_screen.dart | Frontend | +120 | Redesign UI |
| group_detail_screen.dart | Frontend | +150 | Cartes verrouillage |
| join_group_screen.dart | Frontend | +20 | Messages d'erreur |

**Total:** 11 fichiers, ~532 lignes de code

---

## 🔄 Ordre de Modification Recommandé

1. **index.js** - DB doit être prête avant contrôleurs
2. **dashboardController.js** - APIs doivent retourner données
3. **membersController.js** - Validation avant insertion
4. **yengaController.js** - Auto-activation après paiement
5. **groupsController.js** - Nouvel endpoint optionnel
6. **routes/groups.js** - Enregistrer routes
7. **group_model.dart** - Modèle doit matcher API
8. **api_service.dart** - Services avant screens
9. **mes_groups_screen.dart** - Liste des groupes
10. **group_detail_screen.dart** - Détails groupe
11. **join_group_screen.dart** - Adhésion groupe

---

## ✅ Vérification Post-Modification

- [ ] Backend compile sans erreur
- [ ] Frontend compile sans erreur
- [ ] API retourne nouveaux champs
- [ ] UI affiche badges et barres
- [ ] Validation statut fonctionne
- [ ] Auto-activation se déclenche

