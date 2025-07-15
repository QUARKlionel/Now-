import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/cupertino.dart';

/// Seuil par défaut (minutes) pour considérer « rapproché »
const int STEP_MIN = 15;

/// Modèle pour stocker un écart entre deux enregistrements (heure seule)
class TimeDiff {
  final String firstTime;    // Heure du premier enregistrement (HH:mm:ss)
  final String firstEvent;   // Description du premier événement
  final String secondTime;   // Heure du second enregistrement (HH:mm:ss)
  final String secondEvent;  // Description du second événement
  final Duration diff;       // Durée de l'écart entre les deux enregistrements

  TimeDiff({
    required this.firstTime,
    required this.firstEvent,
    required this.secondTime,
    required this.secondEvent,
    required this.diff,
  });
}

/// Calcule les écarts en triant par heure seule (HH:mm:ss)
List<TimeDiff> computeTimeDiffs(List<Map<String, Object?>> raw) {
  // 1) Conversion en Duration depuis minuit pour chaque enregistrement
  final records = raw.map((m) {
    final timeStr = m['time'] as String;      // ex. "14:35:20"
    final parts = timeStr.split(':');          // ["14","35","20"]
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = int.parse(parts[2]);
    final tod = Duration(
      hours: hours,
      minutes: minutes,
      seconds: seconds,
    );
    return {
      'tod': tod,
      'timeStr': timeStr,
      'event': m['event'] as String,
    };
  }).toList();

  // 2) Tri selon la durée depuis minuit
  records.sort((a, b) {
    final da = a['tod'] as Duration;
    final db = b['tod'] as Duration;
    return da.compareTo(db);
  });

  // 3) Calcul des écarts consécutifs
  final diffs = <TimeDiff>[];
  for (var i = 0; i < records.length - 1; i++) {
    final curr = records[i];
    final next = records[i + 1];
    final dt1 = curr['tod'] as Duration;
    final dt2 = next['tod'] as Duration;
    final delta = dt2 - dt1;
    diffs.add(TimeDiff(
      firstTime: curr['timeStr'] as String,
      firstEvent: curr['event'] as String,
      secondTime: next['timeStr'] as String,
      secondEvent: next['event'] as String,
      diff: delta,
    ));
  }
  return diffs;
}

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: NoteEntryScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// =================================
/// Écran de saisie principal
/// =================================
class NoteEntryScreen extends StatefulWidget {
  const NoteEntryScreen({super.key});
  @override
  State<NoteEntryScreen> createState() => _NoteEntryScreenState();
}

class _NoteEntryScreenState extends State<NoteEntryScreen> {
  DateTime? _h;
  int? _type;
  String? _displayH;
  final _eventCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _rating = 0;
  List<Map<String, Object?>> _memory = [];

  @override
  void dispose() {
    _eventCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _formatH() =>
      _h == null ? '--:--:--' : DateFormat('HH:mm:ss').format(_h!);

  void _onTypePressed(int type) => setState(() {
        _type = type;
        _h = DateTime.now();
        _displayH = _formatH();
      });

  void _onStarPressed(int idx) => setState(() => _rating = idx);

  void _saveToDB() {
    if (_type == null || _eventCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type et événement requis')),
      );
      return;
    }
    _memory.insert(0, {
      'date': DateFormat('yyyy-MM-dd').format(_h!),
      'time': DateFormat('HH:mm:ss').format(_h!),
      'type': _type,
      'event': _eventCtrl.text,
      'rating': _rating,
      'note': _noteCtrl.text,
    });
    setState(() {
      _displayH = null;
      _type = null;
      _eventCtrl.clear();
      _noteCtrl.clear();
      _rating = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasType = _type != null;
    final seen = <String>{};
    final lastEvents = [
      for (var e in _memory.map((r) => r['event'] as String))
        if (seen.add(e)) e
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Qu'est-ce qu'il se passe MAINTENANT ?"),
        actions: [
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: 'Gérer la base',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RecordListScreen(memory: _memory)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.timeline),
            tooltip: 'Voir écarts',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => RapprochementsScreen(memory: _memory)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                      onPressed: () => _onTypePressed(0),
                      child: const Text('Fatigue')),
                  ElevatedButton(
                      onPressed: () => _onTypePressed(1),
                      child: const Text('Bonne forme')),
                ],
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: hasType ? 1 : 0.5,
                child: AbsorbPointer(
                  absorbing: !hasType,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Quel précurseur à ${_displayH ?? "--:--:--"}?',
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 150,
                        child: lastEvents.isEmpty
                            ? const Center(child: Text('Aucun événement'))
                            : ListView.builder(
                                itemCount: lastEvents.length,
                                itemBuilder: (ctx, i) => ListTile(
                                  title: Text(lastEvents[i]),
                                  onTap: () => setState(
                                      () => _eventCtrl.text = lastEvents[i]),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Autre :',
                          style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _eventCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Que se passe-t-il ?',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      const Text('Intensité :',
                          style: TextStyle(fontSize: 16)),
                      Row(
                          children: List.generate(5, (i) {
                        final idx = i + 1;
                        return IconButton(
                            icon: Icon(
                                _rating >= idx
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber),
                            onPressed: () => _onStarPressed(idx));
                      })),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Note',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _saveToDB,
                          child: const Text('Enregistrer')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Écran Gestion de la base
class RecordListScreen extends StatefulWidget {
  final List<Map<String, Object?>> memory;
  const RecordListScreen({required this.memory, super.key});
  @override
  State<RecordListScreen> createState() => _RecordListScreenState();
}

class _RecordListScreenState extends State<RecordListScreen> {
  late List<Map<String, Object?>> records;
  int? sortColumnIndex;
  bool sortAscending = true;

  @override
  void initState() {
    super.initState();
    records = List.from(widget.memory);
  }

  void _sort<T extends Comparable>(
      T Function(Map<String, Object?>) getField,
      int columnIndex,
      bool ascending) {
    records.sort((a, b) {
      final va = getField(a), vb = getField(b);
      return ascending ? va.compareTo(vb) : vb.compareTo(va);
    });
    setState(() {
      sortColumnIndex = columnIndex;
      sortAscending = ascending;
    });
  }

  Future<void> _showEditDialog(int idx) async {
    final rec = records[idx];
    DateTime edited = DateFormat('yyyy-MM-dd HH:mm:ss')
        .parse('${rec['date']} ${rec['time']}');
    int type = rec['type'] as int;
    final evCtrl = TextEditingController(text: rec['event'] as String);
    int rating = rec['rating'] as int;
    final noteCtrl = TextEditingController(text: rec['note'] as String);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSt2) => AlertDialog(
          title: const Text('Modifier / Supprimer'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextButton(
                    onPressed: () async {
                      final newD = await showDatePicker(
                          context: ctx2,
                          initialDate: edited,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100));
                      if (newD != null) setSt2(() => edited = DateTime(newD.year, newD.month, newD.day, edited.hour, edited.minute));
                    },
                    child: Text('Date : ${DateFormat('yyyy-MM-dd').format(edited)}')),
                TextButton(
                    onPressed: () async {
                      final newT = await showTimePicker(
                          context: ctx2,
                          initialTime: TimeOfDay.fromDateTime(edited));
                      if (newT != null) setSt2(() => edited = DateTime(edited.year, edited.month, edited.day, newT.hour, newT.minute));
                    },
                    child: Text('Heure : ${DateFormat('HH:mm:ss').format(edited)}')),
