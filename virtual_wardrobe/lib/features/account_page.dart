import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app/theme/app_colors.dart';
import '../core/services/auth_api.dart';
import '../core/services/token_storage.dart';
import 'image_edit_page.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _loading = false;
  String? _error;

  String? _avatarUrl;
  String? _avatarLocalPath;
  String? _fullBodyUrl;
  String? _fullBodyLocalPath;
  bool _fullBodyUploading = false;

  final _nameCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();
  DateTime? _selectedBirthDate;

  String? _selectedGender;
  bool _isMetric = true; // true: 公制(cm/kg), false: 英制(ft/lb)

  final List<String> _genderOptions = ['Male', 'Female', 'Other', 'Prefer not to say'];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _heightCtrl.dispose();
    _weightCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final avatar = await AuthApi.getMyAvatar(token);
      if (!mounted) return;
      setState(() {
        _avatarUrl = avatar;
        _avatarLocalPath = null;
      });

      // TODO: 若你有 GET /profile/me，可以在這裡把數據填回 Controller
      // e.g. _nameCtrl.text = profileData['name'] ?? '';
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedBirthDate = picked;
        _birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  int? _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return null;
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  Future<void> _saveProfile() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final name = _nameCtrl.text.trim();
    final height = int.tryParse(_heightCtrl.text.trim());
    final weight = double.tryParse(_weightCtrl.text.trim());
    final age = _calculateAge(_selectedBirthDate);

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthApi.updateMyProfile(
        token,
        name: name.isNotEmpty ? name : null,
        height: height,
        weight: weight,
        age: age,
      );

      // TODO: 如果後端支援 gender 與 unit_system，也一併傳送
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
    } on AuthExpiredException {
      if (!mounted) return;
      await AuthExpiredHandler.handle(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _buildAvatarProvider();

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],

          const SizedBox(height: 12),
          Center(
            child: Stack(
              children: [
                CircleAvatar(radius: 56, backgroundImage: avatarProvider),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: InkWell(
                    onTap: _loading ? null : _changeAvatar,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black87,
                      ),
                      child: const Icon(Icons.edit, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _field('Full Name', _nameCtrl, keyboard: TextInputType.name),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: _genderOptions.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
            onChanged: (val) => setState(() => _selectedGender = val),
          ),
          const SizedBox(height: 16),

          _field(
            'Birth Date',
            _birthDateCtrl,
            readOnly: true,
            onTap: _pickBirthDate,
            suffixIcon: const Icon(Icons.calendar_today, size: 20),
          ),

          const SizedBox(height: 24),
          const Divider(),
          SwitchListTile(
            title: const Text('Use Metric Units (cm/kg)'),
            subtitle: Text(_isMetric ? 'Currently: Metric' : 'Currently: Imperial (ft/lb)'),
            value: _isMetric,
            onChanged: (val) => setState(() => _isMetric = val),
          ),
          const Divider(),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _field(
                  _isMetric ? 'Height (cm)' : 'Height (ft/in)',
                  _heightCtrl,
                  keyboard: TextInputType.text,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _field(
                  _isMetric ? 'Weight (kg)' : 'Weight (lb)',
                  _weightCtrl,
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Text('Full Body Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildBodyPhotoSection(),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _loading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Profile', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // --- 輔助 UI 元件與方法 ---

  ImageProvider _buildAvatarProvider() {
    if (_avatarLocalPath != null) return FileImage(File(_avatarLocalPath!));
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) return NetworkImage(_avatarUrl!);
    return const AssetImage('assets/avatar_placeholder.png');
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType? keyboard,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Future<void> _changeAvatar() async {
    final picked = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditPage(initialPath: _avatarLocalPath ?? _avatarUrl)),
    );
    if (picked == null || picked.isEmpty) return;
    setState(() => _avatarLocalPath = picked);
    await _uploadAvatar(picked);
  }

  Future<void> _uploadAvatar(String localPath) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;
    setState(() => _loading = true);
    try {
      final init = await AuthApi.avatarInitUpload(token);
      await AuthApi.putJpegToSignedUrl(init.uploadUrl, localPath);
      await AuthApi.avatarComplete(token, objectName: init.objectName);
      final avatar = await AuthApi.getMyAvatar(token);
      if (mounted) setState(() { _avatarUrl = avatar; _avatarLocalPath = null; });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBodyPhotoSection() {
    final bool hasBodyImage = _fullBodyLocalPath != null || (_fullBodyUrl != null && _fullBodyUrl!.isNotEmpty);
    final ImageProvider? bodyProvider = _fullBodyLocalPath != null
        ? FileImage(File(_fullBodyLocalPath!))
        : (_fullBodyUrl != null && _fullBodyUrl!.isNotEmpty) ? NetworkImage(_fullBodyUrl!) : null;

    return InkWell(
      onTap: (_loading || _fullBodyUploading) ? null : _changeFullBodyPhoto,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (bodyProvider != null)
                  Image(image: bodyProvider, fit: BoxFit.cover)
                else
                  const Center(child: Text('Tap to upload full body photo', style: TextStyle(color: AppColors.textSecondary))),
                if (_fullBodyUploading) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeFullBodyPhoto() async {
    final result = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditPage(initialPath: _fullBodyLocalPath ?? _fullBodyUrl)),
    );
    if (result != null) setState(() => _fullBodyLocalPath = result);
  }
}
