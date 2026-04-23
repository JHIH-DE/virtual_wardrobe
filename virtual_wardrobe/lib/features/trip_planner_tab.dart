import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import '../app/theme/app_colors.dart';
import '../core/services/error_handler.dart';
import '../core/services/weekly_plans_service.dart';
import '../core/services/outfit_service.dart';
import '../core/utils/try_on_mixin.dart';
import '../data/garment_category.dart';
import '../data/look_category.dart';

class TripPlannerTab extends StatefulWidget {
  const TripPlannerTab({super.key});

  @override
  State<TripPlannerTab> createState() => _TripPlannerTabState();
}

class _TripPlannerTabState extends State<TripPlannerTab> {
  final List<TripPlan> _trips = [];

  void _addTrip(TripPlan trip) {
    setState(() {
      _trips.insert(0, trip);
    });
  }

  void _deleteTrip(String id) {
    setState(() {
      _trips.removeWhere((t) => t.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Plan Your Next Adventure",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        "Add locations and see forecasts",
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final result = await showDialog<TripPlan>(
                      context: context,
                      builder: (_) => const CreateTripDialog(),
                    );
                    if (result != null) {
                      _addTrip(result);
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("New Trip"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _trips.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.beach_access, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          "No trips planned yet",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _trips.length,
                    itemBuilder: (context, index) {
                      final trip = _trips[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _TripPlanCard(
                          key: ValueKey(trip.id),
                          trip: trip,
                          onDelete: () => _deleteTrip(trip.id),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class TripPlan {
  final String id;
  final String name;
  final DateTimeRange dateRange;
  final LocationResult location;

  TripPlan({
    required this.id,
    required this.name,
    required this.dateRange,
    required this.location,
  });
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

class _TripPlanCard extends StatelessWidget {
  final TripPlan trip;
  final VoidCallback onDelete;

  const _TripPlanCard({
    super.key,
    required this.trip,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${DateFormat('MMM d').format(trip.dateRange.start)} - ${DateFormat('MMM d, yyyy').format(trip.dateRange.end)}";

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TripDetailsPage(trip: trip),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    trip.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.white70),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Delete Trip"),
                        content: const Text("Are you sure you want to delete this trip?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text("Cancel"),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              onDelete();
                            },
                            child: const Text("Delete", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    trip.location.name,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "View Plan",
                  style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TripDetailsPage extends StatefulWidget {
  final TripPlan trip;
  const TripDetailsPage({super.key, required this.trip});

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> with TryOnMixin {
  bool _loading = true;
  int _selectedDayIndex = 0;
  
  List<int> _weatherCodes = [];
  List<double> _highTemps = [];
  List<double> _lowTemps = [];
  
  List<Garment> _todayGarments = [];
  bool _loadingOutfits = false;
  String? _todayLookImageUrl;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _loading = true);
    try {
      await _fetchTripWeather();
      await _loadDailyData();
    } catch (e) {
      debugPrint('Trip initialization error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchTripWeather() async {
    final startOffset = widget.trip.dateRange.start.difference(DateTime.now()).inDays;
    final duration = widget.trip.dateRange.duration.inDays + 1;
    final lat = widget.trip.location.latitude;
    final lon = widget.trip.location.longitude;
    int daysNeeded = startOffset + duration;
    if (daysNeeded > 16) daysNeeded = 16;
    if (daysNeeded < 7) daysNeeded = 7;
    final url = 'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&daily=weathercode,temperature_2m_max,temperature_2m_min&timezone=auto&forecast_days=$daysNeeded';
    
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _weatherCodes = List<int>.from(data['daily']['weathercode']);
          _highTemps = List<double>.from(data['daily']['temperature_2m_max'].map((t) => (t as num).toDouble()));
          _lowTemps = List<double>.from(data['daily']['temperature_2m_min'].map((t) => (t as num).toDouble()));
        });
      }
    } catch (e) {
      debugPrint('Fetch trip weather failed: $e');
    }
  }

  Future<void> _loadDailyData() async {
    await _getGarments();
    await _getOutfits();
  }

  Future<void> _getGarments() async {
    final date = widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    setState(() => _loadingOutfits = true);
    try {
      final list = await WeeklyPlansService().getGarments(dayStr);
      if (mounted) setState(() => _todayGarments = list);
    } catch (e) {
      debugPrint('Failed to get trip garments: $e');
    } finally {
      if (mounted) setState(() => _loadingOutfits = false);
    }
  }

  Future<void> _getOutfits() async {
    final date = widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
    final dayStr = DateFormat('yyyy-MM-dd').format(date);
    try {
      final jobId = await WeeklyPlansService().getLook(dayStr);
      if (jobId != null) {
        final statusRes = await OutfitService().getOutfit(jobId);
        if (mounted) setState(() => _todayLookImageUrl = statusRes['result_image_url']);
      } else {
        if (mounted) setState(() => _todayLookImageUrl = null);
      }
    } catch (e) {
      debugPrint('Failed to get trip outfits: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.trip.name),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildTripHeader(),
          const SizedBox(height: 20),
          _buildTripDaySelector(),
          const SizedBox(height: 20),
          _buildWardrobeSection(),
          const SizedBox(height: 20),
          _TodayOutfitIdea(
            onSave: _onSaveLook,
            onRegenerate: _handleGenerateLook,
            imageUrl: tryOnResultUrl ?? _todayLookImageUrl,
            isLoading: _loadingOutfits || isOutfitLoading,
            onGenerate: _handleGenerateLook,
            jobStatus: isOutfitLoading ? (tryOnJobId == 0 ? 'Creating...' : 'Generating...') : null,
            errorMessage: tryOnErrorMessage,
          ),
        ],
      ),
    );
  }

  Widget _buildTripHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(widget.trip.location.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "${DateFormat('MMM d').format(widget.trip.dateRange.start)} - ${DateFormat('MMM d, yyyy').format(widget.trip.dateRange.end)}",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildTripDaySelector() {
    final int totalDays = widget.trip.dateRange.duration.inDays + 1;
    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: totalDays,
        itemBuilder: (context, index) {
          final date = widget.trip.dateRange.start.add(Duration(days: index));
          final isSelected = index == _selectedDayIndex;
          
          return GestureDetector(
            onTap: () {
              setState(() => _selectedDayIndex = index);
              _loadDailyData();
            },
            child: Container(
              width: 100,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.1) : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: isSelected ? 2 : 1),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(DateFormat('M/d').format(date), style: TextStyle(
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  if (_weatherCodes.length > index)
                    Column(
                      children: [
                        Icon(_mapWeatherIcon(_weatherCodes[index]), size: 28, color: AppColors.textPrimary),
                        const SizedBox(height: 4),
                        Text(
                          "${_highTemps[index].round()}° / ${_lowTemps[index].round()}°",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWardrobeSection() {
    final dateStr = DateFormat('EEEE, MMM d').format(widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Wardrobe for $dateStr", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_loadingOutfits)
          const Center(child: CircularProgressIndicator())
        else if (_todayGarments.isEmpty)
          _buildEmptyState("No items planned")
        else
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _todayGarments.length,
              itemBuilder: (context, index) => _buildGarmentItem(_todayGarments[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildGarmentItem(Garment g) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: g.imageUrl != null && g.imageUrl!.isNotEmpty
            ? Image.network(g.imageUrl!, fit: BoxFit.cover)
            : const Icon(Icons.inventory_2_outlined, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Center(child: Text(msg, style: const TextStyle(color: AppColors.textSecondary))),
    );
  }

  IconData _mapWeatherIcon(int code) {
    if (code <= 3) return Icons.wb_sunny_rounded;
    if (code <= 67) return Icons.umbrella_rounded;
    return Icons.wb_cloudy_rounded;
  }

  Future<void> _handleGenerateLook() async {
    if (_todayGarments.isEmpty) return;
    final ids = _todayGarments.where((g) => g.id != null).map((g) => g.id!).toList();
    final int? jobId = await performTryOn(ids, "weekly");
    
    if (jobId != null) {
      final date = widget.trip.dateRange.start.add(Duration(days: _selectedDayIndex));
      final dayStr = DateFormat('yyyy-MM-dd').format(date);
      try {
        await WeeklyPlansService().saveJobId(dayStr, jobId);
      } catch (e) {
        debugPrint('Failed to save jobId: $e');
      }
    }
  }

  Future<void> _onSaveLook() async {
    final url = tryOnResultUrl ?? _todayLookImageUrl;
    if (url == null) return;
    
    try {
      Look look = Look(
        id: tryOnJobId,
        imageUrl: url,
        seasons: 'Trip',
        style: 'Daily',
        advice: tryOnAiAdvice,
      );

      LooksStore.I.add(look);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved to Closet ✅')));
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }
}

class _TodayOutfitIdea extends StatelessWidget {
  final VoidCallback onSave;
  final VoidCallback onRegenerate;
  final String? imageUrl;
  final bool isLoading;
  final VoidCallback onGenerate;
  final String? jobStatus;
  final String? errorMessage;

  const _TodayOutfitIdea({
    required this.onSave,
    required this.onRegenerate,
    this.imageUrl,
    this.isLoading = false,
    required this.onGenerate,
    this.jobStatus,
    this.errorMessage,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(jobStatus ?? "Loading...", style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(errorMessage!, textAlign: TextAlign.center),
                  ),
                  const SizedBox(height: 16),
                  TextButton(onPressed: onGenerate, child: const Text("Try Again")),
                ],
              ),
            )
          else if (hasImage)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.network(
                  imageUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Column(
                children: [
                  Icon(Icons.auto_awesome, size: 64, color: AppColors.primary.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  const Text("No look image yet", style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: onGenerate,
                    icon: const Icon(Icons.brush_rounded, color: Colors.white),
                    label: const Text("Generate Look", style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            ),
          
          if (hasImage && !isLoading && errorMessage == null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text("Regenerate"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_border_rounded),
                      label: const Text("Save"),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
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
      title: const Text("New Trip", style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _tripNameController,
            decoration: const InputDecoration(labelText: "Trip Name"),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_dateRange == null
                ? "Select Dates"
                : "${DateFormat('MM/dd').format(_dateRange!.start)} - ${DateFormat('MM/dd').format(_dateRange!.end)}"),
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
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _saveTrip, child: const Text("Create")),
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
    Navigator.pop(
      context,
      TripPlan(
        id: DateTime.now().toIso8601String(),
        name: _tripNameController.text,
        dateRange: _dateRange!,
        location: _location!,
      ),
    );
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
          _results = (data['results'] as List)
              .map((r) => LocationResult(
                    name: "${r['name']}, ${r['country']}",
                    latitude: r['latitude'],
                    longitude: r['longitude'],
                  ))
              .toList();
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
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _results.length,
              itemBuilder: (context, i) => ListTile(
                title: Text(_results[i].name),
                onTap: () => Navigator.pop(context, _results[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
