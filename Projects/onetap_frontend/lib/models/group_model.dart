class Beneficiaire {
  final String nom;
  final String telephone;

  Beneficiaire({required this.nom, required this.telephone});

  factory Beneficiaire.fromJson(Map<String, dynamic> json) {
    return Beneficiaire(
      nom: json['nom'] as String,
      telephone: json['telephone'] as String,
    );
  }
}

class GroupModel {
  final int id;
  final String nom;
  final double montant;
  final String frequence;
  final bool isActive;
  final String status; // 'en_attente', 'active', 'terminee'
  final DateTime? startDate;
  final int maxMembers;
  final int currentMembers;
  final int availableSlots;
  final Beneficiaire? prochainBeneficiaire;

  GroupModel({
    required this.id,
    required this.nom,
    required this.montant,
    required this.frequence,
    required this.isActive,
    required this.status,
    required this.startDate,
    required this.maxMembers,
    required this.currentMembers,
    required this.availableSlots,
    required this.prochainBeneficiaire,
  });

  bool get isLocked => status == 'active';
  bool get isFull => availableSlots <= 0;
  bool get canJoin => !isLocked && !isFull;

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString()) ?? fallback;
  }

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: _asInt(json['id']),
      nom: json['nom']?.toString() ?? '',
      montant: (json['montant'] is num)
          ? (json['montant'] as num).toDouble()
          : double.tryParse(json['montant'].toString()) ?? 0,
      frequence: json['frequence']?.toString() ?? '',
      isActive: json['isActive'] == 1 || json['isActive'] == true,
      status: json['status']?.toString() ?? 'recrutement',
      startDate: json['startDate'] != null 
          ? DateTime.tryParse(json['startDate'].toString())
          : null,
      maxMembers: _asInt(json['maxMembers'], 10),
      currentMembers: _asInt(json['currentMembers']),
      availableSlots: _asInt(json['availableSlots']),
      prochainBeneficiaire: json['prochainBeneficiaire'] != null
          ? Beneficiaire.fromJson(json['prochainBeneficiaire'] as Map<String, dynamic>)
          : null,
    );
  }
}
