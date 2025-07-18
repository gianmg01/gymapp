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
  ExerciseLeaf(this.summary) : super(DateTime.now().toIso8601String());
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

// --- MainScreen w/ drag/drop ---
class MainScreen extends StatefulWidget {
  final Settings settings;
  const MainScreen({Key? key, required this.settings}) : super(key: key);
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  DateTime selectedDate = DateTime.now();
  List<ExerciseNode> items = [];
  int supersetCounter = 1;

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

  void _deleteNode(ExerciseNode node) =>
      setState(() => _removeNode(node));

  Future<void> _editNode(ExerciseNode node) async {
    if (node is ExerciseLeaf) {
      final newSum = await _showAdd(existing: node.summary);
      if (newSum != null) {
        setState(() => node.summary = newSum);
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
                child: Text('OK'))
          ],
        ),
      );
      if (renamed != null && renamed.isNotEmpty) {
        setState(() => node.name = renamed);
      }
    }
  }

  Future<String?> _showAdd({String? existing}) {
    String? type; // 'Weightlifting' or 'Cardio'
    bool dynamicReps = false, dynamicWeight = false;
    // Controllers
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    final repsCtrl = TextEditingController();
    final setsCtrl = TextEditingController();
    final dynRepsCtrl = TextEditingController();
    final dynWtsCtrl = TextEditingController();
    final distCtrl = TextEditingController();
    final timeCtrl = TextEditingController();

    // Pre-fill when editing
    if (existing != null) {
      final lines = existing.split('\n');
      final header = lines.first;
      if (header.contains(' in ')) {
        // Cardio
        type = 'Cardio';
        final parts = header.split(' - ');
        nameCtrl.text = parts[0];
        final dm = RegExp(r'([\d.]+)\s*km').firstMatch(parts[1]);
        if (dm != null) distCtrl.text = dm.group(1)!;
        final tm = RegExp(r'in (.+)$').firstMatch(header);
        if (tm != null) timeCtrl.text = tm.group(1)!;
      } else {
        // Weightlifting
        type = 'Weightlifting';
        final wtMatch = RegExp(r' - ([\d.]+)(kg|lbs)').firstMatch(
            header);
        if (wtMatch != null) weightCtrl.text = wtMatch.group(1)!;
        final namePart = header.split(' - ').first;
        nameCtrl.text = namePart;
        if (lines.length > 1) {
          // detect dynamic reps/weight
          final sample = lines[1];
          dynamicReps =
              RegExp(r'Set \d+: .* reps').hasMatch(sample);
          dynamicWeight =
              RegExp(r'Set \d+: .*?(kg|lbs)').hasMatch(sample);
          // extract per-set lists
          final entries = lines
              .sublist(1)
              .map((l) => l.split(': ')[1])
              .toList();
          if (dynamicReps) {
            dynRepsCtrl.text = entries
                .map((e) => e.replaceAll(RegExp(r'\s*reps$'), ''))
                .join('\n');
          }
          if (dynamicWeight) {
            dynWtsCtrl.text = entries
                .map((e) => e.replaceAll(RegExp(r'\s*(kg|lbs).*$'), ''))
                .join('\n');
          }
          // static reps/sets not shown when dynamicReps
        } else {
          // static
          final rMatch =
          RegExp(r'(\d+)\s*reps').firstMatch(header);
          if (rMatch != null) repsCtrl.text = rMatch.group(1)!;
          final sMatch =
          RegExp(r'x\s*(\d+)\s*sets').firstMatch(header);
          if (sMatch != null) setsCtrl.text = sMatch.group(1)!;
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
                    .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
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
                  // Weight / Dynamic weight
                  SwitchListTile(
                    title: Text('Dynamic weight'),
                    value: dynamicWeight,
                    onChanged: (v) =>
                        setSt(() => dynamicWeight = v),
                  ),
                  if (!dynamicWeight) ...[
                    TextField(
                      controller: weightCtrl,
                      keyboardType:
                      TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: InputDecoration(
                        labelText:
                        'Weight (${widget.settings.weightUnit == WeightUnit.metric ? 'kg' : 'lbs'})',
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: dynWtsCtrl,
                      decoration: InputDecoration(
                          labelText:
                          'Weight per set (one per line)'),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  ],

                  SizedBox(height: 8),
                  // Reps / Dynamic reps
                  SwitchListTile(
                    title: Text('Dynamic reps'),
                    value: dynamicReps,
                    onChanged: (v) =>
                        setSt(() => dynamicReps = v),
                  ),
                  if (!dynamicReps) ...[
                    TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                      InputDecoration(labelText: 'Reps'),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: setsCtrl,
                      keyboardType: TextInputType.number,
                      decoration:
                      InputDecoration(labelText: 'Sets'),
                    ),
                  ] else ...[
                    TextField(
                      controller: dynRepsCtrl,
                      decoration: InputDecoration(
                          labelText:
                          'Reps per set (one per line)'),
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                    ),
                  ],
                ] else ...[
                  // Cardio
                  TextField(
                    controller: distCtrl,
                    keyboardType: TextInputType.number,
                    decoration:
                    InputDecoration(labelText: 'Distance'),
                  ),
                  SizedBox(height: 8),
                  TextField(
                    controller: timeCtrl,
                    decoration:
                    InputDecoration(labelText: 'Time'),
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
                    // static
                    final wt = weightCtrl.text.trim();
                    final r = repsCtrl.text.trim();
                    final s = setsCtrl.text.trim();
                    result =
                    '$name - ${wt}${unit} - $r reps x $s sets';
                  } else {
                    // dynamic combos
                    // determine number of sets
                    List<String> wts = dynamicWeight
                        ? dynWtsCtrl.text
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty)
                        .toList()
                        : [];
                    List<String> reps = dynamicReps
                        ? dynRepsCtrl.text
                        .split('\n')
                        .map((l) => l.trim())
                        .where((l) => l.isNotEmpty)
                        .toList()
                        : [];
                    int sets = dynamicReps
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
                  // cardio
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
    }
  }

  Widget _buildGap(int idx,
      {Superset? sup, int? childIndex}) {
    return DragTarget<ExerciseNode>(
      onWillAccept: (_) => true,
      onAccept: (node) {
        setState(() {
          if (sup != null && node is ExerciseLeaf) {
            final inSup = sup.children.contains(node);
            if (inSup) {
              sup.children.remove(node);
              sup.children.insert(
                  childIndex!.clamp(0, sup.children.length),
                  node);
            } else {
              _removeNode(node);
              sup.children.insert(
                  childIndex!.clamp(0, sup.children.length),
                  node);
            }
          } else {
            _removeNode(node);
            items.insert(idx.clamp(0, items.length), node);
          }
        });
      },
      builder: (ctx, cand, rej) => Container(
        height: cand.isNotEmpty ? 20 : 6,
        color:
        cand.isNotEmpty ? Colors.blueAccent.withOpacity(0.3) : null,
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
      final i = items.indexOf(node);
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
              onAccept: (d) =>
                  setState(() { _removeNode(d); node.children.add(d as ExerciseLeaf); }),
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
                      PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width:8), Text('Edit')])),
                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width:8), Text('Delete')])),
                    ],
                  ),
                ],
              ),
            ),
            for (int j = 0; j <= node.children.length; j++) ...[
              _buildGap(i + 1 + j, sup: node, childIndex: j),
              if (j < node.children.length)
                _buildDraggable(node.children[j], insideSup: true),
            ],
            // editable sets count
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Number of sets:'),
                SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: TextField(
                    controller: TextEditingController(text: node.sets.toString()),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    onSubmitted: (v) => setState(() => node.sets = int.tryParse(v) ?? node.sets),
                    decoration: InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical:4, horizontal:4), border: OutlineInputBorder()),
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
      final rest = parts.length>1 ? parts.sublist(1) : null;
      Widget content;
      if (rest != null) {
        content = Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(header),
          for(var line in rest)
            Padding(padding: EdgeInsets.only(left:16), child: Text(line)),
        ]);
      } else {
        content = Text(header);
      }
      return Container(
          margin: EdgeInsets.symmetric(vertical:4, horizontal:12),
          child: DragTarget<ExerciseNode>(
              onWillAccept: (d) => d is ExerciseLeaf && d.id!=leaf.id,
              onAccept: (d){
                setState(() {
                  final idx = items.indexOf(leaf);
                  _removeNode(d);
                  _removeNode(leaf);
                  final sup = Superset('Superset ${supersetCounter++}', children:[d as ExerciseLeaf, leaf]);
                  items.insert(idx.clamp(0, items.length), sup);
                });
              },
              builder:(ctx,cand,rej)=>Container(
                padding:EdgeInsets.all(8),
                decoration:BoxDecoration(
                  border:Border.all(color:cand.isNotEmpty?Colors.blueAccent:Colors.grey),
                  borderRadius:BorderRadius.circular(8),
                ),
                child:Row(children:[
                  Icon(header.toLowerCase().contains(' in ')? Icons.directions_run : Icons.fitness_center),
                  SizedBox(width:12),
                  Expanded(child:content),
                  PopupMenuButton<String>(
                    onSelected:(v){
                      if(v=='edit')_editNode(leaf);
                      else _deleteNode(leaf);
                    },
                    itemBuilder:(_)=>[
                      PopupMenuItem(value:'edit',child:Row(children:[Icon(Icons.edit),SizedBox(width:8),Text('Edit')])),
                      PopupMenuItem(value:'delete',child:Row(children:[Icon(Icons.delete,color:Colors.red),SizedBox(width:8),Text('Delete')])),
                    ],
                  )
                ]),
              )
          )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows=<Widget>[];

    rows.add(Padding(padding:EdgeInsets.symmetric(vertical:8),child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[
      IconButton(icon:Icon(Icons.chevron_left),onPressed:()=>setState(()=>selectedDate=selectedDate.subtract(Duration(days:1)))),
      Text(_friendly(selectedDate),style:TextStyle(fontSize:18)),
      IconButton(icon:Icon(Icons.chevron_right),onPressed:()=>setState(()=>selectedDate=selectedDate.add(Duration(days:1)))),
    ])));
    rows.add(Divider());

    for(int i=0;i<=items.length;i++){
      rows.add(_buildGap(i));
      if(i<items.length) rows.add(_buildDraggable(items[i]));
    }

    return Scaffold(
      appBar:AppBar(automaticallyImplyLeading:false,title:Row(children:[
        IconButton(icon:Icon(Icons.calendar_today),onPressed:()async{
          final pick=await Navigator.push<DateTime>(context,MaterialPageRoute(builder:(_)=>CalendarScreen(exercisesPerDay:{})));
          if(pick!=null) setState(()=>selectedDate=pick);
        }),
        Spacer(),
        IconButton(icon:Icon(Icons.settings),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>SettingsScreen(settings:widget.settings)))),
      ])),
      body:SingleChildScrollView(child:Column(children:rows)),
      floatingActionButton:FloatingActionButton(onPressed:_add,child:Icon(Icons.add),tooltip:'Add Exercise'),
    );
  }
}

// --- Settings ---
class Settings extends ChangeNotifier {
  ThemeMode themeMode=ThemeMode.light;
  WeightUnit weightUnit=WeightUnit.metric;
  CardioUnit cardioUnit=CardioUnit.km;

  void toggleTheme(bool isDark){ themeMode=isDark?ThemeMode.dark:ThemeMode.light; notifyListeners();}
  void setWeightUnit(WeightUnit u){ weightUnit=u; notifyListeners();}
  void setCardioUnit(CardioUnit u){ cardioUnit=u; notifyListeners();}
}
