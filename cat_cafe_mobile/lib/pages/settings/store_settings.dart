import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StoreSettings {
  Map<String, dynamic> openTimes;
  Map<String, dynamic> settings;
  int id;

  StoreSettings(this.id, this.openTimes, this.settings);


  String _formatTimeOfDay(TimeOfDay time) {
    final dt = DateTime(0, 0, 0, time.hour, time.minute);
    return DateFormat.Hms().format(dt);
  }

  Future<void> save() async {
    await CRDatabase.client
        .from('store_settings')
        .upsert({...settings, 'store_id': id}); // Upsert back to database
    await CRDatabase.client
        .from('store_open_times')
        .upsert({...openTimes, 'store_id': id}); // Upsert back to database
  }

  static Future<StoreSettings> load({int id = 1111}) async {
    var resOpen = await CRDatabase.client
        .from('store_open_times')
        .select('*')
        .eq('store_id', id)
        .maybeSingle();
    var resSettings = await CRDatabase.client
        .from('store_settings')
        .select('*')
        .eq('store_id', id)
        .maybeSingle();
    resOpen ??= {};
    resSettings ??= {};
    return StoreSettings(id, resOpen, resSettings);
  }
}
