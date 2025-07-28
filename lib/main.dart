import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'settings_screen.dart';
import 'calendar_screen.dart';

// Enums for unit preferences
enum WeightUnit { metric, imperial }
enum CardioUnit { km, miles, feet }

// --- Data model ---
abstract class ExerciseNode {
  final String id;
  ExerciseNode(this.id);
}

class ExerciseLeaf extends ExerciseNode {
  String summary;
  String? note;
  ExerciseLeaf(this.summary, {this.note})
      : super(DateTime.now().toIso8601String());
}

class Superset extends ExerciseNode {
  String name;
  int sets;
  List<ExerciseLeaf> children;
  Superset(this.name, {this.sets = 1, List<ExerciseLeaf>? children})
      : children = children ?? [],
        super(DateTime.now().toIso8601String());
}

// --- App entrypoint ---
void main() => runApp(GymTrackerApp());

class GymTrackerApp extends StatefulWidget {
  @override
  _GymTrackerAppState createState() => _GymTrackerAppState();
}

class _GymTrackerAppState extends State<GymTrackerApp> {
  final settings = Settings();

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('settings.themeIsDark') ?? false;
    settings.themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final wu = prefs.getString('settings.weightUnit') ?? 'metric';
    settings.weightUnit =
    wu == 'imperial' ? WeightUnit.imperial : WeightUnit.metric;
    final cu = prefs.getString('settings.cardioUnit') ?? 'km';
    settings.cardioUnit = cu == 'miles'
        ? CardioUnit.miles
        : cu == 'feet'
        ? CardioUnit.feet
        : CardioUnit.km;
    settings.notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (_, __) => MaterialApp(
        title: 'Gym Tracker',
        themeMode: settings.themeMode,
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        home: MainScreen(settings: settings),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final Settings settings;
  const MainScreen({Key? key, required this.settings}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime selectedDate = DateTime.now();
  final Map<String, List<ExerciseNode>> exercisesPerDay = {};
  int supersetCounter = 1;

  String _extractName(String summary) {
    final firstLine = summary.split('\n').first;
    return firstLine.split(' - ').first.trim();
  }

  List<ExerciseNode> get items {
    final key = _dateKey(selectedDate);
    return exercisesPerDay.putIfAbsent(key, () => []);
  }

  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  String _friendly(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(d.year, d.month, d.day);
    final diff = target.difference(today).inDays;
    if (diff == -1) return 'Yesterday';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('MMM d').format(d);
  }

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('exercises');
    if (raw == null) return;
    final Map<String, dynamic> jsonMap = jsonDecode(raw);
    final loaded = <String, List<ExerciseNode>>{};
    jsonMap.forEach((date, list) {
      if (list is List) {
        final nodes = <ExerciseNode>[];
        for (var item in list) {
          if (item['type'] == 'leaf') {
            final leaf = ExerciseLeaf(item['summary']);
            final note = (item['note'] as String);
            leaf.note = note.isNotEmpty ? note : null;
            nodes.add(leaf);
          } else {
            final children = <ExerciseLeaf>[];
            for (var s in item['children']) {
              children.add(ExerciseLeaf(s));
            }
            nodes.add(Superset(item['name'],
                sets: item['sets'], children: children));
          }
        }
        loaded[date] = nodes;
      }
    });
    setState(() {
      exercisesPerDay
        ..clear()
        ..addAll(loaded);
    });
  }

  Future<void> _saveExercises() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap = <String, List<Map<String, dynamic>>>{};
    exercisesPerDay.forEach((date, list) {
      jsonMap[date] = list.map((node) {
        if (node is ExerciseLeaf) {
          return {
            'type': 'leaf',
            'summary': node.summary,
            'note': node.note ?? '',
          };
        } else {
          final sup = node as Superset;
          return {
            'type': 'superset',
            'name': sup.name,
            'sets': sup.sets,
            'children': sup.children.map((e) => e.summary).toList(),
          };
        }
      }).toList();
    });
    await prefs.setString('exercises', jsonEncode(jsonMap));
  }

  void _removeNode(ExerciseNode node) {
    if (node is Superset) {
      items.remove(node);
    } else if (node is ExerciseLeaf) {
      for (var n in items.toList()) {
        if (n is Superset && n.children.contains(node)) {
          n.children.remove(node);
          if (n.children.isEmpty) items.remove(n);
          return;
        }
      }
      items.remove(node);
    }
  }

  void _deleteNode(ExerciseNode node) {
    setState(() => _removeNode(node));
    _saveExercises();
  }

  Future<void> _editNode(ExerciseNode node) async {
    if (node is ExerciseLeaf) {
      final newSum = await _showAdd(existing: node.summary);
      if (newSum != null) {
        setState(() => node.summary = newSum);
        _saveExercises();
      }
    } else {
      final sup = node as Superset;
      final ctrl = TextEditingController(text: sup.name);
      final renamed = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Rename Superset'),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, ctrl.text),
                child: Text('OK'))
          ],
        ),
      );
      if (renamed != null && renamed.isNotEmpty) {
        setState(() => sup.name = renamed);
        _saveExercises();
      }
    }
  }

  Future<void> _editNote(ExerciseLeaf leaf) async {
    final ctrl = TextEditingController(text: leaf.note);
    final note = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Add Note'),
        content: TextField(
          controller: ctrl,
          decoration: InputDecoration(labelText: 'Note'),
          maxLines: null,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, ctrl.text),
              child: Text('Save'))
        ],
      ),
    );
    if (note != null) {
      setState(() => leaf.note = note.isNotEmpty ? note : null);
      _saveExercises();
    }
  }

  Future<String?> _showAdd({String? existing}) {
    String? type;
    bool dynamicReps = false, dynamicWeight = false;
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final repsCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final dynRepsCtrl = TextEditingController();
    final dynWtsCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    if (existing != null) {
      final lines = existing.split('\n');
      final header = lines.first;
      if (header.contains(' in ')) {
        type = 'Cardio';
        nameCtrl.text = header.split(' - ').first;
        final dm = RegExp(r'([\d.]+)\s*km').firstMatch(header);
        if (dm != null) distCtrl.text = dm.group(1)!;
        final tm = RegExp(r'in (.+)$').firstMatch(header);
        if (tm != null) timeCtrl.text = tm.group(1)!;
      } else {
        type = 'Weightlifting';
        nameCtrl.text = header.split(' - ').first;
        final wtM =
        RegExp(r' - ([\d.]+)(kg|lbs)').firstMatch(header);
        if (wtM != null) weightCtrl.text = wtM.group(1)!;
        if (lines.length > 1) {
          dynamicReps =
              RegExp(r'Set \d+: .* reps').hasMatch(lines[1]);
          dynamicWeight =
              RegExp(r'Set \d+: .*?(kg|lbs)').hasMatch(lines[1]);
          final entries =
          lines.sublist(1).map((l) => l.split(': ')[1]).toList();
          if (dynamicReps) {
            dynRepsCtrl.text = entries
                .map((e) => e.replaceAll(RegExp(r'\s*reps$'), ''))
                .join('\n');
          }
          if (dynamicWeight) {
            dynWtsCtrl.text = entries
                .map((e) =>
                e.replaceFirst(RegExp(r'\s*(kg|lbs).*$'), ''))
                .join('\n');
          }
        } else {
          final rM =
          RegExp(r'(\d+)\s*reps').firstMatch(header);
          if (rM != null) repsCtrl.text = rM.group(1)!;
          final sM =
          RegExp(r'x\s*(\d+)\s*sets').firstMatch(header);
          if (sM != null) setsCtrl.text = sM.group(1)!;
        }
      }
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSt) => AlertDialog(
          title:
          Text(existing != null ? 'Edit Exercise' : 'Add Exercise'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButton<String>(
                value: type,
                hint: Text('Select type'),
                isExpanded: true,
                items: ['Weightlifting', 'Cardio']
                    .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e),
                ))
                    .toList(),
                onChanged: (v) => setSt(() => type = v),
              ),
              if (type != null) ...[
                SizedBox(height: 8),
                TextField(
                  controller: nameCtrl,
                  decoration:
                  InputDecoration(labelText: 'Exercise Name'),
                ),
                SizedBox(height: 8),
                if (type == 'Weightlifting') ...[
                  SwitchListTile(
                    title: Text('Dynamic weight'),
                    value: dynamicWeight,
                    onChanged: (v) => setSt(() => dynamicWeight = v),
                  ),
                  if (!dynamicWeight)
                    TextField(
                      controller: weightCtrl,
                      keyboardType:
                      TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                        'Weight (${widget.settings.weightUnit == WeightUnit.metric ? 'kg' : 'lbs'})',
                      ),
                    )
                  else
                    TextField(
                      controller: dynWtsCtrl,
                      decoration: InputDecoration(
                          labelText: 'Weight per set (one per line)'),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  SizedBox(height: 8),
                  SwitchListTile(
                    title: Text('Dynamic reps'),
                    value: dynamicReps,
                    onChanged: (v) => setSt(() => dynamicReps = v),
                  ),
                  if (!dynamicReps) ...[
                    TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Reps'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Sets'),
                    ),
                  ] else
                    TextField(
                      controller: dynRepsCtrl,
                      decoration: InputDecoration(
                          labelText: 'Reps per set (one per line)'),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                ] else ...[
                  TextField(
                    controller: distCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                    InputDecoration(labelText: 'Distance'),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: timeCtrl,
                    decoration: InputDecoration(labelText: 'Time'),
                  ),
                ],
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (type == null ||
                    nameCtrl.text.trim().isEmpty) {
                  Navigator.pop(ctx, null);
                  return;
                }
                final name = nameCtrl.text.trim();
                String result;
                if (type == 'Weightlifting') {
                  final unit = widget.settings.weightUnit ==
                      WeightUnit.metric
                      ? 'kg'
                      : 'lbs';
                  if (!dynamicWeight && !dynamicReps) {
                    final wt = weightCtrl.text.trim();
                    final r = repsCtrl.text.trim();
                    final s = setsCtrl.text.trim();
                    result =
                    '$name - ${wt}${unit} - $r reps x $s sets';
                  } else {
                    final wts = dynamicWeight
                        ? dynWtsCtrl.text
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty)
                        .toList()
                        : [];
                    final reps = dynamicReps
                        ? dynRepsCtrl.text
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty)
                        .toList()
                        : [];
                    final sets = dynamicReps
                        ? reps.length
                        : dynamicWeight
                        ? wts.length
                        : int.tryParse(setsCtrl.text) ?? 1;
                    final header = '$name';
                    final lines = <String>[];
                    for (int i = 0; i < sets; i++) {
                      final wtPart = dynamicWeight && i < wts.length
                          ? '${wts[i]}$unit'
                          : (!dynamicWeight
                          ? '${weightCtrl.text.trim()}$unit'
                          : '');
                      final repPart = dynamicReps && i < reps.length
                          ? '${reps[i]} reps'
                          : (!dynamicReps
                          ? '${repsCtrl.text.trim()} reps'
                          : '');
                      lines.add(
                          'Set ${i + 1}: ${wtPart.isNotEmpty ? wtPart + ' × ' : ''}$repPart');
                    }
                    result = header + '\n' + lines.join('\n');
                  }
                } else {
                  final d = distCtrl.text.trim();
                  final t = timeCtrl.text.trim();
                  result = '$name - $d km in $t';
                }
                Navigator.pop(ctx, result);
              },
              child: Text(existing != null ? 'Save' : 'Add'),
            )
          ],
        ),
      ),
    );
  }

  void _add() async {
    final sum = await _showAdd();
    if (sum != null) {
      setState(() => items.add(ExerciseLeaf(sum)));
      _saveExercises();
    }
  }

  Future<void> _handleFindReplace() async {
    // 1) gather unique base names
    final names = <String>{};
    exercisesPerDay.values.forEach((list) {
      for (var node in list) {
        if (node is ExerciseLeaf) {
          names.add(_extractName(node.summary));
        } else if (node is Superset) {
          node.children.forEach((leaf) {
            names.add(_extractName(leaf.summary));
          });
        }
      }
    });

    String? selected;
    final newNameCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setSt) => AlertDialog(
          title: Text('Find & Replace'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                value: selected,
                hint: Text('Select exercise'),
                isExpanded: true,
                items: names
                    .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                    .toList(),
                onChanged: (v) => setSt(() => selected = v),
              ),
              TextField(
                controller: newNameCtrl,
                decoration: InputDecoration(labelText: 'New name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selected != null && newNameCtrl.text.trim().isNotEmpty) {
                  final oldName = selected!;
                  final newName = newNameCtrl.text.trim();
                  setState(() {
                    exercisesPerDay.values.forEach((list) {
                      for (var node in list) {
                        if (node is ExerciseLeaf) {
                          if (_extractName(node.summary) == oldName) {
                            node.summary =
                                newName + node.summary.substring(oldName.length);
                          }
                        } else {
                          for (var leaf in (node as Superset).children) {
                            if (_extractName(leaf.summary) == oldName) {
                              leaf.summary =
                                  newName + leaf.summary.substring(oldName.length);
                            }
                          }
                        }
                      }
                    });
                  });
                  _saveExercises();
                  Navigator.pop(c2);
                }
              },
              child: Text('Replace'),
            )
          ],
        ),
      ),
    );
  }


  Future<void> _handleFindRemove() async {
    final names = <String>{};
    exercisesPerDay.values.forEach((list) {
      for (var node in list) {
        if (node is ExerciseLeaf) {
          names.add(node.summary.split(' - ').first);
        } else if (node is Superset) {
          node.children.forEach((leaf) {
            names.add(leaf.summary.split(' - ').first);
          });
        }
      }
    });
    String? selected;

    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setSt) => AlertDialog(
          title: Text('Find & Remove'),
          content: DropdownButton<String>(
            value: selected,
            hint: Text('Select exercise'),
            isExpanded: true,
            items: names
                .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                .toList(),
            onChanged: (v) => setSt(() => selected = v),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selected != null) {
                  final old = selected!;
                  setState(() {
                    // remove standalone
                    exercisesPerDay.values.forEach((list) {
                      list.removeWhere((node) =>
                      node is ExerciseLeaf &&
                          node.summary.split(' - ').first == old);
                    });
                    // remove inside supersets
                    exercisesPerDay.values.forEach((list) {
                      for (var node in list.whereType<Superset>().toList()) {
                        node.children.removeWhere((leaf) =>
                        leaf.summary.split(' - ').first == old);
                        if (node.children.isEmpty) {
                          list.remove(node);
                        }
                      }
                    });
                  });
                  _saveExercises();
                  Navigator.pop(c2);
                }
              },
              child: Text('Remove'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Delete All Data?'),
        content:
        Text('This will remove ALL exercise data. Are you sure?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child:
              Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        exercisesPerDay.clear();
      });
      _saveExercises();
    }
  }

  Widget _buildGap(int idx, {Superset? sup, int? childIndex}) {
    return DragTarget<ExerciseNode>(
      onWillAccept: (_) => true,
      onAccept: (node) {
        setState(() {
          if (sup != null && node is ExerciseLeaf) {
            final inSup = sup.children.contains(node);
            if (inSup) {
              sup.children.remove(node);
              sup.children.insert(
                  childIndex!.clamp(0, sup.children.length), node);
            } else {
              _removeNode(node);
              sup.children.insert(
                  childIndex!.clamp(0, sup.children.length), node);
            }
          } else {
            _removeNode(node);
            items.insert(idx.clamp(0, items.length), node);
          }
        });
        _saveExercises();
      },
      builder: (ctx, cand, rej) => Container(
        height: cand.isNotEmpty ? 20 : 6,
        color: cand.isNotEmpty
            ? Colors.blueAccent.withOpacity(0.3)
            : null,
      ),
    );
  }

  Widget _buildDraggable(ExerciseNode node,
      {bool insideSup = false}) {
    return LongPressDraggable<ExerciseNode>(
      data: node,
      feedback: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 300),
        child: Material(
          elevation: 4,
          child: _buildNodeTile(node, insideSup: insideSup),
        ),
      ),
      child: _buildNodeTile(node, insideSup: insideSup),
    );
  }

  Widget _buildNodeTile(ExerciseNode node,
      {bool insideSup = false}) {
    if (node is Superset) {
      final idx0 = items.indexOf(node);
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DragTarget<ExerciseNode>(
              onWillAccept: (d) => d is ExerciseLeaf,
              onAccept: (d) {
                setState(() {
                  _removeNode(d);
                  node.children.add(d as ExerciseLeaf);
                  _saveExercises();
                });
              },
              builder: (ctx, cand, rej) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(node.name,
                      style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') _editNode(node);
                      else _deleteNode(node);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'edit',
                          child: Row(children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit')
                          ])),
                      PopupMenuItem(
                          value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete')
                          ])),
                    ],
                  ),
                ],
              ),
            ),
            for (int j = 0; j <= node.children.length; j++) ...[
              _buildGap(idx0 + 1 + j, sup: node, childIndex: j),
              if (j < node.children.length)
                _buildDraggable(node.children[j], insideSup: true),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Number of sets:'),
                SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: TextEditingController(
                        text: node.sets.toString()),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onSubmitted: (v) {
                      setState(() {
                        node.sets = int.tryParse(v) ?? node.sets;
                        _saveExercises();
                      });
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                      EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      final leaf = node as ExerciseLeaf;
      final parts = leaf.summary.split('\n');
      final header = parts.first;
      final rest = parts.length > 1 ? parts.sublist(1) : null;

      return Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: DragTarget<ExerciseNode>(
          onWillAccept: (d) =>
          d is ExerciseLeaf && d.id != leaf.id,
          onAccept: (d) {
            setState(() {
              final idx1 = items.indexOf(leaf);
              _removeNode(d);
              _removeNode(leaf);
              final sup = Superset(
                  'Superset ${supersetCounter++}',
                  children: [d as ExerciseLeaf, leaf]);
              items.insert(idx1.clamp(0, items.length), sup);
              _saveExercises();
            });
          },
          builder: (ctx, cand, rej) => Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                  color: cand.isNotEmpty
                      ? Colors.blueAccent
                      : Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(header.toLowerCase().contains(' in ')
                        ? Icons.directions_run
                        : Icons.fitness_center),
                    SizedBox(width: 12),
                    Expanded(
                      child: rest != null
                          ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(header),
                          for (var line in rest)
                            Padding(
                              padding: EdgeInsets.only(left: 16),
                              child: Text(line),
                            ),
                        ],
                      )
                          : Text(header),
                    ),
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'edit')
                          _editNode(leaf);
                        else if (v == 'note')
                          _editNote(leaf);
                        else
                          _deleteNode(leaf);
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [
                              Icon(Icons.edit),
                              SizedBox(width: 8),
                              Text('Edit')
                            ])),
                        PopupMenuItem(
                            value: 'note',
                            child: Row(children: [
                              Icon(Icons.note),
                              SizedBox(width: 8),
                              Text('Add Note')
                            ])),
                        PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete')
                            ])),
                      ],
                    ),
                  ],
                ),
                if (leaf.note != null && leaf.note!.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(top: 4, left: 40),
                    child: Text(
                      leaf.note!,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey[700]),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    rows.add(Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
              icon: Icon(Icons.chevron_left),
              onPressed: () => setState(() =>
              selectedDate =
                  selectedDate.subtract(Duration(days: 1)))),
          Text(_friendly(selectedDate),
              style: TextStyle(fontSize: 18)),
          IconButton(
              icon: Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
              selectedDate =
                  selectedDate.add(Duration(days: 1)))),
        ],
      ),
    ));
    rows.add(Divider());

    for (int i = 0; i <= items.length; i++) {
      rows.add(_buildGap(i));
      if (i < items.length) rows.add(_buildDraggable(items[i]));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(children: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final flatMap = exercisesPerDay.map((date, list) {
                final allSummaries = <String>[];
                for (var node in list) {
                  if (node is ExerciseLeaf) {
                    allSummaries.add(node.summary);
                  } else if (node is Superset) {
                    allSummaries
                        .addAll(node.children.map((e) => e.summary));
                  }
                }
                return MapEntry(date, allSummaries);
              });
              final pick = await Navigator.push<DateTime>(
                context,
                MaterialPageRoute(
                    builder: (_) => CalendarScreen(
                        exercisesPerDay: flatMap)),
              );
              if (pick != null)
                setState(() => selectedDate = pick);
            },
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SettingsScreen(
                  settings: widget.settings,
                  onFindReplace: _handleFindReplace,
                  onFindRemove: _handleFindRemove,
                  onDeleteAll: _handleDeleteAll,
                ),
              ),
            ),
          ),
        ]),
      ),
      body: SingleChildScrollView(child: Column(children: rows)),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: Icon(Icons.add),
        tooltip: 'Add Exercise',
      ),
    );
  }
}

// --- Settings controller with persistence ---
class Settings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  WeightUnit weightUnit = WeightUnit.metric;
  CardioUnit cardioUnit = CardioUnit.km;

  void toggleTheme(bool isDark) {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _saveTheme();
  }

  void setWeightUnit(WeightUnit u) {
    weightUnit = u;
    notifyListeners();
    _saveWeightUnit();
  }

  void setCardioUnit(CardioUnit u) {
    cardioUnit = u;
    notifyListeners();
    _saveCardioUnit();
  }

  Future<void> _saveTheme() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('settings.themeIsDark', themeMode == ThemeMode.dark);
  }

  Future<void> _saveWeightUnit() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('settings.weightUnit',
        weightUnit == WeightUnit.metric ? 'metric' : 'imperial');
  }

  Future<void> _saveCardioUnit() async {
    final prefs = await SharedPreferences.getInstance();
    String s = cardioUnit == CardioUnit.km
        ? 'km'
        : cardioUnit == CardioUnit.miles
        ? 'miles'
        : 'feet';
    prefs.setString('settings.cardioUnit', s);
  }
}
