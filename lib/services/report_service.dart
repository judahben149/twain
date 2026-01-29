import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:twain/models/content_report.dart';

class ReportService {
  final _supabase = Supabase.instance.client;

  Future<void> reportContent({
    required String contentType,
    required String contentId,
    required String reason,
    String? description,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    await _supabase.from('reported_content').insert({
      'content_type': contentType,
      'content_id': contentId,
      'reporter_id': userId,
      'reason': reason,
      'description': description,
      'status': 'pending',
    });
  }

  Future<List<ContentReport>> getMyReports() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final response = await _supabase
        .from('reported_content')
        .select()
        .eq('reporter_id', userId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ContentReport.fromJson(json))
        .toList();
  }
}
