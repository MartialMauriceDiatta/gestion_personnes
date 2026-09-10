import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liste au départ de Bransan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Poppins',
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const PersonListScreen(),
    );
  }
}

// Modèle de données
class Personne {
  final int? id;
  final String nom;
  final String prenom;
  final String telephone;
  final String departement;
  final int numero; // Numéro d'ordre

  Personne({
    this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.departement,
    required this.numero,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'departement': departement,
      'numero': numero,
    };
  }

  factory Personne.fromMap(Map<String, dynamic> map) {
    return Personne(
      id: map['id'],
      nom: map['nom'],
      prenom: map['prenom'],
      telephone: map['telephone'],
      departement: map['departement'],
      numero: map['numero'],
    );
  }
}

// Helper SQLite
class DatabaseHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'bransan_liste.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE personnes(id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT, prenom TEXT, telephone TEXT, departement TEXT, numero INTEGER)',
        );
      },
    );
  }

  static Future<int> insert(Personne p) async {
    final dbClient = await db;
    return await dbClient.insert('personnes', p.toMap());
  }

  static Future<List<Personne>> getAll() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps = await dbClient.query(
      'personnes',
      orderBy: 'numero ASC', // Du premier au dernier
    );
    return List.generate(maps.length, (i) => Personne.fromMap(maps[i]));
  }

  static Future<int> update(Personne p) async {
    final dbClient = await db;
    return await dbClient.update('personnes', p.toMap(), where: 'id = ?', whereArgs: [p.id]);
  }

  static Future<int> delete(int id) async {
    final dbClient = await db;
    return await dbClient.delete('personnes', where: 'id = ?', whereArgs: [id]);
  }
}

// Écran principal
class PersonListScreen extends StatefulWidget {
  const PersonListScreen({super.key});

  @override
  State<PersonListScreen> createState() => _PersonListScreenState();
}

class _PersonListScreenState extends State<PersonListScreen> {
  List<Personne> _allPersonnes = [];
  List<Personne> _filteredPersonnes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _refreshList();
  }

  Future<void> _refreshList() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.getAll();
    setState(() {
      _allPersonnes = data;
      _filteredPersonnes = data;
      _isLoading = false;
    });
    if (_searchController.text.isNotEmpty) {
      _filter(_searchController.text);
    }
  }

  void _filter(String keyword) {
    setState(() {
      _filteredPersonnes = _allPersonnes
          .where((p) =>
              p.nom.toLowerCase().contains(keyword.toLowerCase()) ||
              p.prenom.toLowerCase().contains(keyword.toLowerCase()) ||
              p.departement.toLowerCase().contains(keyword.toLowerCase()) ||
              p.telephone.contains(keyword))
          .toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.deepPurple.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showFormDialog({Personne? personne}) {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: personne?.nom ?? '');
    final prenomController = TextEditingController(text: personne?.prenom ?? '');
    final telephoneController = TextEditingController(text: personne?.telephone ?? '');
    final departementController = TextEditingController(text: personne?.departement ?? '');
    final numeroController = TextEditingController(text: personne?.numero.toString() ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          top: 24,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  personne == null ? 'Ajouter un passager' : 'Modifier le passager',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.deepPurple,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Remplissez les informations ci-dessous',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFormField(
                  controller: numeroController,
                  label: 'Numéro d\'ordre',
                  icon: Icons.numbers,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Numéro obligatoire';
                    final parsed = int.tryParse(val);
                    if (parsed == null || parsed <= 0) return 'Saisissez un numéro valide';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: prenomController,
                  label: 'Prénom',
                  icon: Icons.person_outline,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Prénom obligatoire' : null,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: nomController,
                  label: 'Nom',
                  icon: Icons.person,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Nom obligatoire' : null,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: telephoneController,
                  label: 'Numéro de téléphone',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Téléphone obligatoire' : null,
                ),
                const SizedBox(height: 12),
                _buildFormField(
                  controller: departementController,
                  label: 'Département',
                  icon: Icons.location_on,
                  validator: (val) => val == null || val.trim().isEmpty ? 'Département obligatoire' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final p = Personne(
                          id: personne?.id,
                          nom: nomController.text.trim(),
                          prenom: prenomController.text.trim(),
                          telephone: telephoneController.text.trim(),
                          departement: departementController.text.trim(),
                          numero: int.parse(numeroController.text.trim()),
                        );

                        if (personne == null) {
                          await DatabaseHelper.insert(p);
                          _showSnackBar('${p.prenom} ${p.nom} a été ajouté(e) à la liste.');
                        } else {
                          await DatabaseHelper.update(p);
                          _showSnackBar('Informations de ${p.prenom} ${p.nom} mises à jour.');
                        }

                        if (mounted) Navigator.of(context).pop();
                        _refreshList();
                      }
                    },
                    child: Text(
                      personne == null ? 'Ajouter à la liste' : 'Mettre à jour',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.deepPurple.shade400),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.deepPurple.shade400, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  void _confirmDelete(Personne personne) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirmation'),
        content: Text(
          'Voulez-vous retirer ${personne.prenom} ${personne.nom} de la liste ?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              await DatabaseHelper.delete(personne.id!);
              if (mounted) Navigator.of(ctx).pop();
              _refreshList();
              _showSnackBar(
                '${personne.prenom} ${personne.nom} a été retiré de la liste.',
                isError: true,
              );
            },
            child: const Text('Retirer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 180,
            floating: true,
            pinned: true,
            snap: false,
            backgroundColor: Colors.deepPurple,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                '🚌 Liste au départ de Bransan',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                  color: Colors.white,
                ),
              ),
              centerTitle: true,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.deepPurple.shade700,
                      Colors.deepPurple.shade400,
                      Colors.purple.shade300,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_bus, color: Colors.white.withOpacity(0.3), size: 60),
                          const SizedBox(width: 12),
                          Text(
                            'Bransan',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w300,
                              color: Colors.white.withOpacity(0.5),
                              letterSpacing: 4,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(60),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _filter,
                    decoration: InputDecoration(
                      hintText: 'Rechercher un passager...',
                      prefixIcon: Icon(Icons.search, color: Colors.deepPurple.shade400),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.deepPurple.shade400),
                              onPressed: () {
                                _searchController.clear();
                                _filter('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_filteredPersonnes.length} passagers',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Ordre croissant',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.deepPurple.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: _isLoading
                ? const SliverFillRemaining(
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _filteredPersonnes.isEmpty
                    ? SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off_outlined,
                                size: 80,
                                color: Colors.grey.shade300,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? 'Aucun passager dans la liste'
                                    : 'Aucun résultat pour cette recherche',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 16,
                                ),
                              ),
                              if (_searchController.text.isEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  'Appuyez sur le bouton + pour ajouter',
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final item = _filteredPersonnes[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Colors.deepPurple.shade400,
                                        Colors.purple.shade300,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '#${item.numero}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  '${item.prenom} ${item.nom}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.telephone,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          item.departement,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.deepPurple.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: Colors.deepPurple.shade600,
                                          size: 20,
                                        ),
                                        onPressed: () => _showFormDialog(personne: item),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.red.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: IconButton(
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade600,
                                          size: 20,
                                        ),
                                        onPressed: () => _confirmDelete(item),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _filteredPersonnes.length,
                        ),
                      ),
          ),
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(),
          backgroundColor: Colors.deepPurple,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Ajouter un passager',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
    );
  }
}