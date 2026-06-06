# 🧪 REQUÊTES API DE TEST - Curl Commands

## 📍 Configuration

```bash
# Variables à définir
export API_URL=\"http://localhost:3000\"
export TOKEN=\"YOUR_JWT_TOKEN_HERE\"
export USER_ID=1
export GROUP_ID=1
export PHONE=\"+22261234567\"
```

---

## 🌐 Tests d'API

### 1️⃣ Créer un Groupe

```bash
curl -X POST \"${API_URL}/api/groups/creer\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{
    \"nom\": \"Tontine Test\",
    \"montant\": 2000,
    \"frequence\": \"mensuel\",
    \"maxMembers\": 20
  }'

# Réponse attendue:
# {
#   \"id\": 1,
#   \"nom\": \"Tontine Test\",
#   \"status\": \"en_attente\",    ← NOUVEAU
#   \"startDate\": null,            ← NOUVEAU
#   \"codeInvitation\": \"ABC12345\",
#   \"createdAt\": \"2026-06-02T...\"
# }
```

---

### 2️⃣ Lister Mes Groupes (Nouveaux Champs)

```bash
curl -X GET \"${API_URL}/api/groups/mes-groupes/${USER_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\"

# Réponse attendue:
# [
#   {
#     \"id\": 1,
#     \"nom\": \"Tontine Test\",
#     \"montant\": 2000,
#     \"frequence\": \"mensuel\",
#     \"status\": \"en_attente\",         ← NOUVEAU
#     \"startDate\": null,               ← NOUVEAU
#     \"maxMembers\": 20,                ← NOUVEAU
#     \"currentMembers\": 1,             ← NOUVEAU (Comptage temps réel)
#     \"availableSlots\": 19,            ← NOUVEAU (Calcul auto)
#     \"prochainBeneficiaire\": {...}
#   }
# ]
```

**Points à vérifier:**
- ✅ `status` est présent
- ✅ `currentMembers` est un nombre
- ✅ `availableSlots` = maxMembers - currentMembers
- ✅ `startDate` est null si status='en_attente'

---

### 3️⃣ Détails du Groupe (Nouveaux Champs)

```bash
curl -X GET \"${API_URL}/api/groups/details/${GROUP_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\"

# Réponse attendue:
# {
#   \"id\": 1,
#   \"nom\": \"Tontine Test\",
#   \"montant\": 2000,
#   \"frequence\": \"mensuel\",
#   \"codeInvitation\": \"ABC12345\",
#   \"status\": \"en_attente\",           ← NOUVEAU
#   \"startDate\": null,                 ← NOUVEAU
#   \"maxMembers\": 20,                  ← NOUVEAU
#   \"currentMembers\": 1,               ← NOUVEAU
#   \"availableSlots\": 19,              ← NOUVEAU
#   \"isOwner\": true,
#   \"isLocked\": false,                 ← NOUVEAU (status === 'active')
#   \"createdAt\": \"2026-06-02T...\",
#   \"prochainBeneficiaire\": {...}
# }
```

**Points à vérifier:**
- ✅ `isLocked` = (status === 'active')
- ✅ Tous les champs présents

---

### 4️⃣ Rejoindre un Groupe (AVANT Activation)

```bash
curl -X POST \"${API_URL}/api/members/rejoindre\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{
    \"groupCode\": \"ABC12345\"
  }'

# Réponse attendue (200):
# {
#   \"message\": \"Adhésion enregistrée\"
# }
```

**Points à vérifier:**
- ✅ Status: 200 OK
- ✅ Message confirme adhésion

---

### 5️⃣ Rejoindre un Groupe (APRÈS Activation) ❌

```bash
# D'abord, activer le groupe avec le scénario ci-dessous
# Puis relancer ce test

curl -X POST \"${API_URL}/api/members/rejoindre\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{
    \"groupCode\": \"ABC12345\"
  }'

# Réponse attendue (403): ← NOUVEAU
# {
#   \"error\": \"Cette tontine a déjà démarré. Les inscriptions sont fermées.\"
# }
```

**Points à vérifier:**
- ✅ Status: 403 Forbidden
- ✅ Message correct et en français

---

### 6️⃣ Enregistrer une Cotisation (1ère = AUTO-ACTIVATION)

```bash
# DÉPEND du backend payment (YengaPay)
# Endpoint supposé: /api/yengapay/payer

curl -X POST \"${API_URL}/api/yengapay/payer\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{
    \"groupId\": 1,
    \"montant\": 2000,
    \"phone\": \"'${PHONE}'\"
  }'

# Réponse attendue (200):
# {
#   \"message\": \"Cotisation enregistrée\",
#   \"paymentId\": 1
# }

# ⚠️ IMPORTANT: À ce moment-ci, le backend auto-exécute:
# UPDATE groups SET status='active', start_date=NOW() WHERE id=1
```

**Points à vérifier après cette requête:**
1. Relancer \"Lister Mes Groupes\" (#2)
2. Vérifier que:
   - ✅ `status` est maintenant 'active'
   - ✅ `startDate` n'est plus null
   - ✅ Le badge dans MesGroupsScreen dit \"Active\"

---

### 7️⃣ Activation Manuelle (PUT - NOUVEAU ENDPOINT)

```bash
# Endpoint créé: PUT /api/groups/status/:groupId

curl -X PUT \"${API_URL}/api/groups/status/${GROUP_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{
    \"status\": \"active\"
  }'

# Réponse attendue (200):
# {
#   \"message\": \"Statut mis à jour\",
#   \"status\": \"active\",
#   \"startDate\": \"2026-06-02T15:00:00.000Z\"
# }
```

**Points à vérifier:**
- ✅ Status: 200 OK
- ✅ `status` changé
- ✅ `startDate` enregistrée si activation

---

### 8️⃣ Lister les Membres du Groupe

```bash
curl -X GET \"${API_URL}/api/groups/membres/${GROUP_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\"

# Réponse attendue:
# [
#   {
#     \"id\": 1,
#     \"nom\": \"Ali\",
#     \"telephone\": \"+22261234567\",
#     \"statut\": \"approuvé\",
#     \"joinedAt\": \"2026-06-02T14:00:00.000Z\"
#   },
#   {
#     \"id\": 2,
#     \"nom\": \"Boma\",
#     \"telephone\": \"+22261234568\",
#     \"statut\": \"en_attente\",
#     \"joinedAt\": \"2026-06-02T14:05:00.000Z\"
#   }
# ]
```

**Points à vérifier:**
- ✅ Comptage correct = currentMembers dans API
- ✅ Seuls les \"approuvé\" comptent pour currentMembers

---

## 🔄 Scénario Complet de Test

### Étape 1: Créer groupe
```bash
curl -X POST \"${API_URL}/api/groups/creer\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{ \"nom\": \"Test\", \"montant\": 2000, \"frequence\": \"mensuel\", \"maxMembers\": 5 }'
```
✅ Groupe créé avec status='en_attente'

### Étape 2: Vérifier groupes
```bash
curl -X GET \"${API_URL}/api/groups/mes-groupes/${USER_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\"
```
✅ Vérifier status='en_attente', currentMembers=1, availableSlots=4

### Étape 3: Ajouter 3 autres membres
```bash
# Faire rejoindre 3 autres users avec le code d'invitation
```
✅ currentMembers=4, availableSlots=1

### Étape 4: Approuver adhésions
```bash
# Propriétaire approuve les 3 adhésions
```
✅ currentMembers=4

### Étape 5: Enregistrer cotisation (AUTO-ACTIVATION)
```bash
curl -X POST \"${API_URL}/api/yengapay/payer\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{ \"groupId\": 1, \"montant\": 2000, \"phone\": \"+2226...\" }'
```
✅ status change à 'active', startDate enregistrée

### Étape 6: Vérifier verrouillage
```bash
curl -X GET \"${API_URL}/api/groups/mes-groupes/${USER_ID}\" \\
  -H \"Authorization: Bearer ${TOKEN}\"
```
✅ status='active', isLocked=true

### Étape 7: Essayer rejoindre
```bash
curl -X POST \"${API_URL}/api/members/rejoindre\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{ \"groupCode\": \"ABC12345\" }'
```
❌ Status 403: \"Cette tontine a déjà démarré...\"

---

## 📊 Comparaison: Avant vs Après

### Avant (GET /mes-groupes)
```json
{
  \"id\": 1,
  \"nom\": \"Tontine\",
  \"montant\": 2000,
  \"frequence\": \"mensuel\",
  \"isActive\": true
}
```

### Après (GET /mes-groupes) - NOUVEAU
```json
{
  \"id\": 1,
  \"nom\": \"Tontine\",
  \"montant\": 2000,
  \"frequence\": \"mensuel\",
  \"status\": \"active\",              ← NOUVEAU
  \"startDate\": \"2026-06-02T...\",   ← NOUVEAU
  \"maxMembers\": 20,                  ← NOUVEAU
  \"currentMembers\": 15,              ← NOUVEAU
  \"availableSlots\": 5,               ← NOUVEAU
  \"isActive\": true
}
```

---

## 🛠️ Outils Recommandés pour Tester

### Postman
1. Import `{{API_URL}}`
2. Set variable `TOKEN`
3. Exécuter les requêtes avec pre-request scripts

### Insomnia
```
1. Créer workspace
2. Ajouter variables d'environnement
3. Importer requêtes depuis curl
```

### cURL depuis Terminal
```bash
# Tester directement avec les commandes ci-dessus
# Ajouter | jq pour formater JSON
curl ... | jq '.'
```

### Postman Export (Format HAR)
```bash
# Pour exporter tous les tests
# Utile pour CI/CD
```

---

## ✅ Checklist de Vérification API

- [ ] Créer groupe: status='en_attente' ✓
- [ ] Lister groupes: currentMembers correct ✓
- [ ] Détails groupe: isLocked=false si en_attente ✓
- [ ] Rejoindre avant activation: OK (200) ✓
- [ ] 1ère cotisation: auto-active groupe ✓
- [ ] Rejoin après activation: Erreur 403 ✓
- [ ] PUT statut: Activation manuelle ✓
- [ ] Tous les champs présents dans réponses ✓

---

## 🚨 Erreurs Courantes

### 401 Unauthorized
```
→ Token manquant ou expiré
→ Solution: Vérifier Authorization header
```

### 403 Forbidden (avant activation)
```
→ Ne devrait pas arriver (groupe n'est pas actif)
→ Vérifier statut du groupe
```

### 400 Bad Request
```
→ Paramètres manquants ou invalides
→ Vérifier format JSON
```

### 500 Server Error
```
→ Erreur backend
→ Vérifier logs serveur
→ Vérifier DB connexion
```

---

## 🔐 Sécurité des Tests

⚠️ **Ne pas utiliser en production:**
- Tokens de test codés en dur
- CORS ouvert à tous
- Données sensibles dans logs

✅ **Bonnes pratiques:**
- Utiliser variables d'environnement
- Tokens générés frais avant test
- Nettoyer données test après
- Ne pas commiter secrets

---

## 📝 Template cURL Réutilisable

```bash
#!/bin/bash

API_URL=\"http://localhost:3000\"
TOKEN=\"$1\"  # À passer en argument
METHOD=\"$2\"
ENDPOINT=\"$3\"
DATA=\"$4\"

if [ -z \"$TOKEN\" ]; then
  echo \"Usage: $0 <TOKEN> <METHOD> <ENDPOINT> [DATA]\"
  exit 1
fi

curl -X \"${METHOD}\" \\
  \"${API_URL}${ENDPOINT}\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  ${DATA:+-d \"${DATA}\"} | jq '.'
```

**Utilisation:**
```bash
./api-call.sh \"MY_TOKEN\" GET \"/api/groups/mes-groupes/1\"
./api-call.sh \"MY_TOKEN\" POST \"/api/members/rejoindre\" '{\"groupCode\": \"ABC123\"}'
```

---

## 🎬 Script de Test Automatisé

```bash
#!/bin/bash

# Script de test automatisé
set -e  # Exit on error

TOKEN=\"$1\"
API=\"http://localhost:3000\"

echo \"🧪 Démarrage des tests...\"

# Test 1: Créer groupe
echo \"1️⃣ Créer groupe...\"
GROUP=$(curl -s -X POST \"${API}/api/groups/creer\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"nom\":\"Test\",\"montant\":2000,\"frequence\":\"mensuel\",\"maxMembers\":5}')
GROUP_ID=$(echo $GROUP | jq '.id')
echo \"✅ Groupe créé: ID=$GROUP_ID\"

# Test 2: Vérifier statut initial
echo \"2️⃣ Vérifier statut initial...\"
GROUPS=$(curl -s -X GET \"${API}/api/groups/mes-groupes/1\" \\
  -H \"Authorization: Bearer ${TOKEN}\")
STATUS=$(echo $GROUPS | jq '.[0].status')
echo \"✅ Statut: $STATUS\"

# Test 3: Rejoindre groupe
echo \"3️⃣ Rejoindre groupe...\"
JOIN=$(curl -s -X POST \"${API}/api/members/rejoindre\" \\
  -H \"Authorization: Bearer ${TOKEN}\" \\
  -H \"Content-Type: application/json\" \\
  -d '{\"groupCode\":\"ABC123\"}')
echo \"✅ Adhésion: $(echo $JOIN | jq '.message')\"

echo \"\"
echo \"🎉 Tous les tests passés!\"
```

**Exécution:**
```bash
chmod +x test-api.sh
./test-api.sh \"MY_TOKEN\"
```

