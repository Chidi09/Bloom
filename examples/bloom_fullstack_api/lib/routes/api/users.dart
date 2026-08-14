// lib/routes/api/users.dart
import 'package:bloom_framework/bloom_server.dart';

final List<Map<String, dynamic>> _mockUsers = [
  {'id': '1', 'name': 'Sol', 'role': 'Architect'},
  {'id': '2', 'name': 'Chidi', 'role': 'Lead Engineer'},
];

BloomResponse handleGetUsers(BloomRequest request) {
  return BloomResponse.json({
    'users': _mockUsers,
    'count': _mockUsers.length,
  });
}

Future<BloomResponse> handleCreateUser(BloomRequest request) async {
  final body = await request.bodyJson;
  if (body == null || body['name'] == null) {
    return BloomResponse.json({'error': 'Name is required'}, statusCode: 400);
  }

  final newUser = {
    'id': '${_mockUsers.length + 1}',
    'name': body['name'],
    'role': body['role'] ?? 'Member',
  };

  _mockUsers.add(newUser);
  return BloomResponse.json(newUser, statusCode: 201);
}
