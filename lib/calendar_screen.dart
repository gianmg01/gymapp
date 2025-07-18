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

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // Now flags any summary containing "sets" OR "reps"
  bool _hasWeight(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final list = widget.exercisesPerDay[key];
    if (list == null) return false;
    return list.any((s) {
      final low = s.toLowerCase();
      return low.contains('sets') || low.contains('reps');
    });
  }

  bool _hasCardio(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    final list = widget.exercisesPerDay[key];
    if (list == null) return false;
    return list.any((s) => s.toLowerCase().contains(' in '));
  }

  List<Widget> _buildCalendarDays() {
    final year = displayedMonth.year;
    final month = displayedMonth.month;
    final first = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);
    final startOffset = first.weekday % 7;
    List<Widget> cells = [];

    const weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    for (var wd in weekDays) {
      cells.add(Center(
        child: Text(wd, style: TextStyle(fontWeight: FontWeight.bold)),
      ));
    }
    for (var i = 0; i < startOffset; i++) cells.add(Container());

    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      final isToday = _isSameDay(date, today);
      final w = _hasWeight(date);
      final c = _hasCardio(date);

      cells.add(
        GestureDetector(
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
                Text(
                  '$d',
                  style: TextStyle(
                    color: isToday ? Colors.white : null,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (w || c)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (w)
                        Container(
                          margin:
                          EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (c)
                        Container(
                          margin:
                          EdgeInsets.symmetric(horizontal: 1, vertical: 2),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }
    return cells;
  }

  void _changeMonth(int delta) {
    setState(() {
      displayedMonth =
          DateTime(displayedMonth.year, displayedMonth.month + delta, 1);
    });
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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(monthLabel,
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
                IconButton(
                  icon: Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 7,
          children: _buildCalendarDays(),
        ),
      ),
    );
  }
}
