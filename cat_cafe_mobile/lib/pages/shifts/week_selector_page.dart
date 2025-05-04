import 'package:cat_cafe_mobile/pages/shifts/manage_schedule_page.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeekSelectorPage extends StatelessWidget {
  const WeekSelectorPage({super.key});

  List<DateTime> generateWeeks({int past = 5, int future = 5}) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final weeks = <DateTime>[];

    for (int i = -past; i <= future; i++) {
      weeks.add(startOfWeek.add(Duration(days: i * 7)));
    }

    return weeks;
  }

  String formatRange(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final startStr = DateFormat("MMM d").format(start);
    final endStr = DateFormat("MMM d").format(end);
    return "$startStr - $endStr";
  }
  bool isCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    final target = DateTime(date.year, date.month, date.day);
    return target.isAtSameMomentAs(startOfWeek) ||
        (target.isAfter(startOfWeek) && target.isBefore(endOfWeek)) ||
        target.isAtSameMomentAs(endOfWeek);
  }

  @override
  Widget build(BuildContext context) {
    final weeks = generateWeeks();

    return CRAppBar(
      title: "Shift Editor",
      scrollable: false,
      surfaceVarient: true,
      backButton: true,
      child: ListView.builder(
        itemCount: weeks.length,
        itemBuilder: (context, index) {
          final weekStart = weeks[index];
          final range = formatRange(weekStart);

          return FutureBuilder<bool>(
            future: isWeekPosted(weekStart),
            builder: (context, snapshot) {
              final isPosted = snapshot.data ?? false;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: CRRegion(
                  color: isCurrentWeek(weekStart) ? Theme.of(context).colorScheme.surfaceTint.withAlpha(100) : null,
                  child: ListTile(
                    title: Text(range),
                    // subtitle:
                    //     Text(isPosted ? "Posted" : "Not posted"),
                    trailing: isPosted ? Icon(CupertinoIcons.check_mark_circled_solid, color: Theme.of(context).colorScheme.surfaceTint,) : null,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ManagerSchedulePage(startOfWeek: weekStart),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> isWeekPosted(DateTime startOfWeek) async {
    // TODO: Replace with real logic
    // Check Supabase or your database to see if this week has posted shifts
    await Future.delayed(const Duration(milliseconds: 200));
    return isCurrentWeek(startOfWeek);
  }
}
