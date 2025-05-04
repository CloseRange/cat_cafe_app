import 'package:cat_cafe_mobile/pages/shifts/daily_shift_page.dart';
import 'package:cat_cafe_mobile/pages/shifts/week_selector_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ShiftListPage extends StatefulWidget {
  const ShiftListPage({super.key});

  @override
  State<ShiftListPage> createState() => _ShiftListPageState();
}

class _ShiftListPageState extends State<ShiftListPage> {
  List<Map<String, dynamic>> shifts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  Future<void> _loadShifts() async {
    setState(() => loading = true);
    try {
      final response = await CRDatabase.client
          .from('shifts')
          .select('*')
          .eq("user_id", CRUser.current?.uuid ?? "")
          .order('start_time', ascending: true);
      setState(() {
        shifts = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      debugPrint('Error loading shifts: $e');
      if (mounted) setState(() => loading = false);
    }
  }

  List<DateTime> _generatePayWeekDates(int weeks) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7 * weeks, (i) => startOfWeek.add(Duration(days: i)));
  }

  DateTime parseDateTime(String date, String time) {
    return DateTime.parse('$date $time');
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var shift in shifts) {
      final date = shift['date'];
      grouped.putIfAbsent(date, () => []).add(shift);
    }

    final payPeriodDates = _generatePayWeekDates(2);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return CRRole.bind(builder: (context) {
      return CRAppBar(
        title: "Shifts",
        surfaceVarient: true,
        scrollable: false,
        action: (!CRRole.hasRole("modify_shifts"))
            ? null
            : IconButton(
                icon: const Icon(CupertinoIcons.doc_chart_fill),
                onPressed: () {
                  pageGoto(context, const WeekSelectorPage());
                },
              ),
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : CRRefreshPage(
                onRefresh: _loadShifts,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: payPeriodDates.length,
                  itemBuilder: (context, index) {
                    final date = payPeriodDates[index];
                    final dateKey = DateFormat('yyyy-MM-dd').format(date);
                    final shiftList = grouped[dateKey];
                    final displayDate = DateFormat('EEE, MMM d').format(date);
                    final isToday = dateKey == today;

                    double dailyHours = 0;
                    if (shiftList != null) {
                      for (var shift in shiftList) {
                        final start =
                            parseDateTime(shift['date'], shift['start_time']);
                        final end =
                            parseDateTime(shift['date'], shift['end_time']);
                        dailyHours += end.difference(start).inMinutes / 60.0;
                      }
                    }

                    final weekStart =
                        date.subtract(Duration(days: date.weekday - 1));
                    final weekEnd = weekStart.add(const Duration(days: 6));
                    final isEndOfWeek = date.isAtSameMomentAs(weekEnd);
                    final currentWeekShifts = payPeriodDates.where((d) =>
                        d.isAfter(
                            weekStart.subtract(const Duration(days: 1))) &&
                        d.isBefore(weekEnd.add(const Duration(days: 1))));

                    double weekTotal = 0;
                    for (var d in currentWeekShifts) {
                      final dKey = DateFormat('yyyy-MM-dd').format(d);
                      final shiftsThatDay = grouped[dKey];
                      if (shiftsThatDay != null) {
                        for (var shift in shiftsThatDay) {
                          final start =
                              parseDateTime(shift['date'], shift['start_time']);
                          final end =
                              parseDateTime(shift['date'], shift['end_time']);
                          weekTotal += end.difference(start).inMinutes / 60.0;
                        }
                      }
                    }

                    final shiftCards = shiftList == null || shiftList.isEmpty
                        ? [_buildOffCard(displayDate, date, isToday, 0)]
                        : shiftList.map((shift) {
                            final start = parseDateTime(
                                shift['date'], shift['start_time']);
                            final end =
                                parseDateTime(shift['date'], shift['end_time']);
                            return _buildShiftCard(displayDate, start, end,
                                shift['notes'], isToday, dailyHours);
                          }).toList();

                    return Column(
                      children: [
                        ...shiftCards,
                        if (isEndOfWeek)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Text(
                              "Total Weekly Hours: ${weekTotal.toStringAsFixed(2)}",
                              style: Theme.of(context).textTheme.titleMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
      );
    });
  }

  String _formatTime(DateTime time) {
    return DateFormat.jm().format(time);
  }

  Widget _buildShiftCard(String label, DateTime start, DateTime? end,
      dynamic notes, bool highlight, double hours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: GestureDetector(
        onTap: () {
          pageGoto(
              context,
              DailyShiftPage(
                  date: DateTime(start.year, start.month, start.day)));
        },
        child: CRRegion(
          padding: 0,
          color: highlight
              ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
              : null,
          child: ListTile(
            tileColor: Theme.of(context).colorScheme.primary,
            leading: end == null ? Icon(Icons.block, color: Theme.of(context).colorScheme.error) : const Icon(Icons.schedule),
            title: Text(label),
            subtitle: Text((end == null)
                ? "Off"
                : "${_formatTime(start)} - ${_formatTime(end)}"),
            trailing: (hours == 0 && notes == null) ? null : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (notes != null) const Icon(Icons.note),
                Text("${hours.toStringAsFixed(1)} hrs")
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOffCard(
      String label, DateTime date, bool highlight, double hours) {
    return _buildShiftCard(label, date, null, null, highlight, 0);
  }
}
