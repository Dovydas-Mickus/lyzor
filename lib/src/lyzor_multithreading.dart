import 'dart:io';
import 'dart:isolate';

import 'package:lyzor/lyzor.dart';

typedef AppBuilder = Lyzor Function();

extension LyzorMultithreading on Lyzor {
  static Future<void> spawn(AppBuilder builder, {int count = 0, String host = '127.0.0.1', int port = 8080}) async {
    final workers = count <= 0 ? Platform.numberOfProcessors : count;

    print('Starting $workers workers on http://$host:$port');

    for (int i = 0; i < workers; i++) {
      Isolate.spawn(_startWorker, {'builder': builder, 'host': host, 'port': port});
    }

    await ProcessSignal.sigint.watch().first;
  }

  static void _startWorker(Map<String, dynamic> message) async {
    final AppBuilder builder = message['builder'];
    final String host = message['host'];
    final int port = message['port'];

    final app = builder();

    await app.run(host: host, port: port, shared: true);
  }
}
