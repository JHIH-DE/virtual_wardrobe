import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../app/theme/app_colors.dart';
import '../../core/utils/debug_log.dart';
import '../../data/location_result.dart';
import '../../l10n/generated/app_localizations.dart';
import '../widgets/common/app_tool_bar.dart';
import '../widgets/common/images/app_spinner.dart';
import '../widgets/common/overlays/error_dialog.dart';

class LocationPickerPage extends StatefulWidget {
  const LocationPickerPage({super.key});

  @override
  State<LocationPickerPage> createState() => _LocationPickerPageState();
}

class _LocationPickerPageState extends State<LocationPickerPage> {
  final TextEditingController _controller = TextEditingController();
  List<LocationResult> _results = [];
  bool _isLoading = false;

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _isLoading = true);
    final language = Localizations.localeOf(context).languageCode;
    try {
      final responses = await Future.wait(
        _queryVariants(query).map(
          (name) => http
              .get(
                Uri.parse(
                  'https://geocoding-api.open-meteo.com/v1/search'
                  '?name=${Uri.encodeQueryComponent(name)}'
                  '&count=5&language=$language',
                ),
              )
              .timeout(const Duration(seconds: 15)),
        ),
      );
      final byId = <Object, Map<String, dynamic>>{};
      for (final res in responses) {
        final results = json.decode(res.body)['results'] as List?;
        for (final r in results ?? const []) {
          byId.putIfAbsent(
            r['id'] ?? '${r['latitude']},${r['longitude']}',
            () => r,
          );
        }
      }
      // Variant queries can surface a small homonym (e.g. 高雄 in Sichuan)
      // alongside the intended city, so rank the merged set by population.
      final merged = byId.values.toList()
        ..sort(
          (a, b) => ((b['population'] as num?) ?? 0).compareTo(
            (a['population'] as num?) ?? 0,
          ),
        );
      if (!mounted) return;
      setState(() {
        _results = merged
            .take(8)
            .map(
              (r) => LocationResult(
                name: "${r['name']}, ${r['country']}",
                latitude: (r['latitude'] as num).toDouble(),
                longitude: (r['longitude'] as num).toDouble(),
                timezone: r['timezone'] ?? 'UTC',
              ),
            )
            .toList();
      });
    } catch (e) {
      debugLog('LocationPickerPage search error: $e');
      if (!mounted) return;
      showErrorDialog(context, message: _l10n.locationSearchFailed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Open-Meteo only matches a GeoNames name/alternate name exactly — there is
  /// no prefix or fuzzy matching for CJK text. Its Chinese alternate names are
  /// usually the full administrative form in one specific script (`台北市`,
  /// `臺中市`, `花蓮市`), so a bare `台北` / `台中` finds nothing. For CJK input,
  /// also try the 台/臺 spelling swap and a trailing `市`.
  static List<String> _queryVariants(String query) {
    if (!RegExp(r'[\u4e00-\u9fff]').hasMatch(query)) return [query];
    final spellings = {
      query,
      query.replaceAll('台', '臺'),
      query.replaceAll('臺', '台'),
    };
    return {
      for (final s in spellings) ...[
        s,
        if (!RegExp(r'[市縣县]$').hasMatch(s)) '$s市',
      ],
    }.toList();
  }

  AppToolBar _buildAppBar() {
    return AppToolBar(title: _l10n.searchLocationTitle);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchField(),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: AppSpinner()),
            ),
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
          hintText: _l10n.cityNameHint,
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
