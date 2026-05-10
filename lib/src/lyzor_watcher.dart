import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

class LyzorWatcher {
  final List<String> paths;
  final List<String> ignore;
  final Duration debounce;

  LyzorWatcher({
    required this.paths,
    this.ignore = const [],
    this.debounce = const Duration(milliseconds: 300),
  });

  Stream<String> get changes {
    final controller = StreamController<String>.broadcast();
    Timer? timer;
    final pending = <String>{};

    for (final path in paths) {
      DirectoryWatcher(path).events.listen((event) {
        if (_shouldIgnore(event.path)) return;
        pending.add(event.path);
        timer?.cancel();
        timer = Timer(debounce, () {
          for (final changed in pending) {
            controller.add(changed);
          }
          pending.clear();
        });
      });
    }

    return controller.stream;
  }

  bool _shouldIgnore(String filePath) {
    final normalized = p.normalize(filePath);
    return ignore.any((pattern) {
      final normalizedPattern = p.normalize(pattern);
      return normalized == normalizedPattern ||
          normalized.startsWith(normalizedPattern + p.separator);
    });
  }
}
