import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:image_picker/image_picker.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion des Personnes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
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
  final int age;
  final String role;
  final String? imagePath;

  Personne({
    this.id,
    required this.nom,
    required this.prenom,
    required this.age,
    required this.role,
    this.imagePath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nom': nom,
      'prenom': prenom,
      'age': age,
      'role': role,
      'imagePath': imagePath,
    };
  }

  factory Personne.fromMap(Map<String, dynamic> map) {
    return Personne(
      id: map['id'],
      nom: map['nom'],
      prenom: map['prenom'],
      age: map['age'],
      role: map['role'],
      imagePath: map['imagePath'],
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
    String path = p.join(dbPath, 'personnes_v2.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE personnes(id INTEGER PRIMARY KEY AUTOINCREMENT, nom TEXT, prenom TEXT, age INTEGER, role TEXT, imagePath TEXT)',
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
    final List<Map<String, dynamic>> maps = await dbClient.query('personnes', orderBy: 'id DESC');
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
              p.role.toLowerCase().contains(keyword.toLowerCase()))
          .toList();
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showFormDialog({Personne? personne}) {
    final formKey = GlobalKey<FormState>();
    final nomController = TextEditingController(text: personne?.nom ?? '');
    final prenomController = TextEditingController(text: personne?.prenom ?? '');
    final ageController = TextEditingController(text: personne?.age.toString() ?? '');
    final roleController = TextEditingController(text: personne?.role ?? '');
    String? selectedImagePath = personne?.imagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          Future<void> pickImage() async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(source: ImageSource.gallery);
            if (pickedFile != null) {
              setModalState(() {
                selectedImagePath = pickedFile.path;
              });
            }
          }

          return Padding(
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
                  children: [
                    Text(
                      personne == null ? 'Ajouter une personne' : 'Modifier la personne',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: pickImage,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                            backgroundImage: (selectedImagePath != null && File(selectedImagePath!).existsSync())
                                ? FileImage(File(selectedImagePath!))
                                : null,
                            child: (selectedImagePath == null || !File(selectedImagePath!).existsSync())
                                ? const Icon(Icons.person, size: 40)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 14,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: prenomController,
                      decoration: const InputDecoration(labelText: 'Prénom', prefixIcon: Icon(Icons.person_outline)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Prénom obligatoire' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: nomController,
                      decoration: const InputDecoration(labelText: 'Nom', prefixIcon: Icon(Icons.person)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Nom obligatoire' : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: ageController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Âge', prefixIcon: Icon(Icons.cake_outlined)),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Âge obligatoire';
                        final parsed = int.tryParse(val);
                        if (parsed == null || parsed <= 0) return 'Saisissez un âge valide';
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: roleController,
                      decoration: const InputDecoration(labelText: 'Rôle / Profession', prefixIcon: Icon(Icons.work_outline)),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Rôle obligatoire' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            final p = Personne(
                              id: personne?.id,
                              nom: nomController.text.trim(),
                              prenom: prenomController.text.trim(),
                              age: int.parse(ageController.text.trim()),
                              role: roleController.text.trim(),
                              imagePath: selectedImagePath,
                            );

                            if (personne == null) {
                              await DatabaseHelper.insert(p);
                              _showSnackBar('${p.prenom} a été ajouté(e) avec succès.');
                            } else {
                              await DatabaseHelper.update(p);
                              _showSnackBar('Informations de ${p.prenom} mises à jour.');
                            }

                            if (mounted) Navigator.of(context).pop();
                            _refreshList();
                          }
                        },
                        child: Text(personne == null ? 'Enregistrer' : 'Mettre à jour'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _confirmDelete(Personne personne) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmation'),
        content: Text('Voulez-vous supprimer ${personne.prenom} ${personne.nom} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await DatabaseHelper.delete(personne.id!);
              if (mounted) Navigator.of(ctx).pop();
              _refreshList();
              _showSnackBar('${personne.prenom} ${personne.nom} a été supprimé(e).', isError: true);
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
        title: const Text('Répertoire des Personnes'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Rechercher un nom, rôle...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filter('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPersonnes.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Aucune personne enregistrée.'
                              : 'Aucun résultat pour cette recherche.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredPersonnes.length,
                        itemBuilder: (ctx, i) {
                          final item = _filteredPersonnes[i];
                          final bool hasImage = item.imagePath != null && File(item.imagePath!).existsSync();

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 0,
                            color: Theme.of(context).colorScheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 26,
                                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                backgroundImage: hasImage ? FileImage(File(item.imagePath!)) : null,
                                child: !hasImage
                                    ? Text(
                                        '${item.prenom[0]}${item.nom[0]}'.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                        ),
                                      )
                                    : null,
                              ),
                              title: Text(
                                '${item.prenom} ${item.nom.toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('${item.role} • ${item.age} ans'),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                                    onPressed: () => _showFormDialog(personne: item),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _confirmDelete(item),
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
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}