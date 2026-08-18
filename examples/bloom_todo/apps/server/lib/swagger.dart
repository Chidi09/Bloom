/// OpenAPI 3.1 Specification and Interactive Swagger UI / Scalar documentation for Bloom.
class BloomSwagger {
  static Map<String, dynamic> generateOpenApiSpec() {
    return {
      'openapi': '3.1.0',
      'info': {
        'title': 'Bloom Todo Full-Stack API',
        'description': 'Production REST API for Bloom Todoist-grade full-stack task manager. Built with Bloom Multi-Isolate AOT Server, SQLite WAL mode, and offline CRDT synchronization.',
        'version': '1.0.0',
        'contact': {
          'name': 'Bloom Framework Team',
          'url': 'https://github.com/Chidi09/Bloom',
        },
      },
      'servers': [
        {'url': '/', 'description': 'Active Multi-Isolate Cluster Server'},
      ],
      'paths': {
        '/api/health': {
          'get': {
            'summary': 'Cluster Health Check',
            'description': 'Returns active isolate status, server version, and timestamp.',
            'responses': {
              '200': {
                'description': 'Cluster is healthy and active.',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'object',
                      'properties': {
                        'status': {'type': 'string', 'example': 'healthy'},
                        'engine': {'type': 'string', 'example': 'bloom_realtime_aot'},
                        'version': {'type': 'string', 'example': '1.0.0'},
                        'timestamp': {'type': 'string', 'format': 'date-time'},
                      },
                    },
                  },
                },
              },
            },
          },
        },
        '/api/tasks': {
          'get': {
            'summary': 'List Tasks',
            'description': 'Retrieve all active tasks with optional workspace or project filtering.',
            'parameters': [
              {
                'name': 'workspaceId',
                'in': 'query',
                'required': false,
                'schema': {'type': 'string', 'example': 'ws_1'},
              },
              {
                'name': 'projectId',
                'in': 'query',
                'required': false,
                'schema': {'type': 'string', 'example': 'prj_1'},
              },
            ],
            'responses': {
              '200': {
                'description': 'Array of tasks.',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'array',
                      'items': {'\$ref': '#/components/schemas/Task'},
                    },
                  },
                },
              },
            },
          },
          'post': {
            'summary': 'Create Task',
            'description': 'Create a new task in a specific project with priority and due date.',
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {'\$ref': '#/components/schemas/TaskCreateDto'},
                },
              },
            },
            'responses': {
              '201': {
                'description': 'Task created successfully.',
                'content': {
                  'application/json': {
                    'schema': {'\$ref': '#/components/schemas/Task'},
                  },
                },
              },
              '400': {'description': 'Validation error.'},
            },
          },
        },
        '/api/tasks/{id}': {
          'get': {
            'summary': 'Get Task by ID',
            'parameters': [
              {'name': 'id', 'in': 'path', 'required': true, 'schema': {'type': 'string'}},
            ],
            'responses': {
              '200': {
                'description': 'Task details.',
                'content': {
                  'application/json': {
                    'schema': {'\$ref': '#/components/schemas/Task'},
                  },
                },
              },
              '404': {'description': 'Task not found.'},
            },
          },
          'put': {
            'summary': 'Update Task',
            'parameters': [
              {'name': 'id', 'in': 'path', 'required': true, 'schema': {'type': 'string'}},
            ],
            'requestBody': {
              'required': true,
              'content': {
                'application/json': {
                  'schema': {'\$ref': '#/components/schemas/TaskUpdateDto'},
                },
              },
            },
            'responses': {
              '200': {'description': 'Task updated.'},
              '404': {'description': 'Task not found.'},
            },
          },
        },
        '/api/tasks/{id}/complete': {
          'post': {
            'summary': 'Toggle Task Completion',
            'parameters': [
              {'name': 'id', 'in': 'path', 'required': true, 'schema': {'type': 'string'}},
            ],
            'responses': {
              '200': {'description': 'Task completion status toggled.'},
            },
          },
        },
        '/api/projects': {
          'get': {
            'summary': 'List Projects',
            'responses': {
              '200': {
                'description': 'Array of workspace projects.',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'array',
                      'items': {'\$ref': '#/components/schemas/Project'},
                    },
                  },
                },
              },
            },
          },
        },
        '/api/workspaces': {
          'get': {
            'summary': 'List Workspaces',
            'responses': {
              '200': {
                'description': 'Array of user workspaces.',
                'content': {
                  'application/json': {
                    'schema': {
                      'type': 'array',
                      'items': {'\$ref': '#/components/schemas/Workspace'},
                    },
                  },
                },
              },
            },
          },
        },
      },
      'components': {
        'schemas': {
          'Task': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'project_id': {'type': 'string'},
              'workspace_id': {'type': 'string'},
              'creator_id': {'type': 'string'},
              'title': {'type': 'string'},
              'description': {'type': 'string', 'nullable': true},
              'priority': {'type': 'string', 'enum': ['p1', 'p2', 'p3', 'p4']},
              'due_at': {'type': 'string', 'format': 'date-time', 'nullable': true},
              'is_completed': {'type': 'boolean'},
              'labels': {'type': 'array', 'items': {'type': 'string'}},
              'created_at': {'type': 'string', 'format': 'date-time'},
              'updated_at': {'type': 'string', 'format': 'date-time'},
            },
          },
          'TaskCreateDto': {
            'type': 'object',
            'required': ['title', 'projectId', 'workspaceId'],
            'properties': {
              'title': {'type': 'string', 'example': 'Complete cluster benchmarks'},
              'description': {'type': 'string', 'example': 'Profile 8 AOT isolates'},
              'projectId': {'type': 'string', 'example': 'prj_1'},
              'workspaceId': {'type': 'string', 'example': 'ws_1'},
              'priority': {'type': 'string', 'enum': ['p1', 'p2', 'p3', 'p4'], 'example': 'p1'},
              'dueAt': {'type': 'string', 'format': 'date-time'},
              'labels': {'type': 'array', 'items': {'type': 'string'}, 'example': ['benchmark']},
            },
          },
          'TaskUpdateDto': {
            'type': 'object',
            'properties': {
              'title': {'type': 'string'},
              'description': {'type': 'string'},
              'priority': {'type': 'string', 'enum': ['p1', 'p2', 'p3', 'p4']},
              'isCompleted': {'type': 'boolean'},
              'labels': {'type': 'array', 'items': {'type': 'string'}},
            },
          },
          'Project': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'workspace_id': {'type': 'string'},
              'name': {'type': 'string'},
              'color_hex': {'type': 'string'},
              'icon': {'type': 'string'},
              'position': {'type': 'integer'},
              'created_at': {'type': 'string', 'format': 'date-time'},
            },
          },
          'Workspace': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'name': {'type': 'string'},
              'slug': {'type': 'string'},
              'owner_id': {'type': 'string'},
              'created_at': {'type': 'string', 'format': 'date-time'},
            },
          },
        },
      },
    };
  }

  /// Interactive modern Scalar / Swagger UI documentation viewer.
  static String renderScalarDocsHtml() {
    return '''
<!doctype html>
<html>
  <head>
    <title>Bloom API Reference • Swagger & Scalar</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <style>
      body { margin: 0; background-color: #09090B; }
    </style>
  </head>
  <body>
    <script
      id="api-reference"
      data-url="/api/openapi.json"
      data-configuration='{"theme":"purple","darkMode":true,"layout":"modern","showSidebar":true}'
    ></script>
    <script src="https://cdn.jsdelivr.net/npm/@scalar/api-reference"></script>
  </body>
</html>
''';
  }

  /// Classic Swagger UI viewer.
  static String renderSwaggerUiHtml() {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>Bloom API • Swagger UI</title>
  <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5/swagger-ui.css" />
  <style>
    html { box-sizing: border-box; overflow: -moz-scrollbars-vertical; overflow-y: scroll; }
    *, *:before, *:after { box-sizing: inherit; }
    body { margin: 0; background: #09090B; color: #FFF; }
    .swagger-ui .topbar { display: none; }
    .swagger-ui { filter: invert(88%) hue-rotate(180deg); }
  </style>
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="https://unpkg.com/swagger-ui-dist@5/swagger-ui-bundle.js"></script>
  <script>
    window.onload = function() {
      SwaggerUIBundle({
        url: "/api/openapi.json",
        dom_id: '#swagger-ui',
        deepLinking: true,
        presets: [
          SwaggerUIBundle.presets.apis,
          SwaggerUIBundle.SwaggerUIStandalonePreset
        ],
      });
    };
  </script>
</body>
</html>
''';
  }
}
