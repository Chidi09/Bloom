// lib/routes/users/[id].dart
import 'package:flutter/material.dart';
import 'package:bloom_framework/bloom.dart';

class UsersIdRoute extends BloomRoute {
  const UsersIdRoute({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UsersIdRoute'),
      ),
      body: const Center(
        child: Text('UsersIdRoute Screen'),
      ),
    );
  }
}
