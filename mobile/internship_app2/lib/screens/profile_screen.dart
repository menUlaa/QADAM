import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:internship_app2/l10n/strings.dart';
import 'package:internship_app2/models/user.dart';
import 'package:internship_app2/screens/ai_chat_screen.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/auth_service.dart';
import 'package:internship_app2/services/base_url.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// ── Tokens ────────────────────────────────────────────────────────────────────
const _blue    = Color(0xFF2164F3);
const _green   = Color(0xFF059669);
const _red     = Color(0xFFEF4444);
const _ink     = Color(0xFF111827);
const _sub     = Color(0xFF6B7280);
const _div     = Color(0xFFE5E7EB);
const _surface = Color(0xFFF3F2EE); // used in form sheets
const _pageBg  = Color(0xFFF8F9FB);

BoxDecoration _card() => BoxDecoration(
  color: Colors.white,
  border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
  borderRadius: BorderRadius.circular(14),
);

TextStyle _h2(Color c) => GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: c);

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

  int get _acceptedCount =>
      _applications.where((a) => a['status'] == 'accepted').length;

  List<Map<String, dynamic>> get _filteredApps {
    return switch (_appFilter) {
      'active'   => _applications.where((a) => a['status'] == 'pending').toList(),
      'accepted' => _applications.where((a) => a['status'] == 'accepted').toList(),
      _ => _applications,
    };
  }

  Future<void> _toggleStatus() async {
    if (_user == null) return;
    final updated = await _auth.updateProfile(openToWork: !_user!.openToWork);
    if (mounted) setState(() => _user = updated);
  }

  void _openEditSheet({int tab = 0}) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => _EditProfileDialog(
        user: _user!,
        authService: _auth,
        onSaved: (u) => setState(() => _user = u),
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
    final isDesktop = w > 900;
    return Scaffold(
      backgroundColor: _pageBg,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: isDesktop ? _buildDesktop() : _buildMobile(),
      ),
    );
  }

  // ── Desktop: two-column 62/38 ─────────────────────────────────────────────────
  Widget _buildDesktop() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left column 62%
            Expanded(
              flex: 62,
              child: Column(
                children: [
                  _buildHeaderCard(),
                  const SizedBox(height: 14),
                  // Card 2: Резюме
                  Container(
                    decoration: _card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle('Резюме'),
                        const Divider(height: 1, thickness: 0.5, color: _div),
                        _CvRow(
                          cvUrl: _user?.cvUrl,
                          cvFilename: _user?.cvFilename,
                          cvUploadedAt: _user?.cvUploadedAt,
                          uploading: _cvUploading,
                          onUpload: _uploadCv,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Card 3: Профиль
                  Container(
                    decoration: _card(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _cardTitle('Профиль'),
                        _profileRows(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Card 4: Мои заявки
                  Container(
                    decoration: _card(),
                    child: _ApplicationsSection(
                      loading: _loadingApps,
                      apps: _filteredApps,
                      allApps: _applications,
                      filter: _appFilter,
                      onFilterChange: (f) => setState(() => _appFilter = f),
                      onReport: _openReportSheet,
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Right column 38%
            Expanded(
              flex: 38,
              child: Column(
                children: [
                  if (_user != null) ...[
                    Container(
                      decoration: _card(),
                      child: _CompletenessBar(value: _completeness, missing: _missingItems),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      decoration: _card(),
                      child: _AiProfileCard(api: _api),
                    ),
                    const SizedBox(height: 14),
                  ],
                  Container(
                    decoration: _card(),
                    child: _StatsBar(total: _applications.length, accepted: _acceptedCount),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: _card(),
                    child: _SettingsSection(onLogout: _logout),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Mobile: single column ─────────────────────────────────────────────────────
  Widget _buildMobile() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        _buildHeaderCard(),
        const SizedBox(height: 12),
        if (_user != null) ...[
          Container(
            decoration: _card(),
            child: _CompletenessBar(value: _completeness, missing: _missingItems),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: _card(),
            child: _AiProfileCard(api: _api),
          ),
          const SizedBox(height: 12),
        ],
        Container(
          decoration: _card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle('Резюме'),
              const Divider(height: 1, thickness: 0.5, color: _div),
              _CvRow(
                cvUrl: _user?.cvUrl,
                cvFilename: _user?.cvFilename,
                cvUploadedAt: _user?.cvUploadedAt,
                uploading: _cvUploading,
                onUpload: _uploadCv,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _card(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardTitle('Профиль'),
              _profileRows(),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _card(),
          child: _StatsBar(total: _applications.length, accepted: _acceptedCount),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _card(),
          child: _ApplicationsSection(
            loading: _loadingApps,
            apps: _filteredApps,
            allApps: _applications,
            filter: _appFilter,
            onFilterChange: (f) => setState(() => _appFilter = f),
            onReport: _openReportSheet,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _card(),
          child: _SettingsSection(onLogout: _logout),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  // ── Header Card ───────────────────────────────────────────────────────────────
  Widget _buildHeaderCard() {
    final open = _user?.openToWork ?? true;
    final name = _user?.name.isNotEmpty == true ? _user!.name : 'Имя не указано';

    return Container(
      decoration: _card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 90,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1a4fd6), Color(0xFF2164F3), Color(0xFF6b8ef5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
              ),
              // "Редактировать" button top-right
              Positioned(
                top: 10, right: 12,
                child: GestureDetector(
                  onTap: _user != null ? () => _openEditSheet() : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Text('Редактировать',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ),
              // Avatar overlapping banner by -28px
              Positioned(
                bottom: -29, left: 16,
                child: GestureDetector(
                  onTap: _user != null ? _toggleStatus : null,
                  child: Container(
                    width: 58, height: 58,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _blue,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: Center(
                      child: Text(_initials,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Content below banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 37, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 70), // avatar placeholder
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + badge
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(name,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _ink)),
                          if (open)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF3DE),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: const Color(0xFFa8d58a)),
                              ),
                              child: const Text('В поиске работы',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF27500A))),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(_user?.email ?? '',
                        style: const TextStyle(fontSize: 12, color: _sub)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: _user != null ? () => _openEditSheet() : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _div),
                        ),
                        child: const Text('Добавить раздел',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _ink)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GestureDetector(
                      onTap: _user != null ? () => _openEditSheet() : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _blue,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('Настройки',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRows() => Column(
    children: [
      _ProfileRow(
        icon: Icons.notes_rounded, title: 'О себе',
        iconColor: const Color(0xFF2164F3), iconBg: const Color(0xFFEBF0FA),
        subtitle: (_user?.bio ?? '').isNotEmpty
            ? _user!.bio!
            : 'Расскажи о себе — работодатели читают это первым',
        dim: (_user?.bio ?? '').isEmpty,
        onTap: () => _openEditSheet(),
      ),
      const Divider(height: 0.5, color: _div),
      _ProfileRow(
        icon: Icons.bolt_rounded, title: 'Навыки',
        iconColor: const Color(0xFF7C3AED), iconBg: const Color(0xFFF3EEFF),
        subtitle: _user?.skills.isNotEmpty == true
            ? _user!.skills.take(4).join(', ') +
              (_user!.skills.length > 4 ? '  +${_user!.skills.length - 4}' : '')
            : 'Добавить навыки — работодатели фильтруют по ним',
        dim: _user?.skills.isEmpty != false,
        onTap: () => _openSkillsSheet(),
      ),
      const Divider(height: 0.5, color: _div),
      _ProfileRow(
        icon: Icons.school_rounded, title: 'Образование',
        iconColor: const Color(0xFF059669), iconBg: const Color(0xFFECFDF5),
        subtitle: (_user?.universityName ?? '').isNotEmpty
            ? _user!.universityName! +
              ((_user?.specialty ?? '').isNotEmpty ? ' · ${_user!.specialty}' : '')
            : 'Добавить университет и специальность',
        dim: (_user?.universityName ?? '').isEmpty,
        onTap: () => _openEditSheet(tab: 1),
      ),
      const Divider(height: 0.5, color: _div),
      _ProfileRow(
        icon: Icons.work_rounded, title: 'Опыт работы',
        iconColor: const Color(0xFFD97706), iconBg: const Color(0xFFFFF7ED),
        subtitle: 'Стажировки, работа, фриланс',
        dim: false,
        onTap: () => _openEditSheet(tab: 2),
      ),
      const Divider(height: 0.5, color: _div),
      _ProfileRow(
        icon: Icons.link_rounded, title: 'Portfolio URL',
        iconColor: const Color(0xFFDB2777), iconBg: const Color(0xFFFDF2F8),
        subtitle: (_user?.portfolioUrl ?? '').isNotEmpty
            ? _user!.portfolioUrl!
            : 'GitHub, Behance, Dribbble...',
        dim: (_user?.portfolioUrl ?? '').isEmpty,
        onTap: () => _openEditSheet(),
      ),
    ],
  );

  Widget _cardTitle(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
    child: Text(title, style: _h2(_ink)),
  );
}

// ── Profile Row ───────────────────────────────────────────────────────────────
class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool dim;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBg;

  const _ProfileRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.dim = false,
    this.iconColor,
    this.iconBg,
  });

  @override
  Widget build(BuildContext context) {
    final ic = dim ? const Color(0xFFD1D5DB) : (iconColor ?? _blue);
    final bg = dim ? const Color(0xFFF3F4F6) : (iconBg ?? const Color(0xFFEBF0FA));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: ic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
                  const SizedBox(height: 1),
                  Text(subtitle,
                    style: TextStyle(fontSize: 12, color: dim ? const Color(0xFFBEC3CA) : _sub),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFFCBD5E1)),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.upload_file_rounded, size: 18, color: _blue),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Загрузить резюме',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _ink)),
                    SizedBox(height: 2),
                    Text('PDF, максимум 5 МБ',
                        style: TextStyle(fontSize: 12, color: _sub)),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF4FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.description_outlined, size: 18, color: _blue),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cvFilename ?? 'resume.pdf',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _ink),
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
              final url = Uri.parse('$apiBaseUrl$cvUrl');
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Заполнение профиля',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
              ),
              Text('$pct%',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _blue)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 5,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: const AlwaysStoppedAnimation<Color>(_blue),
            ),
          ),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: missing.map((m) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEBF0FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(m,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats Bar ─────────────────────────────────────────────────────────────────
class _StatsBar extends StatelessWidget {
  final int total;
  final int accepted;
  const _StatsBar({required this.total, required this.accepted});

  @override
  Widget build(BuildContext context) {
    final pending = total - accepted;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _StatBox(value: '$total',   label: 'Всего заявок', color: _blue),
          const SizedBox(width: 8),
          _StatBox(value: '$accepted', label: 'Принято',     color: const Color(0xFF059669)),
          const SizedBox(width: 8),
          _StatBox(value: '$pending',  label: 'В ожидании',  color: const Color(0xFFD97706)),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatBox({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FB),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: color)),
            const SizedBox(height: 2),
            Text(label,
              style: const TextStyle(fontSize: 11, color: _sub),
              textAlign: TextAlign.center),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Мои заявки',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: _div),
          const SizedBox(height: 12),
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
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
            ))
          else if (apps.isEmpty)
            _EmptyApplications()
          else
            ...apps.map((app) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ApplicationCard(app: app, onReport: onReport),
            )),
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
        child: Text(label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _sub,
          )),
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: _sub),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ещё нет откликов',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _ink)),
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

  static const _avatarColors = [
    Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFF10B981),
    Color(0xFFF59E0B), Color(0xFFEF4444), Color(0xFF06B6D4),
  ];

  Color _avatarColor(String name) =>
      _avatarColors[name.codeUnits.fold(0, (a, b) => a + b) % _avatarColors.length];

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final words = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
    return words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : name[0].toUpperCase();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      const m = ['', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
          'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
      return '${dt.day} ${m[dt.month]}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    final status    = app['status'] as String? ?? 'pending';
    final hasReport = app['has_report'] as bool? ?? false;
    final title     = app['internship_title'] as String? ?? '—';
    final company   = app['company'] as String? ?? app['company_name'] as String? ?? '—';
    final city      = app['city'] as String? ?? app['internship_city'] as String? ?? '';
    final createdAt = app['created_at'] as String?;
    final salaryKzt = app['salary_kzt'] as int?;
    final duration  = app['duration'] as String?;

    final (statusLabel, statusColor, statusBg) = switch (status) {
      'accepted'  => ('Принят!',         const Color(0xFF059669), const Color(0xFFD1FAE5)),
      'rejected'  => ('Отказано',        const Color(0xFFDC2626), const Color(0xFFFEE2E2)),
      'interview' => ('Собеседование',   _blue,                   const Color(0xFFEFF4FF)),
      'reviewed'  => ('Просмотрено',     const Color(0xFF6366F1), const Color(0xFFEEF2FF)),
      _           => ('На рассмотрении', const Color(0xFFB45309), const Color(0xFFFEF3EC)),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: _avatarColor(company),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(child: Text(_initials(company),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white))),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(company,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _blue),
                        overflow: TextOverflow.ellipsis),
                    ),
                    if (city.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text('· $city',
                        style: const TextStyle(fontSize: 11, color: _sub)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _ink),
            maxLines: 2, overflow: TextOverflow.ellipsis),
          if (salaryKzt != null || duration != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                if (salaryKzt != null) ...[
                  _AppTag('${(salaryKzt / 1000).round()}K ₸',
                    const Color(0xFF059669), const Color(0xFFECFDF5)),
                  const SizedBox(width: 4),
                ],
                if (duration != null)
                  _AppTag(duration, _sub, const Color(0xFFF1F5F9)),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 11, color: _sub),
              const SizedBox(width: 4),
              Text('Подано ${_fmtDate(createdAt)}',
                style: const TextStyle(fontSize: 11, color: _sub)),
              const Spacer(),
              if (status == 'accepted')
                hasReport
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.check_circle_rounded, size: 12, color: Color(0xFF059669)),
                          SizedBox(width: 4),
                          Text('Отчёт сдан',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669))),
                        ]),
                      )
                    : GestureDetector(
                        onTap: () => onReport(app),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEBF0FA),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.edit_note_rounded, size: 12, color: _blue),
                            SizedBox(width: 4),
                            Text('Сдать отчёт',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _blue)),
                          ]),
                        ),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppTag extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;
  const _AppTag(this.text, this.color, this.bg);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Settings Section ──────────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final VoidCallback onLogout;
  const _SettingsSection({required this.onLogout});

  void _openNotifications(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationsSheet(),
    );
  }

  void _openChangePassword(BuildContext ctx, AuthService auth) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: _ChangePasswordSheet(authService: auth),
      ),
    );
  }

  void _openAbout(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AboutSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Настройки',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 12),
          // Language row
          ValueListenableBuilder<String>(
            valueListenable: localeNotifier,
            builder: (_, lang, __) => _SettingsRow(
              icon: Icons.language_rounded,
              label: 'Язык',
              right: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in {'RU': 'ru', 'ҚЗ': 'kz', 'EN': 'en'}.entries)
                    GestureDetector(
                      onTap: () => setLocale(e.value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.only(left: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          color: lang == e.value ? _blue : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: lang == e.value ? _blue : _div,
                          ),
                        ),
                        child: Text(e.key,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: lang == e.value ? Colors.white : _sub,
                          )),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: _div),
          _SettingsRow(
            icon: Icons.notifications_outlined,
            label: 'Уведомления',
            right: const Icon(Icons.chevron_right, size: 18, color: _sub),
            onTap: () => _openNotifications(context),
          ),
          const Divider(height: 1, thickness: 0.5, color: _div),
          _SettingsRow(
            icon: Icons.lock_outline_rounded,
            label: 'Изменить пароль',
            right: const Icon(Icons.chevron_right, size: 18, color: _sub),
            onTap: () => _openChangePassword(context, auth),
          ),
          const Divider(height: 1, thickness: 0.5, color: _div),
          _SettingsRow(
            icon: Icons.info_outline_rounded,
            label: 'О приложении',
            right: const Icon(Icons.chevron_right, size: 18, color: _sub),
            onTap: () => _openAbout(context),
          ),
          const Divider(height: 1, thickness: 0.5, color: _div),
          _SettingsRow(
            icon: Icons.logout_rounded,
            label: 'Выйти из аккаунта',
            iconColor: _red,
            labelColor: _red,
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Выйти?',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                  content: const Text('Вы уверены, что хотите выйти из аккаунта?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Выйти', style: TextStyle(color: _red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) onLogout();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? right;
  final Color? iconColor;
  final Color? labelColor;
  final VoidCallback? onTap;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.right,
    this.iconColor,
    this.labelColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: iconColor ?? _sub),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? _ink,
                )),
            ),
            if (right != null) right!,
          ],
        ),
      ),
    );
  }
}

// ── Notifications Sheet ───────────────────────────────────────────────────────
class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet();
  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  bool _newJobs    = true;
  bool _status     = true;
  bool _messages   = false;
  bool _tips       = true;
  bool _loaded     = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    if (mounted) setState(() {
      _newJobs  = p.getBool('notif_new_jobs') ?? true;
      _status   = p.getBool('notif_status')   ?? true;
      _messages = p.getBool('notif_messages') ?? false;
      _tips     = p.getBool('notif_tips')     ?? true;
      _loaded   = true;
    });
  }

  Future<void> _save(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final modalW  = screenW > 620 ? 560.0 : screenW;

    final rows = [
      (Icons.work_outline_rounded,  'Новые стажировки',    _newJobs,  'notif_new_jobs',  (bool v) => setState(() => _newJobs  = v)),
      (Icons.assignment_turned_in_outlined, 'Статус заявки', _status, 'notif_status',    (bool v) => setState(() => _status   = v)),
      (Icons.chat_bubble_outline_rounded, 'Сообщения',    _messages, 'notif_messages',   (bool v) => setState(() => _messages = v)),
      (Icons.lightbulb_outline_rounded, 'Советы по профилю', _tips,  'notif_tips',       (bool v) => setState(() => _tips     = v)),
    ];

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: modalW,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 14),
              const Text('Уведомления',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink)),
              const SizedBox(height: 4),
              if (!_loaded)
                const Padding(padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(color: _blue, strokeWidth: 2))),
              if (_loaded)
                ...rows.map((r) {
                  final (icon, label, val, key, setter) = r;
                  return Column(
                    children: [
                      const Divider(height: 20, thickness: 0.5, color: _div),
                      Row(
                        children: [
                          Icon(icon, size: 18, color: _sub),
                          const SizedBox(width: 12),
                          Expanded(child: Text(label,
                            style: const TextStyle(fontSize: 14, color: _ink))),
                          Switch(
                            value: val,
                            activeColor: _blue,
                            onChanged: (v) { setter(v); _save(key, v); },
                          ),
                        ],
                      ),
                    ],
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Change Password Sheet ─────────────────────────────────────────────────────
class _ChangePasswordSheet extends StatefulWidget {
  final AuthService authService;
  const _ChangePasswordSheet({required this.authService});
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _current  = TextEditingController();
  final _newPass  = TextEditingController();
  final _confirm  = TextEditingController();
  bool _hideCurrent = true;
  bool _hideNew     = true;
  bool _hideConfirm = true;
  bool _saving      = false;

  @override
  void dispose() {
    _current.dispose(); _newPass.dispose(); _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cur = _current.text.trim();
    final nw  = _newPass.text.trim();
    final cf  = _confirm.text.trim();
    if (cur.isEmpty || nw.isEmpty || cf.isEmpty) {
      _snack('Заполните все поля', _red); return;
    }
    if (nw.length < 8) {
      _snack('Новый пароль — минимум 8 символов', _red); return;
    }
    if (nw != cf) {
      _snack('Пароли не совпадают', _red); return;
    }
    setState(() => _saving = true);
    try {
      await widget.authService.changePassword(currentPassword: cur, newPassword: nw);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Пароль изменён', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: _green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      _snack(e.toString().replaceAll('Exception: ', ''), _red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  InputDecoration _fieldDeco(String hint, IconData icon, bool hidden, VoidCallback toggle) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
      prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
      suffixIcon: IconButton(
        icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 18, color: const Color(0xFF9CA3AF)),
        onPressed: toggle,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final modalW  = screenW > 620 ? 560.0 : screenW;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: modalW,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text('Изменить пароль',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink)),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _current,
                obscureText: _hideCurrent,
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: _fieldDeco('Текущий пароль', Icons.lock_outline_rounded,
                    _hideCurrent, () => setState(() => _hideCurrent = !_hideCurrent)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _newPass,
                obscureText: _hideNew,
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: _fieldDeco('Новый пароль', Icons.lock_outline_rounded,
                    _hideNew, () => setState(() => _hideNew = !_hideNew)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _confirm,
                obscureText: _hideConfirm,
                style: const TextStyle(fontSize: 14, color: _ink),
                decoration: _fieldDeco('Подтвердить пароль', Icons.lock_outline_rounded,
                    _hideConfirm, () => setState(() => _hideConfirm = !_hideConfirm)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── About Sheet ───────────────────────────────────────────────────────────────
class _AboutSheet extends StatelessWidget {
  const _AboutSheet();

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final modalW  = screenW > 620 ? 560.0 : screenW;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: modalW,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
              )),
              const SizedBox(height: 20),
              const Icon(Icons.directions_walk_rounded, size: 48, color: _blue),
              const SizedBox(height: 10),
              const Text('Qadam',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _ink)),
              const SizedBox(height: 4),
              const Text('Платформа стажировок Казахстана',
                style: TextStyle(fontSize: 14, color: _sub),
                textAlign: TextAlign.center),
              const SizedBox(height: 4),
              const Text('Версия 1.0.0',
                style: TextStyle(fontSize: 12, color: _sub)),
              const SizedBox(height: 16),
              const Divider(thickness: 0.5, color: _div),
              _AboutRow(
                label: 'Политика конфиденциальности',
                url: 'https://qadam.kz/privacy',
              ),
              const Divider(thickness: 0.5, color: _div),
              _AboutRow(
                label: 'Условия использования',
                url: 'https://qadam.kz/terms',
              ),
              const Divider(thickness: 0.5, color: _div),
              const SizedBox(height: 12),
              const Text('© 2026 Qadam',
                style: TextStyle(fontSize: 12, color: _sub)),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final String label;
  final String url;
  const _AboutRow({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            Expanded(child: Text(label,
              style: const TextStyle(fontSize: 14, color: _ink))),
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

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3730a3), Color(0xFF4338ca)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AI Анализ профиля',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                      Text('Как усилить профиль для работодателя',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
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
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (score != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: score / 100,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  minHeight: 4,
                ),
              ),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text('Добавь: ${missing.map(_fieldName).join(', ')}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ],
            if (analysis != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(analysis,
                  style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.5)),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AiChatScreen(mode: AiChatMode.general),
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 14),
                      SizedBox(width: 6),
                      Text('Обсудить с AI',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
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
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.psychology_outlined, color: Colors.white, size: 16),
                  label: Text(
                    _loading ? 'Анализирую...' : 'Проанализировать профиль',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
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

// ── Edit Profile Dialog (LinkedIn-style) ─────────────────────────────────────
class _EditProfileDialog extends StatefulWidget {
  final User user;
  final AuthService authService;
  final void Function(User) onSaved;

  const _EditProfileDialog({
    required this.user,
    required this.authService,
    required this.onSaved,
  });

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  bool _saving = false;
  final _scrollCtrl = ScrollController();

  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _bio;
  late final TextEditingController _portfolio;
  late final TextEditingController _university;
  late final TextEditingController _specialty;
  late final TextEditingController _gpaCtrl;
  int? _studyYear;
  int? _graduationYear;

  List<WorkExperience> _experiences = [];
  bool _loadingExps = false;

  @override
  void initState() {
    super.initState();
    _firstName  = TextEditingController(text: widget.user.firstName);
    _lastName   = TextEditingController(text: widget.user.lastName);
    _bio        = TextEditingController(text: widget.user.bio ?? '');
    _portfolio  = TextEditingController(text: widget.user.portfolioUrl ?? '');
    _university = TextEditingController(text: widget.user.universityName ?? '');
    _specialty  = TextEditingController(text: widget.user.specialty ?? '');
    _gpaCtrl    = TextEditingController(
        text: widget.user.gpa != null ? widget.user.gpa.toString() : '');
    _studyYear      = widget.user.studyYear;
    _graduationYear = widget.user.graduationYear;
    _loadExperiences();
  }

  Future<void> _loadExperiences() async {
    setState(() => _loadingExps = true);
    try {
      final exps = await widget.authService.getExperiences();
      if (mounted) setState(() { _experiences = exps; _loadingExps = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingExps = false);
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    for (final c in [_firstName, _lastName, _bio, _portfolio, _university, _specialty, _gpaCtrl]) {
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
        gpa:            double.tryParse(_gpaCtrl.text.trim()),
        graduationYear: _graduationYear,
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

  void _openExpForm(WorkExperience? exp) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: _ExperienceFormSheet(
          existing: exp,
          authService: widget.authService,
          onSaved: (saved) {
            setState(() {
              if (exp == null) {
                _experiences.add(saved);
              } else {
                final idx = _experiences.indexWhere((e) => e.id == saved.id);
                if (idx >= 0) _experiences[idx] = saved;
              }
            });
          },
        ),
      ),
    );
  }

  Future<void> _deleteExp(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Удалить?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Удалить эту запись об опыте?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить', style: TextStyle(color: _red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.authService.deleteExperience(id);
      setState(() => _experiences.removeWhere((e) => e.id == id));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: _red,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.sizeOf(context).height;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      elevation: 8,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: screenH * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 12, 14),
              child: Row(
                children: [
                  Text('Редактировать профиль',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    )),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 22, color: _sub),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: _div),
            // ── Scrollable body ─────────────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // — Основные сведения
                    _LiSection('Основные сведения'),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _LiField(label: 'Имя', ctrl: _firstName)),
                        const SizedBox(width: 12),
                        Expanded(child: _LiField(label: 'Фамилия', ctrl: _lastName)),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LiField(
                      label: 'О себе',
                      ctrl: _bio,
                      hint: 'Расскажи о себе — работодатели читают это первым',
                      maxLength: 300,
                      maxLines: 4,
                      minLines: 3,
                    ),
                    const SizedBox(height: 18),
                    _LiField(
                      label: 'Portfolio URL',
                      ctrl: _portfolio,
                      hint: 'GitHub, Behance, Dribbble...',
                    ),
                    const SizedBox(height: 32),
                    const Divider(thickness: 0.5, color: _div),
                    const SizedBox(height: 24),
                    // — Образование
                    _LiSection('Образование'),
                    const SizedBox(height: 20),
                    _LiField(
                      label: 'Университет',
                      ctrl: _university,
                      hint: 'Название учебного заведения',
                    ),
                    const SizedBox(height: 18),
                    _LiField(
                      label: 'Специальность',
                      ctrl: _specialty,
                      hint: 'Направление обучения',
                    ),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _LiDropdown<int>(
                            label: 'Курс',
                            value: _studyYear,
                            hint: 'Выбери курс',
                            items: const [
                              DropdownMenuItem(value: 1, child: Text('1 курс')),
                              DropdownMenuItem(value: 2, child: Text('2 курс')),
                              DropdownMenuItem(value: 3, child: Text('3 курс')),
                              DropdownMenuItem(value: 4, child: Text('4 курс')),
                              DropdownMenuItem(value: 5, child: Text('5 курс (магистр)')),
                            ],
                            onChanged: (v) => setState(() => _studyYear = v),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _LiDropdown<int>(
                            label: 'Год выпуска',
                            value: _graduationYear,
                            hint: 'Выбери год',
                            items: List.generate(10, (i) {
                              final y = DateTime.now().year - 3 + i;
                              return DropdownMenuItem(value: y, child: Text('$y'));
                            }),
                            onChanged: (v) => setState(() => _graduationYear = v),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _LiField(label: 'GPA', ctrl: _gpaCtrl, hint: 'Например: 3.8'),
                    const SizedBox(height: 32),
                    const Divider(thickness: 0.5, color: _div),
                    const SizedBox(height: 24),
                    // — Опыт работы
                    Row(
                      children: [
                        Expanded(child: _LiSection('Опыт работы')),
                        GestureDetector(
                          onTap: () => _openExpForm(null),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: _blue),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text('+ Добавить',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _blue,
                              )),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_loadingExps)
                      const Center(child: Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(color: _blue, strokeWidth: 2),
                      ))
                    else if (_experiences.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _div, width: 0.5),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.work_outline_rounded, size: 36, color: Color(0xFFD1D5DB)),
                            SizedBox(height: 8),
                            Text('Нет записей об опыте',
                              style: TextStyle(fontSize: 14, color: _sub)),
                          ],
                        ),
                      )
                    else
                      ...(_experiences.map((exp) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ExpTile(
                          exp: exp,
                          onEdit: () => _openExpForm(exp),
                          onDelete: () => _deleteExp(exp.id),
                        ),
                      ))),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // ── Footer ─────────────────────────────────────────────────────────
            const Divider(height: 1, thickness: 1, color: _div),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: Text('Отмена',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: _sub,
                        fontWeight: FontWeight.w500,
                      )),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: _saving
                        ? const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Сохранить',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            )),
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

// ── LinkedIn-style form helpers ───────────────────────────────────────────────

class _LiSection extends StatelessWidget {
  final String title;
  const _LiSection(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title,
      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: _ink));
  }
}

class _LiField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final String? hint;
  final int? maxLength;
  final int maxLines;
  final int minLines;

  const _LiField({
    required this.label,
    required this.ctrl,
    this.hint,
    this.maxLength,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          )),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          style: GoogleFonts.inter(fontSize: 14, color: _ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            counterStyle: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _LiDropdown<T> extends StatelessWidget {
  final String label;
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final void Function(T?) onChanged;

  const _LiDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _ink,
          )),
        const SizedBox(height: 6),
        DropdownButtonFormField<T>(
          value: value,
          hint: hint != null
              ? Text(hint!,
                  style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF9CA3AF)))
              : null,
          style: GoogleFonts.inter(fontSize: 14, color: _ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: const BorderSide(color: _blue, width: 1.5),
            ),
          ),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final int maxLines;
  final int minLines;
  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.maxLines = 1,
    this.minLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      minLines: minLines,
      style: const TextStyle(fontSize: 14, color: _ink),
      decoration: InputDecoration(
        hintText: label,
        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF8F9FB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5),
        ),
      ),
    );
  }
}

// ── Experience Tile ───────────────────────────────────────────────────────────
class _ExpTile extends StatelessWidget {
  final WorkExperience exp;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ExpTile({required this.exp, required this.onEdit, required this.onDelete});

  static const _typeLabels = {
    'internship': 'Стажировка',
    'job': 'Работа',
    'freelance': 'Фриланс',
    'volunteer': 'Волонтёрство',
  };

  @override
  Widget build(BuildContext context) {
    final typeLabel = _typeLabels[exp.expType] ?? exp.expType;
    final period = exp.isCurrent
        ? '${exp.startDate} — по наст. вр.'
        : '${exp.startDate}${exp.endDate != null ? ' — ${exp.endDate}' : ''}';

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _div),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.work_outline_rounded, size: 18, color: _blue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(exp.title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _ink)),
                Text('${exp.organization} · $typeLabel',
                  style: const TextStyle(fontSize: 12, color: _sub)),
                Text(period, style: const TextStyle(fontSize: 11, color: _sub)),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 16, color: _sub),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 16, color: _red),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }
}

// ── Experience Form Sheet ─────────────────────────────────────────────────────
class _ExperienceFormSheet extends StatefulWidget {
  final WorkExperience? existing;
  final AuthService authService;
  final void Function(WorkExperience) onSaved;

  const _ExperienceFormSheet({
    required this.existing,
    required this.authService,
    required this.onSaved,
  });

  @override
  State<_ExperienceFormSheet> createState() => _ExperienceFormSheetState();
}

class _ExperienceFormSheetState extends State<_ExperienceFormSheet> {
  late final TextEditingController _title;
  late final TextEditingController _org;
  late final TextEditingController _startDate;
  late final TextEditingController _endDate;
  late final TextEditingController _desc;
  String _expType = 'internship';
  bool _isCurrent = false;
  bool _saving = false;

  static const _types = {
    'internship': 'Стажировка',
    'job': 'Работа',
    'freelance': 'Фриланс',
    'volunteer': 'Волонтёрство',
  };

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title     = TextEditingController(text: e?.title ?? '');
    _org       = TextEditingController(text: e?.organization ?? '');
    _startDate = TextEditingController(text: e?.startDate ?? '');
    _endDate   = TextEditingController(text: e?.endDate ?? '');
    _desc      = TextEditingController(text: e?.description ?? '');
    _expType   = e?.expType ?? 'internship';
    _isCurrent = e?.isCurrent ?? false;
  }

  @override
  void dispose() {
    for (final c in [_title, _org, _startDate, _endDate, _desc]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _org.text.trim().isEmpty || _startDate.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Заполните название, организацию и дату начала'),
        backgroundColor: _red,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        'title': _title.text.trim(),
        'organization': _org.text.trim(),
        'exp_type': _expType,
        'start_date': _startDate.text.trim(),
        'end_date': _isCurrent ? null : (_endDate.text.trim().isEmpty ? null : _endDate.text.trim()),
        'is_current': _isCurrent,
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      };
      WorkExperience saved;
      if (widget.existing == null) {
        saved = await widget.authService.createExperience(data);
      } else {
        saved = await widget.authService.updateExperience(widget.existing!.id, data);
      }
      widget.onSaved(saved);
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
    const _fieldDeco = InputDecoration(
      filled: true,
      fillColor: Color(0xFFF8F9FB),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
        borderSide: BorderSide(color: Color(0xFF2164F3), width: 1.5),
      ),
    );
    const _iconColor = Color(0xFF9CA3AF);
    const _fieldStyle = TextStyle(fontSize: 14, color: _ink);

    final screenW = MediaQuery.sizeOf(context).width;
    final modalW = screenW > 620 ? 560.0 : screenW;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: modalW,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      widget.existing == null ? 'Добавить опыт' : 'Редактировать опыт',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Сохранить',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    children: [
                      TextField(
                        controller: _title,
                        style: _fieldStyle,
                        decoration: _fieldDeco.copyWith(
                          hintText: 'Должность / Название',
                          prefixIcon: const Icon(Icons.work_outline_rounded, size: 18, color: _iconColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _org,
                        style: _fieldStyle,
                        decoration: _fieldDeco.copyWith(
                          hintText: 'Организация',
                          prefixIcon: const Icon(Icons.business_outlined, size: 18, color: _iconColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _expType,
                        style: _fieldStyle,
                        decoration: _fieldDeco.copyWith(
                          labelText: 'Тип',
                          prefixIcon: const Icon(Icons.category_outlined, size: 18, color: _iconColor),
                        ),
                        items: _types.entries
                            .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                            .toList(),
                        onChanged: (v) => setState(() => _expType = v ?? _expType),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _startDate,
                              style: _fieldStyle,
                              decoration: _fieldDeco.copyWith(
                                hintText: 'Начало (ГГГГ-ММ)',
                                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: _iconColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _endDate,
                              enabled: !_isCurrent,
                              style: _fieldStyle,
                              decoration: _fieldDeco.copyWith(
                                hintText: 'Конец (ГГГГ-ММ)',
                                prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18, color: _iconColor),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _isCurrent = !_isCurrent),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _isCurrent,
                                onChanged: (v) => setState(() => _isCurrent = v ?? false),
                                activeColor: _blue,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              const Text('По настоящее время',
                                style: TextStyle(fontSize: 13, color: _ink)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _desc,
                        maxLines: 3,
                        minLines: 2,
                        style: _fieldStyle,
                        decoration: _fieldDeco.copyWith(
                          hintText: 'Описание (необязательно)',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 18, color: _iconColor),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
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
    final screenW = MediaQuery.sizeOf(context).width;
    final modalW = screenW > 620 ? 560.0 : screenW;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: modalW,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Text('Навыки',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _ink)),
                    const Spacer(),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: _saving
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Сохранить',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        style: const TextStyle(fontSize: 14, color: _ink),
                        decoration: InputDecoration(
                          hintText: 'Добавить навык...',
                          hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF9CA3AF)),
                          filled: true,
                          fillColor: const Color(0xFFF8F9FB),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5),
                          ),
                        ),
                        onSubmitted: _add,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44, height: 44,
                      child: Material(
                        color: _blue,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => _add(_ctrl.text),
                          child: const Icon(Icons.add, color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (_skills.isNotEmpty) ...[
                  const Text('Добавлено:',
                    style: TextStyle(fontSize: 12, color: _sub, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: _skills.map((s) =>
                      _RemovableChip(label: s, onRemove: () => _remove(s))).toList(),
                  ),
                  const SizedBox(height: 14),
                ],
                if (suggestions.isNotEmpty) ...[
                  const Text('Популярные:',
                    style: TextStyle(fontSize: 12, color: _sub, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: suggestions.take(14).map((s) => GestureDetector(
                      onTap: () => _add(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5E7EB), width: 0.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 13, color: _blue),
                            const SizedBox(width: 4),
                            Text(s, style: const TextStyle(fontSize: 13, color: _sub)),
                          ],
                        ),
                      ),
                    )).toList(),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
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
      padding: const EdgeInsets.only(left: 12, top: 5, bottom: 5, right: 6),
      decoration: BoxDecoration(
        color: _blue,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: Colors.white),
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
  const _ReportSheet({required this.app, required this.apiService, required this.onSuccess});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  final _tasks     = TextEditingController();
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
    final fieldDeco = InputDecoration(
      filled: true, fillColor: _surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _div)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _div)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _blue, width: 1.5)),
    );

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
                decoration: BoxDecoration(color: _div, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Отчёт о стажировке',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            TextField(
              controller: _tasks,
              maxLines: 4,
              decoration: fieldDeco.copyWith(
                labelText: 'Описание задач',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Часов отработано:', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _hours = (_hours - 10).clamp(0, 1000)),
                  icon: const Icon(Icons.remove_circle_outline, color: _blue),
                ),
                Text('$_hours', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () => setState(() => _hours = (_hours + 10).clamp(0, 1000)),
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
                    decoration: fieldDeco.copyWith(
                      hintText: 'Добавить навык...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    minimumSize: const Size(48, 48),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            if (_skillsGained.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: _skillsGained.map((s) => _RemovableChip(
                  label: s,
                  onRemove: () => setState(() => _skillsGained.remove(s)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 50,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Отправить отчёт',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
