import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/main.dart' show themeNotifier;
import 'package:internship_app2/models/user.dart';
import 'package:internship_app2/screens/university_login_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/auth_service.dart';

const _categoryColors = {
  'IT': Color(0xFF2164F3),
  'Финансы': Color(0xFF047857),
  'Дизайн': Color(0xFFB45309),
  'Маркетинг': Color(0xFFDC2626),
  'HR': Color(0xFF7C3AED),
};

class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _apiService = ApiService();

  User? _user;
  List<Map<String, dynamic>> _applications = [];
  bool _loadingApps = true;
  bool _cvUploading = false;
  String? _cvUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _authService.getSavedUser();
    if (mounted) setState(() => _user = user);
    try {
      final apps = await _apiService.getMyApplications();
      if (mounted) {
        setState(() {
          _applications = apps;
          _loadingApps = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    widget.onLogout();
  }

  Future<void> _uploadCv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;
    final file = result.files.single;
    setState(() => _cvUploading = true);
    try {
      final url = await _apiService.uploadCv(file.bytes!, file.name);
      setState(() => _cvUrl = url);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('CV успешно загружен!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF10B981),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFFDC2626),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _cvUploading = false);
    }
  }

  void _openReportSheet(Map<String, dynamic> app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ReportSheet(
          app: app,
          apiService: _apiService,
          onSuccess: _load,
        ),
      ),
    );
  }

  void _openEditName() {
    final ctrl = TextEditingController(text: _user?.name ?? '');
    bool saving = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  tr('edit_name'),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: tr('first_name'),
                    prefixIcon: const Icon(Icons.person_outline),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Color(0xFF2164F3), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: saving
                        ? null
                        : () async {
                            if (ctrl.text.trim().length < 2) return;
                            setModal(() => saving = true);
                            try {
                              await _authService.updateProfile(
                                  name: ctrl.text.trim());
                              final updated =
                                  await _authService.getSavedUser();
                              if (mounted) setState(() => _user = updated);
                              if (!ctx.mounted) return;
                              Navigator.pop(ctx);
                            } catch (e) {
                              if (!ctx.mounted) return;
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                SnackBar(
                                    content: Text(e
                                        .toString()
                                        .replaceAll('Exception: ', ''))),
                              );
                            } finally {
                              setModal(() => saving = false);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2164F3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(tr('save'),
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _user?.name ?? '';
    final email = _user?.email ?? '';
    final initials = name.isNotEmpty
        ? name
            .trim()
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase()
        : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            // ── Gradient header banner ────────────────────────────────────
            _ProfileHeader(
              initials: initials,
              name: name,
              email: email,
              onEdit: _openEditName,
              onRefresh: _load,
            ),

            const SizedBox(height: 16),

            // ── CV Upload ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _cvUploading ? null : _uploadCv,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _cvUrl != null
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _cvUrl != null
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFEBF0FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _cvUrl != null
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_rounded,
                          color: _cvUrl != null
                              ? const Color(0xFF10B981)
                              : const Color(0xFF2164F3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _cvUrl != null ? 'CV загружен' : 'Загрузить CV (PDF)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: _cvUrl != null
                                    ? const Color(0xFF10B981)
                                    : const Color(0xFF111827),
                              ),
                            ),
                            Text(
                              _cvUrl != null
                                  ? 'Нажмите чтобы обновить'
                                  : 'Максимум 5 МБ · только PDF',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                            ),
                          ],
                        ),
                      ),
                      if (_cvUploading)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2164F3)),
                        )
                      else
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: const Color(0xFF9CA3AF),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // ── Applications section ──────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    tr('my_applications'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_loadingApps)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF0FA),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_applications.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2164F3),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_loadingApps)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(
                      color: Color(0xFF2164F3)),
                ),
              )
            else if (_applications.isEmpty)
              const _EmptyApplications()
            else
              ...(_applications.map(
                (app) => Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: _ApplicationCard(
                    app: app,
                    onSubmitReport: (app['status'] == 'accepted' &&
                            app['report'] == null)
                        ? () => _openReportSheet(app)
                        : null,
                  ),
                ),
              )),

            const SizedBox(height: 28),

            // ── Settings ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                tr('settings'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _SettingsCard(
                onLogout: _logout,
                onUniversityTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UniversityLoginScreen(),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Logout ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(tr('logout')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Profile header ────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final String initials;
  final String name;
  final String email;
  final VoidCallback onEdit;
  final VoidCallback onRefresh;

  const _ProfileHeader({
    required this.initials,
    required this.name,
    required this.email,
    required this.onEdit,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Gradient banner
        Container(
          height: 160 + topPad,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0F2166), Color(0xFF2164F3)],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -30,
                right: -20,
                child: _circle(130, 0.05),
              ),
              Positioned(
                top: 30,
                right: 40,
                child: _circle(70, 0.07),
              ),
              Positioned(
                bottom: 20,
                left: 160,
                child: _circle(50, 0.06),
              ),
              // Top bar: title + actions
              Positioned(
                top: topPad + 12,
                left: 20,
                right: 12,
                child: Row(
                  children: [
                    Text(
                      tr('profile_title'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    _iconBtn(Icons.edit_outlined, onEdit),
                    const SizedBox(width: 6),
                    _iconBtn(Icons.refresh_rounded, onRefresh),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Avatar — overlapping bottom of banner
        Positioned(
          bottom: -36,
          left: 20,
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF3F4F6),
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2164F3), Color(0xFF6D28D9)],
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Name + email inside banner, right of avatar position
        Positioned(
          bottom: 18,
          left: 108,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                email,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _circle(double size, double opacity) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      );

  static Widget _iconBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.22)),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      );
}

// ── Empty applications ────────────────────────────────────────────────────────

class _EmptyApplications extends StatelessWidget {
  const _EmptyApplications();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEBF0FA),
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 36,
              color: Color(0xFF2164F3),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('no_applications'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('no_results_sub'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Application card ──────────────────────────────────────────────────────────

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final VoidCallback? onSubmitReport;
  const _ApplicationCard({required this.app, this.onSubmitReport});

  @override
  Widget build(BuildContext context) {
    final status = app['status'] as String? ?? 'pending';
    final title = app['internship_title'] as String? ?? '';
    final company = app['internship_company'] as String? ?? '';
    final message = app['message'] as String? ?? '';

    final (statusLabel, statusColor) = switch (status) {
      'accepted' => (tr('status_accepted'), const Color(0xFF16A34A)),
      'rejected' => (tr('status_rejected'), const Color(0xFFDC2626)),
      _ => (tr('status_pending'), const Color(0xFF2164F3)),
    };

    // Company initial for avatar
    final companyInitials = company
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();

    // Try to find category color from title keywords
    final accentColor =
        _categoryColors.entries
            .firstWhere(
              (e) => title.contains(e.key) || company.contains(e.key),
              orElse: () => const MapEntry('', Color(0xFF2164F3)),
            )
            .value;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Colored left stripe
            Container(width: 4, color: statusColor),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    // Company avatar
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          companyInitials,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: accentColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF111827),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            company,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Submit report button for accepted apps
            if (onSubmitReport != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 14, 12),
                child: SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: onSubmitReport,
                    icon: const Icon(Icons.assignment_outlined, size: 15),
                    label: Text(tr('submit_report')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2164F3),
                      side: const BorderSide(color: Color(0xFF2164F3)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ),
            // Already submitted badge
            if (app['report'] != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 14, 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: Color(0xFF16A34A)),
                    const SizedBox(width: 5),
                    Text(
                      tr('report_sent'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Settings card ─────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final VoidCallback onLogout;
  final VoidCallback onUniversityTap;

  const _SettingsCard({
    required this.onLogout,
    required this.onUniversityTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Dark mode
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (_, mode, _) {
              final isDark = mode == ThemeMode.dark;
              return _SettingRow(
                icon: isDark
                    ? Icons.dark_mode_rounded
                    : Icons.light_mode_rounded,
                iconBg: const Color(0xFFFEF3C7),
                iconColor: const Color(0xFFD97706),
                title: tr('dark_mode'),
                trailing: Switch(
                  value: isDark,
                  activeThumbColor: const Color(0xFF2164F3),
                  onChanged: (val) async {
                    themeNotifier.value =
                        val ? ThemeMode.dark : ThemeMode.light;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('dark_mode', val);
                  },
                ),
                isFirst: true,
              );
            },
          ),
          const _Divider(),

          // Language
          _SettingRow(
            icon: Icons.language_rounded,
            iconBg: const Color(0xFFEBF0FA),
            iconColor: const Color(0xFF2164F3),
            title: tr('language'),
            trailing: ValueListenableBuilder<String>(
              valueListenable: localeNotifier,
              builder: (_, lang, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e
                      in {'RU': 'ru', 'ҚЗ': 'kz', 'EN': 'en'}.entries)
                    GestureDetector(
                      onTap: () => setLocale(e.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: lang == e.value
                              ? const Color(0xFF2164F3)
                              : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          e.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: lang == e.value
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const _Divider(),

          // University portal
          _SettingRow(
            icon: Icons.school_rounded,
            iconBg: const Color(0xFFF3E8FF),
            iconColor: const Color(0xFF7C3AED),
            title: tr('footer_portal'),
            subtitle: tr('footer_monitoring'),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
            onTap: onUniversityTap,
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool isFirst;
  final bool isLast;

  const _SettingRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: isFirst ? const Radius.circular(16) : Radius.zero,
        bottom: isLast ? const Radius.circular(16) : Radius.zero,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 68),
        child: Divider(height: 1, color: Color(0xFFF3F4F6)),
      );
}

// ── Report submission sheet ───────────────────────────────────────────────────

class _ReportSheet extends StatefulWidget {
  final Map<String, dynamic> app;
  final ApiService apiService;
  final VoidCallback onSuccess;

  const _ReportSheet({
    required this.app,
    required this.apiService,
    required this.onSuccess,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _hoursCtrl = TextEditingController();
  final _tasksCtrl = TextEditingController();
  final _skillCtrl = TextEditingController();
  final List<String> _skills = [];
  bool _loading = false;

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _tasksCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  void _addSkill() {
    final s = _skillCtrl.text.trim();
    if (s.isNotEmpty && !_skills.contains(s)) {
      setState(() {
        _skills.add(s);
        _skillCtrl.clear();
      });
    }
  }

  bool get _valid =>
      int.tryParse(_hoursCtrl.text.trim()) != null &&
      _tasksCtrl.text.trim().length >= 10;

  Future<void> _submit() async {
    if (!_valid) return;
    setState(() => _loading = true);
    try {
      await widget.apiService.submitReport(
        applicationId: widget.app['id'] as int,
        hoursCompleted: int.parse(_hoursCtrl.text.trim()),
        tasksDescription: _tasksCtrl.text.trim(),
        skillsGained: List<String>.from(_skills),
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onSuccess();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Text(tr('report_success')),
            ],
          ),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.app['internship_title'] as String? ?? '';
    final company = widget.app['internship_company'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Text(
            tr('report_title'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$title · $company',
            style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),

          // Hours
          _label(tr('report_hours')),
          const SizedBox(height: 6),
          _field(
            controller: _hoursCtrl,
            hint: tr('report_hours_hint'),
            keyboardType: TextInputType.number,
            maxLines: 1,
          ),
          const SizedBox(height: 14),

          // Tasks description
          _label(tr('report_tasks')),
          const SizedBox(height: 6),
          _field(
            controller: _tasksCtrl,
            hint: tr('report_tasks_hint'),
            maxLines: 4,
          ),
          const SizedBox(height: 14),

          // Skills gained
          _label(tr('report_skills')),
          const SizedBox(height: 6),
          // Existing skill chips
          if (_skills.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _skills.map((s) => Chip(
                label: Text(s),
                labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                backgroundColor: const Color(0xFFEBF0FA),
                side: BorderSide.none,
                deleteIcon: const Icon(Icons.close, size: 14, color: Color(0xFF2164F3)),
                onDeleted: () => setState(() => _skills.remove(s)),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              )).toList(),
            ),
            const SizedBox(height: 8),
          ],
          // Add skill row
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: _skillCtrl,
                  hint: tr('report_skill_hint'),
                  maxLines: 1,
                  onSubmitted: (_) => _addSkill(),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSkill,
                child: Container(
                  width: 40,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2164F3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: (_valid && !_loading) ? _submit : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2164F3),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _loading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      tr('report_submit_btn'),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    void Function(String)? onSubmitted,
  }) =>
      TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        onSubmitted: onSubmitted,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
          filled: true,
          fillColor: const Color(0xFFF9FAFB),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                const BorderSide(color: Color(0xFF2164F3), width: 1.5),
          ),
        ),
      );
}
