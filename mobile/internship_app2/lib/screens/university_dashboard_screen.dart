import 'package:flutter/material.dart';
import 'package:internship_app2/services/university_service.dart';

class UniversityDashboardScreen extends StatefulWidget {
  final UniversityInfo info;
  const UniversityDashboardScreen({super.key, required this.info});

  @override
  State<UniversityDashboardScreen> createState() =>
      _UniversityDashboardScreenState();
}

class _UniversityDashboardScreenState
    extends State<UniversityDashboardScreen> with SingleTickerProviderStateMixin {
  final _service = UniversityService();

  late TabController _tabs;
  List<StudentRecord>? _students;
  UniversityAnalytics? _analytics;
  bool _loadingStudents = true;
  bool _loadingAnalytics = true;
  String? _studentsError;
  String? _analyticsError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadStudents();
    _loadAnalytics();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _loadingStudents = true;
      _studentsError = null;
    });
    try {
      final s = await _service.getStudents();
      if (mounted) setState(() => _students = s);
    } catch (e) {
      if (mounted) setState(() => _studentsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _loadingAnalytics = true;
      _analyticsError = null;
    });
    try {
      final a = await _service.getAnalytics();
      if (mounted) setState(() => _analytics = a);
    } catch (e) {
      if (mounted) setState(() => _analyticsError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingAnalytics = false);
    }
  }

  Future<void> _showLinkDialog() async {
    final emailCtrl = TextEditingController();
    final specialtyCtrl = TextEditingController();
    final idCtrl = TextEditingController();
    int? year;
    String? err;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Добавить студента',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dialogField(emailCtrl, 'Email студента *',
                    Icons.email_rounded, TextInputType.emailAddress),
                const SizedBox(height: 12),
                _dialogField(specialtyCtrl, 'Специальность',
                    Icons.school_rounded, TextInputType.text),
                const SizedBox(height: 12),
                _dialogField(idCtrl, 'Номер студенческого билета',
                    Icons.badge_rounded, TextInputType.text),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: year,
                  decoration: _inputDeco('Курс', Icons.calendar_today_rounded),
                  items: [1, 2, 3, 4]
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y курс')))
                      .toList(),
                  onChanged: (v) => year = v,
                ),
                if (err != null) ...[
                  const SizedBox(height: 12),
                  Text(err!,
                      style: const TextStyle(color: Colors.red, fontSize: 13)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  foregroundColor: Colors.white),
              onPressed: () async {
                if (emailCtrl.text.trim().isEmpty) {
                  setLocal(() => err = 'Введите email студента');
                  return;
                }
                try {
                  await _service.linkStudent(
                    studentEmail: emailCtrl.text.trim(),
                    specialty: specialtyCtrl.text.trim(),
                    studyYear: year,
                    studentIdNumber: idCtrl.text.trim(),
                  );
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _loadStudents();
                  _loadAnalytics();
                } catch (e) {
                  setLocal(() =>
                      err = e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: const Text('Добавить'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmUnlink(StudentRecord s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить студента?'),
        content: Text('${s.name} будет удалён из списка вашего университета.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.unlinkStudent(s.userId);
      _loadStudents();
      _loadAnalytics();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F2EF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.info.name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800)),
            if (widget.info.city.isNotEmpty)
              Text(widget.info.city,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF767676))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Выйти',
            onPressed: () {
              final nav = Navigator.of(context);
              _service.logout().then((_) {
                if (mounted) nav.pop();
              });
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF2164F3),
          unselectedLabelColor: const Color(0xFF595959),
          indicatorColor: const Color(0xFF2164F3),
          tabs: const [
            Tab(icon: Icon(Icons.people_rounded), text: 'Студенты'),
            Tab(icon: Icon(Icons.bar_chart_rounded), text: 'Аналитика'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLinkDialog,
        backgroundColor: const Color(0xFF2164F3),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Добавить студента',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _StudentsTab(
            loading: _loadingStudents,
            error: _studentsError,
            students: _students ?? [],
            onRefresh: _loadStudents,
            onUnlink: _confirmUnlink,
          ),
          _AnalyticsTab(
            loading: _loadingAnalytics,
            error: _analyticsError,
            analytics: _analytics,
            onRefresh: _loadAnalytics,
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      TextInputType type) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: _inputDeco(label, icon),
    );
  }

  InputDecoration _inputDeco(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF767676)),
        filled: true,
        fillColor: const Color(0xFFF8F8F8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

// ── Students tab ───────────────────────────────────────────────────────────────

class _StudentsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final List<StudentRecord> students;
  final VoidCallback onRefresh;
  final Future<void> Function(StudentRecord) onUnlink;

  const _StudentsTab({
    required this.loading,
    required this.error,
    required this.students,
    required this.onRefresh,
    required this.onUnlink,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRefresh, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.school_outlined, size: 64, color: Color(0xFFBDBDBD)),
            const SizedBox(height: 16),
            const Text('Студентов пока нет',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF595959))),
            const SizedBox(height: 8),
            const Text('Нажмите «Добавить студента» чтобы начать',
                style: TextStyle(color: Color(0xFF767676))),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: students.length,
        itemBuilder: (_, i) => _StudentCard(
          student: students[i],
          onUnlink: () => onUnlink(students[i]),
        ),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final StudentRecord student;
  final VoidCallback onUnlink;

  const _StudentCard({required this.student, required this.onUnlink});

  Color _statusColor(String status) => switch (status) {
        'accepted' => const Color(0xFF16A34A),
        'rejected' => const Color(0xFFDC2626),
        _ => const Color(0xFFD97706),
      };

  String _statusLabel(String status) => switch (status) {
        'accepted' => 'Принят',
        'rejected' => 'Отклонён',
        _ => 'На рассмотрении',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E2E0)),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFEBF0FA),
          child: Text(
            student.name.isNotEmpty ? student.name[0].toUpperCase() : '?',
            style: const TextStyle(
                color: Color(0xFF2164F3), fontWeight: FontWeight.w800),
          ),
        ),
        title: Text(student.name,
            style: const TextStyle(
                fontWeight: FontWeight.w700, fontSize: 15)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(student.email,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF767676))),
            if (student.specialty.isNotEmpty)
              Text(student.specialty,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF595959))),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Stats badges
            _badge('${student.accepted}', const Color(0xFF16A34A),
                const Color(0xFFDCFCE7)),
            const SizedBox(width: 4),
            _badge('${student.totalApps}', const Color(0xFF2164F3),
                const Color(0xFFEBF0FA)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  size: 20, color: Color(0xFFDC2626)),
              onPressed: onUnlink,
              tooltip: 'Удалить',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        children: [
          if (student.applications.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Заявок пока нет',
                  style: TextStyle(color: Color(0xFF767676))),
            )
          else
            ...student.applications.map((a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(a.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.internshipTitle,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(a.company,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF767676))),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _statusColor(a.status).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusLabel(a.status),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(a.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }

  Widget _badge(String text, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
      );
}

// ── Analytics tab ──────────────────────────────────────────────────────────────

class _AnalyticsTab extends StatelessWidget {
  final bool loading;
  final String? error;
  final UniversityAnalytics? analytics;
  final VoidCallback onRefresh;

  const _AnalyticsTab({
    required this.loading,
    required this.error,
    required this.analytics,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
                onPressed: onRefresh, child: const Text('Повторить')),
          ],
        ),
      );
    }
    if (analytics == null) return const SizedBox.shrink();

    final a = analytics!;
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Top KPI cards
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              _kpi('Студентов', '${a.totalStudents}',
                  Icons.people_rounded, const Color(0xFF2164F3)),
              _kpi('Заявок', '${a.totalApplications}',
                  Icons.send_rounded, const Color(0xFF7C3AED)),
              _kpi('Принято', '${a.accepted}',
                  Icons.check_circle_rounded, const Color(0xFF16A34A)),
              _kpi('Конверсия', '${a.acceptanceRate}%',
                  Icons.trending_up_rounded, const Color(0xFFD97706)),
            ],
          ),
          const SizedBox(height: 20),

          // Status breakdown
          _sectionTitle('По статусу заявок'),
          const SizedBox(height: 10),
          _StatusBar(
            accepted: a.accepted,
            rejected: a.rejected,
            pending: a.pending,
            total: a.totalApplications,
          ),
          const SizedBox(height: 20),

          // Top companies
          if (a.topCompanies.isNotEmpty) ...[
            _sectionTitle('Топ компании'),
            const SizedBox(height: 10),
            ...a.topCompanies.asMap().entries.map((e) {
              final rank = e.key + 1;
              final item = e.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE4E2E0)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: rank == 1
                            ? const Color(0xFFFEF3C7)
                            : const Color(0xFFF3F2EF),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text('$rank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: rank == 1
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF595959),
                            )),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item['company'],
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      '${item['count']} заявок',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF767676)),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
          ],

          // By category
          if (a.byCategory.isNotEmpty) ...[
            _sectionTitle('По категориям'),
            const SizedBox(height: 10),
            ...a.byCategory.map((item) {
              final count = item['count'] as int;
              final maxCount = a.byCategory
                  .map((x) => x['count'] as int)
                  .reduce((a, b) => a > b ? a : b);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(item['category'],
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600)),
                        Text('$count',
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF767676))),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: maxCount > 0 ? count / maxCount : 0,
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE4E2E0),
                        valueColor: const AlwaysStoppedAnimation(
                            Color(0xFF2164F3)),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E2E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22, color: color),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF767676))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A)),
      );
}

class _StatusBar extends StatelessWidget {
  final int accepted, rejected, pending, total;
  const _StatusBar(
      {required this.accepted,
      required this.rejected,
      required this.pending,
      required this.total});

  @override
  Widget build(BuildContext context) {
    if (total == 0) {
      return const Center(
          child: Text('Нет данных',
              style: TextStyle(color: Color(0xFF767676))));
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE4E2E0)),
      ),
      child: Column(
        children: [
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  if (accepted > 0)
                    Flexible(
                      flex: accepted,
                      child: Container(color: const Color(0xFF16A34A)),
                    ),
                  if (rejected > 0)
                    Flexible(
                      flex: rejected,
                      child: Container(color: const Color(0xFFDC2626)),
                    ),
                  if (pending > 0)
                    Flexible(
                      flex: pending,
                      child: Container(color: const Color(0xFFD97706)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legend('Принято', accepted, const Color(0xFF16A34A)),
              _legend('Отклонено', rejected, const Color(0xFFDC2626)),
              _legend('В ожидании', pending, const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legend(String label, int count, Color color) => Column(
        children: [
          Container(
              width: 12,
              height: 12,
              decoration:
                  BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 4),
          Text('$count',
              style: TextStyle(
                  fontWeight: FontWeight.w800, color: color, fontSize: 16)),
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: Color(0xFF767676))),
        ],
      );
}
