import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

/// Nom de la base et du store
const _dbName = 'my_app.db';
const _storeName = 'records';

/// Box JSON avec clé auto-incrémentée
final _store = intMapStoreFactory.store(_storeName);

/// Ouverture du DB (IndexedDB sous le capot)
Future<Database> openDatabase() async {
  return await databaseFactoryWeb.openDatabase(_dbName);
}

/// Récupère tous les enregistrements triés par date+heure
Future<List<Map<String, dynamic>>> loadAll() async {
  final db = await openDatabase();
  final records = await _store.find(db,
      finder: Finder(sortOrders: [
        SortOrder('date'),
        SortOrder('time'),
      ]));
  // On retourne la valeur et on injecte l'id pour update/delete
  return records.map((snap) => {'id': snap.key, ...snap.value}).toList();
}

/// Ajoute un enregistrement et renvoie son clé
Future<int> insert(Map<String, dynamic> record) async {
  final db = await openDatabase();
  return await _store.add(db, record);
}

/// Met à jour l’enregistrement d’id [key]
Future<void> update(int key, Map<String, dynamic> record) async {
  final db = await openDatabase();
  await _store.record(key).update(db, record);
}

/// Supprime l’enregistrement d’id [key]
Future<void> delete(int key) async {
  final db = await openDatabase();
  await _store.record(key).delete(db);
}
