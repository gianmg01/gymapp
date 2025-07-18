import 'package:flutter/material.dart';
import 'main.dart'; // for access to Settings, WeightUnit, CardioUnit

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: ListView(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        children: [
          SwitchListTile(
            title: Text("Dark Mode"),
            value: settings.themeMode == ThemeMode.dark,
            onChanged: (val) => settings.toggleTheme(val),
          ),
          SizedBox(height: 16),
          Text("Weightlifting Units"),
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
          SizedBox(height: 16),
          Text("Cardio Units"),
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
        ],
      ),
    );
  }
}
