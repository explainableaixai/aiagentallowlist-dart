import 'dart:io';
import 'package:aiagentallowlist/aiagentallowlist.dart';

Future<void> main() async {
  final client =
      AIAgentAllowlistClient(apiKey: Platform.environment['AQ_API_KEY'] ?? '');
  try {
    print(await client.check('https://example.com/checkout'));
  } finally {
    client.close();
  }
}
