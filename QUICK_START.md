# ⚡ QUICK START - Démarrage Rapide

## 🏃 5 minutes pour mettre en production

### Étape 1: Déployer le Backend
```bash
cd onetap_backend
npm install          # Si première fois
node index.js        # Démarre le serveur
# Les migrations SQL se feront automatiquement
```

**Vérification:**
```
Console doit afficher:
✅ Database connected
✅ Server running on port 3000
✅ SQL migrations applied
```

---

### Étape 2: Déployer le Frontend
```bash
cd onetap_frontend
flutter pub get
flutter run                    # Pour développement
# OU
flutter build apk --release   # Pour production
```

---

### Étape 3: Test Rapide (2 min)

1. **Créer une tontine**
   - Ouvrir app → Dashboard
   - "Créer Nouveau Groupe"
   - Nom: "Test Tontine"
   - Montant: 2000 FCFA
   - Fréquence: Mensuel
   - Max Members: 5
   - ✅ Créer

2. **Vérifier le statut initial**
   - MesGroupsScreen: Badge dit "En attente" ✅
   - GroupDetailScreen: Affiche "👥 1/5 membres" ✅

3. **Ajouter des membres**
   - Obtenir le code d'invitation
   - Ajouter 4 amis
   - Approuver chaque adhésion
   - Vérifier: "👥 5/5 membres" ✅

4. **Première cotisation (DÉCLENCHEUR)**
   - Propriétaire: "Payer ma cotisation"
   - YengaPay: Complète paiement
   - ✅ Paiement approuvé
   - **⏰ AUTOMATIQUE: Groupe devient "Active"** ✅

5. **Vérifier verrouillage**
   - MesGroupsScreen: Badge "🔒 Verrouillée" ✅
   - GroupDetailScreen: Affiche "Tontine verrouillée" ✅
   - Essayer rejoindre: ❌ "Tontine a déjà démarré" ✅

---

## 🔥 Fichiers Clés Modifiés

### Backend
```
onetap_backend/
├── index.js (Migrations SQL)
├── controllers/
│   ├── dashboardController.js (Comptage)
│   ├── membersController.js (Validation)
│   ├── yengaController.js (Auto-activation)
│   └── groupsController.js (Nouvel endpoint)
└── routes/groups.js (Route +PUT)
```

### Frontend
```
onetap_frontend/lib/
├── models/group_model.dart (Nouveaux champs)
├── services/api_service.dart (Nouvelle méthode)
└── screens/
    ├── mes_groups_screen.dart (Redesign)
    ├── group_detail_screen.dart (Cartes verrouillage)
    └── join_group_screen.dart (Messages)
```

---

## 🆘 Si Ça Ne Marche Pas

### Problème: Groupe ne se verrouille pas après cotisation
**Solution:**
```javascript
// Dans yengaController.js, vérifier que cette ligne existe:
UPDATE groups SET status = 'active', start_date = NOW() WHERE id = ?
```

### Problème: Badge "Verrouillée" ne s'affiche pas
**Solution:**
```dart
// Dans group_model.dart, vérifier:
bool get isLocked => status == 'active';  // ← Doit être là
```

### Problème: "currentMembers" indéfini dans API
**Solution:**
```bash
# Dans dashboardController, vérifier requête:
SELECT COUNT(*) as count FROM group_members 
WHERE group_id = ? AND statut = 'approuvé'
```

### Problème: Flutter erreur compilation
**Solution:**
```bash
cd onetap_frontend
flutter clean
flutter pub get
flutter run
```

---

## 📊 Vérification Rapide Post-Déploiement

### API Health Check
```bash
# Vérifier les colonnes BD existentes:
curl -X GET http://localhost:3000/api/groups/mes-groupes/1 \
  -H "Authorization: Bearer YOUR_TOKEN"

# Réponse doit inclure:
# "status": "en_attente" ✅
# "startDate": null ✅
# "currentMembers": X ✅
# "availableSlots": Y ✅
```

### Frontend Check
```dart
// Dans Dart, vérifier que tout compile:
flutter analyze

// Doit retourner:
// ✅ No issues found
```

---

## 📚 Documentation Complète

Si besoin de détails:

1. **Fonctionnalités** → Lire: `IMPLEMENTATION_GUIDE.md`
2. **Tests** → Lire: `CHECKLIST_IMPLEMENTATION.md`
3. **Code** → Lire: `CODE_SNIPPETS.md`
4. **Architecture** → Lire: `ARCHITECTURE.md`
5. **Résumé** → Lire: `DELIVERABLE_SUMMARY.md`

---

## ✅ Checklist Pré-Production

- [ ] Backend démarre sans erreurs
- [ ] Frontend compile sans warnings
- [ ] Créer groupe: fonctionnel ✅
- [ ] Adhésion avant activation: fonctionne ✅
- [ ] Première cotisation: groupe se verrouille ✅
- [ ] Adhésion après activation: bloquée ✅
- [ ] MesGroupsScreen: badges affichés ✅
- [ ] GroupDetailScreen: cartes affichées ✅
- [ ] Barre progression: mise à jour temps réel ✅

---

## 🎉 Fait!

Si tous les points ✅ sont verts = **PRÊT POUR PRODUCTION**

---

## 🎯 Points à Retenir

1. **Auto-activation** se déclenche à **première cotisation validée**
2. **Blocage adhésion** se fait **au niveau serveur** (sécurisé)
3. **Comptage membres** est **temps réel** à chaque requête
4. **Pas de données** à migrer (nouvelles colonnes par défaut)
5. **Backward compatible** (anciennes tontines restent en_attente)

---

## 🆘 Emergency Contacts

Erreurs non listées? Chercher dans:
1. Logs serveur: `npm start` output
2. Logs Flutter: `flutter run` output
3. Network tab: Browser DevTools (API calls)
4. Database: Vérifier colonnes `status` et `start_date` existent

---

**Besoin d'aide?** Consulter le fichier correspondant ci-haut.

Bon déploiement! 🚀

