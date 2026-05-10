# Lyzor

A lightweight, expressive HTTP server framework for Dart.

---

## Install CLI

```bash
dart pub global activate --source path path/to/lyzor
```

## Create a project

```bash
lyzor create my_app
cd my_app
dart pub get
lyzor dev
```

`lyzor dev` starts the server and hot-reloads on file changes. Press `q` + Enter to stop.

---

## Quick start

```dart
import 'package:lyzor/lyzor.dart';

Future<void> main() async {
  final app = Lyzor()
    ..use(recovery())
    ..use(logger());

  app.route('/').get(() => JsonResult({'message': 'Hello, Lyzor!'}));

  await app.run(port: 8080);
}
```

---

## Routing

```dart
app.route('/users').get(() => ...);
app.route('/users').post(() => ...);
app.route('/users/:id').get(() {
  final id = Context.current.pathParams['id'];
  return JsonResult({'id': id});
});

// Wildcard
app.route('/files/*').get(() {
  final path = Context.current.pathParams['*'];
  return TextResult(path);
});
```

### Route groups

```dart
app.group('/api/v1')
  .route('/users').get(() => ...)
  .route('/users/:id').delete(() => ...);
```

### Route-level middleware

```dart
app.route('/admin').get(() => ...).use(authRequired());
```

### Controllers

```dart
class UserController implements Controller {
  @override
  void registerRoutes(Lyzor app) {
    app.route('/users').get(index);
    app.route('/users/:id').get(show);
  }

  Object? index() => JsonResult({'users': []});
  Object? show() {
    final id = Context.current.pathParams['id'];
    return JsonResult({'id': id});
  }
}

app.addController(UserController());
```

---

## Context

`Context.current` is available anywhere inside a request — handlers, middleware, services.

```dart
final ctx = Context.current;

ctx.method;           // 'GET', 'POST', ...
ctx.uri;              // Uri
ctx.pathParams;       // {'id': '42'}
ctx.queryParams;      // {'page': '1'}
ctx.headers;          // HttpHeaders
ctx.locals;           // Map<String, dynamic> — shared per request
await ctx.body;       // raw String
await ctx.json;       // Map<String, dynamic>
```

---

## Responses

Return any of these from a handler or middleware:

```dart
JsonResult({'ok': true})
TextResult('hello')
HtmlResult('<h1>Hello</h1>')
XmlResult('<note/>')
FileResult(File('report.pdf'))
RedirectResult('/new-path')
StatusResult(status: 204)
```

All results support chaining:

```dart
JsonResult({'ok': true})
  .withStatus(201)
  .withHeader('X-Request-Id', id)
  .withCookie(Cookie('session', token));
```

Returning a `Map`, `List`, or `String` from a handler is auto-coerced to `JsonResult` / `TextResult`.

---

## Dependency injection

```dart
app.provide<Database>(Database(dsn));

// Anywhere in a request:
final db = Context.current.read<Database>();
```

---

## Middleware

### Built-in middleware

```dart
app.use(recovery());          // catches unhandled exceptions, returns 500
app.use(logger());            // logs method, path, status, duration
app.use(logger(logQuery: true)); // also logs query params (off by default)
app.use(cors(origin: 'https://myapp.com'));
app.use(securityHeaders());   // CSP, X-Frame-Options, HSTS, Referrer-Policy
app.use(csrf(cookieSecure: true));
app.use(rateLimit(maxRequests: 100, window: Duration(minutes: 1)));
```

### Validation

```dart
final schema = Validator({
  'email': [Rules.required(), Rules.isEmail()],
  'password': [Rules.required(), Rules.minLength(8)],
});

app.route('/register')
  .post(() async {
    final data = await Context.current.json;
    // data is guaranteed valid here
    return StatusResult(status: 201);
  })
  .use(validateBody(schema));
```

### Custom middleware

```dart
Middleware myMiddleware() {
  return (ctx, next) async {
    ctx.locals['started'] = DateTime.now();
    final result = await next();
    return result;
  };
}
```

---

## Configuration

```dart
final app = Lyzor()
  ..maxBodySize = 5 * 1024 * 1024        // default 10 MB
  ..requestTimeout = Duration(seconds: 30) // null = no timeout
  ..poweredBy = false;                     // removes X-Powered-By header
```

### Multi-isolate (production)

```dart
await Lyzor.spawn(createApp, count: 4, port: 8080);
```

---

## Static files

```dart
app.static('/assets', './public');

// With options:
app.static(
  '/uploads',
  './uploads',
  cacheControl: 'private, no-store',
  listDirectories: false,
);
```

---

## File uploads

```dart
app.route('/upload').post(() async {
  final form = await Context.current.request.getFormData(maxFiles: 1);
  final file = form.files['avatar']?.first;
  if (file == null) return JsonResult({'error': 'no file'}, status: 400);

  final bytes = await file.stream.fold<List<int>>([], (a, b) => a..addAll(b));
  await File('uploads/${file.filename}').writeAsBytes(bytes);
  return StatusResult(status: 201);
});
```

---

## CLI

| Command | Description |
|---------|-------------|
| `lyzor create <name>` | Scaffold a new project |
| `lyzor dev` | Start dev server with hot-reload |
| `lyzor add feature <name>` | Generate controller / service / repository |

---

## License

MIT
