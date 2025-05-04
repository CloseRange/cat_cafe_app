import 'package:cat_cafe_mobile/pages/shifts/weekly_schedule_stats_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ManagerSchedulePage extends StatefulWidget {
  final DateTime startOfWeek;
  const ManagerSchedulePage({super.key, required this.startOfWeek});

  @override
  State<ManagerSchedulePage> createState() => _ManagerSchedulePageState();
}

class _ManagerSchedulePageState extends State<ManagerSchedulePage> {
  late DateTime _selectedWeekStart;
  Map<String, List<Map<String, dynamic>>> dailyShifts = {};
  bool loading = true;

  Map<String, dynamic>? storeSettings;
  Map<String, Map<String, dynamic>> openTimes = {};

  @override
  void initState() {
    super.initState();
    _selectedWeekStart = DateTime(
      widget.startOfWeek.year,
      widget.startOfWeek.month,
      widget.startOfWeek.day,
    );
    _loadShiftsForWeek();
    _loadStoreHours();
  }

  List<DateTime> get _weekDays {
    return List.generate(7, (i) => _selectedWeekStart.add(Duration(days: i)));
  }

  Future<void> _loadShiftsForWeek() async {
    setState(() => loading = true);
    try {
      final endOfWeek = _selectedWeekStart.add(const Duration(days: 6));
      final response = await CRDatabase.client
          .from('shifts')
          .select('*, profiles!inner(first_name, last_name, role)')
          .gte('date', _selectedWeekStart.toIso8601String().substring(0, 10))
          .lte('date', endOfWeek.toIso8601String().substring(0, 10))
          .order('start_time', ascending: true);

      final List<Map<String, dynamic>> shifts =
          List<Map<String, dynamic>>.from(response);
      final grouped = <String, List<Map<String, dynamic>>>{};

      for (var shift in shifts) {
        final date = shift['date'];
        grouped.putIfAbsent(date, () => []).add(shift);
      }

      setState(() {
        dailyShifts = grouped;
        loading = false;
      });
    } catch (e) {
      debugPrint("Error fetching shifts: $e");
      setState(() => loading = false);
    }
  }

  Future<void> _loadStoreHours() async {
    final response = await CRDatabase.client
        .from('store_open_times')
        .select()
        .eq('store_id', 1111); // Replace with dynamic store_id if needed

    final result = Map<String, Map<String, dynamic>>.fromIterable(
      response,
      key: (e) => (e['dow'] as String).toLowerCase(),
      value: (e) => e,
    );

    setState(() {
      openTimes = result;
    });
  }

  String _storeHoursLabel(DateTime date) {
    final dow = DateFormat('EEE').format(date).toLowerCase();
    final entry = openTimes[dow];

    if (entry == null || entry['is_open'] == false) return 'Closed';

    final open = entry['open']?.toString();
    final close = entry['close']?.toString();

    if (open == null || close == null) return '--';

    final openTime = DateFormat.Hms().parseLoose(open);
    final closeTime = DateFormat.Hms().parseLoose(close);

    final openFormatted = DateFormat.jm().format(openTime);   // e.g. 9:00 AM
    final closeFormatted = DateFormat.jm().format(closeTime); // e.g. 5:00 PM

    return "$openFormatted – $closeFormatted";
  }

  String _formatTime(String time) {
    final parsed = DateFormat("HH:mm:ss").parse(time);
    return DateFormat.jm().format(parsed);
  }

  void _addShift(DateTime date) async {
    Map<String, dynamic>? profile = await showEmployeePicker(context, 1111);
    if (profile == null) return;
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEditShiftModal(date: date, profile: profile),
    );

    if (result == true) {
      _loadShiftsForWeek(); // Refresh after adding
    }
  }

  void _editShift(Map<String, dynamic> shift, DateTime day) async {
    final result = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AddEditShiftModal(
        shift: shift,
        date: day,
      ),
    );

    if (result == true) {
      _loadShiftsForWeek(); // Refresh after editing
    }
  }

  @override
  Widget build(BuildContext context) {
    return CRAppBar(
      title:
          "Editing ${DateFormat('MMM d').format(_selectedWeekStart)}-${DateFormat('MMM d').format(_selectedWeekStart.add(const Duration(days: 6)))}",
      scrollable: false,
      surfaceVarient: true,
      backButton: true,
      action: IconButton(
        icon: const Icon(Icons.bar_chart),
        tooltip: "View Weekly Stats",
        onPressed: () {
          pageGoto(context,
              WeeklyScheduleStatsPage(startOfWeek: _selectedWeekStart));
        },
      ),
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _weekDays.map((day) {
                final dayKey = DateFormat('yyyy-MM-dd').format(day);
                final dayLabel = DateFormat("EEE, MMM d").format(day);
                final shifts = dailyShifts[dayKey] ?? [];
                final isClosed = openTimes[DateFormat('EEE').format(day).toLowerCase()]?['is_open'] == false;

                return Card(
                  margin: const EdgeInsets.all(8),
                  color: isClosed ? Colors.grey[200] : null,
                  child: ExpansionTile(
                    title: Text(dayLabel),
                    leading: Text(
                      _storeHoursLabel(day),
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(color: isClosed ? Theme.of(context).colorScheme.error : null),
                    ),
                    children: [
                      ...shifts.map((shift) {
                        final profile = shift['profiles'] ?? {};
                        final name = _formatNameInformal(profile);
                        final role = profile['role'] ?? 'Unknown';
                        final start = _formatTime(shift['start_time']);
                        final end = _formatTime(shift['end_time']);

                        return ListTile(
                          title: Text(name),
                          subtitle: Text("$start - $end"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(role, style: TextStyle(fontSize: 16)),
                              // Icon(Icons.edit)
                            ],
                          ),
                          onTap: () => _editShift(shift, day),
                        );
                      }),
                      ListTile(
                        trailing: const Icon(Icons.add),
                        title: const Text("Add shift"),
                        onTap: () => _addShift(day),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

String _formatName(Map profile) {
  final first = profile['first_name'] ?? '';
  final last = profile['last_name'] ?? '';
  if (first.isEmpty && last.isEmpty) return 'Unnamed';
  return last.isNotEmpty ? "$last, $first" : first;
}

String _formatNameInformal(Map profile) {
  final first = profile['first_name'] ?? '';
  final last = profile['last_name'] ?? '';

  if (first.isEmpty && last.isEmpty) return 'Unnamed';
  if (last.isEmpty) return first;
  return '$first, ${last[0]}.';
}

Future<Map<String, dynamic>?> showEmployeePicker(BuildContext context, int storeNumber) async {
  final response = await CRDatabase.client
      .from('profiles')
      .select('user_id, first_name, last_name')
      .eq('store', storeNumber)
      .order('last_name');

  final profiles = List<Map<String, dynamic>>.from(response);

  // ignore: use_build_context_synchronously
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      TextEditingController searchController = TextEditingController();
      List<Map<String, dynamic>> filteredProfiles = List.from(profiles);

      return StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.0)),
          backgroundColor: Theme.of(context).colorScheme.background,
          child: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Column(
              children: [
                Container(
                  height: 50,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(15),
                      topRight: Radius.circular(15),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      "Select Employee",
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: "Search...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        filteredProfiles = profiles.where((profile) {
                          final first =
                              profile['first_name']?.toLowerCase() ?? '';
                          final last =
                              profile['last_name']?.toLowerCase() ?? '';
                          final query = value.toLowerCase();
                          return first.contains(query) || last.contains(query);
                        }).toList();
                      });
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: ListView.builder(
                    itemCount: filteredProfiles.length,
                    itemBuilder: (context, index) {
                      final profile = filteredProfiles[index];
                      final first = profile['first_name'] ?? '';
                      final last = profile['last_name'] ?? '';
                      final label = first.isEmpty && last.isEmpty
                          ? "Unnamed"
                          : "$first${last.isNotEmpty ? " ${last[0]}." : ""}";
                      return ListTile(
                        title: Text(label),
                        leading: FutureBuilder<CRUser?>(
                          future: CRUser.loadCache(profile['user_id']),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                    ConnectionState.done ||
                                !snapshot.hasData) {
                              return const SizedBox(
                                width: 40,
                                height: 40,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              );
                            }
                            return CRProfilePicture(
                                user: snapshot.data!, size: 40);
                          },
                        ),
                        onTap: () => Navigator.pop(context, profile),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class AddEditShiftModal extends StatefulWidget {
  final DateTime date;
  final Map<String, dynamic>? shift;
  final Map<String, dynamic>? profile;

  const AddEditShiftModal({
    super.key,
    required this.date,
    this.shift,
    this.profile,
  });

  @override
  State<AddEditShiftModal> createState() => _AddEditShiftModalState();
}

class _AddEditShiftModalState extends State<AddEditShiftModal> {
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _start = widget.shift != null
        ? _parseTime(widget.shift!['start_time'])
        : const TimeOfDay(hour: 9, minute: 0);
    _end = widget.shift != null
        ? _parseTime(widget.shift!['end_time'])
        : const TimeOfDay(hour: 17, minute: 0);
  }

  String _displayName(Map profile) {
    final first = profile['first_name'] ?? '';
    final last = profile['last_name'] ?? '';
    if (first.isEmpty && last.isEmpty) return 'Unnamed';
    return last.isNotEmpty ? "$first, ${last[0]}." : first;
  }

  TimeOfDay _parseTime(String timeStr) {
    final parsed = DateFormat("HH:mm:ss").parse(timeStr);
    return TimeOfDay.fromDateTime(parsed);
  }

  Future<void> _save() async {
    final start =
        "${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}:00";
    final end =
        "${_end.hour.toString().padLeft(2, '0')}:${_end.minute.toString().padLeft(2, '0')}:00";

    if (widget.shift != null) {
      await CRDatabase.client.from('shifts').update({
        'start_time': start,
        'end_time': end,
      }).eq('id', widget.shift!['id']);
    } else if (widget.profile != null) {
      await CRDatabase.client.from('shifts').insert({
        'user_id': widget.profile!['user_id'],
        'date': widget.date.toIso8601String().substring(0, 10),
        'start_time': start,
        'end_time': end,
      });
    }

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final id = widget.shift?['id'];
    if (id != null) {
      await CRDatabase.client.from('shifts').delete().eq('id', id);
      if (mounted) Navigator.pop(context, true);
    }
  }

  String _formatHoursWorked() {
    final now = DateTime.now();
    final startDateTime =
        DateTime(now.year, now.month, now.day, _start.hour, _start.minute);
    final endDateTime =
        DateTime(now.year, now.month, now.day, _end.hour, _end.minute);

    final duration = endDateTime.difference(startDateTime);
    final hours = duration.inMinutes / 60.0;

    if (hours <= 0) return "Invalid Time";
    return "${hours.toStringAsFixed(2)} hours";
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile ?? widget.shift?['profiles'];
    final name = _displayName(profile);
    final dateStr = DateFormat('EEE, MMM d').format(widget.date);
    final isEditing = widget.shift != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          runSpacing: 16,
          children: [
            Text(
              isEditing ? "Editing $name" : "Add Shift for $name",
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              dateStr,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            Row(
              children: [
                Expanded(
                  child: _TimeSelector(
                    label: "Start Time",
                    time: _start,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _start,
                      );
                      if (picked != null) setState(() => _start = picked);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TimeSelector(
                    label: "End Time",
                    time: _end,
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _end,
                      );
                      if (picked != null) setState(() => _end = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Total: ${_formatHoursWorked()}",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _save,
                    icon: const Icon(Icons.check),
                    label: const Text("Save"),
                  ),
                ),
                if (isEditing) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _delete,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      icon: Icon(Icons.delete,
                          color: Theme.of(context).colorScheme.onError),
                      label: Text("Delete",
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.onError)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeSelector extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimeSelector({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      tileColor: Theme.of(context).colorScheme.surfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
      title: Text(label),
      subtitle: Text(time.format(context)),
      trailing: const Icon(Icons.access_time),
    );
  }
}
