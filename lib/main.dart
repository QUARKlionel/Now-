import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'src/db.dart' as db;

/// Seuil par défaut (minutes) pour considérer « rapproché »
const int stepMin = 15;

/// Modèle pour stocker un écart entre deux enregistrements
class TimeDiff {
  final DateTime firstDt;
  final String firstEvent;
  final DateTime secondDt;
  final String secondEvent;
  final Duration diff;

  TimeDiff({
    required this.firstDt,
    required this.firstEvent,
    required this.secondDt,
    required this.secondEvent,
    required this.diff,
  });
}

/// Calcule les écarts en triant par heure seule (HH:mm:ss)
List<TimeDiff> computeTimeDiffs(List<Map<String, Object?>> raw) {
  final records = raw.map((m) {
    final dateStr = m['date'] as String;
    final timeStr = m['time'] as String;
    final dt = DateFormat('yyyy-MM-dd HH:mm:ss').parse('$dateStr $timeStr');
    return {'dt': dt, 'event': m['event'] as String};
  }).toList();

  records.sort((a, b) {
    final da = a['dt'] as DateTime;
    final db = b['dt'] as DateTime;
    if (da.hour != db.hour) return da.hour.compareTo(db.hour);
    if (da.minute != db.minute) return da.minute.compareTo(db.minute);
    return da.second.compareTo(db.second);
  });

  final diffs = <TimeDiff>[];
  for (var i = 0; i < records.length - 1; i++) {
    final curr = records[i];
    final next = records[i + 1];
    final dt1 = curr['dt'] as DateTime;
    final dt2 = next['dt'] as DateTime;
    final d1 =
        Duration(hours: dt1.hour, minutes: dt1.minute, seconds: dt1.second);
    final d2 =
        Duration(hours: dt2.hour, minutes: dt2.minute, seconds: dt2.second);
    final delta = d2 - d1;
    diffs.add(TimeDiff(
      firstDt: dt1,
      firstEvent: curr['event'] as String,
      secondDt: dt2,
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
  final TextEditingController _eventCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  int _rating = 0;
  List<Map<String, Object?>> _memory = [];

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

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

  Future<void> _loadMemory() async {
    final recs = await db.loadAll();
    setState(() => _memory = recs);
  }

  Future<void> _saveToDB() async {
    if (_type == null || _eventCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Type et événement requis')),
      );
      return;
    }
    final data = {
      'date': DateFormat('yyyy-MM-dd').format(_h!),
      'time': DateFormat('HH:mm:ss').format(_h!),
      'type': _type,
      'event': _eventCtrl.text,
      'rating': _rating,
      'note': _noteCtrl.text,
    };
    final key = await db.insert(data);
    setState(() {
      _memory.insert(0, {'id': key, ...data});
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              ElevatedButton(
                  onPressed: () => _onTypePressed(0),
                  child: const Text('Fatigue')),
              ElevatedButton(
                  onPressed: () => _onTypePressed(1),
                  child: const Text('Bonne forme')),
            ]),
            const SizedBox(height: 16),
            Opacity(
              opacity: hasType ? 1 : 0.5,
              child: AbsorbPointer(
                absorbing: !hasType,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Quel précurseur à ${_displayH ?? "--:--:--"} ?',
                          style: const TextStyle(fontSize: 18)),
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
                      const Text('Autre :', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 8),
                      TextField(
                          controller: _eventCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Que se passe-t-il ?',
                              border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      const Text('Intensité :', style: TextStyle(fontSize: 16)),
                      Row(
                          children: List.generate(5, (i) {
                        final idx = i + 1;
                        return IconButton(
                          icon: Icon(
                              _rating >= idx ? Icons.star : Icons.star_border,
                              color: Colors.amber),
                          onPressed: () => _onStarPressed(idx),
                        );
                      })),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _noteCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Note', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      ElevatedButton(
                          onPressed: _saveToDB,
                          child: const Text('Enregistrer')),
                    ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// =================================
/// Écran Gestion de la base
/// =================================
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

  void _sort<T extends Comparable>(T Function(Map<String, Object?>) getField,
      int columnIndex, bool ascending) {
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
      builder: (ctx2) => StatefulBuilder(
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
                        if (newD != null)
                          setSt2(() => edited = DateTime(newD.year, newD.month,
                              newD.day, edited.hour, edited.minute));
                      },
                      child: Text(
                          'Date : ${DateFormat('yyyy-MM-dd').format(edited)}')),
                  TextButton(
                      onPressed: () async {
                        final newT = await showTimePicker(
                            context: ctx2,
                            initialTime: TimeOfDay.fromDateTime(edited));
                        if (newT != null)
                          setSt2(() => edited = DateTime(
                              edited.year,
                              edited.month,
                              edited.day,
                              newT.hour,
                              newT.minute));
                      },
                      child: Text(
                          'Heure : ${DateFormat('HH:mm:ss').format(edited)}')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Fatigue')),
                      DropdownMenuItem(value: 1, child: Text('Bonne forme')),
                    ],
                    onChanged: (v) => setSt2(() => type = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                      controller: evCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Événement')),
                  const SizedBox(height: 8),
                  Row(
                      children: List.generate(5, (i) {
                    final idx = i + 1;
                    return IconButton(
                        icon: Icon(
                            rating >= idx ? Icons.star : Icons.star_border),
                        onPressed: () => setSt2(() => rating = idx));
                  })),
                  const SizedBox(height: 8),
                  TextField(
                      controller: noteCtrl,
                      decoration: const InputDecoration(labelText: 'Note')),
                ]),
          ),
          actions: [
            TextButton(
                onPressed: () async {
                  final key = records[idx]['id'] as int;
                  await db.delete(key);
                  setState(() {
                    widget.memory.removeAt(idx);
                    records.removeAt(idx);
                  });
                  Navigator.of(ctx2).pop();
                },
                child: const Text('Supprimer')),
            TextButton(
                onPressed: () async {
                  final key = records[idx]['id'] as int;
                  final updated = {
                    'date': DateFormat('yyyy-MM-dd').format(edited),
                    'time': DateFormat('HH:mm:ss').format(edited),
                    'type': type,
                    'event': evCtrl.text,
                    'rating': rating,
                    'note': noteCtrl.text,
                  };
                  await db.update(key, updated);
                  setState(() {
                    widget.memory[idx] = {'id': key, ...updated};
                    records[idx] = {'id': key, ...updated};
                  });
                  Navigator.of(ctx2).pop();
                },
                child: const Text('Enregistrer')),
            TextButton(
                onPressed: () => Navigator.of(ctx2).pop(),
                child: const Text('Annuler')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de la base')),
      body: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          sortColumnIndex: sortColumnIndex,
          sortAscending: sortAscending,
          columns: [
            DataColumn(
                label: const Text('Date'),
                onSort: (ci, asc) => _sort(
                    (r) => DateFormat('yyyy-MM-dd').parse(r['date'] as String),
                    ci,
                    asc)),
            DataColumn(
                label: const Text('Heure'),
                onSort: (ci, asc) => _sort(
                    (r) => DateFormat('HH:mm:ss').parse(r['time'] as String),
                    ci,
                    asc)),
            DataColumn(
                label: const Text('Type'),
                onSort: (ci, asc) => _sort((r) => r['type'] as int, ci, asc)),
            DataColumn(
                label: const Text('Event'),
                onSort: (ci, asc) => _sort(
                    (r) => (r['event'] as String).toLowerCase(), ci, asc)),
            DataColumn(
                label: const Text('Intensité'),
                numeric: true,
                onSort: (ci, asc) => _sort((r) => r['rating'] as int, ci, asc)),
            DataColumn(
                label: const Text('Note'),
                onSort: (ci, asc) =>
                    _sort((r) => (r['note'] as String).toLowerCase(), ci, asc)),
          ],
          rows: records
              .map(
                (r) => DataRow(
                  onSelectChanged: (_) => _showEditDialog(records.indexOf(r)),
                  cells: [
                    DataCell(Text(r['date'] as String)),
                    DataCell(Text(r['time'] as String)),
                    DataCell(Text(r['type'] == 0 ? 'Fatigue' : 'Bonne forme')),
                    DataCell(Text(r['event'] as String)),
                    DataCell(Text('${r['rating']}')),
                    DataCell(Text(r['note'] as String)),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// =================================
/// Écran des écarts rapprochés
/// =================================
class RapprochementsScreen extends StatefulWidget {
  final List<Map<String, Object?>> memory;
  const RapprochementsScreen({required this.memory, super.key});
  @override
  State<RapprochementsScreen> createState() => _RapprochementsScreenState();
}

class _RapprochementsScreenState extends State<RapprochementsScreen> {
  double _maxMinutes = stepMin.toDouble();

  @override
  Widget build(BuildContext context) {
    final diffs = computeTimeDiffs(widget.memory);
    final filtered =
        diffs.where((d) => d.diff.inMinutes <= _maxMinutes).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Écarts rapprochés')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Text('Seuil max (min) :'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 60,
                    divisions: 60,
                    label: _maxMinutes.round().toString(),
                    value: _maxMinutes,
                    onChanged: (v) => setState(() => _maxMinutes = v),
                  ),
                ),
                Text('${_maxMinutes.round()}'),
              ],
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              const Expanded(
                  child: Center(child: Text('Aucun écart sous le seuil.')))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final d = filtered[i];
                    final mins = d.diff.inMinutes;
                    final secs = d.diff.inSeconds % 60;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Écart : ${mins}m ${secs}s',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                            '• ${DateFormat('HH:mm dd/MM/yy').format(d.firstDt)} — ${d.firstEvent}'),
                        Text(
                            '• ${DateFormat('HH:mm dd/MM/yy').format(d.secondDt)} — ${d.secondEvent}'),
                        const Divider(),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
