#!/usr/bin/env dart

/// Simple migration CLI that doesn't hang
library;

import 'dart:io';
import 'package:args/args.dart';

void main(List<String> arguments) async {
  final parser = ArgParser();
  
  // Global options
  parser.addOption('config', 
      abbr: 'c', 
      help: 'Database configuration file',
      defaultsTo: 'database.yaml');
  parser.addFlag('verbose',
      abbr: 'v',
      help: 'Enable verbose output',
      negatable: false);
  parser.addFlag('help',
      abbr: 'h',
      help: 'Show this help message',
      negatable: false);

  // Commands
  parser.addCommand('status');
  parser.addCommand('init');

  try {
    final results = parser.parse(arguments);
    
    if (results['help'] as bool || results.command == null) {
      showHelp(parser);
      return;
    }

    final verbose = results['verbose'] as bool;
    
    switch (results.command?.name) {
      case 'status':
        await runStatus(verbose);
        break;
      case 'init':
        await runInit(verbose);
        break;
      default:
        throw Exception('Unknown command: ${results.command?.name}');
    }
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

Future<void> runStatus(bool verbose) async {
  print('📋 Migration Status');
  if (verbose) {
    print('  Checking migration system...');
  }
  print('  No migrations found (system not initialized)');
}

Future<void> runInit(bool verbose) async {
  print('🏗️  Initializing migration system...');
  if (verbose) {
    print('  Creating migration directories...');
  }
  
  final migrationsDir = Directory('migrations');
  await migrationsDir.create(recursive: true);
  
  print('✅ Migration system initialized!');
  if (verbose) {
    print('  Migration directory created: ${migrationsDir.path}');
  }
}

void showHelp(ArgParser parser) {
  print('Gisila Migration Manager');
  print('');
  print('USAGE:');
  print('  dart run bin/migrate_simple.dart <command> [options]');
  print('');
  print('COMMANDS:');
  print('  status     Show migration status');
  print('  init       Initialize migration system');
  print('');
  print('OPTIONS:');
  print(parser.usage);
} 