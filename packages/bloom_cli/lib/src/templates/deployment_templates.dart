// lib/src/templates/deployment_templates.dart
import '../deployment/deployment_target_detector.dart';

/// Pure templates for Docker, Compose, .dockerignore, Nginx, and environment files.
class BloomDeploymentTemplates {
  /// Generates target-specific multi-stage Dockerfile content.
  static String dockerfile({
    required BloomDeploymentTarget target,
    required String appName,
    bool hasSsr = false,
    String? staticSourceDir,
  }) {
    switch (target) {
      case BloomDeploymentTarget.flutter:
        return _flutterDockerfile(appName: appName);
      case BloomDeploymentTarget.jsNative:
        return hasSsr
            ? _jsNativeSsrDockerfile(appName: appName)
            : _jsNativeStaticDockerfile(appName: appName);
      case BloomDeploymentTarget.server:
        return _serverDockerfile(appName: appName);
      case BloomDeploymentTarget.hybrid:
        return _hybridDockerfile(appName: appName);
    }
  }

  static String _flutterDockerfile({required String appName}) {
    return '''
# Multi-stage Dockerfile for Bloom Flutter Web Application
# Stage 1: Build Flutter Web release bundle
FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get

COPY . .
RUN flutter build web --release

# Stage 2: Minimal runtime image serving static assets
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \\
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
'''
        .trimLeft();
  }

  static String _jsNativeStaticDockerfile({required String appName}) {
    return '''
# Multi-stage Dockerfile for Bloom JS Native Web Application
# Stage 1: Build pure Dart JS Native client bundle
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile js -O4 -o build/web/main.dart.js web/main.dart 2>/dev/null || dart compile js -O4 -o build/web/main.dart.js lib/main.dart

# Stage 2: Minimal runtime image
FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \\
  CMD wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
'''
        .trimLeft();
  }

  static String _jsNativeSsrDockerfile({required String appName}) {
    return '''
# Multi-stage Dockerfile for Bloom JS Native Application (SSR Server)
# Stage 1: Compile standalone SSR server executable and client assets
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal runtime container
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/build/web /app/build/web

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
'''
        .trimLeft();
  }

  static String _serverDockerfile({required String appName}) {
    return '''
# Multi-stage Dockerfile for Bloom Server (Backend)
# Stage 1: Build standalone self-contained server executable
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal runtime container
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
'''
        .trimLeft();
  }

  static String _hybridDockerfile({required String appName}) {
    return '''
# Multi-stage Dockerfile for Bloom Hybrid Full-Stack Application
# Stage 1: Build client assets and standalone server executable
FROM dart:stable AS build

WORKDIR /app
COPY pubspec.* ./
RUN dart pub get

COPY . .
RUN dart compile exe bin/server.dart -o bin/server

# Stage 2: Minimal runtime container
FROM scratch
COPY --from=build /runtime/ /
COPY --from=build /app/bin/server /app/bin/server
COPY --from=build /app/build/web /app/build/web

EXPOSE 8080
ENTRYPOINT ["/app/bin/server"]
'''
        .trimLeft();
  }

  /// Generates `.dockerignore` file content preventing leaks of secrets and build artifacts.
  static String dockerIgnore() {
    return '''
# Bloom Docker Ignore File
.git/
.github/
.dart_tool/
.packages
.pub-cache/
build/
bin/server
bin/*.exe

# Protect secrets and credentials
.env
.env.*
!.env.example
*.pem
*.key
*.cert
*.p12

# Native platform caches
android/.gradle/
android/app/build/
ios/Pods/
ios/.symlinks/
windows/flutter/ephemeral/
macos/Pods/
linux/flutter/ephemeral/

# Developer tooling & artifacts
node_modules/
coverage/
.idea/
.vscode/
*.log
*.tmp
Dockerfile
docker-compose*.yml
'''
        .trimLeft();
  }

  /// Generates `docker-compose.yml` for local development.
  static String dockerCompose({
    required BloomDeploymentTarget target,
    required String appName,
    String dbDialect = 'postgres',
  }) {
    switch (target) {
      case BloomDeploymentTarget.flutter:
      case BloomDeploymentTarget.jsNative:
        return _clientDockerCompose(appName: appName);
      case BloomDeploymentTarget.server:
        return _serverDockerCompose(appName: appName, dbDialect: dbDialect);
      case BloomDeploymentTarget.hybrid:
        return _hybridDockerCompose(appName: appName, dbDialect: dbDialect);
    }
  }

  static String _clientDockerCompose({required String appName}) {
    return '''
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName-web:latest
    container_name: $appName-web
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - APP_ENV=local
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s
'''
        .trimLeft();
  }

  static String _serverDockerCompose({
    required String appName,
    required String dbDialect,
  }) {
    if (dbDialect == 'sqlite') {
      return '''
services:
  server:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName-server:latest
    container_name: $appName-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - APP_ENV=local
      - DB_NAME=/data/$appName.db
    volumes:
      - sqlite_data:/data
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

volumes:
  sqlite_data:
'''
          .trimLeft();
    }

    return '''
services:
  server:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName-server:latest
    container_name: $appName-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - APP_ENV=local
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - DB_NAME=${appName}_dev
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    container_name: $appName-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=${appName}_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
'''
        .trimLeft();
  }

  static String _hybridDockerCompose({
    required String appName,
    required String dbDialect,
  }) {
    return '''
services:
  server:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName-server:latest
    container_name: $appName-server
    restart: unless-stopped
    ports:
      - "8080:8080"
    environment:
      - PORT=8080
      - APP_ENV=local
      - DB_HOST=db
      - DB_PORT=5432
      - DB_USER=postgres
      - DB_PASSWORD=postgres
      - DB_NAME=${appName}_dev
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "curl -f http://localhost:8080/api/health || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  web:
    build:
      context: .
      dockerfile: Dockerfile
    image: $appName-web:latest
    container_name: $appName-web
    restart: unless-stopped
    ports:
      - "3000:8080"
    environment:
      - PORT=8080
      - API_URL=http://server:8080
    depends_on:
      server:
        condition: service_healthy
    healthcheck:
      test: ["CMD-SHELL", "wget --quiet --tries=1 --spider http://localhost:8080/ || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 5s

  db:
    image: postgres:16-alpine
    container_name: $appName-db
    restart: unless-stopped
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=${appName}_dev
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
'''
        .trimLeft();
  }

  /// Generates target-specific `.env.example` template with safe dummy placeholders and NO secrets.
  static String envExample({
    required BloomDeploymentTarget target,
    required String appName,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# Environment Configuration Template for $appName');
    buffer.writeln('# Copy to .env and fill in real secrets for production');
    buffer.writeln('APP_NAME=$appName');
    buffer.writeln('APP_ENV=production');
    buffer.writeln('PORT=8080');
    buffer.writeln();

    if (target == BloomDeploymentTarget.flutter ||
        target == BloomDeploymentTarget.jsNative) {
      buffer.writeln('# Public API Endpoint (Client-accessible)');
      buffer.writeln('BLOOM_PUBLIC_API_URL=https://api.example.com');
      buffer.writeln('BLOOM_PUBLIC_APP_TITLE=$appName');
    } else if (target == BloomDeploymentTarget.server ||
        target == BloomDeploymentTarget.hybrid) {
      buffer.writeln('# Database Configuration');
      buffer.writeln('DB_HOST=127.0.0.1');
      buffer.writeln('DB_PORT=5432');
      buffer.writeln('DB_USER=postgres');
      buffer.writeln('DB_PASSWORD=change-to-a-secure-database-password');
      buffer.writeln('DB_NAME=${appName}_prod');
      buffer.writeln();
      buffer.writeln(
          '# Authentication & Session Secret (Must be >= 32 characters)');
      buffer.writeln(
          'BLOOM_AUTH_SECRET=change-this-to-a-secure-random-32-character-secret');
      buffer.writeln();
      buffer.writeln('# Server Telemetry & CORS');
      buffer.writeln(
          'CORS_ALLOWED_ORIGINS=https://$appName.com,https://app.$appName.com');
      buffer.writeln('LOG_LEVEL=info');
    }

    return buffer.toString();
  }

  /// Generates `nginx.conf` with SPA fallback routing.
  static String nginxConf({
    String root = '/usr/share/nginx/html',
  }) {
    return '''
server {
  listen 8080;
  server_name localhost;
  root $root;
  index index.html;

  location / {
    try_files \$uri \$uri/ /index.html;
  }
}
'''
        .trimLeft();
  }
}
