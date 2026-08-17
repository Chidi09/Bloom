import 'package:bloom_validate/bloom_validate.dart';

/// Request body schema for user registration.
class SignupRequestSchema extends BloomRequestSchema {
  SignupRequestSchema(super.data);
  SignupRequestSchema.fromRequest(super.request) : super.fromRequest();

  late final String name = requireStringLength('name', min: 2, max: 100, description: 'User full name');
  late final String email = requireEmail('email', description: 'Account email address');
  late final String password = requireStringLength('password', min: 8, max: 128, description: 'Account password');

  @override
  void validate() {
    name;
    email;
    password;
  }
}

/// Request body schema for user login.
class LoginRequestSchema extends BloomRequestSchema {
  LoginRequestSchema(super.data);
  LoginRequestSchema.fromRequest(super.request) : super.fromRequest();

  late final String email = requireEmail('email', description: 'Account email address');
  late final String password = requireString('password', description: 'Account password');

  @override
  void validate() {
    email;
    password;
  }
}

/// Request body schema for TodoList creation and update.
class CreateTodoListSchema extends BloomRequestSchema {
  CreateTodoListSchema(super.data);
  CreateTodoListSchema.fromRequest(super.request) : super.fromRequest();

  late final String name = requireStringLength('name', min: 1, max: 255, description: 'List title/name');

  @override
  void validate() {
    name;
  }
}

/// Request body schema for TodoTask creation.
class CreateTodoTaskSchema extends BloomRequestSchema {
  CreateTodoTaskSchema(super.data);
  CreateTodoTaskSchema.fromRequest(super.request) : super.fromRequest();

  late final int listId = requireInt('listId', description: 'Parent TodoList ID');
  late final String title = requireStringLength('title', min: 1, max: 255, description: 'Task title');
  late final bool done = optionalBool('done', defaultValue: false);

  @override
  void validate() {
    listId;
    title;
    done;
  }
}

/// Request body schema for TodoTask update.
class UpdateTodoTaskSchema extends BloomRequestSchema {
  UpdateTodoTaskSchema(super.data);
  UpdateTodoTaskSchema.fromRequest(super.request) : super.fromRequest();

  late final String? title = optionalStringLength('title', min: 1, max: 255);
  late final bool? done = data.containsKey('done') ? optionalBool('done') : null;

  @override
  void validate() {
    title;
    done;
  }
}
