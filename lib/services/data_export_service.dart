import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'goal_service.dart';

class DataExportException implements Exception {
  DataExportException(this.message);
  final String message;

  @override
  String toString() => message;
}

class DataExportService {
  DataExportService({SupabaseClient? client})
    : _supabase = client ?? Supabase.instance.client;

  static const formatVersion = 1;

  final SupabaseClient _supabase;

  /// Builds a JSON export for the signed-in user only, then writes it to a temp file.
  /// Does not log payload contents.
  Future<File> createCurrentUserExportFile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw DataExportException('Sign in to download your data.');
    }

    final payload = await _buildPayload(user);
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final stamp = DateTime.now().toUtc().toIso8601String().split('T').first;
    final file = File(
      '${Directory.systemTemp.path}/got-motion-export-$stamp.json',
    );
    await file.writeAsString(json, flush: true);
    return file;
  }

  Future<Map<String, dynamic>> _buildPayload(User user) async {
    final userId = user.id;
    final goals = UserGoals.fromMetadata(user.userMetadata);

    final profile = await _supabase
        .from('profiles')
        .select(
          'id, email, full_name, display_name, avatar_url, avatar_source, updated_at',
        )
        .eq('id', userId)
        .maybeSingle();

    final membershipRows = await _supabase
        .from('group_members')
        .select('group_id, groups(id, name)')
        .eq('user_id', userId);

    final groups = <Map<String, dynamic>>[];
    for (final row in List<Map<String, dynamic>>.from(membershipRows)) {
      final nested = row['groups'];
      if (nested is Map<String, dynamic>) {
        groups.add({
          'id': nested['id']?.toString() ?? row['group_id']?.toString(),
          'name': nested['name']?.toString(),
        });
      } else {
        groups.add({'id': row['group_id']?.toString(), 'name': null});
      }
    }

    final stepsRows = await _supabase
        .from('daily_steps')
        .select(
          'date, steps, miles, active_calories, exercise_minutes, created_at',
        )
        .eq('user_id', userId)
        .order('date');

    return {
      'format_version': formatVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'note':
          'This export includes activity already synced to Got Motion. It is not a copy of every record stored in Apple Health.',
      'account': {
        'user_id': userId,
        'email': user.email,
        'created_at': user.createdAt,
        'last_sign_in_at': user.lastSignInAt,
      },
      'profile': profile,
      'daily_goals': {
        'steps': goals.steps,
        'active_calories': goals.activeCalories,
        'exercise_minutes': goals.exerciseMinutes,
        'miles': goals.miles,
      },
      'groups': groups,
      'daily_steps': List<Map<String, dynamic>>.from(stepsRows),
    };
  }
}
