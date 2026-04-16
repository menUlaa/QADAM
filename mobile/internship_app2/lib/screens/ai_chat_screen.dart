import 'package:flutter/material.dart';
import 'package:internship_app2/services/api_service.dart';

/// How the AI chat was opened — determines initial prompt and quick actions.
enum AiChatMode {
  general,       // normal chat tab
  coverLetter,   // opened from internship details
  interviewPrep, // opened from internship details
  skillGap,      // opened from internship details
}

class AiChatScreen extends StatefulWidget {
  final AiChatMode mode;
  final int? internshipId;
  final String? internshipTitle;
  final String? companyName;

  const AiChatScreen({
    super.key,
    this.mode = AiChatMode.general,
    this.internshipId,
    this.internshipTitle,
    this.companyName,
  });

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _api = ApiService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _loading = false;
  bool _loadingHistory = true;
  int? _conversationId;

  static const _generalSuggestions = [
    'Как составить хорошее резюме?',
    'Как подготовиться к собеседованию?',
    'Какие навыки нужны для IT стажировки?',
    'Как написать сопроводительное письмо?',
  ];

  static const _welcomeMsg = _Msg(
    role: 'assistant',
    text: 'Привет! Я AI-ассистент Qadam 👋\n\nЯ помогу тебе:\n• Составить резюме и сопроводительное письмо\n• Подготовиться к собеседованию\n• Выбрать направление карьеры\n• Узнать какие навыки развивать\n\nЧем могу помочь?',
  );

  List<String> get _suggestions {
    if (widget.mode != AiChatMode.general &&
        widget.internshipTitle != null) {
      return [
        'Напиши сопроводительное письмо',
        'Подготовь меня к собеседованию',
        'Анализ пробелов в навыках',
        'Что изучить перед стажировкой?',
      ];
    }
    return _generalSuggestions;
  }

  String get _contextTitle {
    switch (widget.mode) {
      case AiChatMode.coverLetter:
        return 'Сопроводительное письмо';
      case AiChatMode.interviewPrep:
        return 'Подготовка к собеседованию';
      case AiChatMode.skillGap:
        return 'Анализ навыков';
      case AiChatMode.general:
        return 'AI Ассистент';
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.mode != AiChatMode.general && widget.internshipId != null) {
      _loadContextualResponse();
    } else {
      _loadHistory();
    }
  }

  /// For context modes (cover letter, interview prep, skill gap) — call
  /// the dedicated endpoint immediately instead of loading chat history.
  Future<void> _loadContextualResponse() async {
    final id = widget.internshipId!;
    final title = widget.internshipTitle ?? 'стажировка';
    final company = widget.companyName ?? '';

    final contextLabel = switch (widget.mode) {
      AiChatMode.coverLetter => 'Составляю сопроводительное письмо для "$title" в $company...',
      AiChatMode.interviewPrep => 'Готовлю план подготовки к собеседованию в $company...',
      AiChatMode.skillGap => 'Анализирую соответствие твоего профиля вакансии "$title"...',
      AiChatMode.general => '',
    };

    setState(() {
      _messages.add(_Msg(role: 'user', text: contextLabel));
      _loading = true;
      _loadingHistory = false;
    });

    try {
      Map<String, dynamic> result;
      switch (widget.mode) {
        case AiChatMode.coverLetter:
          result = await _api.generateCoverLetter(id);
          final letter = result['cover_letter'] as String;
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: letter));
            _loading = false;
          });
        case AiChatMode.interviewPrep:
          result = await _api.generateInterviewPrep(id);
          final guide = result['prep_guide'] as String;
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: guide));
            _loading = false;
          });
        case AiChatMode.skillGap:
          result = await _api.analyzeSkillGap(id);
          final analysis = result['analysis'] as String;
          setState(() {
            _messages.add(_Msg(role: 'assistant', text: analysis));
            _loading = false;
          });
        case AiChatMode.general:
          break;
      }
    } catch (e) {
      setState(() {
        _messages.add(_Msg(
          role: 'assistant',
          text: 'Не удалось загрузить ответ. ${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        ));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  Future<void> _loadHistory() async {
    try {
      final convs = await _api.getAiConversations();
      if (convs.isNotEmpty) {
        final latest = convs.first;
        final detail = await _api.getAiConversation(latest['id'] as int);
        final msgs = (detail['messages'] as List)
            .map((m) => _Msg(role: m['role'] as String, text: m['content'] as String))
            .toList();
        if (mounted) {
          setState(() {
            _conversationId = latest['id'] as int;
            _messages.addAll(msgs);
            _loadingHistory = false;
          });
          _scrollToBottom();
        }
        return;
      }
    } catch (_) {
      // Not authenticated or error — start fresh
    }
    if (mounted) {
      setState(() {
        _messages.add(_welcomeMsg);
        _loadingHistory = false;
      });
    }
  }

  void _startNewChat() {
    setState(() {
      _conversationId = null;
      _messages.clear();
      _messages.add(_welcomeMsg);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _input.text).trim();
    if (content.isEmpty || _loading) return;
    _input.clear();

    setState(() {
      _messages.add(_Msg(role: 'user', text: content));
      _loading = true;
    });
    _scrollToBottom();

    try {
      final history = _messages
          .where((m) => !m.isError)
          .map((m) => {'role': m.role, 'content': m.text})
          .toList();
      final result = await _api.aiChat(history, conversationId: _conversationId);
      final reply = result['reply'] as String;
      final convId = result['conversation_id'];
      setState(() {
        if (convId != null) _conversationId = convId as int;
        _messages.add(_Msg(role: 'assistant', text: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_Msg(
          role: 'assistant',
          text: 'Извините, произошла ошибка. Попробуйте ещё раз.\n\n${e.toString().replaceAll('Exception: ', '')}',
          isError: true,
        ));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showHistory() async {
    List<Map<String, dynamic>> convs = [];
    try {
      convs = await _api.getAiConversations();
    } catch (_) {}

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _HistorySheet(
        conversations: convs,
        currentId: _conversationId,
        onSelect: (id) async {
          Navigator.pop(context);
          setState(() {
            _messages.clear();
            _loadingHistory = true;
          });
          try {
            final detail = await _api.getAiConversation(id);
            final msgs = (detail['messages'] as List)
                .map((m) => _Msg(role: m['role'] as String, text: m['content'] as String))
                .toList();
            setState(() {
              _conversationId = id;
              _messages.addAll(msgs);
              _loadingHistory = false;
            });
            _scrollToBottom();
          } catch (_) {
            setState(() => _loadingHistory = false);
          }
        },
        onDelete: (id) async {
          await _api.deleteAiConversation(id);
          if (id == _conversationId) _startNewChat();
        },
        onNew: () {
          Navigator.pop(context);
          _startNewChat();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width > 720;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2164F3), Color(0xFF6D28D9)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_contextTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                const Text('Qadam AI', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'История чатов',
            onPressed: _showHistory,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Новый чат',
            onPressed: _startNewChat,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isDesktop ? 700 : double.infinity),
          child: _loadingHistory
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // Messages list
                    Expanded(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _messages.length + (_loading ? 1 : 0),
                        itemBuilder: (context, i) {
                          if (i == _messages.length) return const _TypingIndicator();
                          return _MessageBubble(msg: _messages[i]);
                        },
                      ),
                    ),

                    // Suggestions (only when few messages)
                    if (_messages.length <= 2 && !_loading)
                      SizedBox(
                        height: 44,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: _suggestions
                              .map((s) => Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: GestureDetector(
                                      onTap: () => _send(s),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(color: const Color(0xFFE5E7EB)),
                                        ),
                                        child: Text(
                                          s,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF374151),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                      ),

                    // Input bar
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16, 10, 16,
                        10 + MediaQuery.paddingOf(context).bottom,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              maxLines: 4,
                              minLines: 1,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                              decoration: InputDecoration(
                                hintText: 'Задай вопрос...',
                                hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                                filled: true,
                                fillColor: const Color(0xFFF9FAFB),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(22),
                                  borderSide: const BorderSide(
                                      color: Color(0xFF2164F3), width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: _loading ? null : _send,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: _loading
                                    ? null
                                    : const LinearGradient(
                                        colors: [Color(0xFF2164F3), Color(0xFF6D28D9)],
                                      ),
                                color: _loading ? const Color(0xFFE5E7EB) : null,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: _loading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Color(0xFF9CA3AF),
                                        ),
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded,
                                      color: Colors.white, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ── History bottom sheet ─────────────────────────────────────────────────────

class _HistorySheet extends StatefulWidget {
  final List<Map<String, dynamic>> conversations;
  final int? currentId;
  final void Function(int id) onSelect;
  final void Function(int id) onDelete;
  final VoidCallback onNew;

  const _HistorySheet({
    required this.conversations,
    required this.currentId,
    required this.onSelect,
    required this.onDelete,
    required this.onNew,
  });

  @override
  State<_HistorySheet> createState() => _HistorySheetState();
}

class _HistorySheetState extends State<_HistorySheet> {
  late List<Map<String, dynamic>> _convs;

  @override
  void initState() {
    super.initState();
    _convs = List.from(widget.conversations);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('История чатов',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton.icon(
                  onPressed: widget.onNew,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Новый чат'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (_convs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('Нет сохранённых чатов',
                  style: TextStyle(color: Color(0xFF9CA3AF))),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _convs.length,
                separatorBuilder: (context, index) => const Divider(height: 1, indent: 16),
                itemBuilder: (_, i) {
                  final c = _convs[i];
                  final id = c['id'] as int;
                  final isActive = id == widget.currentId;
                  return ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: isActive
                            ? const LinearGradient(
                                colors: [Color(0xFF2164F3), Color(0xFF6D28D9)])
                            : null,
                        color: isActive ? null : const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: isActive ? Colors.white : const Color(0xFF6B7280)),
                    ),
                    title: Text(
                      c['title'] as String? ?? 'Чат',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    subtitle: c['last_message'] != null
                        ? Text(
                            c['last_message'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                          )
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFF9CA3AF)),
                      onPressed: () {
                        setState(() => _convs.removeAt(i));
                        widget.onDelete(id);
                      },
                    ),
                    onTap: () => widget.onSelect(id),
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.paddingOf(context).bottom + 8),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _Msg {
  final String role;
  final String text;
  final bool isError;

  const _Msg({
    required this.role,
    required this.text,
    this.isError = false,
  });
}

class _MessageBubble extends StatelessWidget {
  final _Msg msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: msg.isError
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF2164F3), Color(0xFF6D28D9)]),
                color: msg.isError ? const Color(0xFFFEE2E2) : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                msg.isError ? Icons.error_outline : Icons.auto_awesome,
                color: msg.isError ? const Color(0xFFDC2626) : Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF2164F3)
                    : msg.isError
                        ? const Color(0xFFFEF2F2)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                msg.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isUser
                      ? Colors.white
                      : msg.isError
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF111827),
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF2164F3), Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, w) {
                    final offset = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
                    final bounce = (offset < 0.5 ? offset : 1.0 - offset) * 2;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 7,
                      height: 7 + bounce * 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2164F3).withValues(
                            alpha: 0.4 + bounce * 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
