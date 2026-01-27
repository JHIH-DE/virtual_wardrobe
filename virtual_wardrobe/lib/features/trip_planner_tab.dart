import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/theme/app_colors.dart';

class TripPlannerTab extends StatefulWidget {
  const TripPlannerTab({super.key});

  @override
  State<TripPlannerTab> createState() => _TripPlannerTabState();
}

class _TripPlannerTabState extends State<TripPlannerTab> {
  bool _isLoading = false;
  List<DailyWeather> _forecast = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _forecast.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.travel_explore, size: 64, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        "Please select a location first",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => const CreateTripDialog(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Create New Trip"),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _forecast.length,
                  itemBuilder: (context, index) {
                    final item = _forecast[index];
                    return _ForecastCard(MeteoDailyForecast(
                      date: DateTime.parse(item.date),
                      maxTemp: item.high,
                      minTemp: item.low,
                      weatherCode: item.weatherCode,
                    ));
                  },
                ),
    );
  }
}

// --- Data Models ---

class DailyWeather {
  final String date;
  final int high;
  final int low;
  final int weatherCode;

  DailyWeather({
    required this.date,
    required this.high,
    required this.low,
    required this.weatherCode,
  });

  Map<String, dynamic> toJson() => {
        "date": date,
        "high": high,
        "low": low,
        "weatherCode": weatherCode,
      };
}

class LocationResult {
  final String name;
  final double latitude;
  final double longitude;

  LocationResult({
    required this.name,
    required this.latitude,
    required this.longitude,
  });
}

class MeteoDailyForecast {
  final DateTime date;
  final int maxTemp;
  final int minTemp;
  final int weatherCode;

  MeteoDailyForecast({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.weatherCode,
  });
}

// --- Components ---

class _ForecastCard extends StatelessWidget {
  final MeteoDailyForecast day;
  const _ForecastCard(this.day);

  @override
  Widget build(BuildContext context) {
    final condition = _mapWeatherCodeToText(day.weatherCode);
    final icon = _mapWeatherCodeToIcon(day.weatherCode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: AppColors.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEE, MMM d').format(day.date),
                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$condition · H:${day.maxTemp}° L:${day.minTemp}°',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${day.maxTemp}°',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  String _mapWeatherCodeToText(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Clouds';
    if (code == 45 || code == 48) return 'Fog';
    if (code <= 55) return 'Drizzle';
    if (code <= 65) return 'Rain';
    if (code <= 77) return 'Snow';
    if (code <= 82) return 'Rain';
    return 'Thunderstorm';
  }

  IconData _mapWeatherCodeToIcon(int code) {
    final text = _mapWeatherCodeToText(code);
    switch (text) {
      case 'Clear': return Icons.wb_sunny_rounded;
      case 'Clouds': return Icons.cloud_rounded;
      case 'Rain': return Icons.umbrella_rounded;
      case 'Snow': return Icons.ac_unit_rounded;
      case 'Fog': return Icons.foggy;
      default: return Icons.wb_cloudy_rounded;
    }
  }
}

class CreateTripDialog extends StatefulWidget {
  const CreateTripDialog({super.key});

  @override
  State<CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<CreateTripDialog> {
  final TextEditingController _tripNameController = TextEditingController();
  DateTimeRange? _dateRange;
  LocationResult? _location;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text("New Trip", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _tripNameController,
            decoration: const InputDecoration(
              labelText: "Trip Name",
              labelStyle: TextStyle(color: AppColors.textSecondary),
              border: UnderlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dateRange == null ? "Select Dates" : "${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}"),
            leading: const Icon(Icons.calendar_today, color: AppColors.primary),
            onTap: _pickDateRange,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_location == null ? "Select Location" : _location!.name),
            leading: const Icon(Icons.location_on, color: AppColors.primary),
            onTap: _pickLocation,
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Cancel", style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _saveTrip,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text("Create"),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickDateRange() async {
    final result = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (result != null) setState(() => _dateRange = result);
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LocationPickerPage()),
    );
    if (result is LocationResult) setState(() => _location = result);
  }

  Future<void> _saveTrip() async {
    if (_tripNameController.text.isEmpty || _dateRange == null || _location == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }
    Navigator.pop(context);
  }
}

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});
  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _controller = TextEditingController();
  List<LocationResult> _results = [];
  bool _isLoading = false;

  Future<void> _search() async {
    if (_controller.text.isEmpty) return;
    setState(() => _isLoading = true);
    final url = Uri.parse('https://geocoding-api.open-meteo.com/v1/search?name=${_controller.text}&count=5');
    try {
      final res = await http.get(url);
      final data = json.decode(res.body);
      if (data['results'] != null) {
        setState(() {
          _results = (data['results'] as List).map((r) => LocationResult(
            name: "${r['name']}, ${r['country']}",
            latitude: r['latitude'],
            longitude: r['longitude'],
          )).toList();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text("Search Location"),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: "City name...",
                prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (context, i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: ListTile(
                  title: Text(_results[i].name, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.pop(context, _results[i]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
