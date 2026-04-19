import 'dart:convert';
import 'package:http/http.dart' as http;

class LocalDnsClient {
  final String baseUrl;
  final String apiKey;

  LocalDnsClient({required this.baseUrl, required this.apiKey});

  Future<String?> resolve(String name) async {
    final uri = Uri.parse('$baseUrl/resolve/$name');

    final res = await http.get(uri, headers: {'X-API-Key': apiKey});

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      return data['ip']; // ignore port
    }

    return null;
  }
}
