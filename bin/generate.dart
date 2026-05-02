#!/usr/bin/env dart
//
// Thin wrapper around `dart run build_runner build` so users can keep
// typing `dart run gisila:generate`.

import 'dart:io';

Future<void> main(List<String> args) async {
  final extra = args.toList();
  final passDelete = !extra.contains('--no-delete');
  if (passDelete && !extra.contains('--delete-conflicting-outputs')) {
    extra.add('--delete-conflicting-outputs');
  }

  final result = await Process.start(
    'dart',
    ['run', 'build_runner', 'build', ...extra.where((a) => a != '--no-delete')],
    mode: ProcessStartMode.inheritStdio,
  );
  exit(await result.exitCode);
}
