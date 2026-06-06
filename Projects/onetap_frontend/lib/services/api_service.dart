import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const _tokenKey = 'auth_token';
const _userIdKey = 'user_id';
const _userNameKey = 'user_name';

class ApiService {
  static const String baseUrl = 'http://localhost:3000/api';

  static dynamic _parseResponse(http.Response response) {
    dynamic body;
    try {
      body = response.body.isNotEmpty ? jsonDecode(response.body) : null;
    } catch (_) {
      throw Exception('Réponse serveur invalide (${response.statusCode})');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = body is Map ? body['message']?.toString() : null;
    throw Exception(message ?? 'Erreur API ${response.statusCode}');
  }

  // Inscription
  static Future<Map<String, dynamic>> inscription({
    required String nom,
    required String prenom,
    required String telephone,
    required int age,
    required String ville,
    required String quartier,
    required String numeroCnib,
    required String pin,
    required String numeroUrgence,
    required String nomUrgence,
    required String photoProfil,
    required bool contratAccepte,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/inscription'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'age': age,
        'ville': ville,
        'quartier': quartier,
        'numero_cnib': numeroCnib,
        'pin': pin,
        'numero_urgence': numeroUrgence,
        'nom_urgence': nomUrgence,
        'photo_profil': photoProfil,
        'contrat_accepte': contratAccepte,
      }),
    );

    final body = jsonDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (body['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, body['token']);
        if (body['user'] != null) {
          final user = body['user'];
          if (user['id'] != null) {
            await prefs.setInt(
              _userIdKey,
              user['id'] is int
                  ? user['id'] as int
                  : (user['id'] as num).toInt(),
            );
          }
          if (user['nom'] != null)
            await prefs.setString(_userNameKey, user['nom']);
        }
      }
      return body as Map<String, dynamic>;
    }

    throw Exception(body['message'] ?? 'Erreur API ${response.statusCode}');
  }

  // Connexion
  static Future<Map<String, dynamic>> connexion({
    required String telephone,
    required String pin,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/connexion'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'telephone': telephone, 'pin': pin}),
    );
    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['token'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, body['token']);
      if (body['user'] != null) {
        final user = body['user'];
        if (user['id'] != null) {
          await prefs.setInt(
            _userIdKey,
            user['id'] is int ? user['id'] as int : (user['id'] as num).toInt(),
          );
        }
        if (user['nom'] != null)
          await prefs.setString(_userNameKey, user['nom']);
      }
    }
    return body;
  }

  static Future<String?> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey);
  }

  // Récupérer l'identifiant de l'utilisateur connecté
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  // Récupérer le token stocké
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  // En-têtes avec authentification
  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<List<dynamic>> getMesGroupes(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/mes-groupes/$userId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getTotalCotisations(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payments/total/$userId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getProchainBeneficiaire(
    int groupId,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/beneficiaries/prochain/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getGroupDetails(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/details/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getGroupStatus(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/statut/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> demarrerGroupe(int groupId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/groups/demarrer/$groupId'),
      headers: await authHeaders(),
      body: jsonEncode({}),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getPublicGroups() async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/publics'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> getGroupMembers(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/groups/membres/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  static Future<List<dynamic>> getGroupPayments(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payments/groupe/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
  }

  static Future<Map<String, dynamic>> getUserProfile(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/profil/$userId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> getUserReputation(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/reputation/$userId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateUserProfile({
    required int userId,
    required String nom,
    String? prenom,
    required String telephone,
    String? ville,
    String? quartier,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/modifier/$userId'),
      headers: await authHeaders(),
      body: jsonEncode({
        'nom': nom,
        'prenom': prenom,
        'telephone': telephone,
        'ville': ville,
        'quartier': quartier,
      }),
    );
    final body = _parseResponse(response);
    if (body is Map<String, dynamic> && body['user'] != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _userNameKey,
        body['user']['nom'] as String? ?? nom,
      );
    }
    return body as Map<String, dynamic>;
  }

  // Initier le paiement YengaPay
  static Future<Map<String, dynamic>> initierPaiement({
    required double montant,
    required String reference,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/yengapay/initier'),
      headers: await authHeaders(),
      body: jsonEncode({'montant': montant, 'reference': reference}),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Payer la cotisation via YengaPay
  static Future<Map<String, dynamic>> payerCotisation({
    required String paymentIntentId,
    required String operatorCode,
    required String telephone,
    required int groupId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/yengapay/payer'),
      headers: await authHeaders(),
      body: jsonEncode({
        'paymentIntentId': paymentIntentId,
        'operatorCode': operatorCode,
        'countryCode': 'BF',
        'customerMSISDN': telephone,
        'groupId': groupId,
      }),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Vérifier le statut du paiement
  static Future<Map<String, dynamic>> verifierStatut({
    required String paymentIntentId,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/yengapay/statut/$paymentIntentId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Créer un nouveau groupe
  static Future<Map<String, dynamic>> creerGroupe({
    required String nom,
    required double montant,
    required String frequence,
    required int maxMembres,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/groups/creer'),
      headers: await authHeaders(),
      body: jsonEncode({
        'nom': nom,
        'montant': montant,
        'frequence': frequence,
        'max_membres': maxMembres,
      }),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Rejoindre un groupe avec un code d'invitation
  static Future<Map<String, dynamic>> rejoindreGroupe({
    required String codeInvitation,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/members/rejoindre'),
      headers: await authHeaders(),
      body: jsonEncode({'codeInvitation': codeInvitation}),
    );
    return jsonDecode(response.body);
  }

  // Récupérer les membres en attente d'approbation
  static Future<List<dynamic>> getMembresEnAttente(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/members/en-attente/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  // Approuver un membre
  static Future<Map<String, dynamic>> approuverMembre(int memberId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/members/approuver/$memberId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Rejeter un membre
  static Future<Map<String, dynamic>> rejeterMembre(int memberId) async {
    final response = await http.put(
      Uri.parse('$baseUrl/members/rejeter/$memberId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Récupérer les bénéficiaires d'un groupe
  static Future<List<dynamic>> getBeneficiairesGroupe(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/beneficiaries/groupe/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as List<dynamic>;
  }

  // Mettre à jour le statut d'un groupe
  static Future<Map<String, dynamic>> updateGroupStatus({
    required int groupId,
    required String status,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/groups/status/$groupId'),
      headers: await authHeaders(),
      body: jsonEncode({'status': status}),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Récupérer les commissions d'un créateur
  static Future<Map<String, dynamic>> getCommissionsCreateur(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/commissions/createur/$userId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Récupérer les commissions d'un groupe
  static Future<Map<String, dynamic>> getCommissionsGroupe(int groupId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/commissions/groupe/$groupId'),
      headers: await authHeaders(),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Récupérer les paiements d'un utilisateur
  static Future<List<dynamic>> getUserPayments(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/payments/mes-paiements/$userId'),
      headers: await authHeaders(),
    );
    final body = _parseResponse(response);
    return body as List<dynamic>;
  }

  // Payer une cotisation simple (Mobile Money)
  static Future<Map<String, dynamic>> payerCotisationSimple({
    required int groupId,
    required double montant,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/payer'),
      headers: await authHeaders(),
      body: jsonEncode({'groupId': groupId, 'montant': montant}),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Simuler un paiement (pour démonstration)
  static Future<Map<String, dynamic>> simulerPaiement({
    required int groupId,
    required double montant,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/payments/simuler'),
      headers: await authHeaders(),
      body: jsonEncode({'groupId': groupId, 'montant': montant}),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Récupérer les notifications d'un utilisateur
  static Future<List<dynamic>> getNotifications(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/$userId'),
      headers: await authHeaders(),
    );
    final body = _parseResponse(response);
    return body as List<dynamic>;
  }

  // Marquer une notification comme lue
  static Future<void> markNotificationAsRead(int notificationId) async {
    await http.put(
      Uri.parse('$baseUrl/notifications/$notificationId/lire'),
      headers: await authHeaders(),
    );
  }

  // Marquer toutes les notifications comme lues
  static Future<void> markAllNotificationsAsRead(int userId) async {
    await http.put(
      Uri.parse('$baseUrl/notifications/$userId/tout-lire'),
      headers: await authHeaders(),
    );
  }

  // Récupérer le nombre de notifications non lues
  static Future<int> getUnreadNotificationCount(int userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/notifications/$userId/non-lues'),
      headers: await authHeaders(),
    );
    final body = _parseResponse(response);
    return body['count'] as int;
  }
}
