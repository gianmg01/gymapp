import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  final Map<String, List<String>> exercisesPerDay;
  const CalendarScreen({super.key, required this.exercisesPerDay});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime displayedMonth = DateTime.now();
  final DateTime today = DateTime.now();

  // Filter state
  bool _showWeight = true;
  bool _showCardio = true;
  Color _weightColor = Colors.blue;
  Color _cardioColor = Colors.orange;
  late Map<String, bool> _showExercise;
  late Map<String, Color> _exerciseColor;

  @override
  void initState() {
    super.initState();
    _initExerciseFilters();
  }

  void _initExerciseFilters() {
    final names = <String>{};
    widget.exercisesPerDay.values.forEach((list) {
      for (var summary in list) {
        final firstLine = summary.split('\n').first;
        final name = firstLine.split(' - ').first.trim();
        names.add(name);
      }
    });
    _showExercise = {for (var n in names) n: false};
    _exerciseColor = {for (var n in names) n: Colors.green};
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hasWeight(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final list = widget.exercisesPerDay[key];
    if (list == null) return false;
    return list.any((s) => s.toLowerCase().contains('sets'));
  }

  bool _hasCardio(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final list = widget.exercisesPerDay[key];
    if (list == null) return false;
    return list.any((s) => s.toLowerCase().contains(' in '));
  }

  Widget _buildDot(Color color) => Container(
    margin: EdgeInsets.symmetric(horizontal: 1, vertical: 2),
    width: 6,
    height: 6,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  List<Widget> _buildCalendarDays() {
    final year = displayedMonth.year;
    final month = displayedMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startOffset = first.weekday % 7;

    final cells = <Widget>[];

    // Weekday headers
    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (var wd in weekDays) {
      cells.add(Center(child: Text(wd, style: TextStyle(fontWeight: FontWeight.bold))));
    }
    // Leading empty cells
    for (int i = 0; i < startOffset; i++) cells.add(Container());

    for (int d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final isToday = _isSameDay(date, today);
      final w = _hasWeight(date);
      final c = _hasCardio(date);
      final key = DateFormat('yyyy-MM-dd').format(date);
      final dayList = widget.exercisesPerDay[key] ?? [];

      // Build dots based on filters
      final dots = <Widget>[];
      if (_showWeight && w) dots.add(_buildDot(_weightColor));
      if (_showCardio && c) dots.add(_buildDot(_cardioColor));
      _showExercise.forEach((name, enabled) {
        if (enabled) {
          final found = dayList.any((summary) {
            final base = summary.split('\n').first.split(' - ').first.trim();
            return base == name;
          });
          if (found) dots.add(_buildDot(_exerciseColor[name]!));
        }
      });

      cells.add(GestureDetector(
        onTap: () => Navigator.pop(context, date),
        child: Container(
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isToday ? Colors.blueAccent : null,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$d',
                  style: TextStyle(
                      color: isToday ? Colors.white : null, fontWeight: FontWeight.w500)),
              if (dots.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: dots),
                ),
            ],
          ),
        ),
      ));
    }

    return cells;
  }

  void _changeMonth(int delta) {
    setState(() {
      displayedMonth =
          DateTime(displayedMonth.year, displayedMonth.month + delta, 1);
    });
  }

  Future<void> _showFilterDialog() async {
    await showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c2, setSt) => AlertDialog(
          title: Text('Calendar Filters'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Weightlifting
              Row(children: [
                Checkbox(value: _showWeight, onChanged: (v) => setSt(() => _showWeight = v!)),
                Text('Weightlifting'),
                Spacer(),
                GestureDetector(
                  onTap: () async {
                    final col = await _pickColor(_weightColor);
                    if (col != null) setSt(() => _weightColor = col);
                  },
                  child: CircleAvatar(backgroundColor: _weightColor, radius: 10),
                ),
              ]),
              // Cardio
              Row(children: [
                Checkbox(value: _showCardio, onChanged: (v) => setSt(() => _showCardio = v!)),
                Text('Cardio'),
                Spacer(),
                GestureDetector(
                  onTap: () async {
                    final col = await _pickColor(_cardioColor);
                    if (col != null) setSt(() => _cardioColor = col);
                  },
                  child: CircleAvatar(backgroundColor: _cardioColor, radius: 10),
                ),
              ]),
              Divider(),
              // Individual exercises
              Text('Exercises', style: TextStyle(fontWeight: FontWeight.bold)),
              for (var name in _showExercise.keys)
                Row(children: [
                  Checkbox(
                      value: _showExercise[name],
                      onChanged: (v) => setSt(() => _showExercise[name] = v!)),
                  Expanded(child: Text(name)),
                  GestureDetector(
                    onTap: () async {
                      final col = await _pickColor(_exerciseColor[name]!);
                      if (col != null) setSt(() => _exerciseColor[name] = col);
                    },
                    child: CircleAvatar(backgroundColor: _exerciseColor[name], radius: 10),
                  ),
                ]),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(c2), child: Text('Done'))],
        ),
      ),
    );
    setState(() {}); // refresh after filters change
  }

  Future<Color?> _pickColor(Color current) {
    const preset = [
      Colors.red,
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.purple,
      Colors.teal
    ];
    return showDialog<Color>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Pick a color'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: preset
              .map((c0) => GestureDetector(
            onTap: () => Navigator.pop(context, c0),
            child: CircleAvatar(backgroundColor: c0),
          ))
              .toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(displayedMonth);

    return Scaffold(
      appBar: AppBar(
        title: SizedBox.shrink(),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(icon: Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
              SizedBox(width: 8),
              Text(monthLabel, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
              SizedBox(width: 8),
              IconButton(icon: Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
            ]),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.count(crossAxisCount: 7, children: _buildCalendarDays()),
            ),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: TextButton.icon(
              icon: Icon(Icons.filter_list),
              label: Text('Filters'),
              onPressed: _showFilterDialog,
            ),
          ),
        ],
      ),
    );
  }
}
