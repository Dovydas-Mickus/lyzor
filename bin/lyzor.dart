import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addCommand('dev')
    ..addCommand('build')
    ..addCommand('create')
    ..addCommand('add');

  late final ArgResults args;

  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    print(e.message);
    print('Usage: lyzor <command>');
    print(parser.usage);
    exit(64);
  }

  if (args.command == null) {
    print('Usage: lyzor <command>');
    print(parser.usage);
    exit(0);
  }

  switch (args.command!.name) {
    case 'dev':
      await _handleDev(args.command!);
      break;

    case 'build':
      print('running build');
      break;

    case 'create':
      await _handleCreate(args.command!);
      break;

    case 'add':
      await _handleAdd(args.command!);
      break;

    default:
      print('Unknown command: ${args.command!.name}');
      print(parser.usage);
  }
}

Future<void> _handleAdd(ArgResults command) async {
  final rest = command.rest;

  if (rest.length < 2 || (rest[0] != 'feature' && rest[0] != 'f')) {
    print('Usage: lyzor add feature <name>');
    print('Alias: lyzor add f <name>');
    exit(64);
  }

  final featureName = rest[1];

  final classNamePrefix = _capitalize(featureName);
  final fileNamePrefix = featureName.toLowerCase();

  final libDir = Directory('lib');
  final baseDir = await libDir.exists() ? Directory(p.join('lib', 'features')) : Directory('features');

  final targetDir = Directory(p.join(baseDir.path, fileNamePrefix));

  if (!await targetDir.exists()) {
    print('Creating feature directory: ${targetDir.path}');
    await targetDir.create(recursive: true);
  } else {
    print('Directory already exists, adding missing files...');
  }

  await _createFile(targetDir, '${fileNamePrefix}_controller.dart', """import 'package:lyzor/lyzor.dart';

class ${classNamePrefix}Controller implements Controller {
  @override
  void registerRoutes(Lyzor app) {
  }
}""");

  await _createFile(targetDir, '${fileNamePrefix}_repository.dart', 'class ${classNamePrefix}Repository {\n}\n');

  await _createFile(targetDir, '${fileNamePrefix}_service.dart', 'class ${classNamePrefix}Service {\n}\n');

  print('Feature "$featureName" created successfully.');
}

Future<void> _createFile(Directory dir, String filename, String content) async {
  final file = File(p.join(dir.path, filename));
  if (await file.exists()) {
    print('  Skipping $filename (already exists)');
  } else {
    await file.writeAsString(content);
    print('  Created $filename');
  }
}

String _capitalize(String input) {
  if (input.isEmpty) return input;
  return input[0].toUpperCase() + input.substring(1);
}

Future<void> _handleCreate(ArgResults command) async {
  final rest = command.rest;

  if (rest.isEmpty) {
    print('Usage: lyzor create <project_name>');
    exit(64);
  }

  final name = rest.first;
  final targetDir = Directory(name);

  if (await targetDir.exists()) {
    print('Directory "$name" already exists.');
    exit(64);
  }

  final libUri = await Isolate.resolvePackageUri(Uri.parse('package:lyzor/lyzor.dart'));

  if (libUri == null) {
    print('Error: Could not resolve package path. Are you sure the package is installed?');
    exit(1);
  }

  final packageRoot = File(p.fromUri(libUri)).parent.parent;
  final templateDir = Directory(p.join(packageRoot.path, 'template', 'basic'));

  if (!await templateDir.exists()) {
    print('Template directory not found: ${templateDir.path}');
    exit(1);
  }

  print('Creating project $name...');
  await _copyTemplate(templateDir, targetDir, replacements: {'__name__': name});

  print('');
  print('Project "$name" created.');
  print('Next steps:');
  print('  cd $name');
  print('  dart pub get');
  print('  dart run bin/main.dart');
}

Future<void> _copyTemplate(Directory source, Directory target, {Map<String, String> replacements = const {}}) async {
  await target.create(recursive: true);

  await for (final entity in source.list(recursive: true)) {
    final relativePath = p.relative(entity.path, from: source.path);
    var newPath = p.join(target.path, relativePath);

    if (newPath.endsWith('.tpl')) {
      newPath = newPath.substring(0, newPath.length - 4);
    }

    if (entity is Directory) {
      await Directory(newPath).create(recursive: true);
    } else if (entity is File) {
      final contents = await entity.readAsString();
      var output = contents;
      replacements.forEach((key, value) {
        output = output.replaceAll(key, value);
      });

      final outFile = File(newPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsString(output);
    }
  }
}

Future<void> _handleDev(ArgResults command) async {
  final projectDir = Directory.current.path;
  final entryFile = p.join(projectDir, 'lib', 'main.dart');

  if (!File(entryFile).existsSync()) {
    print('Could not find entry file: $entryFile');
    exit(1);
  }

  Process? child;
  bool restarting = false;
  Timer? debounce;

  Future<void> start() async {
    print('Starting dev server...');
    child = await Process.start('dart', ['run', 'lib/main.dart'], workingDirectory: projectDir, runInShell: false);

    child!.stdout.listen(stdout.add);
    child!.stderr.listen(stderr.add);

    child!.exitCode.then((code) {
      if (!restarting) {
        print('Server exited with code $code');
      }
    });
  }

  Future<void> restart() async {
    if (restarting) return;
    restarting = true;
    print('\nChange detected, restarting server...\n');

    if (child != null) {
      final old = child!;
      old.kill();
      try {
        await old.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {
        old.kill(ProcessSignal.sigkill);
      }
      child = null;
    }

    await start();
    restarting = false;
  }

  await start();

  final watchers = <DirectoryWatcher>[
    DirectoryWatcher(p.join(projectDir, 'lib')),
    DirectoryWatcher(p.join(projectDir, 'bin')),
  ];

  for (final w in watchers) {
    w.events.listen((event) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), () {
        restart();
      });
    });
  }

  print('Watching for file changes in lib/ and bin/ (press q + Enter to stop)...');

  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().toLowerCase() == 'q') {
      print('\nStopping dev server...');
      if (child != null) {
        child!.kill();
      }
      exit(0);
    }
  }
}
