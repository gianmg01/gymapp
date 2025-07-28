import 'package:flutter/material.dart';
import 'main.dart'; // for Settings, WeightUnit, CardioUnit

class SettingsScreen extends StatelessWidget {
  final Settings settings;
  final VoidCallback onFindReplace;
  final VoidCallback onFindRemove;
  final VoidCallback onDeleteAll;

  const SettingsScreen({
    Key? key,
    required this.settings,
    required this.onFindReplace,
    required this.onFindRemove,
    required this.onDeleteAll,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Text styles pulled from the theme for consistency
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
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [

            // ── DISPLAY SECTION ───────────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Display", style: sectionStyle),
                    SizedBox(height: 12),

                    // Dark Mode
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(Icons.brightness_6),
                      title: Text("Dark Mode", style: labelStyle),
                      value: settings.themeMode == ThemeMode.dark,
                      onChanged: settings.toggleTheme,
                    ),
                    Divider(),

                    // Weightlifting Units
                    Row(
                      children: [
                        Icon(Icons.fitness_center),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text("Weightlifting Units",
                              style: labelStyle),
                        ),
                        DropdownButton<WeightUnit>(
                          value: settings.weightUnit,
                          onChanged: (val) {
                            if (val != null) settings.setWeightUnit(val);
                          },
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
                      ],
                    ),
                    Divider(),

                    // Cardio Units
                    Row(
                      children: [
                        Icon(Icons.directions_run),
                        SizedBox(width: 12),
                        Expanded(
                          child:
                          Text("Cardio Units", style: labelStyle),
                        ),
                        DropdownButton<CardioUnit>(
                          value: settings.cardioUnit,
                          onChanged: (val) {
                            if (val != null) settings.setCardioUnit(val);
                          },
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
                  ],
                ),
              ),
            ),

            SizedBox(height: 24),

            // ── MANAGE DATA SECTION ───────────────────────────────────────
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Manage Data", style: sectionStyle),
                    SizedBox(height: 12),

                    // Find & Replace
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.find_replace),
                      title: Text("Find & Replace", style: labelStyle),
                      onTap: onFindReplace,
                    ),
                    Divider(),

                    // Find & Remove
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.remove_circle_outline),
                      title: Text("Find & Remove", style: labelStyle),
                      onTap: onFindRemove,
                    ),
                    Divider(),

                    // Delete All Data
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_forever,
                          color: Theme.of(context).errorColor),
                      title: Text("Delete All Data",
                          style: labelStyle
                              ?.copyWith(color: Theme.of(context).errorColor)),
                      onTap: onDeleteAll,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
