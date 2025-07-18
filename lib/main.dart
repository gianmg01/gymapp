import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  ExerciseLeaf(String id, this.summary) : super(id);
}

class Superset extends ExerciseNode {
  String name;
  int sets;
  List<ExerciseLeaf> children;
  Superset(String id, this.name,
      {this.sets = 1, List<ExerciseLeaf>? children})
      : children = children ?? [],
        super(id);
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

// --- MainScreen ---
class MainScreen extends StatefulWidget {
  final Settings settings;
  const MainScreen({Key? key, required this.settings}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime selectedDate = DateTime.now();
  List<ExerciseNode> items = [];
  final Set<String> previousNames = {};
  int supersetCounter = 1;

  // Map from children‐name‐sequence key to superset name
  final Map<String, String> supNameByKey = {};

  String _friendly(DateTime d) {
    final now = DateTime.now();
    final t0 = DateTime(now.year, now.month, now.day);
    final t1 = DateTime(d.year, d.month, d.day);
    final diff = t1.difference(t0).inDays;
    if (diff == -1) return 'Yesterday';
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('MMM d').format(d);
  }

  // Generate a key for a superset's children by their base names
  String _childrenKey(List<ExerciseLeaf> children) {
    return children
        .map((e) => e.summary.split(' - ').first)
        .join('|');
  }

  // Update or assign a superset name based on existing patterns
  void _updateSupersetName(Superset sup) {
    final key = _childrenKey(sup.children);
    if (supNameByKey.containsKey(key)) {
      sup.name = supNameByKey[key]!;
    } else {
      supNameByKey[key] = sup.name;
    }
  }

  // Remove a node from wherever it lives
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
  }

  Future<void> _editNode(ExerciseNode node) async {
    if (node is ExerciseLeaf) {
      final newSum = await _showAdd(existing: node);
      if (newSum != null && newSum.isNotEmpty) {
        setState(() {
          node.summary = newSum;
          previousNames.add(newSum.split(' - ').first);
        });
      }
    } else if (node is Superset) {
      final ctrl = TextEditingController(text: node.name);
      final renamed = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text('Rename Superset'),
          content: TextField(controller: ctrl),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(c, ctrl.text),
                child: Text('OK')),
          ],
        ),
      );
      if (renamed != null && renamed.isNotEmpty) {
        setState(() {
          node.name = renamed;
          // update map so future matches adopt this name
          supNameByKey[_childrenKey(node.children)] = renamed;
        });
      }
    }
  }

  Future<String?> _showAdd({ExerciseLeaf? existing}) async {
    String? type;
    final nameCtrl = TextEditingController(
        text: existing?.summary.split(' - ').first ?? '');
    final weightCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final wU = widget.settings.weightUnit;
    final cU = widget.settings.cardioUnit;

    if (existing != null) {
      final parts = existing.summary.split(' - ');
      nameCtrl.text = parts[0];
      final rest = parts.length > 1 ? parts[1] : '';
      if (rest.contains('sets')) {
        type = 'Weightlifting';
        final m =
        RegExp(r"(\d+)(kg|lbs) x (\d+) sets").firstMatch(rest);
        if (m != null) {
          weightCtrl.text = m.group(1)!;
          setsCtrl.text = m.group(3)!;
        }
      } else if (rest.contains('in')) {
        type = 'Cardio';
        final m =
        RegExp(r"(\d+)(km|miles|feet) in (.+)").firstMatch(rest);
        if (m != null) {
          distCtrl.text = m.group(1)!;
          timeCtrl.text = m.group(3)!;
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
                hint: Text('Type'),
                isExpanded: true,
                items: ['Weightlifting', 'Cardio']
                    .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setSt(() => type = v),
              ),
              SizedBox(height: 8),
              Autocomplete<String>(
                optionsBuilder: (te) => te.text.isEmpty
                    ? []
                    : previousNames.where((o) => o
                    .toLowerCase()
                    .contains(te.text.toLowerCase())),
                fieldViewBuilder: (c, ctrl, fn, fs) {
                  ctrl.text = nameCtrl.text;
                  return TextField(
                    controller: ctrl,
                    focusNode: fn,
                    decoration: InputDecoration(labelText: 'Name'),
                    onChanged: (v) => nameCtrl.text = v,
                  );
                },
                onSelected: (sel) => nameCtrl.text = sel,
              ),
              if (type == 'Weightlifting') ...[
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText:
                      'Weight (${wU == WeightUnit.metric ? 'kg' : 'lbs'})'),
                ),
                TextField(
                  controller: setsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Sets'),
                ),
              ],
              if (type == 'Cardio') ...[
                TextField(
                  controller: distCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      labelText:
                      'Distance (${cU == CardioUnit.km ? 'km' : cU == CardioUnit.miles ? 'miles' : 'feet'})'),
                ),
                TextField(
                  controller: timeCtrl,
                  decoration:
                  InputDecoration(labelText: 'Time (e.g. 30 min)'),
                ),
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
                String sum;
                if (type == 'Weightlifting') {
                  sum =
                  '$name - ${weightCtrl.text}${wU == WeightUnit.metric ? 'kg' : 'lbs'} x ${setsCtrl.text} sets';
                } else {
                  final unit = cU == CardioUnit.km
                      ? 'km'
                      : cU == CardioUnit.miles
                      ? 'miles'
                      : 'feet';
                  sum =
                  '$name - ${distCtrl.text}$unit in ${timeCtrl.text}';
                }
                Navigator.pop(ctx, sum);
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
    if (sum != null && sum.isNotEmpty) {
      setState(() {
        final leaf =
        ExerciseLeaf('leaf${DateTime.now().millisecondsSinceEpoch}', sum);
        items.add(leaf);
        previousNames.add(sum.split(' - ').first);
      });
    }
  }

  /// Builds the drag‑target gap. Handles both top‑level and superset contexts.
  Widget _buildGap(int index,
      {Superset? sup, int? childIndex}) {
    return DragTarget<ExerciseNode>(
      onWillAccept: (_) => true,
      onAccept: (node) {
        setState(() {
          if (sup != null && node is ExerciseLeaf) {
            final inThisSup = sup.children.contains(node);
            if (inThisSup) {
              // reorder within sup
              sup.children.remove(node);
              final at = childIndex!.clamp(
                  0, sup.children.length);
              sup.children.insert(at, node);
            } else {
              // move from outside into sup
              _removeNode(node);
              final at = childIndex!.clamp(
                  0, sup.children.length);
              sup.children.insert(at, node);
            }
            _updateSupersetName(sup);
          } else {
            // top‑level reorder/ungroup
            _removeNode(node);
            items.insert(index.clamp(0, items.length), node);
          }
        });
      },
      builder: (ctx, cand, rej) => Container(
        height: cand.isNotEmpty ? 20 : 6,
        color: cand.isNotEmpty
            ? Colors.blueAccent.withOpacity(0.3)
            : null,
      ),
    );
  }

  /// Wraps a node in a LongPressDraggable.
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

  /// Builds a tile for a leaf or superset; hides child‑leaf sets if insideSup.
  Widget _buildNodeTile(ExerciseNode node,
      {bool insideSup = false}) {
    if (node is Superset) {
      final supIndex = items.indexOf(node);
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
            // Superset header
            DragTarget<ExerciseNode>(
              onWillAccept: (d) => d is ExerciseLeaf,
              onAccept: (d) {
                setState(() {
                  _removeNode(d);
                  node.children.add(d as ExerciseLeaf);
                  _updateSupersetName(node);
                });
              },
              builder: (ctx, cand, rej) => Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(node.name,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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

            // Children + gaps
            for (int j = 0; j <= node.children.length; j++) ...[
              _buildGap(supIndex + 1 + j,
                  sup: node, childIndex: j),
              if (j < node.children.length)
                _buildDraggable(node.children[j],
                    insideSup: true),
            ],

            // Editable superset sets
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
                      setState(() =>
                      node.sets = int.tryParse(v) ?? node.sets);
                      _updateSupersetName(node);
                    },
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 4, horizontal: 4),
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
      // Standalone leaf (also drop target for new superset)
      final leaf = node as ExerciseLeaf;
      final displayText = insideSup
          ? leaf.summary.replaceAll(RegExp(r' x \d+ sets'), '')
          : leaf.summary;
      return Container(
        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: DragTarget<ExerciseNode>(
          onWillAccept: (d) => d is ExerciseLeaf && d.id != leaf.id,
          onAccept: (d) {
            setState(() {
              final idx = items.indexOf(leaf);
              _removeNode(d);
              _removeNode(leaf);
              final newSup = Superset(
                  'sup${supersetCounter}',
                  'Superset ${supersetCounter}',
                  children: [d as ExerciseLeaf, leaf]);
              supersetCounter++;
              _updateSupersetName(newSup);
              items.insert(idx.clamp(0, items.length), newSup);
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
            child: Row(
              children: [
                Icon(displayText.toLowerCase().contains(' in ')
                    ? Icons.directions_run
                    : Icons.fitness_center),
                SizedBox(width: 12),
                Expanded(child: Text(displayText)),
                PopupMenuButton<String>(
                  onSelected: (v) {
                    if (v == 'edit') _editNode(leaf);
                    else _deleteNode(leaf);
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
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    // Date navigation
    rows.add(Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () => setState(() =>
            selectedDate = selectedDate.subtract(Duration(days: 1))),
          ),
          Text(_friendly(selectedDate),
              style: TextStyle(fontSize: 18)),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: () => setState(() =>
            selectedDate = selectedDate.add(Duration(days: 1))),
          ),
        ],
      ),
    ));
    rows.add(Divider());

    // Build gaps + draggable items
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
              final pick = await Navigator.push<DateTime>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CalendarScreen(exercisesPerDay: {}),
                ),
              );
              if (pick != null) setState(() => selectedDate = pick);
            },
          ),
          Spacer(),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      SettingsScreen(settings: widget.settings)),
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

// --- Settings controller ---
class Settings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  WeightUnit weightUnit = WeightUnit.metric;
  CardioUnit cardioUnit = CardioUnit.km;

  void toggleTheme(bool isDark) {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setWeightUnit(WeightUnit u) {
    weightUnit = u;
    notifyListeners();
  }

  void setCardioUnit(CardioUnit u) {
    cardioUnit = u;
    notifyListeners();
  }
}
