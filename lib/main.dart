import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spendwise/app/app.dart';
import 'package:spendwise/core/logging/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const logger = AppLogger('Main');
  FlutterError.onError = (details) {
    logger.error('Unhandled Flutter error', details.exception, details.stack);
    FlutterError.presentError(details);
  };

  runApp(const ProviderScope(child: SpendwiseApp()));
}
