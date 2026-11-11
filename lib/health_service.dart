

import 'dart:io';

import 'package:health/health.dart';

class HealthService {
  final Health _health = Health();

  Future<int> getTodaySteps() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError(
        'Health Connect requires an Android device.',
      );
    }

    // Configure Health Connect.
    await _health.configure();

    // Request permission to read step records.
    final authorised = await _health.requestAuthorization(
      [HealthDataType.STEPS],
      permissions: [HealthDataAccess.READ],
    );

    if (!authorised) {
      throw StateError(
        'Health Connect permission was not granted.',
      );
    }

    // Calculate the start of the current day.
    final now = DateTime.now();

    final startOfToday = DateTime(
      now.year,
      now.month,
      now.day,
    );

    // Retrieve today's total steps from Health Connect.
    final steps = await _health.getTotalStepsInInterval(
      startOfToday,
      now,
    );

    if (steps == null) {
      throw StateError(
        'No step count was returned by Health Connect.',
      );
    }

    return steps;
  }
}
