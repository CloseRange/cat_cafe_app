// ignore_for_file: avoid_print

import 'package:cat_cafe_mobile/pages/square/Square.dart';
import 'package:close_range_util/close_range_util.dart';
import 'package:flutter/material.dart';

class SquareUtility {
  static Future<bool> createTeamMember(
    BuildContext context, {
    required String firstName,
    required String lastName,
    required String phone,
    required String userId,
    required int storeNumber,
  }) async {
    final alreadyExists = await Square.findTeamMemberById(userId) != null;
    if (alreadyExists) return false;

    final locationId = await CRDatabase.client
        .from("store")
        .select("location_id")
        .eq("store_id", storeNumber)
        .maybeSingle();
    if (locationId == null || locationId["location_id"] == null) {
      print("No location ID found for store $storeNumber");
      return false;
    }
    var locId = locationId["location_id"].toString().trim();

    String? teamId = await Square.createTeamMember(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      userId: userId,
      locationId: locId,
    );

    if (teamId == null) {
      print("Failed to create team member in Square.");
      return false;
    }

    await CRDatabase.client
        .from("profiles")
        .update({"team_member_id": teamId})
        .eq("user_id", userId);

    return true;
  }
}

