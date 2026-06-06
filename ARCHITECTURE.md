# 🏗️ ARCHITECTURE ET FLUX DE DONNÉES

## 1. Flux d'Adhésion à une Tontine

### Avant implémentation
```
Utilisateur saisit code
           ↓
API /members/rejoindre
           ↓
INSERT into group_members
           ↓
✅ Adhésion approuvée (pas de vérification de statut)
```

### Après implémentation
```
Utilisateur saisit code
           ↓
API /members/rejoindre
           ↓
[NOUVEAU] Vérifier groupe.status != 'active'
           ↓
        OUI         NON
         ↓           ↓
  Continuer      ❌ 403 "Tontine démarrée"
         ↓
INSERT into group_members
         ↓
[NOUVEAU] Vérifier si maxMembers atteint
         ↓
✅ Adhésion approuvée
         ↓
Frontend affiche toast succès
```

---

## 2. Flux de Paiement et Auto-Activation

### Nouveau flux d'activation automatique

```
Utilisateur clique "Payer"
           ↓
Écran de paiement (YengaPay)
           ↓
Paiement approuvé
           ↓
API /yengapay/payer
           ↓
INSERT into payments (statut='VALIDEE')
           ↓
[NOUVEAU] Compter paiements réussis du groupe
           ↓
    Est-ce le 1er?
       ↓        ↓
      OUI       NON
       ↓         ↓
[NOUVEAU]   Continuer
UPDATE groups
SET status='active'
    start_date=NOW()
       ↓
Groupe verrouillé!
       ↓
✅ Cotisation enregistrée
       ↓
Frontend actualise groupes
```

---

## 3. Hiérarchie du Statut d'une Tontine

```
┌────────────────────────────────────────────────────────────┐
│                   TONTINE (Groupe)                         │
│                                                            │
│  État initial: status = 'en_attente' (au création)        │
│                                                            │
│  ┌─────────────────────────────────────────────────┐      │
│  │ PHASE 1: EN_ATTENTE (Pré-lancement)             │      │
│  │ ✅ Adhésions possibles                          │      │
│  │ ✅ Paiements possibles                          │      │
│  │ ❌ Paiement ne déclenche rien                   │      │
│  │ Peut être activé: manuellement OU              │      │
│  │                    à première cotisation       │      │
│  └─────────────────────────────────────────────────┘      │
│                        ↓                                   │
│           [Activation manuelle OU                         │
│            1ère cotisation validée]                       │
│                        ↓                                   │
│  ┌─────────────────────────────────────────────────┐      │
│  │ PHASE 2: ACTIVE (En cours de tontine)           │      │
│  │ ❌ Adhésions BLOQUÉES                           │      │
│  │ ✅ Paiements possibles                          │      │
│  │ ✅ Attributions de bénéficiaires possible       │      │
│  │ Accessible depuis: Dashboard, DetailScreen     │      │
│  │ Signal visuel: 🔒 Badge "Verrouillée"          │      │
│  └─────────────────────────────────────────────────┘      │
│                        ↓                                   │
│          [Après dernier paiement cycleOK]                 │
│                        ↓                                   │
│  ┌─────────────────────────────────────────────────┐      │
│  │ PHASE 3: TERMINEE (Cycle complet)               │      │
│  │ ❌ Adhésions BLOQUÉES                           │      │
│  │ ❌ Paiements bloqués                            │      │
│  │ ✅ Consultation historique possible             │      │
│  │ Statut: 'terminee' (pour archives)              │      │
│  └─────────────────────────────────────────────────┘      │
│                                                            │
└────────────────────────────────────────────────────────────┘
```

---

## 4. États des Membres dans une Tontine

```
┌────────────────────────────────────────────────────┐
│        ÉTATS DE STATUT D'UN MEMBRE                │
│                                                   │
│  statut = 'en_attente' (par défaut)              │
│     ↓                                             │
│     └─→ [Propriétaire accepte] ───→ 'approuvé'  │
│           [Propriétaire refuse] ───→ 'rejeté'   │
│                                                   │
│  Une fois 'approuvé':                             │
│     ✅ Compte comme membre actif                 │
│     ✅ Doit payer les cotisations                │
│     ✅ Peut recevoir les distributions           │
│                                                   │
│  Une fois 'rejeté':                              │
│     ❌ Ne compte pas dans currentMembers         │
│     ❌ Peut demander une nouvelle adhésion       │
│                                                   │
└────────────────────────────────────────────────────┘

SELECT COUNT(*) as count
FROM group_members
WHERE group_id = ? AND statut = 'approuvé'
```

---

## 5. Données Temps Réel - Synchronisation

### Fréquence d'actualisation

```
MesGroupsScreen
    ↓
[Pull-to-refresh] ou [Page load]
    ↓
API GET /api/groups/mes-groupes/:userId
    ↓
Pour chaque groupe:
  - SELECT COUNT(*) from group_members WHERE statut='approuvé'
  - Calculer currentMembers
  - Calculer availableSlots = maxMembers - currentMembers
    ↓
Retourner liste groupes avec chiffres mis à jour
    ↓
Frontend Parse JSON
    ↓
Widget rebuild avec:
  - currentMembers (en temps réel)
  - availableSlots (en temps réel)
  - Barre de progression (recalculée)
```

### Exemple de réponse API actualisée

```json
{
  "id": 1,
  "nom": "Tontine Quartier",
  "status": "en_attente",
  "currentMembers": 12,    // ← Calculé en temps réel
  "maxMembers": 20,
  "availableSlots": 8,     // ← Calculé en temps réel
  "startDate": null,
  "progressValue": 0.6     // ← 12/20 = 60%
}
```

---

## 6. Tableau de Comptabilité - Avant/Après

| Feature | Avant | Après |
|---------|-------|-------|
| **Adhésion après paiement** | ✅ Possible | ❌ Bloquée (status=active) |
| **Comptage des places** | ❌ Manuel | ✅ Automatique temps réel |
| **Affichage "X/Y membres"** | ❌ Non disponible | ✅ Sur tous les écrans |
| **Activation de tontine** | ❌ Nécessaire manuel | ✅ Auto à 1ère cotisation |
| **Date de démarrage** | ❌ Pas enregistrée | ✅ Enregistrée à activation |
| **Barre de progression** | ❌ Non disponible | ✅ LinearProgressIndicator |
| **Badge "Verrouillée"** | ❌ Non disponible | ✅ Visuel clair 🔒 |
| **Message "groupe plein"** | ❌ Pas de feedback | ✅ Message d'erreur clair |
| **Validation backend** | ⚠️ Partielle | ✅ Complète et stricte |

---

## 7. Dépendances entre Modules

```
┌──────────────────────────────────────────────────┐
│              Frontend (Flutter)                  │
├──────────────────────────────────────────────────┤
│  MesGroupsScreen                                 │
│    └─→ ApiService.getMesGroupes()               │
│    └─→ GroupModel (avec isLocked, isFull)       │
│    └─→ CustomCard (avec badges et progress)     │
│                                                  │
│  GroupDetailScreen                               │
│    └─→ ApiService.getGroupDetails()             │
│    └─→ ApiService.updateGroupStatus() [NOUVEAU] │
│    └─→ CarteVerrouillage [NOUVEAU]             │
│    └─→ CarteMembresEtPlaces [NOUVEAU]          │
│                                                  │
│  JoinGroupScreen                                │
│    └─→ ApiService.rejoindreGroupe()            │
│    └─→ Gestion d'erreur améliorée [NOUVEAU]    │
│                                                  │
└──────────────────────────────────────────────────┘
            ↓ HTTP / REST API ↓
┌──────────────────────────────────────────────────┐
│              Backend (Node.js)                   │
├──────────────────────────────────────────────────┤
│  Routes                                          │
│  /api/groups/mes-groupes/:userId               │
│  /api/groups/details/:groupId                  │
│  /api/groups/status/:groupId [PUT] [NOUVEAU]   │
│  /api/members/rejoindre [POST]                 │
│  /api/yengapay/payer [POST]                    │
│                                                  │
│  Controllers                                    │
│  dashboardController                            │
│    └─→ getMesGroupes() [MODIFIÉ]               │
│    └─→ getGroupDetails() [MODIFIÉ]             │
│                                                  │
│  membersController                             │
│    └─→ rejoindre() [VALIDATION STATUT AJOUTÉE] │
│                                                  │
│  yengaController                               │
│    └─→ payerCotisation() [AUTO-ACTIVATION]    │
│                                                  │
│  groupsController                              │
│    └─→ updateGroupStatus() [NOUVEAU]           │
│                                                  │
└──────────────────────────────────────────────────┘
            ↓ Requêtes SQL ↓
┌──────────────────────────────────────────────────┐
│              Base de Données (MySQL)             │
├──────────────────────────────────────────────────┤
│  groups                                          │
│  ├─ id                                           │
│  ├─ nom                                          │
│  ├─ montant                                      │
│  ├─ max_membres                                 │
│  ├─ status [NOUVEAU]                            │
│  └─ start_date [NOUVEAU]                        │
│                                                  │
│  group_members                                  │
│  ├─ id                                           │
│  ├─ group_id                                    │
│  ├─ user_id                                     │
│  ├─ statut (en_attente, approuvé, rejeté)     │
│  └─ joined_at                                   │
│                                                  │
│  payments                                       │
│  ├─ id                                           │
│  ├─ group_id                                    │
│  ├─ user_id                                     │
│  ├─ montant                                     │
│  ├─ statut (VALIDEE, ECHOUEE)                  │
│  └─ created_at                                  │
│                                                  │
└──────────────────────────────────────────────────┘
```

---

## 8. Scénario de Test Complet - Parcours Utilisateur

### Jour 1: Création et adhésions
```
14:00 - Ali crée "Tontine Quartier" (20 places)
        → groups.status = 'en_attente'
        → groups.start_date = NULL
        
14:05 - Ali s'ajoute en tant que propriétaire
        → group_members.statut = 'approuvé'
        → currentMembers = 1
        → availableSlots = 19
        
14:10 - Boma rejoint (code ABC123)
        → Vérification: status != 'active' ✅
        → INSERT group_members (statut='en_attente')
        → currentMembers = 1 (en attente d'approbation)
        
14:15 - Ali approuve Boma
        → group_members.statut = 'approuvé'
        → currentMembers = 2
        → availableSlots = 18

14:20 - 10 autres personnes rejoignent et sont approuvées
        → currentMembers = 12
        → availableSlots = 8
        
MesGroupsScreen affiche:
┌─────────────────────────┐
│ Tontine Quartier        │
│ 👥 12/20 membres        │
│ ✅ 8 places             │
│ ████████░░░░░░░░░░ 60% │
│ Status: En attente      │
└─────────────────────────┘
```

### Jour 2: Première cotisation (ACTIVATION)
```
09:00 - Ali effectue sa première cotisation (2000 FCFA)
        → API POST /api/yengapay/payer
        → INSERT payments (statut='VALIDEE')
        
        [NOUVEAU] Vérification:
        → SELECT COUNT(*) payments WHERE statut='VALIDEE'
        → Résultat: 1 (c'est la première!)
        → UPDATE groups SET status='active', start_date=NOW()
        
        → groups.status = 'active'
        → groups.start_date = '2026-06-02 09:00:00'

09:05 - Charlie essaie de rejoindre le groupe
        → API POST /api/members/rejoindre
        
        [VALIDATION] Vérification:
        → SELECT * FROM groups WHERE id = 1
        → status == 'active' ✓
        → RETOUR 403 "Cette tontine a déjà démarré..."
        
        Frontend affiche:
        ❌ "Cette tontine a déjà démarré. Les inscriptions sont fermées."

10:00 - MesGroupsScreen (Ali) se rafraîchit:
        → API GET /api/groups/mes-groupes/ali_id
        → currentMembers = 12
        → status = 'active'
        
        Affichage:
        ┌──────────────────────────────┐
        │ Tontine Quartier   🔒         │
        │ 👥 12/20 membres             │
        │ ✅ 8 places                  │
        │ ████████░░░░░░░░░░ 60%      │
        │ Status: Active (Orange)      │
        └──────────────────────────────┘

11:00 - Ali ouvre GroupDetailScreen:
        ┌────────────────────────────────────┐
        │ 🔒 Tontine verrouillée             │
        │ Cette tontine a déjà démarré.      │
        │ Les inscriptions sont fermées.     │
        │ Démarrée le: 2026-06-02           │
        └────────────────────────────────────┘
        
        ┌────────────────────────────────────┐
        │ [✅ Payer ma cotisation] (actif)   │
        │ [🔘 Voir les Membres]              │
        └────────────────────────────────────┘
```

---

## 9. Optimisations Proposées (Futures)

### Court terme (Semaines)
```
1. Cache des groupes côté client avec invalidation
   → Réduire nombre de requêtes GET
   
2. Real-time updates avec WebSocket
   → Updates instantanés quand nouveau membre approuvé
   
3. Notifications quand groupe devient plein
   → Alert avant que groupe soit 100% rempli
```

### Moyen terme (Mois)
```
1. Archivage automatique des groupes "terminee"
   → Ne pas charger en mémoire
   
2. Rapports d'adhésion par période
   → Analytics
   
3. Transfert de propriété de groupe
   → Si propriétaire se retire
```

### Long terme (Trimestres)
```
1. "Listes d'attente" pour groupes pleins
   → Rejoindre groupe plein avec notification
   
2. "Tontines récurrentes"
   → Relancer automatiquement après "terminee"
   
3. "Quotas par région"
   → Limiter taille groupes par zone géographique
```

---

## 10. Résumé des Bénéfices

### Pour l'utilisateur
✅ Expérience fluide sans adhésions après démarrage  
✅ Transparence complète du statut du groupe  
✅ Messages clairs et en temps réel  
✅ Interface visuelle cohérente avec badges et barres  
✅ Moins de confusion sur les états du groupe  

### Pour l'administrateur
✅ Contrôle strictement enforced au niveau backend  
✅ Impossibilité de contourner les règles  
✅ Logs automatiques d'activation  
✅ Flexibility d'activation manuelle si nécessaire  
✅ Data intégrité garantie  

### Pour la tontine elle-même
✅ Stabilité du groupe une fois démarré  
✅ Clarté du cycle (en_attente → active → terminee)  
✅ Traçabilité complète des états  
✅ Prévention des "surprise" adhésions en cours de tontine  

