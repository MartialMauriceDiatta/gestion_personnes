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
      title: 'Transport Bransan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E56A0),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: const PassagerListScreen(),
    );
  }
}

// Modèle de données pour les passagers
class Passager {
  final int? id;
  final String nom;
  final String prenom;
  final String telephone;
  final String departement;

  Passager({
    this.id,
    required this.nom,
    required this.prenom,
    required this.telephone,
    required this.departement,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'departement': departement,
    };
  }

  factory Passager.fromMap(Map<String, dynamic> map) {
    return Passager(
      id: map['id'],
      nom: map['nom'],
      prenom: map['prenom'],
      telephone: map['telephone'],
      departement: map['departement'],
    );
  }
}

// Gestionnaire de Base de Données SQLite
class DatabaseHelper {
  static Database? _db;

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    String dbPath = await getDatabasesPath();
    String path = p.join(dbPath, 'bus_bransan_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE passagers('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'nom TEXT, '
          'prenom TEXT, '
          'telephone TEXT, '
          'departement TEXT)',
        );
      },
    );
  }

  static Future<int> insert(Passager p) async {
    final dbClient = await db;
    return await dbClient.insert('passagers', p.toMap());
  }

  // Tri du premier inscrit au dernier (ASC) par ID
  static Future<List<Passager>> getAll() async {
    final dbClient = await db;
    final List<Map<String, dynamic>> maps =
        await dbClient.query('passagers', orderBy: 'id ASC');
    return List.generate(maps.length, (i) => Passager.fromMap(maps[i]));
  }

  static Future<int> update(Passager p) async {
    final dbClient = await db;
    return await dbClient.update(
      'passagers',
      p.toMap(),
      where: 'id = ?',
      whereArgs: [p.id],
    );
  }

  static Future<int> delete(int id) async {
    final dbClient = await db;
    return await dbClient.delete('passagers', where: 'id = ?', whereArgs: [id]);
  }
}

// Écran Principal
class PassagerListScreen extends StatefulWidget {
  const PassagerListScreen({super.key});

  @override
  State<PassagerListScreen> createState() => _PassagerListScreenState();
}

class _PassagerListScreenState extends State<PassagerListScreen> {
  List<Passager> _allPassagers = [];
  List<Passager> _filteredPassagers = [];
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
      _allPassagers = data;
      _filteredPassagers = data;
      _isLoading = false;
    });
    if (_searchController.text.isNotEmpty) {
      _filter(_searchController.text);
    }
  }

  void _filter(String keyword) {
    setState(() {
      _filteredPassagers = _allPassagers
          .where((p) =>
              p.nom.toLowerCase().contains(keyword.toLowerCase()) ||
              p.prenom.toLowerCase().contains(keyword.toLowerCase()) ||
              p.telephone.contains(keyword) ||
              p.departement.toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF1E56A0),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFormDialog({Passager? passager}) {
    final formKey = GlobalKey<FormState>();
    final prenomController = TextEditingController(text: passager?.prenom ?? '');
    final nomController = TextEditingController(text: passager?.nom ?? '');
    final phoneController = TextEditingController(text: passager?.telephone ?? '');
    final deptController = TextEditingController(text: passager?.departement ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  passager == null
                      ? 'Nouveau Passager'
                      : 'Modifier les Informations',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E56A0),
                      ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: prenomController,
                  decoration: _inputDecoration('Prénom', Icons.person_outline),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomController,
                  decoration: _inputDecoration('Nom', Icons.person),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration('Téléphone', Icons.phone_outlined),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: deptController,
                  decoration: _inputDecoration('Département', Icons.business_outlined),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Champ obligatoire' : null,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E56A0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      if (formKey.currentState!.validate()) {
                        final p = Passager(
                          id: passager?.id,
                          prenom: prenomController.text.trim(),
                          nom: nomController.text.trim(),
                          telephone: phoneController.text.trim(),
                          departement: deptController.text.trim(),
                        );

                        if (passager == null) {
                          await DatabaseHelper.insert(p);
                          _showSnackBar('${p.prenom} a été ajouté(e) au bus.');
                        } else {
                          await DatabaseHelper.update(p);
                          _showSnackBar('Fiche de ${p.prenom} mise à jour.');
                        }

                        if (mounted) Navigator.of(context).pop();
                        _refreshList();
                      }
                    },
                    child: Text(
                      passager == null ? 'Enregistrer le passager' : 'Mettre à jour',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF1E56A0)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF1E56A0), width: 2),
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
    );
  }

  void _confirmDelete(Passager passager) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Voulez-vous retirer ${passager.prenom} ${passager.nom} de la liste ?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.delete(passager.id!);
              if (mounted) Navigator.of(ctx).pop();
              _refreshList();
              _showSnackBar('Passager retiré de la liste.', isError: true);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: const Color(0xFF1E56A0),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.directions_bus, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text(
                  'Gestion des clients de Bransan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_allPassagers.length} passager(s) enregistré(s)',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Rechercher (Nom, Téléphone, Département)...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF1E56A0)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
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
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPassagers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.directions_bus_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Aucun passager inscrit.'
                                  : 'Aucun résultat trouvé.',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredPassagers.length,
                        padding: const EdgeInsets.only(bottom: 80),
                        itemBuilder: (ctx, i) {
                          final item = _filteredPassagers[i];

                          // Calcul du numéro dynamique basé sur l'ordre dans la liste globale
                          final int numeroOrdre = _searchController.text.isEmpty
                              ? i + 1
                              : _allPassagers.indexWhere((p) => p.id == item.id) + 1;

                          return Card(
                            margin: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            elevation: 0,
                            color: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                  color: Colors.grey.shade200, width: 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E56A0)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$numeroOrdre',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1E56A0),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item.prenom} ${item.nom.toUpperCase()}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.phone,
                                                size: 14,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Text(
                                              item.telephone,
                                              style: TextStyle(
                                                color: Colors.grey.shade800,
                                                fontSize: 13,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Icon(Icons.location_city,
                                                size: 14,
                                                color: Colors.grey.shade600),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                item.departement,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined,
                                            color: Colors.blue),
                                        onPressed: () =>
                                            _showFormDialog(passager: item),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline,
                                            color: Colors.red),
                                        onPressed: () => _confirmDelete(item),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        backgroundColor: const Color(0xFF1E56A0),
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter un passager'),
      ),
    );
  }
}