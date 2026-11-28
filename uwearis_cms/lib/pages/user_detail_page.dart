import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/admin_user.dart';
import '../widgets/cms_scope.dart';
import '../widgets/delete_user_dialog.dart';
import '../widgets/feedback.dart';
import '../widgets/points_adjust_dialog.dart';

/// One App account: profile, points, Uwearis Plus and admin rights. Every
/// write returns the whole user, which replaces what is shown.
class UserDetailPage extends StatefulWidget {
  final int userId;
  const UserDetailPage({super.key, required this.userId});

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  static const _historyPageSize = 20;

  AdminUser? _user;
  Object? _error;
  bool _busy = false;
  final _profileKey = GlobalKey<_ProfileFormState>();
  int _profileVersion = 0;
  int _historyVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final user = await CmsScope.read(context).getUser(widget.userId);
      if (mounted) _show(user, resetProfile: true);
    } catch (e) {
      if (mounted) setState(() => _error = e);
      if (_user != null && mounted) await showErrorDialog(context, e);
    }
  }

  Future<void> _reload() async {
    if ((_profileKey.currentState?.dirty ?? false) &&
        !await confirmDiscard(context)) {
      return;
    }
    if (mounted) await _load();
  }

  void _show(AdminUser user, {bool resetProfile = false}) => setState(() {
    _user = user;
    if (resetProfile) _profileVersion++;
  });

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) await showErrorDialog(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveProfile(Map<String, Object?> changes) => _run(() async {
    final user = await CmsScope.read(
      context,
    ).updateUser(widget.userId, changes);
    if (!mounted) return;
    _show(user, resetProfile: true);
    showMessage(context, '已儲存');
  });

  Future<void> _setAdmin(AdminUser user, bool value) => _run(() async {
    final ok = await confirm(
      context,
      title: value ? '授予管理員權限？' : '移除管理員權限？',
      body: value
          ? '${user.email} 將可以登入 CMS，並管理所有內容與使用者。'
          : '${user.email} 下次操作 CMS 時就會被登出。',
      confirmLabel: value ? '授予' : '移除',
      destructive: !value,
    );
    if (!ok || !mounted) return;
    _show(await CmsScope.read(context).setUserAdmin(user.id, value));
    if (mounted) showMessage(context, value ? '已授予管理員權限' : '已移除管理員權限');
  });

  Future<void> _adjust(AdminUser user, {required bool add}) async {
    final updated = await showDialog<AdminUser>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PointsAdjustDialog(user: user, add: add),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _user = updated;
      _historyVersion++;
    });
    showMessage(context, '已調整點數');
  }

  Future<void> _setSubscription(AdminUser user) => _run(() async {
    final now = DateTime.now();
    final current = user.subscriptionExpiresAt;
    final initial = current != null && current.isAfter(now)
        ? current
        : DateTime(now.year, now.month + 1, now.day);
    final day = await showDatePicker(
      context: context,
      helpText: 'Uwearis Plus 到期日（台北時間）',
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      helpText: '到期時間（台北時間）',
      initialTime: current != null && current.isAfter(now)
          ? TimeOfDay.fromDateTime(current)
          : const TimeOfDay(hour: 23, minute: 59),
    );
    if (time == null || !mounted) return;
    final expiresAt = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
      time.hour == 23 && time.minute == 59 ? 59 : 0,
    );
    final ok = await confirm(
      context,
      title: '設定 Uwearis Plus？',
      body:
          '${user.email} 的訂閱到 ${formatTaipei(expiresAt)}（台北時間）。今天的每日點數會依新狀態計算。',
      confirmLabel: '設定',
    );
    if (!ok || !mounted) return;
    _show(await CmsScope.read(context).setSubscription(user.id, expiresAt));
    if (mounted) showMessage(context, '已設定訂閱');
  });

  Future<void> _delete(AdminUser user) async {
    final deleted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => DeleteUserDialog(user: user),
    );
    if (deleted != true || !mounted) return;
    showMessage(context, '已刪除 ${user.email}');
    Navigator.pop(context);
  }

  Future<void> _cancelSubscription(AdminUser user) => _run(() async {
    final ok = await confirm(
      context,
      title: '取消 Uwearis Plus？',
      body: '${user.email} 的訂閱會立即結束。',
      confirmLabel: '取消訂閱',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _show(await CmsScope.read(context).setSubscription(user.id, null));
    if (mounted) showMessage(context, '已取消訂閱');
  });

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final error = _error;
    final selfId = CmsScope.of(context).client.userId;
    return PopScope(
      canPop: !(_profileKey.currentState?.dirty ?? false),
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirmDiscard(context) && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            user == null ? '使用者 #${widget.userId}' : user.displayName,
          ),
          actions: [
            IconButton(
              tooltip: '重新整理',
              onPressed: _busy ? null : _reload,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 8),
          ],
          bottom: _busy
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(2),
                  child: LinearProgressIndicator(minHeight: 2),
                )
              : null,
        ),
        body: error != null && user == null
            ? Center(child: Text(errorText(error)))
            : user == null
            ? const Center(child: CircularProgressIndicator())
            : Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      _Overview(user: user),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _Section(
                            width: 320,
                            title: '點數',
                            child: _PointsPanel(
                              user: user,
                              enabled: !_busy,
                              onAdd: () => _adjust(user, add: true),
                              onRemove: () => _adjust(user, add: false),
                            ),
                          ),
                          _Section(
                            width: 320,
                            title: 'Uwearis Plus',
                            child: _SubscriptionPanel(
                              user: user,
                              enabled: !_busy,
                              onSet: () => _setSubscription(user),
                              onCancel: () => _cancelSubscription(user),
                            ),
                          ),
                          _Section(
                            width: 320,
                            title: '管理員權限',
                            child: _AdminPanel(
                              user: user,
                              isSelf: user.id == selfId,
                              enabled: !_busy,
                              onChanged: (value) => _setAdmin(user, value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: '基本資料',
                        child: _ProfileForm(
                          key: _profileKey,
                          user: user,
                          version: _profileVersion,
                          enabled: !_busy,
                          onDirtyChanged: () => setState(() {}),
                          onSave: _saveProfile,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Section(
                        title: '點數紀錄',
                        child: _PointHistory(
                          key: ValueKey(_historyVersion),
                          userId: user.id,
                          pageSize: _historyPageSize,
                        ),
                      ),
                      const SizedBox(height: 40),
                      _DangerZone(
                        isSelf: user.id == selfId,
                        enabled: !_busy,
                        onDelete: () => _delete(user),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class _DangerZone extends StatelessWidget {
  final bool isSelf;
  final bool enabled;
  final VoidCallback onDelete;
  const _DangerZone({
    required this.isSelf,
    required this.enabled,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '刪除使用者',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: scheme.error),
                ),
                const SizedBox(height: 4),
                Text(
                  isSelf ? '這是你自己的帳號：請從 App 刪除。' : '永久刪除這位使用者的所有資料與圖片，無法復原。',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: scheme.error,
              side: BorderSide(color: scheme.error),
            ),
            onPressed: enabled && !isSelf ? onDelete : null,
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('刪除使用者'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  final double? width;
  const _Section({required this.title, required this.child, this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

class _Overview extends StatelessWidget {
  final AdminUser user;
  const _Overview({required this.user});

  @override
  Widget build(BuildContext context) {
    String time(DateTime? t) => t == null ? '—' : formatTaipei(t);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Photo(url: user.avatarUrl, label: '頭像', circle: true),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Fact('ID', '${user.id}'),
                  _Fact('Email', user.email),
                  _Fact('登入方式', authProviderLabel(user.authProvider)),
                  _Fact('註冊時間', time(user.createdAt)),
                  _Fact('最後更新', time(user.updatedAt)),
                  _Fact('新手點數第 1 天', user.welcomeStartsOn ?? '—'),
                ],
              ),
            ),
            const SizedBox(width: 24),
            _Photo(url: user.baseModelUrl, label: 'Base model'),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String? url;
  final String label;
  final bool circle;
  const _Photo({required this.url, required this.label, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = this.url;
    final size = circle ? const Size(96, 96) : const Size(96, 144);
    final image = Container(
      width: size.width,
      height: size.height,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.person_outline, color: scheme.outline, size: 40)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.broken_image_outlined, color: scheme.outline),
            ),
    );
    return Column(
      children: [
        image,
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _PointsPanel extends StatelessWidget {
  final AdminUser user;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  const _PointsPanel({
    required this.user,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${user.pointsBalance}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 8),
        _Fact(
          '今天會拿',
          user.dailyGrant == 0 ? '0（今天沒有）' : '${user.dailyGrant} 點',
        ),
        _Fact('今天已發', user.claimedToday ? '是' : '否'),
        _Fact('每日發點上限', '${user.pointsCap}'),
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add),
              label: const Text('加點'),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.remove),
              label: const Text('扣點'),
            ),
          ],
        ),
      ],
    );
  }
}

class _SubscriptionPanel extends StatelessWidget {
  final AdminUser user;
  final bool enabled;
  final VoidCallback onSet;
  final VoidCallback onCancel;
  const _SubscriptionPanel({
    required this.user,
    required this.enabled,
    required this.onSet,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final expires = user.subscriptionExpiresAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          user.subscriptionActive ? '訂閱中' : '未訂閱',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        _Fact(
          user.subscriptionActive ? '到期' : '上次到期',
          expires == null ? '—' : formatTaipei(expires),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: enabled ? onSet : null,
              child: Text(user.subscriptionActive ? '變更到期日' : '設定訂閱'),
            ),
            if (user.subscriptionActive)
              TextButton(
                onPressed: enabled ? onCancel : null,
                child: const Text('取消訂閱'),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdminPanel extends StatelessWidget {
  final AdminUser user;
  final bool isSelf;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  const _AdminPanel({
    required this.user,
    required this.isSelf,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final locked = isSelf && user.isAdmin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('可以登入 CMS'),
          value: user.isAdmin,
          onChanged: enabled && !locked ? onChanged : null,
        ),
        Text(
          locked ? '這是你自己的帳號，不能移除自己的權限。' : '管理員可以管理雜誌內容與所有使用者。',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Mirrors the App's `PATCH /users/me`: only changed fields are sent.
class _ProfileForm extends StatefulWidget {
  final AdminUser user;

  /// Bumped when the saved user should replace the form's edits.
  final int version;
  final bool enabled;
  final VoidCallback onDirtyChanged;
  final Future<void> Function(Map<String, Object?> changes) onSave;

  const _ProfileForm({
    super.key,
    required this.user,
    required this.version,
    required this.enabled,
    required this.onDirtyChanged,
    required this.onSave,
  });

  @override
  State<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<_ProfileForm> {
  static const _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  static const _genderLabels = {
    'Male': '男',
    'Female': '女',
    'Other': '其他',
    'Prefer not to say': '不透露',
  };

  final _name = TextEditingController();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _location = TextEditingController();
  String? _gender;
  String? _birthday;
  String _unitSystem = 'metric';
  int _offset = 0;
  String _locale = 'en';
  int _resets = 0;
  bool _resetting = false;

  @override
  void initState() {
    super.initState();
    _reset();
    for (final c in [_name, _height, _weight, _location]) {
      c.addListener(_edited);
    }
  }

  @override
  void didUpdateWidget(_ProfileForm old) {
    super.didUpdateWidget(old);
    if (old.version != widget.version) {
      _reset();
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.onDirtyChanged(),
      );
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _height, _weight, _location]) {
      c.dispose();
    }
    super.dispose();
  }

  void _reset() {
    _resetting = true;
    final u = widget.user;
    _name.text = u.name ?? '';
    _height.text = _num(u.height);
    _weight.text = _num(u.weight);
    _location.text = u.location ?? '';
    _gender = u.gender;
    _birthday = u.birthday;
    _unitSystem = u.unitSystem;
    _offset = (u.temperatureOffsetC ?? 0).round().clamp(-10, 10);
    _locale = u.locale;
    _resets++;
    _resetting = false;
  }

  static String _num(double? v) => v == null
      ? ''
      : v == v.roundToDouble()
      ? v.toInt().toString()
      : v.toString();

  void _edited() {
    if (_resetting) return;
    if (mounted) setState(() {});
    widget.onDirtyChanged();
  }

  String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  /// Null when a number field can't be parsed.
  Map<String, Object?>? _changes() {
    final u = widget.user;
    final changes = <String, Object?>{};
    final name = _text(_name);
    if (name != u.name) changes['name'] = name;
    if (_gender != u.gender) changes['gender'] = _gender;
    if (_birthday != u.birthday) changes['birthday'] = _birthday;
    for (final (key, controller, old) in [
      ('height', _height, u.height),
      ('weight', _weight, u.weight),
    ]) {
      final text = _text(controller);
      final value = text == null ? null : double.tryParse(text);
      if (text != null && (value == null || value <= 0)) return null;
      if (value != old) changes[key] = value;
    }
    if (_unitSystem != u.unitSystem) changes['unit_system'] = _unitSystem;
    final location = _text(_location);
    if (location != u.location) changes['location'] = location;
    if (_offset != (u.temperatureOffsetC ?? 0).round()) {
      changes['temperature_offset_c'] = _offset;
    }
    if (_locale != u.locale) changes['locale'] = _locale;
    return changes;
  }

  bool get dirty => _changes()?.isNotEmpty ?? true;

  void _set(VoidCallback change) {
    setState(change);
    widget.onDirtyChanged();
  }

  Future<void> _pickBirthday() async {
    final current = DateTime.tryParse(_birthday ?? '');
    final picked = await showDatePicker(
      context: context,
      helpText: '生日',
      initialDate: current ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      initialEntryMode: DatePickerEntryMode.input,
    );
    if (picked != null) _set(() => _birthday = formatTaipeiDate(picked));
  }

  Future<void> _save() async {
    final changes = _changes();
    if (changes == null) {
      showMessage(context, '身高、體重要是大於 0 的數字');
      return;
    }
    if (changes.isEmpty) return;
    await widget.onSave(changes);
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final enabled = widget.enabled;
    final changes = _changes();
    final locationChanged = _text(_location) != u.location;
    final hasCoordinates = u.latitude != null && u.longitude != null;
    final genders = [
      ..._genders,
      if (u.gender != null && !_genders.contains(u.gender)) u.gender!,
    ];
    const gap = SizedBox(width: 16, height: 16);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            SizedBox(
              width: 300,
              child: TextField(
                controller: _name,
                enabled: enabled,
                decoration: const InputDecoration(
                  labelText: '名稱',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String?>(
                key: ValueKey('gender-$_resets'),
                initialValue: _gender,
                decoration: const InputDecoration(
                  labelText: '性別',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('未填')),
                  for (final g in genders)
                    DropdownMenuItem(
                      value: g,
                      child: Text(_genderLabels[g] ?? g),
                    ),
                ],
                onChanged: enabled ? (v) => _set(() => _gender = v) : null,
              ),
            ),
            SizedBox(
              width: 220,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '生日',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.fromLTRB(12, 4, 4, 4),
                ),
                child: Row(
                  children: [
                    Expanded(child: Text(_birthday ?? '未填')),
                    IconButton(
                      tooltip: '選擇日期',
                      onPressed: enabled ? _pickBirthday : null,
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    if (_birthday != null)
                      IconButton(
                        tooltip: '清空',
                        onPressed: enabled
                            ? () => _set(() => _birthday = null)
                            : null,
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                  ],
                ),
              ),
            ),
            for (final (label, controller, suffix) in [
              ('身高', _height, 'cm'),
              ('體重', _weight, 'kg'),
            ])
              SizedBox(
                width: 140,
                child: TextField(
                  controller: controller,
                  enabled: enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: label,
                    suffixText: suffix,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            SizedBox(
              width: 260,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'App 顯示單位',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(8),
                ),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'metric', label: Text('公制')),
                    ButtonSegment(value: 'imperial', label: Text('英制')),
                  ],
                  selected: {_unitSystem},
                  onSelectionChanged: enabled
                      ? (s) => _set(() => _unitSystem = s.first)
                      : null,
                ),
              ),
            ),
          ],
        ),
        gap,
        Wrap(
          spacing: 16,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                controller: _location,
                enabled: enabled,
                decoration: InputDecoration(
                  labelText: '所在地',
                  border: const OutlineInputBorder(),
                  helperText: locationChanged && hasCoordinates
                      ? '改了所在地，儲存後座標會被清空（CMS 不能選座標）'
                      : hasCoordinates
                      ? '座標：${u.latitude}, ${u.longitude}'
                      : '沒有座標',
                  helperStyle: locationChanged && hasCoordinates
                      ? TextStyle(color: Theme.of(context).colorScheme.error)
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: 300,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: '溫度偏移：${_offset > 0 ? '+' : ''}$_offset°C（負數＝穿更暖）',
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                ),
                child: Slider(
                  value: _offset.toDouble(),
                  min: -10,
                  max: 10,
                  divisions: 20,
                  label: '$_offset',
                  onChanged: enabled
                      ? (v) => _set(() => _offset = v.round())
                      : null,
                ),
              ),
            ),
            SizedBox(
              width: 200,
              child: DropdownButtonFormField<String>(
                key: ValueKey('locale-$_resets'),
                initialValue: _locale,
                decoration: const InputDecoration(
                  labelText: '語系',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'zh-TW', child: Text('繁體中文')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: enabled
                    ? (v) => _set(() => _locale = v ?? _locale)
                    : null,
              ),
            ),
          ],
        ),
        gap,
        Row(
          children: [
            FilledButton(
              onPressed: enabled && (changes == null || changes.isNotEmpty)
                  ? _save
                  : null,
              child: const Text('儲存基本資料'),
            ),
            const SizedBox(width: 8),
            if (changes == null || changes.isNotEmpty)
              TextButton(
                onPressed: enabled ? () => _set(_reset) : null,
                child: const Text('還原'),
              ),
          ],
        ),
      ],
    );
  }
}

class _PointHistory extends StatefulWidget {
  final int userId;
  final int pageSize;
  const _PointHistory({
    super.key,
    required this.userId,
    required this.pageSize,
  });

  @override
  State<_PointHistory> createState() => _PointHistoryState();
}

class _PointHistoryState extends State<_PointHistory> {
  List<PointTransaction>? _items;
  int _total = 0;
  int _page = 1;
  Object? _error;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({int page = 1}) async {
    final id = ++_requestId;
    setState(() => _error = null);
    try {
      final result = await CmsScope.read(
        context,
      ).listPointTransactions(widget.userId, page: page, size: widget.pageSize);
      if (!mounted || id != _requestId) return;
      setState(() {
        _items = result.items;
        _total = result.total;
        _page = page;
      });
    } catch (e) {
      if (mounted && id == _requestId) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final error = _error;
    if (error != null) return Text(errorText(error));
    if (items == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (items.isEmpty) return const Text('還沒有點數紀錄。');
    final pages = (_total / widget.pageSize).ceil();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('時間')),
              DataColumn(label: Text('類型')),
              DataColumn(label: Text('功能')),
              DataColumn(label: Text('變動'), numeric: true),
              DataColumn(label: Text('餘額'), numeric: true),
              DataColumn(label: Text('原因')),
              DataColumn(label: Text('操作者')),
            ],
            rows: [
              for (final t in items)
                DataRow(
                  cells: [
                    DataCell(
                      Text(
                        t.createdAt == null ? '—' : formatTaipei(t.createdAt!),
                      ),
                    ),
                    DataCell(Text(t.kind.label)),
                    DataCell(Text(t.actionLabel ?? '—')),
                    DataCell(
                      Text(
                        t.delta > 0 ? '+${t.delta}' : '${t.delta}',
                        style: TextStyle(
                          color: t.delta < 0
                              ? scheme.error
                              : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(Text('${t.balanceAfter}')),
                    DataCell(
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 260),
                        child: Text(t.note ?? '—'),
                      ),
                    ),
                    DataCell(Text(t.adminEmail ?? '—')),
                  ],
                ),
            ],
          ),
        ),
        if (pages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('$_page / $pages（共 $_total 筆）'),
              IconButton(
                onPressed: _page < pages ? () => _load(page: _page + 1) : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}
