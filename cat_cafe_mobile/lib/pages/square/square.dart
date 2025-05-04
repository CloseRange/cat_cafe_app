import 'dart:convert';

import 'package:close_range_util/close_range_util.dart';
import 'package:dio/dio.dart';

final dio = Dio(
  BaseOptions(
    baseUrl: 'https://connect.squareupsandbox.com/v2/',
    headers: {
      'Authorization': 'Bearer ${CREnv["SQUARE_ACCESS_TOKEN"]}',
      'Content-Type': 'application/json',
    },
  ),
);

class Square {
  static bool get sandbox => true;

  static Future<String?> findTeamMemberById(String userId) async {
    try {
      final response = await dio.get('team-members?reference_id=$userId');
      final teamMembers = response.data['team_members'];
      if (teamMembers != null && teamMembers.isNotEmpty) {
        return teamMembers[0]['id']; // Return existing ID
      }
    } catch (e) {
      return null;
    }
    return null; // Not found
  }

  static Future<String?> createTeamMember({
    required String firstName,
    required String lastName,
    required String phone,
    required String userId,
    required String locationId,
  }) async {
    final data = {
      "team_member": {
        "reference_id": userId,
        "given_name": firstName,
        "family_name": lastName,
        "phone_number": phone,
        if (!sandbox)
          "assigned_locations": [
            {
              "location_id": locationId,
            }
          ]
      }
    };

    try {
      final res = await dio.get('locations');
      print(res.data);

      print(jsonEncode(data));

      final response = await dio.post('team-members', data: data);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final teamMemberId = response.data['team_member']['id'];
        return teamMemberId; // Return the created ID
      } else {
        print(response.data);
        print('Error creating team member: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      if (e is DioException) {
        print('Status Code: ${e.response?.statusCode}');
        print('Error: ${e.response?.data}');
      } else {
        print('Unhandled error: $e');
      }
      return null;
    }
  }
}
