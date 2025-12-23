import 'package:flutter/foundation.dart';
import '../../domain/entities/parsed_transaction.dart';
import 'sms_parser_service.dart';

/// Worker pour le parsing des SMS dans un isolat
class SmsParserWorker {
  /// Parse un SMS de manière asynchrone (Isolat via compute)
  static Future<ParsedTransaction?> parse(String sender, String body, {DateTime? date}) async {
    return compute(_parseTask, {
      'sender': sender,
      'body': body,
      'date': date,
    });
  }

  /// Tâche de parsing exécutée dans l'isolat
  static ParsedTransaction? _parseTask(Map<String, dynamic> params) {
    final sender = params['sender'] as String;
    final body = params['body'] as String;
    final date = params['date'] as DateTime?;
    
    // On instancie le service dans l'isolat (stateless)
    final parser = SmsParserService();
    return parser.parseSms(sender, body, receivedAt: date);
  }
}
