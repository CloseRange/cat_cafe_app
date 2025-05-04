import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StoreSettingsPage extends StatefulWidget {
  const StoreSettingsPage({super.key});

  @override
  State<StoreSettingsPage> createState() => _StoreSettingsPageState();
}

class _StoreSettingsPageState extends State<StoreSettingsPage> {
  final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Map<String, bool> isOpen = {};
  Map<String, TimeOfDay?> openTime = {};
  Map<String, TimeOfDay?> closeTime = {};
  bool loading = true;

  // Global settings
  int maxPerWeek = 40;
  int maxPerDay = 10;
  int minBetweenShifts = 10;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    // Replace with your actual fetch logic
    final storeId = 1111;

    final openTimesResponse = await CRDatabase.client
        .from('store_open_times')
        .select()
        .eq('store_id', storeId);

    final settingsResponse = await CRDatabase.client
        .from('store_settings')
        .select()
        .eq('store_id', storeId)
        .single();

    for (final day in days) {
      final match = openTimesResponse.firstWhere(
        (e) => e['dow'] == day,
        orElse: () => {},
      );
      isOpen[day] = match['is_open'] ?? false;
      openTime[day] = _parseTime(match['open']);
      closeTime[day] = _parseTime(match['close']); // typo in schema noted
    }

    setState(() {
      maxPerWeek = settingsResponse['max_hours_per_week'] ?? 40;
      maxPerDay = settingsResponse['max_hours_per_day'] ?? 10;
      minBetweenShifts = settingsResponse['time_between_shifts'] ?? 10;
      loading = false;
    });
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null) return null;
    final dt = DateFormat("HH:mm:ss").parse(timeStr);
    return TimeOfDay.fromDateTime(dt);
  }


  Future<void> _save() async {
    final storeId = 1111;

    for (final day in days) {
      await CRDatabase.client
          .from('store_open_times')
          .upsert({
            'store_id': storeId,
            'dow': day,
            'is_open': isOpen[day] ?? false,
            'open': openTime[day]?.format(context),
            'close': closeTime[day]?.format(context),
          }, onConflict: 'store_id,dow');
    }

    await CRDatabase.client
        .from('store_settings')
        .upsert({
          'store_id': storeId,
          'max_hours_per_week': maxPerWeek,
          'max_hours_per_day': maxPerDay,
          'time_between_shifts': minBetweenShifts,
        });

    showSimpleSuccess(context, "Settings updated!");
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());

    return CRAppBar(
      title: "Store Settings",
      surfaceVarient: true,
      scrollable: false,
      backButton: true,

      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Weekly Open Times", style: TextStyle(fontWeight: FontWeight.bold)),
          ...days.map((day) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    title: Text(day),
                    value: isOpen[day] ?? false,
                    onChanged: (val) => setState(() => isOpen[day] = val),
                  ),
                  if (isOpen[day] ?? false)
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            title: const Text("Open"),
                            subtitle: Text(openTime[day]?.format(context) ?? "--:--"),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: openTime[day] ?? const TimeOfDay(hour: 9, minute: 0),
                              );
                              if (picked != null) setState(() => openTime[day] = picked);
                            },
                          ),
                        ),
                        Expanded(
                          child: ListTile(
                            title: const Text("Close"),
                            subtitle: Text(closeTime[day]?.format(context) ?? "--:--"),
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: closeTime[day] ?? const TimeOfDay(hour: 17, minute: 0),
                              );
                              if (picked != null) setState(() => closeTime[day] = picked);
                            },
                          ),
                        ),
                      ],
                    ),
                  const Divider(),
                ],
              )),
          const SizedBox(height: 24),
          const Text("Rules", style: TextStyle(fontWeight: FontWeight.bold)),
          ListTile(
            title: const Text("Max Hours / Week"),
            subtitle: Text("$maxPerWeek hours"),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editIntDialog("Max Hours Per Week", maxPerWeek, (val) {
                setState(() => maxPerWeek = val);
              }),
            ),
          ),
          ListTile(
            title: const Text("Max Hours / Day"),
            subtitle: Text("$maxPerDay hours"),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editIntDialog("Max Hours Per Day", maxPerDay, (val) {
                setState(() => maxPerDay = val);
              }),
            ),
          ),
          ListTile(
            title: const Text("Min Hours Between Shifts"),
            subtitle: Text("$minBetweenShifts hours"),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _editIntDialog("Time Between Shifts", minBetweenShifts, (val) {
                setState(() => minBetweenShifts = val);
              }),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text("Save Settings"),
            onPressed: _save,
          )
        ],
      ),
    );
  }

  Future<void> _editIntDialog(String title, int currentValue, void Function(int) onSave) async {
    final controller = TextEditingController(text: currentValue.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: "Enter value"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
              child: const Text("Save")),
        ],
      ),
    );
    if (result != null) onSave(result);
  }
}
