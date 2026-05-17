import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/user.dart';
import 'package:internship_app2/screens/ai_chat_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
const _blue    = Color(0xFF2164F3);
const _green   = Color(0xFF059669);
const _red     = Color(0xFFEF4444);
const _ink     = Color(0xFF111827);
const _sub     = Color(0xFF6B7280);
const _div     = Color(0xFFE5E7EB);
const _surface = Color(0xFFF9FAFB);

const _cardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(12)),
  boxShadow: [BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2))],
);

// ── ProfileScreen ─────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _api  = ApiService();

  User? _user;
  List<Map<String, dynamic>> _applications = [];
  bool _loadingApps = true;
  bool _cvUploading = false;
  String _appFilter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.getSavedUser();
    if (mounted) setState(() => _user = user);

    if (user != null && user.skills.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList('pending_skills');
      if (pending != null && pending.isNotEmpty) {
        try {
          final updated = await _auth.updateProfile(skills: pending);
          await prefs.remove('pending_skills');
          if (mounted) setState(() => _user = updated);
        } catch (_) {}
      }
    }

    try {
      final apps = await _api.getMyApplications();
      if (mounted) setState(() { _applications = apps; _loadingApps = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
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
      final data = await _api.uploadCv(file.bytes!, file.name);
      final updated = _user!.copyWith(
        cvUrl: data['cv_url'],
        cvFilename: data['cv_filename'],
        cvUploadedAt: data['cv_uploaded_at'],
      );
      await _auth.updateProfile();
      setState(() => _user = updated);
      _showSnack('CV успешно загружен!', _green);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), _red);
    } finally {
      if (mounted) setState(() => _cvUploading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // ── Completeness ──────────────────────────────────────────────────────────────
  double get _completeness {
    if (_user == null) return 0;
    final checks = [
      _user!.name.isNotEmpty,
      (_user!.bio ?? '').isNotEmpty,
      _user!.skills.isNotEmpty,
      (_user!.universityName ?? '').isNotEmpty,
      _user!.cvUrl != null,
      (_user!.portfolioUrl ?? '').isNotEmpty,
    ];
    return checks.where((c) => c).length / checks.length;
  }

  List<String> get _missingItems {
    if (_user == null) return [];
    return [
      if ((_user!.bio ?? '').isEmpty) 'Bio',
      if (_user!.skills.isEmpty) 'Навыки',
      if ((_user!.universityName ?? '').isEmpty) 'Образование',
      if (_user!.cvUrl == null) 'CV',
      if ((_user!.portfolioUrl ?? '').isEmpty) 'Portfolio URL',
    ];
  }

  String get _initials {
    final name = _user?.name ?? '';
    if (name.isEmpty) return '?';
    return name.trim().split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0])
        .take(2)
        .join()
        .toUpperCase();
  }

  // ── App stats ─────────────────────────────────────────────────────────────────
  int get _acceptedCount =>
      _applications.where((a) => a['status'] == 'accepted').length;

  List<Map<String, dynamic>> get _filteredApps {
    return switch (_appFilter) {
      'active'   => _applications.where((a) => a['status'] == 'pending').toList(),
      'accepted' => _applications.where((a) => a['status'] == 'accepted').toList(),
      _ => _applications,
    };
  }

  // ── Actions ───────────────────────────────────────────────────────────────────
  Future<void> _toggleStatus() async {
    if (_user == null) return;
    final updated = await _auth.updateProfile(openToWork: !_user!.openToWork);
    if (mounted) setState(() => _user = updated);
  }

  void _openEditSheet({int tab = 0}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditProfileSheet(
        user: _user!,
        authService: _auth,
        onSaved: (u) => setState(() => _user = u),
        initialTab: tab,
      ),
    );
  }

  void _openSkillsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillsSheet(
        skills: _user?.skills ?? [],
        onSave: (skills) async {
          final updated = await _auth.updateProfile(skills: skills);
          if (mounted) setState(() => _user = updated);
        },
      ),
    );
  }

  void _openReportSheet(Map<String, dynamic> app) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ReportSheet(app: app, apiService: _api, onSuccess: _load),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final isDesktop = w > 720;
    final hPad = isDesktop ? ((w - 700) / 2).clamp(0.0, double.infinity) : 0.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          children: [
            // ── Name + avatar ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _user?.name.isNotEmpty == true
                              ? _user!.name
                              : 'Имя не указано',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.email_outlined, size: 14, color: _sub),
                            const SizedBox(width: 6),
                            Text(
                              _user?.email ?? '',
                              style: const TextStyle(fontSize: 13, color: _sub),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    children: [
                      Container(
                        width: 64, height: 64,
                        decoration: const BoxDecoration(
                          color: Color(0xFF374151),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: _user != null ? () => _openEditSheet() : null,
                        child: const Text(
                          'Изменить',
                          style: TextStyle(
                            fontSize: 12,
                            color: _blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Status banner ─────────────────────────────────────────────
            _StatusBanner(
              openToWork: _user?.openToWork ?? true,
              onTap: _user != null ? _toggleStatus : null,
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, thickness: 1, color: _div),

            // ── Completeness ──────────────────────────────────────────────
            if (_user != null && _completeness < 1.0) ...[
              _CompletenessBar(value: _completeness, missing: _missingItems),
              const Divider(height: 1, thickness: 1, color: _div),
            ],

            // ── AI Анализ ─────────────────────────────────────────────────
            if (_user != null) ...[
              _AiProfileCard(api: _api),
              const Divider(height: 1, thickness: 1, color: _div),
            ],

            // ── Резюме ────────────────────────────────────────────────────
            _SectionHeader('Резюме'),
            _CvRow(
              cvUrl: _user?.cvUrl,
              cvFilename: _user?.cvFilename,
              cvUploadedAt: _user?.cvUploadedAt,
              uploading: _cvUploading,
              onUpload: _uploadCv,
            ),
            const Divider(height: 1, thickness: 1, color: _div),

            // ── Профиль ───────────────────────────────────────────────────
            _SectionHeader('Профиль'),
            _ProfileRow(
              icon: Icons.notes_rounded,
              title: 'О себе',
              subtitle: (_user?.bio ?? '').isNotEmpty
                  ? _user!.bio!
                  : 'Расскажи о себе — работодатели читают это первым',
              dim: (_user?.bio ?? '').isEmpty,
              onTap: () => _openEditSheet(),
            ),
            const Divider(height: 1, thickness: 1, indent: 54, color: _div),
            _ProfileRow(
              icon: Icons.bolt_rounded,
              title: 'Навыки',
              subtitle: _user?.skills.isNotEmpty == true
                  ? _user!.skills.take(4).join(', ') +
                    (_user!.skills.length > 4 ? '  +${_user!.skills.length - 4}' : '')
                  : 'Добавить навыки — работодатели фильтруют по ним',
              dim: _user?.skills.isEmpty != false,
              onTap: () => _openSkillsSheet(),
            ),
            const Divider(height: 1, thickness: 1, indent: 54, color: _div),
            _ProfileRow(
              icon: Icons.school_outlined,
              title: 'Образование',
              subtitle: (_user?.universityName ?? '').isNotEmpty
                  ? _user!.universityName! +
                    ((_user?.specialty ?? '').isNotEmpty
                        ? ' · ${_user!.specialty}'
                        : '')
                  : 'Добавить университет и специальность',
              dim: (_user?.universityName ?? '').isEmpty,
              onTap: () => _openEditSheet(tab: 1),
            ),
            const Divider(height: 1, thickness: 1, indent: 54, color: _div),
            _ProfileRow(
              icon: Icons.link_rounded,
              title: 'Portfolio URL',
              subtitle: (_user?.portfolioUrl ?? '').isNotEmpty
                  ? _user!.portfolioUrl!
                  : 'GitHub, Behance, Dribbble...',
              dim: (_user?.portfolioUrl ?? '').isEmpty,
              onTap: () => _openEditSheet(),
            ),
            const Divider(height: 1, thickness: 1, color: _div),

            // ── Stats ─────────────────────────────────────────────────────
            _StatsBar(
              total: _applications.length,
              accepted: _acceptedCount,
              openToWork: _user?.openToWork ?? true,
            ),
            const Divider(height: 1, thickness: 1, color: _div),

            // ── Applications ──────────────────────────────────────────────
            _ApplicationsSection(
              loading: _loadingApps,
              apps: _filteredApps,
              allApps: _applications,
              filter: _appFilter,
              onFilterChange: (f) => setState(() => _appFilter = f),
              onReport: _openReportSheet,
            ),
            const Divider(height: 1, thickness: 1, color: _div),

            // ── Settings ──────────────────────────────────────────────────
            _SettingsSection(onLogout: _logout),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Status Banner ─────────────────────────────────────────────────────────────
class _StatusBanner extends StatelessWidget {
  final bool openToWork;
  final VoidCallback? onTap;
  const _StatusBanner({required this.openToWork, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color  = openToWork ? const Color(0xFF059669) : const Color(0xFF6B7280);
    final bg     = openToWork ? const Color(0xFFF0FDF4) : const Color(0xFFF9FAFB);
    final border = openToWork ? const Color(0xFFBBF7D0) : const Color(0xFFE5E7EB);
    final label  = openToWork
        ? 'Работодатели могут вас найти'
        : 'Скрыт от работодателей';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            Icon(
              openToWork
                  ? Icons.expand_more_rounded
                  : Icons.chevron_right_rounded,
              size: 18,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completeness Bar ──────────────────────────────────────────────────────────
class _CompletenessBar extends StatelessWidget {
  final double value;
  final List<String> missing;
  const _CompletenessBar({required this.value, required this.missing});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up_rounded, size: 15, color: _blue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Профиль заполнен на $pct%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 4,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation(_blue),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Добавь: ${missing.join(', ')}',
              style: const TextStyle(fontSize: 12, color: _sub),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: _ink,
          letterSpacing: -0.3,
        ),
      ),
    );
  }
}

// ── Profile Row ───────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool dim;
  final VoidCallback onTap;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: dim ? const Color(0xFFD1D5DB) : _blue),
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
                      color: _ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: dim ? const Color(0xFFADB5BD) : _sub,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, size: 18, color: _sub),
          ],
        ),
      ),
    );
  }
}

// ── CV Row ────────────────────────────────────────────────────────────────────
class _CvRow extends StatelessWidget {
  final String? cvUrl;
  final String? cvFilename;
  final String? cvUploadedAt;
  final bool uploading;
  final VoidCallback onUpload;

  const _CvRow({
    required this.cvUrl,
    required this.cvFilename,
    required this.cvUploadedAt,
    required this.uploading,
    required this.onUpload,
  });

  String _fmt(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      const m = ['', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
          'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${m[dt.month]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cvUrl == null) {
      return InkWell(
        onTap: uploading ? null : onUpload,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const Icon(Icons.upload_file_rounded, size: 20, color: _blue),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Загрузить резюме',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _ink)),
                    SizedBox(height: 2),
                    Text('PDF, максимум 5 МБ',
                        style: TextStyle(fontSize: 13, color: _sub)),
                  ],
                ),
              ),
              uploading
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                  : const Icon(Icons.add_circle_outline, size: 18, color: _blue),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _div),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: _blue,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('PDF',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w800)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cvFilename ?? 'resume.pdf',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _ink),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Добавлен ${_fmt(cvUploadedAt)}',
                    style: const TextStyle(fontSize: 12, color: _sub),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 18, color: _sub),
              onPressed: () async {
                const base = 'https://qadam-backend.onrender.com';
                final url = Uri.parse('$base$cvUrl');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
            IconButton(
              icon: uploading
                  ? const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _blue))
                  : const Icon(Icons.more_horiz, size: 20, color: _sub),
              onPressed: uploading ? null : onUpload,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final int total;
  final int accepted;
  final bool openToWork;

  const _StatsBar({
    required this.total,
    required this.accepted,
    required this.openToWork,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          _Stat(value: '$total', label: 'Откликов', color: _blue),
          _vline(),
          _Stat(value: '$accepted', label: 'Принято', color: _green),
          _vline(),
          _Stat(
            value: openToWork ? 'Открыт' : 'Закрыт',
            label: 'Статус',
            color: openToWork ? _green : _sub,
          ),
        ],
      ),
    );
  }

  Widget _vline() => Container(
    width: 1, height: 32,
    margin: const EdgeInsets.symmetric(horizontal: 20),
    color: _div,
  );
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        Text(label,
            style: const TextStyle(fontSize: 12, color: _sub)),
      ],
    );
  }
}

// ── Applications Section ──────────────────────────────────────────────────────
class _ApplicationsSection extends StatelessWidget {
  final bool loading;
  final List<Map<String, dynamic>> apps;
  final List<Map<String, dynamic>> allApps;
  final String filter;
  final void Function(String) onFilterChange;
  final void Function(Map<String, dynamic>) onReport;

  const _ApplicationsSection({
    required this.loading,
    required this.apps,
    required this.allApps,
    required this.filter,
    required this.onFilterChange,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final active   = allApps.where((a) => a['status'] == 'pending').length;
    final accepted = allApps.where((a) => a['status'] == 'accepted').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 20, bottom: 12),
            child: Text('Мои заявки',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.3)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                    label: 'Все (${allApps.length})',
                    active: filter == 'all',
                    onTap: () => onFilterChange('all')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Активные ($active)',
                    active: filter == 'active',
                    onTap: () => onFilterChange('active')),
                const SizedBox(width: 8),
                _FilterChip(
                    label: 'Принятые ($accepted)',
                    active: filter == 'accepted',
                    onTap: () => onFilterChange('accepted')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
              ),
            )
          else if (apps.isEmpty)
            _EmptyApplications()
          else
            ...apps.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ApplicationCard(app: app, onReport: onReport),
                )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _blue : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _blue : _div),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _sub,
          ),
        ),
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 18, color: _sub),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Ещё нет откликов',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
                SizedBox(height: 2),
                Text('Просматривай стажировки и откликайся',
                    style: TextStyle(fontSize: 13, color: _sub)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final void Function(Map<String, dynamic>) onReport;
  const _ApplicationCard({required this.app, required this.onReport});

  @override
  Widget build(BuildContext context) {
    final status    = app['status'] as String? ?? 'pending';
    final hasReport = app['has_report'] as bool? ?? false;
    final title     = app['internship_title'] as String? ?? '—';
    final company   = app['company'] as String? ?? '—';
    final createdAt = app['created_at'] as String?;

    final (statusLabel, statusColor, statusBg, statusIcon) = switch (status) {
      'accepted'  => ('Принят!', _green, const Color(0xFFD1FAE5), Icons.check_circle_outline_rounded),
      'rejected'  => ('Отказано', _red, const Color(0xFFFEE2E2), Icons.cancel_outlined),
      'completed' => ('Завершено', _sub, const Color(0xFFF1F5F9), Icons.school_outlined),
      _ => ('Рассматривается', _blue, const Color(0xFFEBF0FA), Icons.hourglass_empty_rounded),
    };

    String? formattedDate;
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        const months = ['', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
            'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
        formattedDate = '${dt.day} ${months[dt.month]}';
      } catch (_) {}
    }

    return Container(
      decoration: _cardDeco,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _div),
                  ),
                  child: Center(
                    child: Text(
                      company.isNotEmpty ? company[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w800, color: _blue),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(company,
                          style: const TextStyle(fontSize: 12, color: _sub)),
                      Text(title,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _ink),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusLabel,
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor)),
                    ],
                  ),
                ),
              ],
            ),
            if (formattedDate != null) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: _div),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 12, color: _sub),
                  const SizedBox(width: 4),
                  Text('Подано $formattedDate',
                      style: const TextStyle(fontSize: 12, color: _sub)),
                  const Spacer(),
                  if (status == 'accepted')
                    hasReport
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle_rounded,
                                    size: 14, color: _green),
                                SizedBox(width: 4),
                                Text('Отчёт сдан',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _green)),
                              ],
                            ),
                          )
                        : GestureDetector(
                            onTap: () => onReport(app),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEBF0FA),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.edit_note_rounded,
                                      size: 14, color: _blue),
                                  SizedBox(width: 4),
                                  Text('Сдать отчёт',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: _blue)),
                                ],
                              ),
                            ),
                          ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Settings Section ──────────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final VoidCallback onLogout;
  const _SettingsSection({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('Настройки',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.3)),
          ),
        ),
        ValueListenableBuilder<String>(
          valueListenable: localeNotifier,
          builder: (_, lang, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.language_rounded, size: 20, color: _sub),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text('Язык',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _ink)),
                ),
                for (final e in {'RU': 'ru', 'ҚЗ': 'kz', 'EN': 'en'}.entries)
                  GestureDetector(
                    onTap: () => setLocale(e.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: lang == e.value
                            ? const Color(0xFFEBF0FA)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                          color: lang == e.value
                              ? _blue
                              : const Color(0xFFD1D5DB),
                        ),
                      ),
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: lang == e.value ? _blue : _sub,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, indent: 54, color: _div),
        _SettingsTile(
          icon: Icons.notifications_outlined,
          label: 'Уведомления',
          onTap: () {},
        ),
        const Divider(height: 1, indent: 54, color: _div),
        _SettingsTile(
          icon: Icons.lock_outline_rounded,
          label: 'Изменить пароль',
          onTap: () {},
        ),
        const Divider(height: 1, indent: 54, color: _div),
        _SettingsTile(
          icon: Icons.info_outline_rounded,
          label: 'О приложении',
          onTap: () {},
        ),
        const Divider(height: 1, color: _div),
        _SettingsTile(
          icon: Icons.logout_rounded,
          label: 'Выйти из аккаунта',
          iconColor: _red,
          labelColor: _red,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                title: const Text('Выйти?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                content: const Text(
                    'Вы уверены, что хотите выйти из аккаунта?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child:
                        const Text('Выйти', style: TextStyle(color: _red)),
                  ),
                ],
              ),
            );
            if (confirm == true) onLogout();
          },
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? _sub),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? _ink)),
            ),
            if (iconColor == null)
              const Icon(Icons.chevron_right, size: 18, color: _sub),
          ],
        ),
      ),
    );
  }
}

// ── AI Profile Card ───────────────────────────────────────────────────────────
class _AiProfileCard extends StatefulWidget {
  final ApiService api;
  const _AiProfileCard({required this.api});

  @override
  State<_AiProfileCard> createState() => _AiProfileCardState();
}

class _AiProfileCardState extends State<_AiProfileCard> {
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _analyze() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await widget.api.getProfileAnalysis();
      if (mounted) setState(() { _result = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceAll('Exception: ', '');
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final score    = _result?['score'] as int?;
    final analysis = _result?['analysis'] as String?;
    final missing  = (_result?['missing_fields'] as List?)?.cast<String>() ?? [];

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4C1D95), Color(0xFF6D28D9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D28D9).withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Анализ профиля',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    Text('Как усилить профиль для работодателя',
                        style: TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('$score%',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900)),
                ),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: score / 100,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 5,
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Добавь: ${missing.map(_fieldName).join(', ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ],
          if (analysis != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(analysis,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 13, height: 1.5)),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const AiChatScreen(mode: AiChatMode.general),
              )),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('Обсудить с AI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(_error!,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12)),
              ),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _analyze,
                icon: _loading
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.psychology_outlined,
                        color: Colors.white, size: 18),
                label: Text(
                  _loading ? 'Анализирую...' : 'Проанализировать профиль',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fieldName(String key) => switch (key) {
        'photo'      => 'фото',
        'university' => 'университет',
        'specialty'  => 'специальность',
        'skills'     => 'навыки',
        'bio'        => 'о себе',
        'cv'         => 'CV',
        _ => key,
      };
}

// ── Edit Profile Sheet ────────────────────────────────────────────────────────
class _EditProfileSheet extends StatefulWidget {
  final User user;
  final AuthService authService;
  final void Function(User) onSaved;
  final int initialTab;

  const _EditProfileSheet({
    required this.user,
    required this.authService,
    required this.onSaved,
    this.initialTab = 0,
  });

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  bool _saving = false;

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _bio;
  late final TextEditingController _portfolio;
  late final TextEditingController _university;
  late final TextEditingController _specialty;
  int? _studyYear;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
        length: 2, vsync: this, initialIndex: widget.initialTab);
    _firstName  = TextEditingController(text: widget.user.firstName);
    _lastName   = TextEditingController(text: widget.user.lastName);
    _bio        = TextEditingController(text: widget.user.bio ?? '');
    _portfolio  = TextEditingController(text: widget.user.portfolioUrl ?? '');
    _university = TextEditingController(text: widget.user.universityName ?? '');
    _specialty  = TextEditingController(text: widget.user.specialty ?? '');
    _studyYear  = widget.user.studyYear;
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _firstName, _lastName, _bio, _portfolio, _university, _specialty
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.authService.updateProfile(
        firstName:      _firstName.text.trim(),
        lastName:       _lastName.text.trim(),
        bio:            _bio.text.trim(),
        portfolioUrl:   _portfolio.text.trim(),
        universityName: _university.text.trim(),
        specialty:      _specialty.text.trim(),
        studyYear:      _studyYear,
      );
      widget.onSaved(updated);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: _div,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text('Редактировать профиль',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TabBar(
              controller: _tabs,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600),
              labelColor: _blue,
              unselectedLabelColor: _sub,
              indicatorColor: _blue,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [Tab(text: 'Обо мне'), Tab(text: 'Образование')],
            ),
            SizedBox(
              height: 340,
              child: TabBarView(
                controller: _tabs,
                children: [_buildIdentityTab(), _buildEducationTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          _SheetField(ctrl: _firstName, label: 'Имя', icon: Icons.person_outline),
          const SizedBox(height: 12),
          _SheetField(ctrl: _lastName, label: 'Фамилия', icon: Icons.person_outline),
          const SizedBox(height: 12),
          _SheetField(ctrl: _bio, label: 'Bio — расскажи о себе',
              icon: Icons.notes_rounded, maxLines: 3),
          const SizedBox(height: 12),
          _SheetField(ctrl: _portfolio,
              label: 'Portfolio URL (GitHub, Behance...)',
              icon: Icons.link_rounded),
        ],
      ),
    );
  }

  Widget _buildEducationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          _SheetField(ctrl: _university, label: 'Университет',
              icon: Icons.school_outlined),
          const SizedBox(height: 12),
          _SheetField(ctrl: _specialty, label: 'Специальность',
              icon: Icons.book_outlined),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _studyYear,
            decoration: InputDecoration(
              labelText: 'Курс',
              prefixIcon:
                  const Icon(Icons.calendar_month_outlined, size: 20),
              filled: true,
              fillColor: _surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _div),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _div),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _blue, width: 1.5),
              ),
            ),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 курс')),
              DropdownMenuItem(value: 2, child: Text('2 курс')),
              DropdownMenuItem(value: 3, child: Text('3 курс')),
              DropdownMenuItem(value: 4, child: Text('4 курс')),
              DropdownMenuItem(value: 5, child: Text('5 курс (магистр)')),
            ],
            onChanged: (v) => setState(() => _studyYear = v),
          ),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        filled: true,
        fillColor: _surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _div),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _div),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }
}

// ── Skills Sheet ──────────────────────────────────────────────────────────────
class _SkillsSheet extends StatefulWidget {
  final List<String> skills;
  final Future<void> Function(List<String>) onSave;
  const _SkillsSheet({required this.skills, required this.onSave});

  @override
  State<_SkillsSheet> createState() => _SkillsSheetState();
}

class _SkillsSheetState extends State<_SkillsSheet> {
  late List<String> _skills;
  final _ctrl = TextEditingController();
  bool _saving = false;

  static const _suggestions = [
    'Flutter', 'Dart', 'Python', 'JavaScript', 'TypeScript', 'React',
    'Node.js', 'Figma', 'SQL', 'Git', 'Java', 'Swift', 'Kotlin', 'Go',
    'C++', 'Django', 'FastAPI', 'PostgreSQL', 'Docker', 'Photoshop',
  ];

  @override
  void initState() {
    super.initState();
    _skills = List.from(widget.skills);
  }

  void _add(String skill) {
    final s = skill.trim();
    if (s.isEmpty || _skills.contains(s) || _skills.length >= 15) return;
    setState(() => _skills.add(s));
    _ctrl.clear();
  }

  void _remove(String skill) => setState(() => _skills.remove(skill));

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.onSave(_skills);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _suggestions.where((s) => !_skills.contains(s)).toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _div,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Навыки',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Сохранить',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Добавить навык...',
                      filled: true,
                      fillColor: _surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _div)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _div)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: _add,
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _add(_ctrl.text),
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_skills.isNotEmpty) ...[
              const Text('Добавлено:',
                  style: TextStyle(fontSize: 12, color: _sub)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills
                    .map((s) =>
                        _RemovableChip(label: s, onRemove: () => _remove(s)))
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],
            if (suggestions.isNotEmpty) ...[
              const Text('Популярные:',
                  style: TextStyle(fontSize: 12, color: _sub)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestions
                    .take(12)
                    .map((s) => GestureDetector(
                          onTap: () => _add(s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: _div),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add, size: 12, color: _sub),
                                const SizedBox(width: 4),
                                Text(s,
                                    style: const TextStyle(
                                        fontSize: 12, color: _sub)),
                              ],
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}


class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF0FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _blue)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: _blue),
          ),
        ],
      ),
    );
  }
}

// ── Report Sheet ──────────────────────────────────────────────────────────────
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
  final _tasks    = TextEditingController();
  final _skillCtrl = TextEditingController();
  int _hours = 0;
  final List<String> _skillsGained = [];
  bool _saving = false;

  @override
  void dispose() {
    _tasks.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_tasks.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.apiService.submitReport(
        applicationId:    widget.app['id'] as int,
        tasksDescription: _tasks.text.trim(),
        hoursCompleted:   _hours,
        skillsGained:     _skillsGained,
      );
      widget.onSuccess();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _red,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: _div,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Отчёт о стажировке',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextField(
              controller: _tasks,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Описание задач',
                alignLabelWithHint: true,
                filled: true,
                fillColor: _surface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _div)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _div)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Часов отработано:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () =>
                      setState(() => _hours = (_hours - 10).clamp(0, 1000)),
                  icon: const Icon(Icons.remove_circle_outline, color: _blue),
                ),
                Text('$_hours',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () =>
                      setState(() => _hours = (_hours + 10).clamp(0, 1000)),
                  icon: const Icon(Icons.add_circle_outline, color: _blue),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Навыки, полученные на стажировке:',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _skillCtrl,
                    decoration: InputDecoration(
                      hintText: 'Добавить навык...',
                      filled: true,
                      fillColor: _surface,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _div)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _div)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (s) {
                      final skill = s.trim();
                      if (skill.isNotEmpty && !_skillsGained.contains(skill)) {
                        setState(() => _skillsGained.add(skill));
                        _skillCtrl.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final s = _skillCtrl.text.trim();
                    if (s.isNotEmpty && !_skillsGained.contains(s)) {
                      setState(() => _skillsGained.add(s));
                      _skillCtrl.clear();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _blue,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            if (_skillsGained.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skillsGained
                    .map((s) => _RemovableChip(
                        label: s,
                        onRemove: () =>
                            setState(() => _skillsGained.remove(s))))
                    .toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Отправить отчёт',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
