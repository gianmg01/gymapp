import 'package:flutter/material.dart';
import 'main.dart'; // for Settings, WeightUnit, CardioUnit

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    // Section headers use a larger, bold style
    final sectionStyle = Theme.of(context)
        .textTheme
        .headline6
        ?.copyWith(fontWeight: FontWeight.bold);
    // Setting labels slightly smaller but still bold
    final labelStyle = Theme.of(context)
        .textTheme
        .subtitle1
        ?.copyWith(fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          // -- Section: Display --
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text("Display", style: sectionStyle),
          ),
          Divider(thickness: 2),

          // Dark Mode
          SwitchListTile(
            title: Text("Dark Mode", style: labelStyle),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (val) => settings.toggleTheme(val),
          ),
          Divider(),

          // Weightlifting Units
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

          // Cardio Units
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
          Divider(),
        ],
      ),
    );
  }
}
