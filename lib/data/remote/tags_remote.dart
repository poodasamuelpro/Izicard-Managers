import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/constants.dart';

class TagsRemote {
  TagsRemote(this._client);
  final SupabaseClient _client;

  Future<void> markWritten({
    required String tagId,
    required String status,
    String? uid,
    String? error,
    bool lockTag = false,
  }) async {
    await _client.schema(AppConstants.nfcSchema).rpc(
      'nfc_mark_written',
      params: {
        'p_tag': tagId,
        'p_status': status,
        'p_uid': uid,
        'p_error': error,
        'p_lock': lockTag,
      },
    );
  }
}
