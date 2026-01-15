import 'package:lyzor/lyzor.dart';

Future<void> main() async {
  final app = Lyzor();

  app.route('/').get((ctx) async {
    await ctx.response.text('Hello from __name__!');
  });

  await app.run(port: 8080);
}
