import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'settings_screen.dart';
import 'calendar_screen.dart';

void main() {
  runApp(GymTrackerApp());
}

enum WeightUnit { metric, imperial }
enum CardioUnit { km, miles, feet }

class Settings extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.light;
  WeightUnit weightUnit = WeightUnit.metric;
  CardioUnit cardioUnit = CardioUnit.km;

  void toggleTheme(bool isDark) {
    themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }

  void setWeightUnit(WeightUnit unit) {
    weightUnit = unit;
    notifyListeners();
  }

  void setCardioUnit(CardioUnit unit) {
    cardioUnit = unit;
    notifyListeners();
  }
}

class GymTrackerApp extends StatefulWidget {
  @override
  State<GymTrackerApp> createState() => _GymTrackerAppState();
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

class MainScreen extends StatefulWidget {
  final Settings settings;
  const MainScreen({Key? key, required this.settings}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime selectedDate = DateTime.now();
  final Map<String, List<String>> exercisesPerDay = {};
  final Set<String> previousExerciseNames = {};

  void _changeDay(int offset) {
    setState(() {
      selectedDate = selectedDate.add(Duration(days: offset));
    });
  }

  String _dateKey(DateTime date) =>
      DateFormat('yyyy-MM-dd').format(date);

  String _getFriendlyDateLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(date.year, date.month, date.day);
    final diff = target.difference(today).inDays;
    if (diff == 0) return "Today";
    if (diff == -1) return "Yesterday";
    if (diff == 1) return "Tomorrow";
    return DateFormat('MMM d').format(date);
  }

  void _addExercise() async {
    final summary = await _showAddExerciseDialog(context);
    if (summary != null && summary.isNotEmpty) {
      final key = _dateKey(selectedDate);
      final name = summary.split(" - ").first;
      setState(() {
        exercisesPerDay.putIfAbsent(key, () => []).add(summary);
        previousExerciseNames.add(name);
      });
    }
  }

  Future<String?> _showAddExerciseDialog(BuildContext context) async {
    String? selectedType;
    final nameController = TextEditingController();
    final weightController = TextEditingController();
    final setsController = TextEditingController();
    final distanceController = TextEditingController();
    final timeController = TextEditingController();

    final weightUnit = widget.settings.weightUnit;
    final cardioUnit = widget.settings.cardioUnit;

    return showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text("Add Exercise"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedType,
                  hint: Text("Select type"),
                  isExpanded: true,
                  items: ["Weightlifting", "Cardio"]
                      .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) =>
                      setState(() => selectedType = val),
                ),
                SizedBox(height: 10),
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    if (textEditingValue.text == '') {
                      return const Iterable<String>.empty();
                    }
                    return previousExerciseNames.where((option) =>
                        option.toLowerCase().contains(
                            textEditingValue.text.toLowerCase()));
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    controller.text = nameController.text;
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration:
                      InputDecoration(labelText: "Exercise Name"),
                      onChanged: (val) =>
                      nameController.text = val,
                    );
                  },
                  onSelected: (selection) {
                    nameController.text = selection;
                  },
                ),
                if (selectedType == "Weightlifting") ...[
                  TextField(
                    controller: weightController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                      "Weight (${weightUnit == WeightUnit.metric ? "kg" : "lbs"})",
                    ),
                  ),
                  TextField(
                    controller: setsController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: "Sets"),
                  ),
                ],
                if (selectedType == "Cardio") ...[
                  TextField(
                    controller: distanceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText:
                      "Distance (${cardioUnit == CardioUnit.km ? "km" : cardioUnit == CardioUnit.miles ? "miles" : "feet"})",
                    ),
                  ),
                  TextField(
                    controller: timeController,
                    decoration:
                    InputDecoration(labelText: "Time (e.g. 30 min)"),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (selectedType == null ||
                    nameController.text.trim().isEmpty) {
                  Navigator.pop(context, null);
                  return;
                }
                final name = nameController.text.trim();
                String summary = "";
                if (selectedType == "Weightlifting") {
                  final weight = weightController.text;
                  final sets = setsController.text;
                  summary =
                  "$name - ${weight}${weightUnit == WeightUnit.metric ? "kg" : "lbs"} x ${sets} sets";
                } else {
                  final dist = distanceController.text;
                  final time = timeController.text;
                  final unitLabel = cardioUnit == CardioUnit.km
                      ? "km"
                      : cardioUnit == CardioUnit.miles
                      ? "miles"
                      : "ft";
                  summary = "$name - ${dist}$unitLabel in $time";
                }
                Navigator.pop(context, summary);
              },
              child: Text("Add"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _dateKey(selectedDate);
    final exercises = exercisesPerDay[key] ?? [];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            IconButton(
              icon: Icon(Icons.calendar_today),
              onPressed: () async {
                final picked = await Navigator.push<DateTime?>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CalendarScreen(
                        exercisesPerDay: exercisesPerDay),
                  ),
                );
                if (picked != null) {
                  setState(() {
                    selectedDate = picked;
                  });
                }
              },
            ),
            Spacer(),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        SettingsScreen(settings: widget.settings),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
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
                  _getFriendlyDateLabel(selectedDate),
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
          Expanded(
            child: exercises.isEmpty
                ? Center(child: Text("No exercises yet. Tap + to add."))
                : ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = exercises.removeAt(oldIndex);
                  exercises.insert(newIndex, item);
                });
              },
              children: [
                for (var i = 0; i < exercises.length; i++)
                  ListTile(
                    key: ValueKey('$key-$i-${exercises[i]}'),
                    leading: exercises[i].toLowerCase().contains(' in ')
                        ? Icon(Icons.directions_run)
                        : Icon(Icons.fitness_center),
                    title: Text(exercises[i]),
                    trailing: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        setState(() {
                          exercises.removeAt(i);
                        });
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExercise,
        child: Icon(Icons.add),
        tooltip: "Add Exercise",
      ),
    );
  }
}
