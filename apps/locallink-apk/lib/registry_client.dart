import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

class LocalDnsClient {
  final String baseUrl;
  final String apiKey;

  LocalDnsClient({required this.baseUrl, required this.apiKey})
    : assert(baseUrl.isNotEmpty, 'BASE_URL cannot be empty'),
      assert(apiKey.isNotEmpty, 'API_KEY cannot be empty'),
      assert(baseUrl.startsWith('http'), 'BASE_URL must be a valid URL');

  Future<String?> resolve(String name) async {
    final uri = Uri.parse('$baseUrl/resolve/$name');

    final res = await http.get(uri, headers: {'X-API-Key': apiKey});

    if (res.statusCode == 200) {
      final data = convert.jsonDecode(res.body);
      return data['ip']; // ignore port
    }

    return null;
  }

  /// Register service
  Future<bool> register({
    required String name,
    required String ip,
    int ttl = 300,
    bool strict = false,
  }) async {
    final endpoint = strict ? 'register-strict' : 'register';
    final uri = Uri.parse('$baseUrl/$endpoint');

    final body = convert.jsonEncode({'name': name, 'ip': ip, 'ttl': ttl});

    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json', 'X-API-Key': apiKey},
      body: body,
    );

    if (res.statusCode == 200) {
      return true;
    }

    return false;
  }
}
