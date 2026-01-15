# Lyzor
A lightweight, high-performance Dart web framework designed for speed, safety, and developer happiness.

## Features
- **Fast Routing**: Radix-tree based router with $O(K)$ lookup complexity.
- **Type-Safe Results**: Responses are managed via `Result` objects, separating logic from I/O.
- **Built-in DI**: Simple service registry for Dependency Injection.
- **Middleware Pipeline**: Global and route-specific middleware support.
- **Safe by Default**: Configurable body size limits and built-in crash recovery.
- **Developer Tools**: CLI for project scaffolding and hot-reloading.

---

## Installation

Add Lyzor to your `pubspec.yaml`:
```yaml
dependencies:
  lyzor:
    git: https://github.com/Dovydas-Mickus/lyzor
```

Install the Lyzor CLI globally:
```bash
dart pub global activate --source git https://github.com/Dovydas-Mickus/lyzor
```

---

## Quick Start

### 1. Create a project
```bash
lyzor create my_awesome_api
cd my_awesome_api
```

### 2. Write your first app
```dart
import 'package:lyzor/lyzor.dart';

void main() async {
  final app = Lyzor();

  // Global Middleware
  app.use(logger());
  app.use(recovery());

  // Simple Route
  app.get('/hello', (ctx) => 'Hello, Lyzor!');

  // Route with Parameters
  app.get('/users/:id', (ctx) {
    final id = ctx.pathParams['id'];
    return {'user_id': id};
  });

  await app.run(port: 8080);
}
```

### 3. Run in development mode (with hot-reload)
```bash
lyzor dev
```

---

## Core Concepts

### Dependency Injection
Register your services once and access them anywhere via the `Context`.

```dart
final db = Database();
app.provide<Database>(db);

app.get('/profile', (ctx) {
  final database = ctx.service<Database>();
  return database.getUsers();
});
```

### Response Results
Instead of manually writing to the response, return a `Result`. Lyzor automatically coerces Strings, Maps, and Lists into the correct format.

```dart
app.get('/data', (ctx) => Results.json({'status': 'ok'}));
app.get('/file', (ctx) => Results.file(File('report.pdf')));
app.get('/old-path', (ctx) => Results.redirect('/new-path'));
```

### Validation
Stop invalid data before it hits your handlers using the declarative validation middleware.

```dart
final userValidator = Validator({
  'email': [Rules.required(), Rules.email()],
  'password': [Rules.required(), Rules.minLength(8)],
});

app.post('/register', (ctx) async {
  final data = await ctx.json;
  return 'User ${data['email']} created!';
}).use(validateBody(userValidator));
```

### File Uploads
Handle `multipart/form-data` with ease.

```dart
app.post('/upload', (ctx) async {
  final form = await ctx.request.formData;
  final photo = form.files['avatar']?.first;

  if (photo != null) {
    await photo.save('uploads/${photo.filename}');
    return 'Saved!';
  }
  return Results.json({'error': 'no file'}, status: 400);
});
```

## Configuration

You can configure global limits like the maximum body size (to prevent OOM attacks):

```dart
final app = Lyzor();
app.maxBodySize = 5 * 1024 * 1024; // Limit to 5MB
```

---

## Middleware Order
Lyzor executes middleware in the order they are added. Always place `recovery()` and `logger()` at the top.

1. **Global Middleware** (Logger, Recovery, CORS)
2. **Route Middleware** (Auth, Validation)
3. **Handler** (Your business logic)

---

### License
MIT