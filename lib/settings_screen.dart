import 'package:flutter/material.dart';
import 'main.dart'; // for Settings, WeightUnit, CardioUnit

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final VoidCallback onFindReplace;
  final VoidCallback onFindRemove;
  final VoidCallback onDeleteAll;

  const SettingsScreen({
    super.key,
    required this.settings,
    required this.onFindReplace,
    required this.onFindRemove,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final sectionStyle = Theme.of(context)
        .textTheme
        .headline6
        ?.copyWith(fontWeight: FontWeight.bold);
    final labelStyle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          // Display section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text("Display", style: sectionStyle),
          ),
          Divider(thickness: 2),
          SwitchListTile(
            title: Text("Dark Mode", style: labelStyle),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (val) => settings.toggleTheme(val),
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Weightlifting Units", style: labelStyle),
          ),
          DropdownButton<WeightUnit>(
            value: settings.weightUnit,
            onChanged: (val) {
              if (val != null) settings.setWeightUnit(val);
            },
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: WeightUnit.metric,
                child: Text("Metric (kg)"),
              ),
              DropdownMenuItem(
                value: WeightUnit.imperial,
                child: Text("Imperial (lbs)"),
              ),
            ],
          ),
          Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text("Cardio Units", style: labelStyle),
          ),
          DropdownButton<CardioUnit>(
            value: settings.cardioUnit,
            onChanged: (val) {
              if (val != null) settings.setCardioUnit(val);
            },
            isExpanded: true,
            items: [
              DropdownMenuItem(
                value: CardioUnit.km,
                child: Text("Metric (km)"),
              ),
              DropdownMenuItem(
                value: CardioUnit.miles,
                child: Text("Imperial (miles)"),
              ),
              DropdownMenuItem(
                value: CardioUnit.feet,
                child: Text("Imperial (feet)"),
              ),
            ],
          ),
          Divider(thickness: 2),

          // Manage Data section
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text("Manage Data", style: sectionStyle),
          ),
          Divider(thickness: 2),
          ListTile(
            title: Text("Find & Replace", style: labelStyle),
            onTap: onFindReplace,
          ),
          Divider(),
          ListTile(
            title: Text("Find & Remove", style: labelStyle),
            onTap: onFindRemove,
          ),
          Divider(),
          ListTile(
            title: Text("Delete All Data", style: labelStyle?.copyWith(color: Colors.red)),
            onTap: onDeleteAll,
          ),
          Divider(),
        ],
      ),
    );
  }
}
