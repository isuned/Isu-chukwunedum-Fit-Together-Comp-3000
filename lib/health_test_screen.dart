
import 'package:flutter/material.dart';

import 'health_service.dart';

class HealthTestScreen extends StatefulWidget {
  const HealthTestScreen({super.key});

  @override
  State<HealthTestScreen> createState() =>
      _HealthTestScreenState();
}

class _HealthTestScreenState extends State<HealthTestScreen> {
  final HealthService healthService = HealthService();

  int? steps;
  String? errorMessage;
  bool loading = false;

  Future<void> readSteps() async {
    setState(() {
      loading = true;
      errorMessage = null;
    });

    try {
      final result = await healthService.getTodaySteps();

      if (!mounted) return;

      setState(() {
        steps = result;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Connect Test'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.directions_walk,
                size: 64,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                "Today's Real Steps",
                style: TextStyle(fontSize: 22),
              ),
              const SizedBox(height: 16),
              Text(
                steps == null ? '--' : '$steps',
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: loading ? null : readSteps,
                icon: const Icon(Icons.sync),
                label: Text(
                  loading ? 'Reading...' : 'Read My Steps',
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 16),
                const CircularProgressIndicator(),
              ],
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
