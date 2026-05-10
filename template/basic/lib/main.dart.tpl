import 'package:lyzor/lyzor.dart';

Lyzor createApp() {
  final app = Lyzor()
    ..use(recovery())
    ..use(logger());

  app.route('/').get(() => JsonResult({'message': 'Hello from __name__!'}));

  return app;
}
