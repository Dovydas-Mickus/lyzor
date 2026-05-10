import 'package:lyzor/lyzor.dart';

Future<void> main() async {
  final app = Lyzor()
    ..use(recovery())
    ..use(logger());

  app.route('/').get(() => JsonResult({'message': 'Hello from __name__!'}));

  await app.run(port: 8080);
}
