import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../app/theme/app_colors.dart';
import '../data/location_result.dart';
import 'widgets/common/app_tool_bar.dart';

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
    final url = Uri.parse(
      'https://geocoding-api.open-meteo.com/v1/search?name=${_controller.text}&count=5',
    );
    try {
      final res = await http.get(url);
      final data = json.decode(res.body);
      if (data['results'] != null) {
        setState(() {
          _results = (data['results'] as List)
              .map(
                (r) => LocationResult(
                  name: "${r['name']}, ${r['country']}",
                  latitude: r['latitude'],
                  longitude: r['longitude'],
                  timezone: r['timezone'] ?? 'UTC',
                ),
              )
              .toList();
        });
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: 'Search Location');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(child: _buildResultsList()),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: "City name...",
          prefixIcon: const Icon(Icons.search),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
        onSubmitted: (_) => _search(),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, i) => _buildResultTile(context, i),
    );
  }

  Widget _buildResultTile(BuildContext context, int i) {
    return ListTile(
      title: Text(_results[i].name),
      onTap: () => Navigator.pop(context, _results[i]),
    );
  }
}
