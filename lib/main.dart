import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // For date formatting

import 'settings_screen.dart';
import 'calendar_screen.dart';

// Enums for unit preferences
enum WeightUnit { metric, imperial }
enum CardioUnit { km, miles, feet }

typedef ExerciseItem = dynamic; // Can be ExerciseLeaf or Superset

// Represents a single exercise entry with summary text
class ExerciseLeaf {
  String summary; // E.g., "Squats - 100kg x 4 sets"
  ExerciseLeaf(this.summary);
}

// Represents a superset grouping multiple exercises
class Superset {
  String name;               // Superset title
  int sets;                  // Total sets for the superset
  List<ExerciseLeaf> children; // Exercises in this superset
  Superset({required this.name, required this.children, this.sets = 1});
}

void main() => runApp(GymTrackerApp()); // Entry point

// Settings controller for theme and unit preferences
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

// Root widget that rebuilds on settings changes
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

// Main screen showing exercises for a selected date
class MainScreen extends StatefulWidget {
  final Settings settings;
  const MainScreen({Key? key, required this.settings}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime selectedDate = DateTime.now();
  final Map<String, List<ExerciseItem>> exercisesPerDay = {};
  final Set<String> previousNames = {};
  int supersetCounter = 1;

  // Helper: format date to 'yyyy-MM-dd'
  String _dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  // Friendly label for date navigation
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

  // Change selected day by offset
  void _changeDay(int off) => setState(() => selectedDate = selectedDate.add(Duration(days: off)));

  // Show dialog to add a new exercise, returns summary string
  Future<String?> _showAdd({ExerciseLeaf? existing, int? currentSets, bool isSuperset = false}) async {
    String? type;
    final nameCtrl = TextEditingController(text: existing?.summary.split(' - ').first ?? '');
    final weightCtrl = TextEditingController();
    final setsCtrl = TextEditingController(text: currentSets?.toString() ?? '');
    final distCtrl = TextEditingController();
    final timeCtrl = TextEditingController();
    final wU = widget.settings.weightUnit;
    final cU = widget.settings.cardioUnit;

    // Pre-populate based on existing summary
    if (existing != null) {
      final parts = existing.summary.split(' - ');
      if (parts.length == 2) {
        nameCtrl.text = parts[0];
        final rest = parts[1];
        if (rest.contains('sets')) {
          type = 'Weightlifting';
          final match = RegExp(r'(\d+)(kg|lbs) x (\d+) sets').firstMatch(rest);
          if (match != null) {
            weightCtrl.text = match.group(1)!;
            setsCtrl.text = match.group(3)!;
          }
        } else if (rest.contains('in')) {
          type = 'Cardio';
          final match = RegExp(r'(\d+)(km|miles|feet) in (.+)').firstMatch(rest);
          if (match != null) {
            distCtrl.text = match.group(1)!;
            timeCtrl.text = match.group(3)!;
          }
        }
      }
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (cst, setSt) => AlertDialog(
          title: Text(existing != null ? 'Edit Exercise' : 'Add Exercise'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Select type
              DropdownButton<String>(
                value: type,
                hint: Text('Type'),
                isExpanded: true,
                items: ['Weightlifting', 'Cardio']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setSt(() => type = v),
              ),
              SizedBox(height: 8),
              // Name autocomplete
              Autocomplete<String>(
                optionsBuilder: (te) {
                  if (te.text.isEmpty) return const [];
                  return previousNames.where((o) =>
                      o.toLowerCase().contains(te.text.toLowerCase()));
                },
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
              // Weightlifting inputs
              if (type == 'Weightlifting') ...[
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Weight (${wU == WeightUnit.metric ? 'kg' : 'lbs'})',
                  ),
                ),
                TextField(
                  controller: setsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Sets'),
                ),
              ],
              // Cardio inputs
              if (type == 'Cardio') ...[
                TextField(
                  controller: distCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Distance (${cU == CardioUnit.km ? 'km' : cU == CardioUnit.miles ? 'miles' : 'feet'})',
                  ),
                ),
                TextField(
                  controller: timeCtrl,
                  decoration: InputDecoration(labelText: 'Time (e.g. 30 min)'),
                ),
              ],
            ]),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (type == null || nameCtrl.text.trim().isEmpty) {
                  Navigator.pop(ctx, null);
                  return;
                }
                final name = nameCtrl.text.trim();
                String sum;
                if (type == 'Weightlifting') {
                  sum = '$name - ${weightCtrl.text}${wU == WeightUnit.metric ? 'kg' : 'lbs'} x ${setsCtrl.text} sets';
                } else {
                  final unit = cU == CardioUnit.km
                      ? 'km'
                      : cU == CardioUnit.miles
                      ? 'miles'
                      : 'feet';
                  sum = '$name - ${distCtrl.text}$unit in ${timeCtrl.text}';
                }
                Navigator.pop(ctx, sum);
              },
              child: Text(existing != null ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  // Add exercise to the list
  void _add() async {
    final sum = await _showAdd();
    if (sum != null && sum.isNotEmpty) {
      final k = _dateKey(selectedDate);
      setState(() {
        exercisesPerDay.putIfAbsent(k, () => []);
        exercisesPerDay[k]!.add(ExerciseLeaf(sum));
        previousNames.add(sum.split(' - ').first);
      });
    }
  }

  // Edit an existing leaf item
  void _editLeaf(ExerciseLeaf item, int idx, List<ExerciseItem> list) async {
    final newSum = await _showAdd(existing: item);
    if (newSum != null && newSum.isNotEmpty) {
      setState(() {
        list[idx] = ExerciseLeaf(newSum);
        previousNames.add(newSum.split(' - ').first);
      });
    }
  }

  // Build each item: either a single exercise or a superset
  Widget _buildItem(ExerciseItem item, int idx, List<ExerciseItem> list) {
    // Single exercise: draggable and deletable/editable
    if (item is ExerciseLeaf) {
      return LongPressDraggable<ExerciseLeaf>(
        key: ValueKey(item.summary + idx.toString()),
        data: item,
        feedback: Material(
          child: Container(
            padding: EdgeInsets.all(8),
            color: Colors.grey.shade200,
            child: Text(item.summary),
          ),
        ),
        child: DragTarget<ExerciseLeaf>(
          onWillAccept: (d) => d != item,
          onAccept: (d) {
            // Combine into a superset on drop
            setState(() {
              list.remove(d);
              list.remove(item);
              final sup = Superset(
                name: 'Superset ${supersetCounter}',
                children: [d, item],
              );
              supersetCounter++;
              list.insert(idx, sup);
            });
          },
          builder: (context, candidate, reject) => ListTile(
            leading: item.summary.toLowerCase().contains(' in ')
                ? Icon(Icons.directions_run)
                : Icon(Icons.fitness_center),
            title: Text(item.summary),
            trailing: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'edit') {
                  _editLeaf(item, idx, list);
                } else if (val == 'delete') {
                  setState(() => list.removeAt(idx));
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [Icon(Icons.edit, color: Colors.white), SizedBox(width: 8), Text('Edit')]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text('Delete')]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Superset: box with indented exercises, edit button, and editable sets count
    if (item is Superset) {
      final setsCtrl = TextEditingController(text: item.sets.toString());
      return Container(
        key: ValueKey(item.name + idx.toString()),
        margin: EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name and edit button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item.name,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(Icons.edit),
                  onPressed: () {
                    // Rename superset dialog
                    showDialog(
                      context: context,
                      builder: (c) {
                        final ctrl = TextEditingController(text: item.name);
                        return AlertDialog(
                          title: Text('Rename Superset'),
                          content: TextField(controller: ctrl),
                          actions: [
                            TextButton(
                              onPressed: () {
                                setState(() => item.name = ctrl.text);
                                Navigator.pop(c);
                              },
                              child: Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            ),
            // Indented exercise list
            Padding(
              padding: EdgeInsets.only(left: 16),
              child: Column(
                children: item.children.map((ch) {
                  return ListTile(
                    leading: ch.summary.toLowerCase().contains(' in ')
                        ? Icon(Icons.directions_run)
                        : Icon(Icons.fitness_center),
                    title: Text(
                      ch.summary.replaceAll(RegExp(r' x \d+ sets'), ''),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => setState(() {
                        item.children.remove(ch);
                        if (item.children.isEmpty) list.remove(item);
                      }),
                    ),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ),
            SizedBox(height: 8),
            // Editable sets count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Number of sets:'),
                SizedBox(width: 8),
                Container(
                  width: 50,
                  child: TextField(
                    controller: setsCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onSubmitted: (v) {
                      setState(() { item.sets = int.tryParse(v) ?? item.sets; });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Fallback
    return Container(key: ValueKey(idx));
  }

  @override
  Widget build(BuildContext context) {
    final k = _dateKey(selectedDate);
    exercisesPerDay.putIfAbsent(k, () => []);
    final list = exercisesPerDay[k]!;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () async {
                final pick = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CalendarScreen(exercisesPerDay: exercisesPerDay
                          .map((key, items) => MapEntry(
                          key,
                          items.whereType<ExerciseLeaf>().map((e) => e.summary).toList())),
                      ),
                    )
                );
                if (pick != null && pick is DateTime) {
                  setState(() => selectedDate = pick);
                }
              },
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(settings: widget.settings),
                ),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date navigation
          Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: () => _changeDay(-1),
                ),
                Text(
                  _friendly(selectedDate),
                  style: TextStyle(fontSize: 18),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: () => _changeDay(1),
                ),
              ],
            ),
          ),
          Divider(),
          // Reorderable list
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = list.removeAt(oldIndex);
                  list.insert(newIndex, item);
                });
              },
              children: [
                for (int i = 0; i < list.length; i++)
                  _buildItem(list[i], i, list),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        child: Icon(Icons.add),
        tooltip: 'Add Exercise',
      ),
    );
  }
}
