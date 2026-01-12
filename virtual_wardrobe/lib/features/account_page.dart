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
  bool _isMetric = true; 

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
      final profile = await AuthApi.getMyProfile(token);

      if (!mounted) return;

      setState(() {
        _avatarUrl = profile['avatar_object_url'] as String?;
        _fullBodyUrl = profile['full_body_object_url'] as String?;
        
        _nameCtrl.text = profile['name'] ?? '';
        _selectedGender = profile['gender'];
        
        final birthdayStr = profile['birthday'] as String?;
        if (birthdayStr != null && birthdayStr.isNotEmpty) {
          try {
            _selectedBirthDate = DateTime.parse(birthdayStr);
            _birthDateCtrl.text = DateFormat('yyyy-MM-dd').format(_selectedBirthDate!);
          } catch (_) {}
        }

        if (profile['height'] != null) {
          _heightCtrl.text = profile['height'].toString();
        }
        if (profile['weight'] != null) {
          _weightCtrl.text = profile['weight'].toString();
        }

        _isMetric = (profile['unit_system'] ?? 'metric') == 'metric';
      });

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

  Future<void> _saveProfile() async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;

    final name = _nameCtrl.text.trim();
    final gender = _selectedGender;
    final birthday = _selectedBirthDate != null 
        ? DateFormat('yyyy-MM-dd').format(_selectedBirthDate!) 
        : null;
    final height = num.tryParse(_heightCtrl.text.trim());
    final weight = num.tryParse(_weightCtrl.text.trim());
    final unitSystem = _isMetric ? 'metric' : 'imperial';

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
     final result = await AuthApi.updateMyProfile(
        token,
        name: name.isNotEmpty ? name : null,
        gender: gender,
        birthday: birthday,
        height: height,
        weight: weight,
        unitSystem: unitSystem,
      );

      if (!mounted) return;
      Navigator.pop(context, result);
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
          _buildAvatarSection(),

          const SizedBox(height: 24),
          const Text('Profile Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          _field('Full Name', _nameCtrl, keyboard: TextInputType.name),
          const SizedBox(height: 16),

          DropdownButtonFormField<String>(
            value: (_genderOptions.contains(_selectedGender)) ? _selectedGender : null,
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
            title: const Text('Unit System'),
            subtitle: Text(_isMetric ? 'Metric (cm/kg)' : 'Imperial (ft/lb)'),
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

  // --- Helpers ---

  Widget _buildAvatarSection() {
    ImageProvider? provider;
    if (_avatarLocalPath != null) {
      provider = FileImage(File(_avatarLocalPath!));
    } else if (_avatarUrl != null && _avatarUrl!.isNotEmpty && _avatarUrl != "string") {
      provider = NetworkImage(_avatarUrl!);
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 56,
            backgroundColor: AppColors.surface,
            backgroundImage: provider,
            child: provider == null
                ? const Icon(Icons.person, size: 56, color: AppColors.textSecondary)
                : null,
          ),
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
    );
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
      final newUrl = await AuthApi.avatarComplete(token, objectName: init.objectName);
      if (mounted) {
        setState(() {
          _avatarUrl = newUrl;
          _avatarLocalPath = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildBodyPhotoSection() {
    final bool hasLocal = _fullBodyLocalPath != null;
    final bool hasUrl = _fullBodyUrl != null && _fullBodyUrl!.isNotEmpty && _fullBodyUrl != "string";
    
    ImageProvider? bodyProvider;
    if (hasLocal) {
      bodyProvider = FileImage(File(_fullBodyLocalPath!));
    } else if (hasUrl) {
      bodyProvider = NetworkImage(_fullBodyUrl!);
    }

    return InkWell(
      onTap: (_loading || _fullBodyUploading) ? null : _changeFullBody,
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
                  Image(
                    key: ValueKey(bodyProvider is NetworkImage ? _fullBodyUrl : _fullBodyLocalPath),
                    image: bodyProvider,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.broken_image_outlined, color: AppColors.textSecondary, size: 40),
                            SizedBox(height: 8),
                            Text('Failed to load photo', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    },
                  )
                else
                  const Center(child: Text('Tap to upload full body photo', style: TextStyle(color: AppColors.textSecondary))),
                
                if (_fullBodyUploading) 
                  Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _changeFullBody() async {
    final picked = await Navigator.push<String?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditPage(initialPath: _fullBodyLocalPath ?? _fullBodyUrl)),
    );
    if (picked == null || picked.isEmpty) return;
    
    setState(() => _fullBodyLocalPath = picked); 
    await _uploadFullBody(picked);
  }

  Future<void> _uploadFullBody(String localPath) async {
    final token = await TokenStorage.getAccessToken();
    if (token == null || token.isEmpty) return;
    
    setState(() => _fullBodyUploading = true); 
    try {
      final init = await AuthApi.fullBodyInitUpload(token); 
      await AuthApi.putJpegToSignedUrl(init.uploadUrl, localPath);
      final newUrl = await AuthApi.fullBodyComplete(token, objectName: init.objectName);
      
      if (mounted) {
        setState(() {
          _fullBodyUrl = newUrl;
          _fullBodyLocalPath = null; // 在 URL 準備好後才清空 LocalPath
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _fullBodyUploading = false);
    }
  }
}
