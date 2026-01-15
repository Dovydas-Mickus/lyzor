import 'package:lizard/lizard.dart';

Future<void> main() async {
  final app = Lizard();

  app.route('/').get((ctx) async {
    await ctx.response.send('Hello from __name__!');
  });

  await app.run(port: 8080);
}
