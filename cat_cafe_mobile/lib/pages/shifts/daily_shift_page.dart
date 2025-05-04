import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DailyShiftPage extends StatefulWidget {
  final DateTime date;

  const DailyShiftPage({super.key, required this.date});

  @override
  State<DailyShiftPage> createState() => _DailyShiftPageState();
}

class _DailyShiftPageState extends State<DailyShiftPage> {
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
          .select('*, profiles ( first_name, last_name, role )')
          .eq('date', DateFormat('yyyy-MM-dd').format(widget.date))
          .order('start_time', ascending: true);

      setState(() {
        shifts = List<Map<String, dynamic>>.from(response);
        loading = false;
      });
    } catch (e) {
      debugPrint("Error loading daily shifts: $e");
      setState(() => loading = false);
    }
  }

  String formatTime(String time) {
    final t = DateFormat("HH:mm:ss").parse(time);
    return DateFormat.jm().format(t);
  }
  
  String formatName(Map<String, dynamic> profile) {
    final first = profile['first_name']?.toString().trim();
    final last = profile['last_name']?.toString().trim();

    if (first == null || first.isEmpty) {
      return last ?? "Unknown";
    }
    if (last == null || last.isEmpty) {
      return first;
    }

    return "$last, $first";
  }


  @override
  Widget build(BuildContext context) {
    final displayDate = DateFormat('EEE, MMM d').format(widget.date);

    return CRAppBar(
      title: displayDate,
      surfaceVarient: true,
      scrollable: false,
      backButton: true,
      child: loading
          ? const Center(child: CircularProgressIndicator())
          : CRRefreshPage(
              onRefresh: _loadShifts,
              child: shifts.isEmpty
                  ? const Center(child: Text("No shifts scheduled for this day."))
                  : ListView.builder(
                      itemCount: shifts.length,
                      itemBuilder: (context, index) {
                        final shift = shifts[index];
                        final profile = shift['profiles'];
                        final start = formatTime(shift['start_time']);
                        final end = formatTime(shift['end_time']);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: ListTile(
                            title: Text(formatName(profile)),
                            subtitle: Text("$start - $end"),
                            trailing: Text(
                              profile['role'] ?? "",
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
