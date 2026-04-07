import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:internship_app2/models/user.dart';
import 'package:internship_app2/services/api_service.dart';
import 'package:internship_app2/services/auth_service.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────
const _blue = Color(0xFF2164F3);
const _green = Color(0xFF10B981);
const _amber = Color(0xFFF59E0B);
const _red = Color(0xFFEF4444);
const _surface = Color(0xFFF8FAFC);
const _border = Color(0xFFE2E8F0);
const _text1 = Color(0xFF0F172A);
const _text2 = Color(0xFF64748B);

const _cardDeco = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.all(Radius.circular(16)),
  boxShadow: [
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────
// ProfileScreen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;
  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _auth = AuthService();
  final _api = ApiService();

  User? _user;
  List<Map<String, dynamic>> _applications = [];
  bool _loadingApps = true;
  bool _cvUploading = false;

  // Application filter
  String _appFilter = 'all'; // all | active | accepted

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = await _auth.getSavedUser();
    if (mounted) setState(() => _user = user);
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

  // ── CV upload ──────────────────────────────────────────────────────────────
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
      // Persist to SharedPrefs
      await _auth.updateProfile(); // no-op ping to get fresh user from server
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

  // ── Profile completeness ──────────────────────────────────────────────────
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

  // ── App stats ──────────────────────────────────────────────────────────────
  int get _acceptedCount =>
      _applications.where((a) => a['status'] == 'accepted').length;
  int get _pendingCount =>
      _applications.where((a) => a['status'] == 'pending').length;

  List<Map<String, dynamic>> get _filteredApps {
    return switch (_appFilter) {
      'active' => _applications
          .where((a) => a['status'] == 'pending')
          .toList(),
      'accepted' => _applications
          .where((a) => a['status'] == 'accepted')
          .toList(),
      _ => _applications,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: RefreshIndicator(
        onRefresh: _load,
        color: _blue,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _IdentityCard(
              user: _user,
              onStatusToggle: _toggleStatus,
              onEditProfile: _openEditSheet,
            ),
            const SizedBox(height: 12),
            if (_user != null && _completeness < 1.0)
              _CompletenessCard(
                value: _completeness,
                missing: _missingItems,
              ),
            if (_user != null && _completeness < 1.0)
              const SizedBox(height: 12),
            _StatsRow(
              total: _applications.length,
              accepted: _acceptedCount,
              pending: _pendingCount,
              openToWork: _user?.openToWork ?? true,
            ),
            const SizedBox(height: 12),
            _SkillsCard(
              skills: _user?.skills ?? [],
              onSave: (skills) async {
                final updated = await _auth.updateProfile(skills: skills);
                if (mounted) setState(() => _user = updated);
              },
            ),
            const SizedBox(height: 12),
            _EducationCard(
              universityName: _user?.universityName,
              specialty: _user?.specialty,
              studyYear: _user?.studyYear,
              onEdit: () => _openEditSheet(tab: 1),
            ),
            const SizedBox(height: 12),
            _CvCard(
              cvUrl: _user?.cvUrl,
              cvFilename: _user?.cvFilename,
              cvUploadedAt: _user?.cvUploadedAt,
              uploading: _cvUploading,
              onUpload: _uploadCv,
            ),
            const SizedBox(height: 20),
            _ApplicationsSection(
              loading: _loadingApps,
              apps: _filteredApps,
              allApps: _applications,
              filter: _appFilter,
              onFilterChange: (f) => setState(() => _appFilter = f),
              onReport: _openReportSheet,
            ),
            const SizedBox(height: 20),
            _SettingsSection(onLogout: _logout),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Actions
  // ─────────────────────────────────────────────────────────────────────────
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
}

// ─────────────────────────────────────────────────────────────────────────────
// IDENTITY CARD
// ─────────────────────────────────────────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final User? user;
  final VoidCallback onStatusToggle;
  final void Function({int tab}) onEditProfile;

  const _IdentityCard({
    required this.user,
    required this.onStatusToggle,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? '';
    final email = user?.email ?? '';
    final initials = name.isNotEmpty
        ? name.trim().split(' ').where((w) => w.isNotEmpty)
            .map((w) => w[0]).take(2).join().toUpperCase()
        : '?';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x0A000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 24),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2164F3), Color(0xFF6C7DFF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Name + status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      name.isEmpty ? 'Имя не указано' : name,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _text1,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 13, color: _text2),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: onStatusToggle,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: (user?.openToWork ?? true)
                              ? const Color(0xFFD1FAE5)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: (user?.openToWork ?? true)
                                    ? _green
                                    : _text2,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              (user?.openToWork ?? true)
                                  ? 'Open to internships'
                                  : 'Not available',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: (user?.openToWork ?? true)
                                    ? _green
                                    : _text2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () => onEditProfile(tab: 0),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.edit_outlined, size: 18, color: _text2),
                ),
              ),
            ],
          ),

          // Bio
          if ((user?.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                user!.bio!,
                style: const TextStyle(fontSize: 14, color: _text1, height: 1.5),
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => onEditProfile(tab: 0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border, style: BorderStyle.solid),
                ),
                child: const Text(
                  '+ Добавь bio — работодатели читают его первым',
                  style: TextStyle(fontSize: 13, color: _text2),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLETENESS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CompletenessCard extends StatelessWidget {
  final double value;
  final List<String> missing;

  const _CompletenessCard({required this.value, required this.missing});

  @override
  Widget build(BuildContext context) {
    final pct = (value * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up_rounded, size: 18, color: _blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Профиль заполнен на $pct%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _text1,
                    ),
                  ),
                ),
                Text('$pct%',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _blue)),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation(_blue),
              ),
            ),
            if (missing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Добавь: ${missing.join(', ')}',
                style: const TextStyle(fontSize: 12, color: _text2),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int total;
  final int accepted;
  final int pending;
  final bool openToWork;

  const _StatsRow({
    required this.total,
    required this.accepted,
    required this.pending,
    required this.openToWork,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatTile(label: 'Откликов', value: '$total', color: _blue),
          const SizedBox(width: 10),
          _StatTile(label: 'Принято', value: '$accepted', color: _green),
          const SizedBox(width: 10),
          _StatTile(
            label: 'Статус',
            value: openToWork ? 'Открыт' : 'Закрыт',
            color: openToWork ? _green : _text2,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: _cardDeco,
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: _text2)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILLS CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SkillsCard extends StatelessWidget {
  final List<String> skills;
  final Future<void> Function(List<String>) onSave;

  const _SkillsCard({required this.skills, required this.onSave});

  void _openEditSkills(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SkillsSheet(skills: skills, onSave: onSave),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 18, color: _blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Навыки',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _text1)),
                ),
                GestureDetector(
                  onTap: () => _openEditSkills(context),
                  child: const Text('Изменить',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _blue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (skills.isEmpty)
              GestureDetector(
                onTap: () => _openEditSkills(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.bolt_outlined, size: 28, color: _text2),
                      SizedBox(height: 6),
                      Text('Нет навыков',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _text2)),
                      SizedBox(height: 2),
                      Text(
                        'Работодатели фильтруют кандидатов по навыкам',
                        style: TextStyle(fontSize: 12, color: _text2),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...skills.map((s) => _SkillChip(label: s)),
                  GestureDetector(
                    onTap: () => _openEditSkills(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEBF0FA),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _blue.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add, size: 14, color: _blue),
                          SizedBox(width: 4),
                          Text('Добавить',
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
        ),
      ),
    );
  }
}

class _SkillChip extends StatelessWidget {
  final String label;
  const _SkillChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF0FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: _blue)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDUCATION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _EducationCard extends StatelessWidget {
  final String? universityName;
  final String? specialty;
  final int? studyYear;
  final VoidCallback onEdit;

  const _EducationCard({
    required this.universityName,
    required this.specialty,
    required this.studyYear,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasData = (universityName ?? '').isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.school_outlined, size: 18, color: _blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Образование',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _text1)),
                ),
                GestureDetector(
                  onTap: onEdit,
                  child: const Text('Изменить',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _blue)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasData)
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.school_outlined, size: 28, color: _text2),
                      SizedBox(height: 6),
                      Text('Добавь образование',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _text2)),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEBF0FA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.account_balance_outlined,
                        size: 22, color: _blue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          universityName!,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _text1),
                        ),
                        if ((specialty ?? '').isNotEmpty)
                          Text(
                            specialty! +
                                (studyYear != null
                                    ? ' · $studyYear курс'
                                    : ''),
                            style: const TextStyle(
                                fontSize: 13, color: _text2),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CV CARD
// ─────────────────────────────────────────────────────────────────────────────
class _CvCard extends StatelessWidget {
  final String? cvUrl;
  final String? cvFilename;
  final String? cvUploadedAt;
  final bool uploading;
  final VoidCallback onUpload;

  const _CvCard({
    required this.cvUrl,
    required this.cvFilename,
    required this.cvUploadedAt,
    required this.uploading,
    required this.onUpload,
  });

  String _formatDate(String? iso) {
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso);
      final months = [
        '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
      ];
      return '${dt.day} ${months[dt.month]} ${dt.year}';
    } catch (_) {
      return '';
    }
  }

  bool get _isOld {
    if (cvUploadedAt == null) return false;
    try {
      final dt = DateTime.parse(cvUploadedAt!);
      return DateTime.now().difference(dt).inDays > 180;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCv = cvUrl != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDeco,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.description_outlined, size: 18, color: _blue),
                SizedBox(width: 8),
                Text('Резюме (CV)',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _text1)),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasCv)
              // ── Empty state — dashed border upload zone ──
              GestureDetector(
                onTap: uploading ? null : onUpload,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 28),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: uploading
                      ? const Center(
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _blue))
                      : const Column(
                          children: [
                            Icon(Icons.upload_file_rounded,
                                size: 36, color: _text2),
                            SizedBox(height: 8),
                            Text('Загрузить CV (PDF)',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _text1)),
                            SizedBox(height: 2),
                            Text('Максимум 5 МБ',
                                style: TextStyle(
                                    fontSize: 12, color: _text2)),
                          ],
                        ),
                ),
              )
            else ...[
              // ── Uploaded state ──
              if (_isOld)
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 14, color: _amber),
                      SizedBox(width: 6),
                      Text('CV устарел — обновите резюме',
                          style: TextStyle(fontSize: 12, color: _amber)),
                    ],
                  ),
                ),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1FAE5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded,
                        color: _green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cvFilename ?? 'resume.pdf',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _text1),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Загружен ${_formatDate(cvUploadedAt)}',
                          style: const TextStyle(
                              fontSize: 12, color: _text2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // cvUrl is a relative path like /uploads/xxx.pdf
                        // Build full URL
                        const base = 'https://qadam-backend.onrender.com';
                        final url = Uri.parse('$base$cvUrl');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.visibility_outlined, size: 16),
                      label: const Text('Просмотр'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _blue,
                        side: const BorderSide(color: _border),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: uploading ? null : onUpload,
                      icon: uploading
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Обновить'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _blue,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
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

// ─────────────────────────────────────────────────────────────────────────────
// APPLICATIONS SECTION
// ─────────────────────────────────────────────────────────────────────────────
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
    final active = allApps.where((a) => a['status'] == 'pending').length;
    final accepted = allApps.where((a) => a['status'] == 'accepted').length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Мои заявки',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: _text1)),
          const SizedBox(height: 12),

          // Filter chips
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
            ))
          else if (apps.isEmpty)
            _EmptyApplications()
          else
            ...apps.map((app) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
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

  const _FilterChip(
      {required this.label, required this.active, required this.onTap});

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
          border: Border.all(color: active ? _blue : _border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : _text2,
          ),
        ),
      ),
    );
  }
}

class _EmptyApplications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_rounded, size: 40, color: _text2),
          SizedBox(height: 10),
          Text('Ещё нет откликов',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _text1)),
          SizedBox(height: 4),
          Text(
            'Просматривай стажировки и откликайся\n— они появятся здесь',
            style: TextStyle(fontSize: 13, color: _text2, height: 1.5),
            textAlign: TextAlign.center,
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
    final status = app['status'] as String? ?? 'pending';
    final title = app['internship_title'] as String? ?? '—';
    final company = app['company'] as String? ?? '—';
    final createdAt = app['created_at'] as String?;

    final (statusLabel, statusColor, statusBg, statusIcon) = switch (status) {
      'accepted' => ('Принят!', _green, const Color(0xFFD1FAE5),
          Icons.check_circle_outline_rounded),
      'rejected' => ('Отказано', _red, const Color(0xFFFEE2E2),
          Icons.cancel_outlined),
      'completed' => ('Завершено', _text2, const Color(0xFFF1F5F9),
          Icons.school_outlined),
      _ => ('Рассматривается', _blue, const Color(0xFFEBF0FA),
          Icons.hourglass_empty_rounded),
    };

    String? formattedDate;
    if (createdAt != null) {
      try {
        final dt = DateTime.parse(createdAt);
        final months = [
          '', 'янв', 'фев', 'мар', 'апр', 'май', 'июн',
          'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'
        ];
        formattedDate = '${dt.day} ${months[dt.month]}';
      } catch (_) {}
    }

    return Container(
      decoration: _cardDeco,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Company logo placeholder
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _border),
                      ),
                      child: Center(
                        child: Text(
                          company.isNotEmpty ? company[0].toUpperCase() : '?',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(company,
                              style: const TextStyle(
                                  fontSize: 12, color: _text2)),
                          Text(title,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: _text1),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
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
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 12, color: _text2),
                      const SizedBox(width: 4),
                      Text('Подано $formattedDate',
                          style: const TextStyle(
                              fontSize: 12, color: _text2)),
                      const Spacer(),
                      if (status == 'accepted')
                        GestureDetector(
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
                                Text('Отчёт',
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
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SETTINGS SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final VoidCallback onLogout;
  const _SettingsSection({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: _cardDeco,
        child: Column(
          children: [
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Уведомления',
              onTap: () {},
            ),
            const Divider(height: 1, indent: 54, color: _border),
            _SettingsTile(
              icon: Icons.lock_outline_rounded,
              label: 'Изменить пароль',
              onTap: () {},
            ),
            const Divider(height: 1, indent: 54, color: _border),
            _SettingsTile(
              icon: Icons.info_outline_rounded,
              label: 'О приложении',
              onTap: () {},
            ),
            const Divider(height: 1, color: _border),
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
                    content:
                        const Text('Вы уверены, что хотите выйти из аккаунта?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Выйти',
                            style: TextStyle(color: _red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true) onLogout();
              },
            ),
          ],
        ),
      ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? _text2),
              const SizedBox(width: 14),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: labelColor ?? _text1)),
              ),
              if (iconColor == null)
                const Icon(Icons.chevron_right,
                    size: 18, color: _text2),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EDIT PROFILE SHEET
// ─────────────────────────────────────────────────────────────────────────────
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

  // Tab 0 — Identity
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _bio;
  late final TextEditingController _portfolio;

  // Tab 1 — Education
  late final TextEditingController _university;
  late final TextEditingController _specialty;
  int? _studyYear;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _firstName = TextEditingController(text: widget.user.firstName);
    _lastName = TextEditingController(text: widget.user.lastName);
    _bio = TextEditingController(text: widget.user.bio ?? '');
    _portfolio = TextEditingController(text: widget.user.portfolioUrl ?? '');
    _university = TextEditingController(text: widget.user.universityName ?? '');
    _specialty = TextEditingController(text: widget.user.specialty ?? '');
    _studyYear = widget.user.studyYear;
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [_firstName, _lastName, _bio, _portfolio, _university, _specialty]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await widget.authService.updateProfile(
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        bio: _bio.text.trim(),
        portfolioUrl: _portfolio.text.trim(),
        universityName: _university.text.trim(),
        specialty: _specialty.text.trim(),
        studyYear: _studyYear,
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
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
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
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
              unselectedLabelColor: _text2,
              indicatorColor: _blue,
              indicatorSize: TabBarIndicatorSize.label,
              tabs: const [
                Tab(text: 'Обо мне'),
                Tab(text: 'Образование'),
              ],
            ),
            SizedBox(
              height: 340,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _buildIdentityTab(),
                  _buildEducationTab(),
                ],
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
          _SheetField(
            ctrl: _bio,
            label: 'Bio — расскажи о себе',
            icon: Icons.notes_rounded,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          _SheetField(
            ctrl: _portfolio,
            label: 'Portfolio URL (GitHub, Behance...)',
            icon: Icons.link_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildEducationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          _SheetField(
            ctrl: _university,
            label: 'Университет',
            icon: Icons.school_outlined,
          ),
          const SizedBox(height: 12),
          _SheetField(
            ctrl: _specialty,
            label: 'Специальность',
            icon: Icons.book_outlined,
          ),
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
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _blue, width: 1.5),
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
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _blue, width: 1.5),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SKILLS SHEET
// ─────────────────────────────────────────────────────────────────────────────
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
    final suggestions =
        _suggestions.where((s) => !_skills.contains(s)).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _border,
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
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Сохранить',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Input
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
                          borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border)),
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

            // Current skills
            if (_skills.isNotEmpty) ...[
              const Text('Добавлено:',
                  style: TextStyle(fontSize: 12, color: _text2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _skills
                    .map((s) => _RemovableChip(
                        label: s, onRemove: () => _remove(s)))
                    .toList(),
              ),
              const SizedBox(height: 14),
            ],

            // Suggestions
            if (suggestions.isNotEmpty) ...[
              const Text('Популярные:',
                  style: TextStyle(fontSize: 12, color: _text2)),
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
                              border: Border.all(color: _border),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.add,
                                    size: 12, color: _text2),
                                const SizedBox(width: 4),
                                Text(s,
                                    style: const TextStyle(
                                        fontSize: 12, color: _text2)),
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
      padding:
          const EdgeInsets.only(left: 12, top: 6, bottom: 6, right: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEBF0FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _blue)),
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

// ─────────────────────────────────────────────────────────────────────────────
// REPORT SHEET (existing)
// ─────────────────────────────────────────────────────────────────────────────
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
  final _tasks = TextEditingController();
  int _hours = 0;
  final List<String> _skillsGained = [];
  final _skillCtrl = TextEditingController();
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
        applicationId: widget.app['id'] as int,
        tasksDescription: _tasks.text.trim(),
        hoursCompleted: _hours,
        skillsGained: _skillsGained,
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
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: _border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Отчёт о стажировке',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            // Tasks
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
                    borderSide: const BorderSide(color: _border)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _blue, width: 1.5)),
              ),
            ),
            const SizedBox(height: 16),

            // Hours
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

            // Skills gained
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
                          borderSide: const BorderSide(color: _border)),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _border)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: _blue, width: 1.5)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                    ),
                    onSubmitted: (s) {
                      final skill = s.trim();
                      if (skill.isNotEmpty &&
                          !_skillsGained.contains(skill)) {
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
                        width: 20,
                        height: 20,
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
