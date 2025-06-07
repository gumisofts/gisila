#!/usr/bin/env dart

/// Simple test CLI for migration tool
library;

import 'dart:io';
import 'package:args/args.dart';

void main(List<String> arguments) async {
  print('🚀 Migration CLI Test');
  
  final parser = ArgParser();
  parser.addFlag('help', abbr: 'h', help: 'Show help', negatable: false);
  parser.addCommand('status');
  
  try {
    final results = parser.parse(arguments);
    
    if (results['help'] as bool) {
      print('Help:');
      print(parser.usage);
      return;
    }
    
    if (results.command?.name == 'status') {
      print('Status: OK');
      return;
    }
    
    print('No command specified. Use --help for options.');
    
  } catch (e) {
    print('Error: $e');
    exit(1);
  }
} 