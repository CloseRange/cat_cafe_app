import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:close_range_util/close_range_util.dart';

class WeeklyScheduleStatsPage extends StatefulWidget {
  final DateTime startOfWeek;

  const WeeklyScheduleStatsPage({super.key, required this.startOfWeek});

  @override
  State<WeeklyScheduleStatsPage> createState() =>
      _WeeklyScheduleStatsPageState();
}

class _WeeklyScheduleStatsPageState extends State<WeeklyScheduleStatsPage> {
  Map<String, List<Map<String, dynamic>>> dailyShifts = {};
  Map<String, Map<String, dynamic>> openTimes = {};
  Map<String, dynamic> storeSettings = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final start = widget.startOfWeek;
    final end = start.add(const Duration(days: 6));

    final response = await CRDatabase.client
        .from('shifts')
        .select('*, profiles!inner(first_name, last_name, role)')
        .gte('date', DateFormat('yyyy-MM-dd').format(start))
        .lte('date', DateFormat('yyyy-MM-dd').format(end))
        .order('start_time');

    final shifts = List<Map<String, dynamic>>.from(response);
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (var shift in shifts) {
      final date = shift['date'];
      grouped.putIfAbsent(date, () => []).add(shift);
    }

    final settingsData = await CRDatabase.client
        .from('store_settings')
        .select()
        .limit(1)
        .maybeSingle();

    final timesData = await CRDatabase.client.from('store_open_times').select();

    if (settingsData == null) {
      // Handle gracefully: show error, fallback, or skip open/close logic
      setState(() {
        dailyShifts = grouped;
        storeSettings = {};
        openTimes = {};
        loading = false;
      });
      return;
    }

    final parsedOpen = <String, Map<String, dynamic>>{};
    for (final entry in timesData) {
      final day = entry['dow'];
      parsedOpen[day] = {
        'is_open': !(entry['is_open'] ?? false),
        'open': _parseTime(entry['open']),
        'close': _parseTime(entry['close']),
      };
    }

    setState(() {
      dailyShifts = grouped;
      storeSettings = settingsData;
      openTimes = parsedOpen;
      loading = false;
    });
  }

  TimeOfDay _parseTime(String? timeStr) {
    if (timeStr == null) return const TimeOfDay(hour: 0, minute: 0);
    final dt = DateFormat("HH:mm").parseLoose(timeStr.split(":").take(2).join(":"));
    return TimeOfDay.fromDateTime(dt);
  }

  @override
  Widget build(BuildContext context) {
    return loading
        ? const Scaffold(body: Center(child: CircularProgressIndicator()))
        : WeeklyScheduleStatsContent(
            startOfWeek: widget.startOfWeek,
            dailyShifts: dailyShifts,
            storeSettings: storeSettings,
            openTimes: openTimes,
          );
  }
}

class WeeklyScheduleStatsContent extends StatelessWidget {
  final DateTime startOfWeek;
  final Map<String, List<Map<String, dynamic>>> dailyShifts;
  final Map<String, dynamic> storeSettings;
  final Map<String, Map<String, dynamic>> openTimes;

  const WeeklyScheduleStatsContent({
    super.key,
    required this.startOfWeek,
    required this.dailyShifts,
    required this.storeSettings,
    required this.openTimes,
  });

  void _applyIssue(Map<String, List<List<dynamic>>> issues, String uid,
      DateTime? date, String issue) {
    issues.putIfAbsent(uid, () => []).add([issue, date, false]);
  }

  void _applyCritical(Map<String, List<List<dynamic>>> issues, String uid,
      DateTime? date, String issue) {
    issues.putIfAbsent(uid, () => []).add([issue, date, true]);
  }

  List<String> _findGlobalIssues(List<DateTime> weekDays) {
    List<String> warnings = [];
    for (var day in weekDays) {
      final dayName = DateFormat('EEE').format(day);
      final open = openTimes[dayName]?['open'];
      final close = openTimes[dayName]?['close'];
      final isOpen = !(openTimes[dayName]?['is_open'] ?? false);
      if (!isOpen) continue;

      final openHour = open?.hour ?? 9;
      final closeHour = close?.hour ?? 17;

      final dateKey = DateFormat('yyyy-MM-dd').format(day);
      final shifts = dailyShifts[dateKey] ?? [];

      if (shifts.isEmpty) {
        warnings.add(
            "No coverage at all on ${DateFormat('EEE, MMM d').format(day)}");
        continue;
      }

      DateTime? earliest;
      DateTime? latest;
      for (var shift in shifts) {
        final start = DateTime.parse("${shift['date']} ${shift['start_time']}");
        final end = DateTime.parse("${shift['date']} ${shift['end_time']}");
        earliest =
            (earliest == null || start.isBefore(earliest)) ? start : earliest;
        latest = (latest == null || end.isAfter(latest)) ? end : latest;
      }

      // Check coverage
      if (earliest!.hour > openHour || latest!.hour < closeHour) {
        warnings
            .add("Partial coverage on ${DateFormat('EEE, MMM d').format(day)}");
      }

      // Check employee count
      final employeeCount = shifts.map((s) => s['user_id']).toSet().length;
      if (employeeCount < 2) {
        warnings.add(
            "Less than 2 employees on ${DateFormat('EEE, MMM d').format(day)}");
      }
    }

    return warnings;
  }

  @override
  Widget build(BuildContext context) {
    final userHours = <String, double>{};
    final userShifts = <String, List<Map<String, dynamic>>>{};
    final issues = <String, List<List<dynamic>>>{};
    final weekDays =
        List.generate(7, (i) => startOfWeek.add(Duration(days: i)));
    final List<String> globalWarnings = _findGlobalIssues(weekDays);

    for (var entry in dailyShifts.entries) {
      // final date = DateTime.parse(entry.key);
      for (var shift in entry.value) {
        final uid = shift['user_id'];
        final start = DateTime.parse("${shift['date']} ${shift['start_time']}");
        final end = DateTime.parse("${shift['date']} ${shift['end_time']}");
        final hours = end.difference(start).inMinutes / 60.0;

        userHours[uid] = (userHours[uid] ?? 0) + hours;
        userShifts
            .putIfAbsent(uid, () => [])
            .add({...shift, 'parsed_start': start, 'parsed_end': end});
      }
    }
    var maxHoursPerDay = storeSettings['max_hours_per_day'] ?? 10;
    var minHoursBetweenShifts = storeSettings['time_between_shifts'] ?? 10;
    var maxHoursPerWeek = storeSettings['max_hours_per_week'] ?? 40;
    final userDaysWorked = <String, Set<String>>{};

    for (var uid in userShifts.keys) {
      final shifts = userShifts[uid]!;
      shifts.sort((a, b) => (a['parsed_start'] as DateTime)
          .compareTo(b['parsed_start'] as DateTime));
      for (int i = 0; i < shifts.length; i++) {
        final isEnd = i == shifts.length - 1;
        final currentStart = shifts[i]['parsed_start'] as DateTime;
        final currentEnd = shifts[i]['parsed_end'] as DateTime;
        final nextStart = isEnd
            ? currentStart.add(const Duration(days: 1))
            : shifts[i + 1]['parsed_start'] as DateTime;

        final shiftDay = DateFormat('yyyy-MM-dd').format(currentStart);
        userDaysWorked.putIfAbsent(uid, () => {}).add(shiftDay);

        final diff = nextStart.difference(currentEnd);
        final shiftTime = currentEnd.difference(currentStart);

        if (diff.inMinutes < 0) {
          _applyCritical(issues, uid, currentStart, "Shift overlap");
        }
        if (shiftTime.inMinutes < 60) {
          _applyIssue(issues, uid, currentStart, "Shift less than 1 hour");
        }
        if (shiftTime.inMinutes > maxHoursPerDay * 60) {
          _applyIssue(issues, uid, currentStart,
              "Shift more than $maxHoursPerDay hours");
        }
        if (diff.inMinutes < minHoursBetweenShifts * 60) {
          _applyIssue(issues, uid, currentStart,
              "Less than $minHoursBetweenShifts hours between shifts");
        }
      }
      final daysWorked = userDaysWorked[uid]?.length ?? 0;
      if (daysWorked > 5) {
        _applyCritical(issues, uid, null, "Works more than 5 days in the week");
      }

      if ((userHours[uid] ?? 0) > maxHoursPerWeek * 1.25) {
        _applyCritical(
            issues, uid, null, "Exceeds ${maxHoursPerWeek * 1.25} hours/week");
      } else if ((userHours[uid] ?? 0) > maxHoursPerWeek) {
        _applyIssue(issues, uid, null, "Exceeds $maxHoursPerWeek hours/week");
      }
    }

    return CRAppBar(
      title: "Week Stats: ${DateFormat('MMM d').format(startOfWeek)}",
      scrollable: false,
      surfaceVarient: true,
      backButton: true,
      child: ListView(padding: const EdgeInsets.all(16), children: [
        if (globalWarnings.isNotEmpty) ...[
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: ExpansionTile(
              title: Text(
                "Global Schedule Warnings",
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer),
              ),
              children: globalWarnings
                  .map((e) => ListTile(
                        leading:
                            const Icon(Icons.warning_amber_outlined, size: 20),
                        title: Text(e),
                        dense: true,
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        ...userHours.entries.map((entry) {
          final uid = entry.key;
          final hours = entry.value;
          final profile = userShifts[uid]!.first['profiles'] ?? {};
          final name = _formatName(profile);
          final hasIssues = issues.containsKey(uid);

          return Card(
            child: ExpansionTile(
              title: Row(
                children: [
                  Expanded(child: Text(name)),
                  Text("${hours.toStringAsFixed(2)} hrs",
                      style: TextStyle(
                        color: hasIssues
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.onBackground,
                        fontWeight: FontWeight.bold,
                      )),
                  if (hasIssues) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.warning,
                        color: Theme.of(context).colorScheme.error),
                  ],
                ],
              ),
              children: hasIssues
                  ? issues[uid]!
                      .map((e) => ListTile(
                            title: Text(e[0]),
                            trailing: e[1] != null
                                ? Text(DateFormat('EEE, MMM d')
                                    .format(e[1] as DateTime))
                                : null,
                            dense: true,
                            leading: Icon(
                              e[2]
                                  ? CupertinoIcons.exclamationmark_triangle
                                  : Icons.error_outline,
                              size: 20,
                              color: e[2]
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ))
                      .toList()
                  : [
                      const ListTile(
                        title: Text("No issues detected."),
                        dense: true,
                        leading:
                            Icon(Icons.check_circle_outline, size: 20),
                      ),
                    ],
            ),
          );
        }).toList(),
      ]),
    );
  }


  String _formatName(Map profile) {
    final first = profile['first_name'] ?? '';
    final last = profile['last_name'] ?? '';
    if (first.isEmpty && last.isEmpty) return 'Unnamed';
    return last.isNotEmpty ? "$last, $first" : first;
  }
}

mixin Pair {}
