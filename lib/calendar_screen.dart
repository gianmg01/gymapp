import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatelessWidget {
  final Map<String, List<String>> exercisesPerDay;
  final DateTime today = DateTime.now();

  CalendarScreen({super.key, required this.exercisesPerDay});

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  bool _hasExercises(DateTime day) {
    final key = DateFormat('yyyy-MM-dd').format(day);
    return exercisesPerDay.containsKey(key) && exercisesPerDay[key]!.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

    final List<Widget> dayWidgets = [];

    // Weekday offset (to align start)
    final int startWeekday = firstDayOfMonth.weekday % 7;
    for (int i = 0; i < startWeekday; i++) {
      dayWidgets.add(Container());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final currentDate = DateTime(now.year, now.month, day);
      final isToday = _isSameDay(currentDate, today);
      final hasExercises = _hasExercises(currentDate);

      dayWidgets.add(
        Container(
          margin: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isToday
                ? Colors.blueAccent
                : hasExercises
                ? Colors.green.withOpacity(0.2)
                : null,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isToday
                  ? Colors.blue
                  : hasExercises
                  ? Colors.green
                  : Colors.grey.shade300,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              color: isToday ? Colors.white : null,
              fontWeight: hasExercises ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(DateFormat('MMMM yyyy').format(now))),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 7,
          children: dayWidgets,
        ),
      ),
    );
  }
}
