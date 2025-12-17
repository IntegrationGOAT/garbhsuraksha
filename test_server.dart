import 'package:http/http.dart' as http;

void main() async {
  print('Testing server connection...');

  final url = 'https://garbhsurakhsha.up.railway.app';

  try {
    print('Testing /health endpoint...');
    final healthResponse = await http.get(
      Uri.parse('$url/health'),
    ).timeout(const Duration(seconds: 30));

    print('Status: ${healthResponse.statusCode}');
    print('Body: ${healthResponse.body}');
    print('Headers: ${healthResponse.headers}');

    if (healthResponse.statusCode == 200) {
      print('✅ Health check passed!');
    } else {
      print('❌ Health check failed with status: ${healthResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Error: $e');
    print('Error type: ${e.runtimeType}');
  }

  try {
    print('\nTesting root / endpoint...');
    final rootResponse = await http.get(
      Uri.parse(url),
    ).timeout(const Duration(seconds: 30));

    print('Status: ${rootResponse.statusCode}');
    print('Body: ${rootResponse.body}');

    if (rootResponse.statusCode == 200) {
      print('✅ Root endpoint works!');
    }
  } catch (e) {
    print('❌ Error on root: $e');
  }
}

