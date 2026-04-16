import 'package:flutter/material.dart';
import 'package:internship_app2/services/api_service.dart';

// ── Kanban pipeline stages ─────────────────────────────────────────────────────

const _stages = [
  _Stage('pending',   'Новые',       Color(0xFFF59E0B), Icons.inbox_outlined),
  _Stage('reviewed',  'Рассмотрено', Color(0xFF2164F3), Icons.visibility_outlined),
  _Stage('interview', 'Интервью',    Color(0xFF8B5CF6), Icons.videocam_outlined),
  _Stage('offer',     'Оффер',       Color(0xFF10B981), Icons.local_offer_outlined),
  _Stage('accepted',  'Принято',     Color(0xFF059669), Icons.check_circle_outline),
  _Stage('rejected',  'Отклонено',   Color(0xFFDC2626), Icons.cancel_outlined),
];

class _Stage {
  final String key;
  final String label;
  final Color color;
  final IconData icon;
  const _Stage(this.key, this.label, this.color, this.icon);
}

String? _nextStage(String current) => switch (current) {
  'pending'   => 'reviewed',
  'reviewed'  => 'interview',
  'interview' => 'offer',
  'offer'     => 'accepted',
  _           => null,
};

// ── Screen ────────────────────────────────────────────────────────────────────

class CompanyDashboardScreen extends StatefulWidget {
  final String token;
  final String companyName;
  const CompanyDashboardScreen({
    super.key,
    required this.token,
    required this.companyName,
  });

  @override
  State<CompanyDashboardScreen> createState() => _CompanyDashboardScreenState();
}

class _CompanyDashboardScreenState extends State<CompanyDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  late final TabController _tabs;

  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _internships = [];
  List<Map<String, dynamic>> _applications = [];
  bool _loadingStats = true;
  bool _loadingInternships = true;
  bool _loadingApps = true;

  // Kanban filters
  int? _filterInternshipId;
  final Map<int, Map<String, dynamic>> _aiScores = {};
  final Map<int, bool> _scoringInProgress = {};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    _loadStats();
    _loadInternships();
    _loadApplications();
  }

  Future<void> _loadStats() async {
    try {
      final data = await _api.getCompanyStats(widget.token);
      if (mounted) setState(() { _stats = data; _loadingStats = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _loadInternships() async {
    try {
      final data = await _api.getCompanyInternshipsList(widget.token);
      if (mounted) setState(() { _internships = data; _loadingInternships = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingInternships = false);
    }
  }

  Future<void> _loadApplications() async {
    try {
      final data = await _api.getCompanyApplications(widget.token);
      if (mounted) setState(() { _applications = data; _loadingApps = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingApps = false);
    }
  }

  Future<void> _updateStatus(int appId, String status) async {
    try {
      await _api.updateApplicationStatus(widget.token, appId, status);
      _loadApplications();
      _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _scoreWithAi(int appId) async {
    if (_scoringInProgress[appId] == true) return;
    setState(() => _scoringInProgress[appId] = true);
    try {
      final result = await _api.scoreCandidateWithAi(widget.token, appId);
      if (mounted) setState(() { _aiScores[appId] = result; _scoringInProgress[appId] = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _scoringInProgress[appId] = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _openAddInternship() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddInternshipSheet(
        token: widget.token,
        api: _api,
        onCreated: _loadInternships,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.companyName,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const Text('Кабинет компании',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFF2164F3),
          labelColor: const Color(0xFF2164F3),
          unselectedLabelColor: const Color(0xFF6B7280),
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Статистика'),
            Tab(text: 'Вакансии'),
            Tab(text: 'Пайплайн'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildStats(),
          _buildInternships(),
          _buildKanban(),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabs,
        builder: (_, w) => _tabs.index == 1
            ? FloatingActionButton.extended(
                onPressed: _openAddInternship,
                backgroundColor: const Color(0xFF2164F3),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text('Добавить', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  // ── Stats tab ────────────────────────────────────────────────────────────────

  Widget _buildStats() {
    if (_loadingStats) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    final pipeline = [
      ('Новые',       '${_stats['pending'] ?? 0}',   const Color(0xFFF59E0B)),
      ('Рассмотрено', '${_stats['reviewed'] ?? 0}',  const Color(0xFF2164F3)),
      ('Интервью',    '${_stats['interview'] ?? 0}', const Color(0xFF8B5CF6)),
      ('Оффер',       '${_stats['offer'] ?? 0}',     const Color(0xFF10B981)),
      ('Принято',     '${_stats['accepted'] ?? 0}',  const Color(0xFF059669)),
      ('Отклонено',   '${_stats['rejected'] ?? 0}',  const Color(0xFFDC2626)),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Top KPI row
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _StatCard(label: 'Вакансии', value: '${_stats['total_internships'] ?? 0}',
                icon: Icons.work_outline, color: const Color(0xFF2164F3)),
            _StatCard(label: 'Всего заявок', value: '${_stats['total_applications'] ?? 0}',
                icon: Icons.inbox_outlined, color: const Color(0xFF8B5CF6)),
          ],
        ),
        const SizedBox(height: 16),
        // Pipeline breakdown card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Пайплайн заявок',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 14),
              ...pipeline.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(p.$1,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF374151))),
                    ),
                    Text(p.$2,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: p.$3)),
                  ],
                ),
              )),
            ],
          ),
        ),
      ],
    );
  }

  // ── Internships tab ──────────────────────────────────────────────────────────

  Widget _buildInternships() {
    if (_loadingInternships) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }
    if (_internships.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.work_off_outlined, size: 56, color: Color(0xFFD1D5DB)),
            SizedBox(height: 12),
            Text('Нет вакансий', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
            Text('Нажмите + чтобы добавить', style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _internships.length,
      separatorBuilder: (_, w) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _InternshipTile(data: _internships[i]),
    );
  }

  // ── Kanban tab ───────────────────────────────────────────────────────────────

  Widget _buildKanban() {
    if (_loadingApps) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF2164F3)));
    }

    // Filter bar
    final internshipOptions = <Map<String, dynamic>>[
      {'id': null, 'title': 'Все вакансии'},
      ..._internships,
    ];

    // Filtered apps
    final apps = _filterInternshipId == null
        ? _applications
        : _applications.where((a) => a['internship_id'] == _filterInternshipId).toList();

    return Column(
      children: [
        // Filter bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int?>(
                    value: _filterInternshipId,
                    isDense: true,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF111827), fontWeight: FontWeight.w600),
                    items: internshipOptions.map((opt) => DropdownMenuItem<int?>(
                      value: opt['id'] as int?,
                      child: Text(opt['title'] as String, overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setState(() => _filterInternshipId = v),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${apps.length} заявок',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF2164F3)),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Kanban board
        Expanded(
          child: apps.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.inbox_outlined, size: 56, color: Color(0xFFD1D5DB)),
                      SizedBox(height: 12),
                      Text('Нет заявок', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ],
                  ),
                )
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.all(12),
                  itemCount: _stages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final stage = _stages[i];
                    final stageApps = apps.where((a) => a['status'] == stage.key).toList();
                    return _KanbanColumn(
                      stage: stage,
                      apps: stageApps,
                      aiScores: _aiScores,
                      scoringInProgress: _scoringInProgress,
                      onMoveForward: (app) {
                        final next = _nextStage(stage.key);
                        if (next != null) _updateStatus(app['id'], next);
                      },
                      onReject: (app) => _updateStatus(app['id'], 'rejected'),
                      onScoreWithAi: (app) => _scoreWithAi(app['id']),
                      onShowDetail: (app) => _showCandidateDetail(context, app),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showCandidateDetail(BuildContext context, Map<String, dynamic> app) {
    final aiScore = _aiScores[app['id'] as int];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CandidateDetailSheet(
        app: app,
        aiScore: aiScore,
        token: widget.token,
        api: _api,
        onStatusChange: _updateStatus,
        onScore: () => _scoreWithAi(app['id'] as int),
        isScoring: _scoringInProgress[app['id'] as int] == true,
      ),
    );
  }
}

// ── Kanban Column ─────────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final _Stage stage;
  final List<Map<String, dynamic>> apps;
  final Map<int, Map<String, dynamic>> aiScores;
  final Map<int, bool> scoringInProgress;
  final void Function(Map<String, dynamic>) onMoveForward;
  final void Function(Map<String, dynamic>) onReject;
  final void Function(Map<String, dynamic>) onScoreWithAi;
  final void Function(Map<String, dynamic>) onShowDetail;

  const _KanbanColumn({
    required this.stage,
    required this.apps,
    required this.aiScores,
    required this.scoringInProgress,
    required this.onMoveForward,
    required this.onReject,
    required this.onScoreWithAi,
    required this.onShowDetail,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 268,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: stage.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: stage.color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(stage.icon, size: 16, color: stage.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stage.label,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: stage.color),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: stage.color,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${apps.length}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Cards
          Expanded(
            child: apps.isEmpty
                ? Center(
                    child: Text(
                      'Пусто',
                      style: TextStyle(fontSize: 13, color: stage.color.withValues(alpha: 0.5)),
                    ),
                  )
                : ListView.separated(
                    itemCount: apps.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final app = apps[i];
                      final id = app['id'] as int;
                      return _KanbanCard(
                        app: app,
                        stage: stage,
                        aiScore: aiScores[id],
                        isScoring: scoringInProgress[id] == true,
                        onMoveForward: () => onMoveForward(app),
                        onReject: () => onReject(app),
                        onScoreWithAi: () => onScoreWithAi(app),
                        onTap: () => onShowDetail(app),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Kanban Card ───────────────────────────────────────────────────────────────

class _KanbanCard extends StatelessWidget {
  final Map<String, dynamic> app;
  final _Stage stage;
  final Map<String, dynamic>? aiScore;
  final bool isScoring;
  final VoidCallback onMoveForward;
  final VoidCallback onReject;
  final VoidCallback onScoreWithAi;
  final VoidCallback onTap;

  const _KanbanCard({
    required this.app,
    required this.stage,
    required this.aiScore,
    required this.isScoring,
    required this.onMoveForward,
    required this.onReject,
    required this.onScoreWithAi,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = app['student_name'] as String? ?? 'Студент';
    final internshipTitle = app['internship_title'] as String? ?? '';
    final university = app['student_university'] as String? ?? '';
    final specialty = app['student_specialty'] as String? ?? '';
    final skills = (app['student_skills'] as List?)?.cast<String>() ?? [];
    final message = app['message'] as String? ?? '';
    final nextStage = _nextStage(stage.key);
    final isTerminal = stage.key == 'accepted' || stage.key == 'rejected';

    final scoreVal = aiScore?['score'] as int?;
    final scoreColor = scoreVal == null
        ? const Color(0xFF9CA3AF)
        : scoreVal >= 75
            ? const Color(0xFF10B981)
            : scoreVal >= 50
                ? const Color(0xFFF59E0B)
                : const Color(0xFFDC2626);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
          border: Border(left: BorderSide(color: stage.color, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Name row + AI score
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: stage.color.withValues(alpha: 0.12),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: stage.color),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // AI score badge
                if (scoreVal != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scoreColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$scoreVal%',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: scoreColor),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            // Internship title
            Text(
              internshipTitle,
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            // University + specialty
            if (university.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.school_outlined, size: 11, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      specialty.isNotEmpty ? '$university · $specialty' : university,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // Skills chips
            if (skills.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 4,
                runSpacing: 3,
                children: skills.take(3).map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 10, color: Color(0xFF374151))),
                )).toList(),
              ),
            ],
            // Cover letter preview
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            // AI score summary
            if (aiScore != null && aiScore!['summary'] != null) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  aiScore!['summary'] as String,
                  style: TextStyle(fontSize: 11, color: scoreColor, fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: 8),
            // Action buttons
            if (!isTerminal) ...[
              Row(
                children: [
                  // AI score button
                  if (aiScore == null)
                    Expanded(
                      child: GestureDetector(
                        onTap: onScoreWithAi,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: isScoring
                              ? const Center(
                                  child: SizedBox(
                                    width: 12, height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF2164F3)),
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.auto_awesome_outlined, size: 12, color: Color(0xFF2164F3)),
                                    SizedBox(width: 4),
                                    Text('AI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2164F3))),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  if (aiScore == null) const SizedBox(width: 5),
                  // Reject button
                  Expanded(
                    child: GestureDetector(
                      onTap: onReject,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.close_rounded, size: 12, color: Color(0xFFDC2626)),
                            SizedBox(width: 4),
                            Text('Откл.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFDC2626))),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  // Move forward button
                  if (nextStage != null)
                    Expanded(
                      child: GestureDetector(
                        onTap: onMoveForward,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: stage.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_forward_rounded, size: 12, color: stage.color),
                              const SizedBox(width: 4),
                              Text(
                                _stages.firstWhere((s) => s.key == nextStage).label.split(' ').first,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: stage.color),
                              ),
                            ],
                          ),
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

// ── Candidate detail bottom sheet ─────────────────────────────────────────────

class _CandidateDetailSheet extends StatelessWidget {
  final Map<String, dynamic> app;
  final Map<String, dynamic>? aiScore;
  final String token;
  final ApiService api;
  final Future<void> Function(int, String) onStatusChange;
  final VoidCallback onScore;
  final bool isScoring;

  const _CandidateDetailSheet({
    required this.app,
    required this.aiScore,
    required this.token,
    required this.api,
    required this.onStatusChange,
    required this.onScore,
    required this.isScoring,
  });

  @override
  Widget build(BuildContext context) {
    final name = app['student_name'] as String? ?? 'Студент';
    final email = app['student_email'] as String? ?? '';
    final university = app['student_university'] as String? ?? '';
    final specialty = app['student_specialty'] as String? ?? '';
    final skills = (app['student_skills'] as List?)?.cast<String>() ?? [];
    final message = app['message'] as String? ?? '';
    final currentStage = _stages.firstWhere((s) => s.key == (app['status'] as String? ?? 'pending'));
    final nextStageKey = _nextStage(currentStage.key);
    final isTerminal = currentStage.key == 'accepted' || currentStage.key == 'rejected';

    final scoreVal = aiScore?['score'] as int?;
    final strengths = (aiScore?['strengths'] as List?)?.cast<String>() ?? [];
    final gaps = (aiScore?['gaps'] as List?)?.cast<String>() ?? [];
    final scoreColor = scoreVal == null
        ? const Color(0xFF9CA3AF)
        : scoreVal >= 75
            ? const Color(0xFF10B981)
            : scoreVal >= 50
                ? const Color(0xFFF59E0B)
                : const Color(0xFFDC2626);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: currentStage.color.withValues(alpha: 0.12),
                  child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: currentStage.color)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                      if (email.isNotEmpty)
                        Text(email, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: currentStage.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: currentStage.color.withValues(alpha: 0.3)),
                  ),
                  child: Text(currentStage.label,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: currentStage.color)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            // Education
            if (university.isNotEmpty) ...[
              _detailRow(Icons.school_outlined, 'Университет', university),
              if (specialty.isNotEmpty) _detailRow(Icons.book_outlined, 'Специальность', specialty),
              const SizedBox(height: 8),
            ],
            // Skills
            if (skills.isNotEmpty) ...[
              const Text('Навыки', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: skills.map((s) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF2164F3), fontWeight: FontWeight.w600)),
                )).toList(),
              ),
              const SizedBox(height: 12),
            ],
            // Cover letter
            if (message.isNotEmpty) ...[
              const Text('Сопроводительное письмо',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.5)),
              ),
              const SizedBox(height: 12),
            ],
            // AI score section
            if (aiScore != null) ...[
              const Text('AI Оценка', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scoreColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scoreColor.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('$scoreVal%',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: scoreColor)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            aiScore!['summary'] as String? ?? '',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
                          ),
                        ),
                      ],
                    ),
                    if (strengths.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      const Text('Сильные стороны:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      ...strengths.map((s) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          const Icon(Icons.check_circle_outline, size: 13, color: Color(0xFF059669)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(s, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                        ]),
                      )),
                    ],
                    if (gaps.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text('Пробелы:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                      ...gaps.map((g) => Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Row(children: [
                          const Icon(Icons.info_outline, size: 13, color: Color(0xFFDC2626)),
                          const SizedBox(width: 6),
                          Expanded(child: Text(g, style: const TextStyle(fontSize: 12, color: Color(0xFF374151)))),
                        ]),
                      )),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ] else ...[
              FilledButton.icon(
                onPressed: isScoring ? null : onScore,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2164F3),
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: isScoring
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome_outlined, size: 16),
                label: Text(isScoring ? 'Оценка...' : 'Оценить с AI',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
            ],
            // Action buttons
            if (!isTerminal) ...[
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onStatusChange(app['id'] as int, 'rejected');
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFFECACA)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 16),
                      label: const Text('Отклонить', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  if (nextStageKey != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          onStatusChange(app['id'] as int, nextStageKey);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: currentStage.color,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                        label: Text(
                          _stages.firstWhere((s) => s.key == nextStageKey).label,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color)),
              Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Internship tile ───────────────────────────────────────────────────────────

class _InternshipTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _InternshipTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFEBF0FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.work_outline, color: Color(0xFF2164F3), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['title'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
                Text(data['category'] ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                data['is_paid'] == true ? 'Оплачиваемая' : 'Волонтёрская',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: data['is_paid'] == true ? const Color(0xFF10B981) : const Color(0xFF6B7280),
                ),
              ),
              Text(data['format'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Add internship bottom sheet ───────────────────────────────────────────────

class _AddInternshipSheet extends StatefulWidget {
  final String token;
  final ApiService api;
  final VoidCallback onCreated;
  const _AddInternshipSheet({required this.token, required this.api, required this.onCreated});

  @override
  State<_AddInternshipSheet> createState() => _AddInternshipSheetState();
}

class _AddInternshipSheetState extends State<_AddInternshipSheet> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _city = TextEditingController();
  String _category = 'IT';
  String _format = 'Офис';
  bool _isPaid = false;
  bool _saving = false;
  String? _error;

  static const _categories = ['IT', 'Финансы', 'Дизайн', 'Маркетинг', 'HR', 'Другое'];
  static const _formats = ['Офис', 'Удалённо', 'Гибрид'];

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Введите название вакансии');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await widget.api.createCompanyInternship(widget.token, {
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'city': _city.text.trim(),
        'category': _category,
        'format': _format,
        'is_paid': _isPaid,
      });
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() { _error = e.toString().replaceAll('Exception: ', ''); _saving = false; });
    }
  }

  @override
  void dispose() { _title.dispose(); _description.dispose(); _city.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Новая вакансия', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _field(_title, 'Название', Icons.work_outline),
            const SizedBox(height: 10),
            _field(_description, 'Описание', Icons.description_outlined, maxLines: 3),
            const SizedBox(height: 10),
            _field(_city, 'Город', Icons.location_on_outlined),
            const SizedBox(height: 12),
            const Text('Категория', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _categories.map((c) => ChoiceChip(
                label: Text(c),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
                selectedColor: const Color(0xFFEBF0FA),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _category == c ? const Color(0xFF2164F3) : const Color(0xFF374151),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            const Text('Формат', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: _formats.map((f) => ChoiceChip(
                label: Text(f),
                selected: _format == f,
                onSelected: (_) => setState(() => _format = f),
                selectedColor: const Color(0xFFEBF0FA),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _format == f ? const Color(0xFF2164F3) : const Color(0xFF374151),
                ),
              )).toList(),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Оплачиваемая стажировка', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: _isPaid,
              onChanged: (v) => setState(() => _isPaid = v),
              activeThumbColor: const Color(0xFF2164F3),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2164F3),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Создать вакансию', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF9CA3AF)),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF2164F3), width: 1.5)),
      ),
    );
  }
}
