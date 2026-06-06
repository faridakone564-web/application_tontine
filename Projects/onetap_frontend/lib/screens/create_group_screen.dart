import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../services/api_service.dart';
import '../widgets/custom_widgets.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _montantController = TextEditingController();
  final _maxMembresController = TextEditingController(text: '10');
  String _frequence = 'hebdomadaire';
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;
  String? _generatedCode;

  @override
  void dispose() {
    _nomController.dispose();
    _montantController.dispose();
    _maxMembresController.dispose();
    super.dispose();
  }

  Future<void> _creerGroupe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final response = await ApiService.creerGroupe(
        nom: _nomController.text.trim(),
        montant: double.parse(_montantController.text),
        frequence: _frequence,
        maxMembres: int.parse(_maxMembresController.text),
      );

      setState(() {
        _successMessage = response['message'] ?? 'Groupe créé avec succès';
        _generatedCode = response['groupe']?['code_invitation']?.toString();
        _errorMessage = null;
      });

      _formKey.currentState!.reset();
      _nomController.clear();
      _montantController.clear();
      _maxMembresController.text = '10';
      setState(() {
        _frequence = 'hebdomadaire';
      });
    } catch (error) {
      setState(() {
        _successMessage = null;
        _generatedCode = null;
        _errorMessage = error is Exception
            ? error.toString().replaceFirst('Exception: ', '')
            : 'Erreur de connexion au serveur';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGreenBg,
      appBar: AppBar(
        title: const Text('Créer un Groupe'),
        backgroundColor: AppColors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Message de succès
              if (_successMessage != null)
                CustomCard(
                  backgroundColor: const Color(0xFFF1F8F1),
                  borderRadius: 12,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(
                            Icons.check_circle,
                            color: AppColors.primaryGreen,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Groupe créé avec succès !',
                              style: TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_generatedCode != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Code d\'invitation :',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _generatedCode!,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.copy),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Code copié!'),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

              // Message d'erreur
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                CustomCard(
                  backgroundColor: const Color(0xFFFFEBEE),
                  borderRadius: 12,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error,
                        color: Color(0xFFD32F2F),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Titre
              Text(
                'Détails du Groupe',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),

              // Champs du formulaire
              CustomTextField(
                label: 'Nom du Groupe',
                hint: 'Entrer le nom',
                icon: Icons.group,
                controller: _nomController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nom du groupe est requis';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              CustomTextField(
                label: 'Montant de Contribution',
                hint: 'Entrer le montant',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                controller: _montantController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le montant est requis';
                  }
                  if (double.tryParse(value) == null ||
                      double.parse(value) <= 0) {
                    return 'Le montant doit être un nombre positif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Dropdown Fréquence
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fréquence',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _frequence,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: AppColors.lightGrey,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'quotidien',
                        child: Text('Quotidien'),
                      ),
                      DropdownMenuItem(
                        value: 'hebdomadaire',
                        child: Text('Hebdomadaire'),
                      ),
                      DropdownMenuItem(
                        value: 'mensuel',
                        child: Text('Mensuel'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _frequence = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),

              CustomTextField(
                label: 'Nombre Maximum de Membres',
                hint: 'Entrer le nombre',
                icon: Icons.people,
                keyboardType: TextInputType.number,
                controller: _maxMembresController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le nombre maximum est requis';
                  }
                  if (int.tryParse(value) == null || int.parse(value) < 2) {
                    return 'Le minimum est 2 membres';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 32),

              // Bouton Créer
              ActionButton(
                label: 'Créer le Groupe',
                icon: Icons.check_circle,
                isLoading: _isLoading,
                onPressed: _creerGroupe,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
