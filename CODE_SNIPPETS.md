# 📚 CODE SNIPPETS - Référence Technique Détaillée

## 1. BACKEND - Code Modifications

### 1.1 Database Schema (index.js)

**Avant:**
```sql
CREATE TABLE IF NOT EXISTS `groups` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `nom` VARCHAR(100),
  `montant` DECIMAL(10, 2),
  `frequence` VARCHAR(20)
  -- ...
)
```

**Après:**
```sql
CREATE TABLE IF NOT EXISTS `groups` (
  `id` INT PRIMARY KEY AUTO_INCREMENT,
  `nom` VARCHAR(100),
  `montant` DECIMAL(10, 2),
  `frequence` VARCHAR(20),
  `status` ENUM('en_attente','active','terminee') NOT NULL DEFAULT 'en_attente',
  `start_date` TIMESTAMP NULL DEFAULT NULL
  -- ...
)
```

**Migration (auto-appliquée):**
```sql
ALTER TABLE `groups` ADD COLUMN `status` ENUM('en_attente','active','terminee') DEFAULT 'en_attente';
ALTER TABLE `groups` ADD COLUMN `start_date` TIMESTAMP NULL DEFAULT NULL;
```

---

### 1.2 Dashboard Controller - getMesGroupes()

**Changement clé:**

```javascript
// Avant: Retournait uniquement infos de base

// Après: Ajoute les infos d'adhésions
const groupsWithMembers = await Promise.all(
  groupes.map(async (groupe) => {
    // Compter les membres approuvés
    const [memberCountRows] = await db.query(
      'SELECT COUNT(*) as count FROM group_members WHERE group_id = ? AND statut = ?',
      [groupe.id, 'approuvé']
    );
    const currentMembers = memberCountRows[0]?.count || 0;
    const maxMembers = groupe.max_membres || 10;
    const availableSlots = Math.max(0, maxMembers - currentMembers);

    return {
      ...groupe,
      status: groupe.status,
      startDate: groupe.start_date,
      maxMembers: maxMembers,
      currentMembers: currentMembers,
      availableSlots: availableSlots
    };
  })
);
```

---

### 1.3 Members Controller - rejoindre() avec Validation

**Avant:**
```javascript
async rejoindre(req, res) {
  try {
    // Insert directement...
    await db.query('INSERT INTO group_members (...)', [...]);
    res.json({ message: 'Adhésion réussie' });
  } catch (error) {
    res.status(500).json({ error: 'Erreur' });
  }
}
```

**Après (NOUVEAU):**
```javascript
async rejoindre(req, res) {
  try {
    const { groupCode } = req.body;
    const userId = req.user.id;

    // 1. Vérifier que le groupe existe
    const [groupResult] = await db.query(
      'SELECT * FROM groups WHERE code_invitation = ?',
      [groupCode]
    );
    
    if (!groupResult || groupResult.length === 0) {
      return res.status(404).json({ error: 'Groupe non trouvé' });
    }

    const groupe = groupResult[0];

    // 2. NOUVELLEMENT: Vérifier que le groupe n'est pas verrouillé
    if (groupe.status === 'active') {
      return res.status(403).json({ 
        error: 'Cette tontine a déjà démarré. Les inscriptions sont fermées.' 
      });
    }

    // 3. Vérifier que l'utilisateur n'est pas déjà membre
    const [existingMember] = await db.query(
      'SELECT * FROM group_members WHERE group_id = ? AND user_id = ?',
      [groupe.id, userId]
    );

    if (existingMember && existingMember.length > 0) {
      return res.status(409).json({ error: 'Vous êtes déjà membre' });
    }

    // 4. Insérer la demande d'adhésion
    await db.query(
      'INSERT INTO group_members (group_id, user_id, statut, joined_at) VALUES (?, ?, ?, NOW())',
      [groupe.id, userId, 'en_attente']
    );

    res.json({ message: 'Adhésion enregistrée' });
  } catch (error) {
    res.status(500).json({ error: 'Erreur serveur' });
  }
}
```

---

### 1.4 Yenga Controller - Auto-Activation

**Fragment modifié:**

```javascript
async payerCotisation(req, res) {
  try {
    const { groupId, montant } = req.body;
    const userId = req.user.id;

    // Insérer le paiement
    const [paymentResult] = await db.query(
      'INSERT INTO payments (group_id, user_id, montant, statut, created_at) VALUES (?, ?, ?, ?, NOW())',
      [groupId, userId, montant, 'VALIDEE']
    );

    // NOUVEAU: Vérifier si c'est la première cotisation réussie
    const [paymentsCount] = await db.query(
      'SELECT COUNT(*) as count FROM payments WHERE group_id = ? AND statut = ?',
      [groupId, 'VALIDEE']
    );

    if (paymentsCount[0].count === 1) {
      // C'est la première! Activer le groupe
      await db.query(
        'UPDATE groups SET status = ?, start_date = NOW() WHERE id = ?',
        ['active', groupId]
      );

      console.log(`[AUTO-ACTIVATION] Groupe ID: ${groupId} activé automatiquement`);
    }

    res.json({ message: 'Cotisation enregistrée', paymentId: paymentResult.insertId });
  } catch (error) {
    res.status(500).json({ error: 'Erreur' });
  }
}
```

---

### 1.5 Groups Controller - Nouvel Endpoint

**Code complet:**

```javascript
// groupsController.js

async updateGroupStatus(req, res) {
  try {
    const { groupId } = req.params;
    const { status } = req.body;
    const userId = req.user.id;

    // Valider le statut
    const validStatuses = ['en_attente', 'active', 'terminee'];
    if (!validStatuses.includes(status)) {
      return res.status(400).json({ 
        error: 'Statut invalide. Doit être en_attente, active ou terminee' 
      });
    }

    // Vérifier que le groupe existe
    const [groupResult] = await db.query(
      'SELECT * FROM groups WHERE id = ?',
      [groupId]
    );

    if (!groupResult || groupResult.length === 0) {
      return res.status(404).json({ error: 'Groupe non trouvé' });
    }

    const groupe = groupResult[0];

    // Vérifier que l'utilisateur est propriétaire
    if (groupe.owner_id !== userId) {
      return res.status(403).json({ 
        error: 'Seul le propriétaire peut mettre à jour le statut' 
      });
    }

    // Mettre à jour
    if (status === 'active' && groupe.status !== 'active') {
      // Si on passe de non-actif à actif, enregistrer la date
      await db.query(
        'UPDATE groups SET status = ?, start_date = NOW() WHERE id = ?',
        [status, groupId]
      );
    } else {
      // Sinon, juste mettre à jour le statut
      await db.query(
        'UPDATE groups SET status = ? WHERE id = ?',
        [status, groupId]
      );
    }

    res.json({ 
      message: 'Statut mis à jour',
      status: status,
      startDate: status === 'active' ? new Date() : null
    });
  } catch (error) {
    console.error('Erreur updateGroupStatus:', error);
    res.status(500).json({ error: 'Erreur serveur' });
  }
}

module.exports = { updateGroupStatus };
```

---

## 2. FRONTEND - Code Modifications

### 2.1 Group Model - Propriétés Calculées

**Dart:**

```dart
class GroupModel {
  // ... autres propriétés ...
  
  final String status;           // 'en_attente', 'active', 'terminee'
  final DateTime? startDate;
  final int maxMembers;
  final int currentMembers;
  final int availableSlots;

  // Propriétés calculées
  bool get isLocked => status == 'active';
  bool get isFull => availableSlots <= 0;
  bool get canJoin => !isLocked && !isFull;

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      // ...
      status: json['status'] ?? 'en_attente',
      startDate: json['startDate'] != null 
        ? DateTime.parse(json['startDate']) 
        : null,
      maxMembers: json['maxMembers'] ?? 10,
      currentMembers: json['currentMembers'] ?? 0,
      availableSlots: json['availableSlots'] ?? 10,
    );
  }
}
```

---

### 2.2 API Service - Nouvelle Méthode

```dart
// api_service.dart

static Future<Map<String, dynamic>> updateGroupStatus({
  required int groupId,
  required String status,
}) async {
  try {
    final String url = '${ApiService.baseUrl}/api/groups/status/$groupId';
    final response = await http.put(
      Uri.parse(url),
      headers: await authHeaders(),
      body: jsonEncode({
        'status': status,
      }),
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

---

### 2.3 MesGroupsScreen - Card Redesign

**Widget principal:**

```dart
InkWell(
  onTap: () {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => GroupDetailScreen(
          groupId: groupe.id,
          groupName: groupe.nom,
          montant: groupe.montant,
          frequence: groupe.frequence,
        ),
      ),
    );
  },
  child: CustomCard(
    backgroundColor: AppColors.white,
    borderRadius: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // En-tête avec titre et badges
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          groupe.nom,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      // Badge Verrouillée
                      if (groupe.isLocked)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.lock, size: 14, color: Color(0xFFD32F2F)),
                              SizedBox(width: 4),
                              Text(
                                'Verrouillée',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFD32F2F),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Badge Complet
                      if (groupe.isFull)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          margin: const EdgeInsets.only(left: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'COMPLET',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${groupe.montant.toStringAsFixed(0)} FCFA · ${groupe.frequence}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  
                  // Section Membres et Places
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '👥 ${groupe.currentMembers}/${groupe.maxMembers} membres',
                            style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '✅ ${groupe.availableSlots} places',
                            style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w600,
                              ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Barre de progression
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: groupe.maxMembers > 0
                            ? groupe.currentMembers / groupe.maxMembers
                            : 0,
                          backgroundColor: const Color(0xFFE0E0E0),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            groupe.isFull
                              ? const Color(0xFFD32F2F)
                              : AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Badge statut
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: groupe.status == 'active'
                  ? AppColors.accentOrange
                  : AppColors.primaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                groupe.status == 'active' ? 'Active' : 'En attente',
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  ),
),
```

---

### 2.4 GroupDetailScreen - Cartes Verrouillage & Places

**Carte Verrouillage (si actif):**

```dart
if (isLocked)
  CustomCard(
    backgroundColor: const Color(0xFFFFEBEE),
    child: Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFFFFCDD2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock, color: Color(0xFFD32F2F)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tontine verrouillée',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFD32F2F),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cette tontine a déjà démarré. Les inscriptions sont fermées.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (startDate != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Démarrée le: ${DateTime.tryParse(startDate)?.toString().split(' ')[0] ?? startDate}',
                  style: Theme.of(context).textTheme.bodySmall
                    ?.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  ),
```

**Carte Membres et Places (si non verrouillé):**

```dart
if (!isLocked)
  CustomCard(
    backgroundColor: AppColors.white,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '👥 Membres et Places',
              style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (isFull)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'COMPLET',
                  style: TextStyle(
                    fontSize: 11,
                    color: Color(0xFFD32F2F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Membres actuels', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '$currentMembers / $maxMembers',
                  style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Places disponibles', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  '$availableSlots',
                  style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(
                      color: isFull ? const Color(0xFFD32F2F) : AppColors.accentOrange,
                      fontWeight: FontWeight.w700,
                    ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            minHeight: 8,
            value: maxMembers > 0 ? currentMembers / maxMembers : 0,
            backgroundColor: const Color(0xFFE0E0E0),
            valueColor: AlwaysStoppedAnimation<Color>(
              isFull ? const Color(0xFFD32F2F) : AppColors.primaryGreen,
            ),
          ),
        ),
      ],
    ),
  ),
```

---

### 2.5 JoinGroupScreen - Gestion d'Erreur Améliorée

```dart
Future<void> _rejoindreGroupe() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
    _errorMessage = null;
    _successMessage = null;
  });

  try {
    final response = await ApiService.rejoindreGroupe(
      codeInvitation: _codeController.text.trim().toUpperCase(),
    );

    if (response['message'] != null) {
      setState(() {
        _successMessage = response['message'];
      });

      _formKey.currentState!.reset();
      _codeController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Groupe rejoint avec succès!'),
            backgroundColor: AppColors.primaryGreen,
            duration: Duration(seconds: 2),
          ),
        );
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } else {
      setState(() {
        _errorMessage = response['error'] ?? 'Erreur lors de la jonction';
      });
    }
  } catch (error) {
    final errorMsg = error.toString();
    
    // Messages d'erreur personnalisés
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
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

---

## 3. Requêtes API - Exemples Curl

### Créer un groupe
```bash
curl -X POST http://localhost:3000/api/groups/creer \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "nom": "Tontine Quartier",
    "montant": 2000,
    "frequence": "mensuel",
    "maxMembers": 20
  }'
```

### Lister mes groupes
```bash
curl http://localhost:3000/api/groups/mes-groupes/USER_ID \
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Rejoindre un groupe
```bash
curl -X POST http://localhost:3000/api/members/rejoindre \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "groupCode": "ABC123"
  }'
```

### Activer un groupe (propriétaire uniquement)
```bash
curl -X PUT http://localhost:3000/api/groups/status/GROUP_ID \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "status": "active"
  }'
```

### Enregistrer une cotisation (auto-active si première)
```bash
curl -X POST http://localhost:3000/api/yengapay/payer \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "groupId": 1,
    "montant": 2000,
    "phone": "+22XXXXXXXXX"
  }'
```

