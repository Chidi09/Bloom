import 'api_client.dart';
import 'realtime_client.dart';
import '../repositories/task_repository.dart';
import '../repositories/project_repository.dart';
import '../controllers/auth_controller.dart';
import '../controllers/task_controller.dart';
import '../controllers/project_controller.dart';

class BloomBoot {
  static late final ApiClient apiClient;
  static late final RealtimeClient realtimeClient;
  static late final TaskRepository taskRepository;
  static late final ProjectRepository projectRepository;
  static late final AuthController authController;
  static late final TaskController taskController;
  static late final ProjectController projectController;

  static Future<void> init() async {
    apiClient = ApiClient();
    realtimeClient = RealtimeClient();
    taskRepository = TaskRepository(apiClient);
    projectRepository = ProjectRepository(apiClient);

    authController = AuthController(apiClient);
    taskController = TaskController(taskRepository);
    projectController = ProjectController(projectRepository);
  }
}
