import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const InternshipApp());

class InternshipApp extends StatelessWidget {
  const InternshipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Internships KZ',
      theme: ThemeData(useMaterial3: true),
      home: const InternshipFeedPage(),
    );
  }
}

class Api {
  static const base = 'http://10.0.2.2:8000';

  static Future<List<dynamic>> listInternships() async {
    final res = await http.get(Uri.parse('$base/internships/'));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as List<dynamic>;
  }

  static Future<Map<String, dynamic>> getInternship(int id) async {
    final res = await http.get(Uri.parse('$base/internships/$id'));
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}

class InternshipFeedPage extends StatefulWidget {
  const InternshipFeedPage({super.key});

  @override
  State<InternshipFeedPage> createState() => _InternshipFeedPageState();
}

class _InternshipFeedPageState extends State<InternshipFeedPage> {
  late Future<List<dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = Api.listInternships();
  }

  Future<void> refresh() async {
    setState(() => future = Api.listInternships());
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Internships')),
      body: FutureBuilder<List<dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Ошибка: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final items = (snap.data ?? []);
          if (items.isEmpty) return const Center(child: Text('Пока нет стажировок'));

          return RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final i = items[index] as Map<String, dynamic>;
                final id = (i['id'] ?? 0) as int;
                final title = (i['title'] ?? 'Internship').toString();
                final company = (i['company'] ?? 'Company').toString();
                final city = (i['city'] ?? '').toString();
                final format = (i['format'] ?? 'Hybrid').toString();
                final paid = (i['paid'] ?? true) == true;

                return InternshipCard(
                  title: title,
                  company: company,
                  city: city,
                  format: format,
                  paid: paid,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => InternshipDetailsPage(internshipId: id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class InternshipDetailsPage extends StatefulWidget {
  final int internshipId;
  const InternshipDetailsPage({super.key, required this.internshipId});

  @override
  State<InternshipDetailsPage> createState() => _InternshipDetailsPageState();
}

class _InternshipDetailsPageState extends State<InternshipDetailsPage> {
  late Future<Map<String, dynamic>> future;

  @override
  void initState() {
    super.initState();
    future = Api.getInternship(widget.internshipId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(title: const Text('Details')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Ошибка: ${snap.error}', textAlign: TextAlign.center),
              ),
            );
          }

          final i = snap.data ?? {};
          final title = (i['title'] ?? 'Internship').toString();
          final company = (i['company'] ?? '').toString();
          final city = (i['city'] ?? '').toString();
          final format = (i['format'] ?? '').toString();
          final paid = i['paid'] == true;
          final description = (i['description'] ?? '').toString();
          final requirements = (i['requirements'] is List) ? (i['requirements'] as List).cast<dynamic>() : [];
          final skills = (i['skills'] is List) ? (i['skills'] as List).cast<dynamic>() : [];

          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(company, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (city.isNotEmpty) _chip(text: city, icon: Icons.location_on_outlined),
                          if (format.isNotEmpty) _chip(text: format, icon: Icons.work_outline),
                          _chip(text: paid ? 'Paid' : 'Unpaid', icon: paid ? Icons.attach_money : Icons.money_off),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Description'),
              _sectionCard(Text(description.isEmpty ? 'No description yet.' : description)),
              const SizedBox(height: 12),
              _sectionTitle('Requirements'),
              _sectionCard(
                requirements.isEmpty
                    ? const Text('No requirements yet.')
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: requirements
                            .map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('•  '),
                                      Expanded(child: Text(r.toString())),
                                    ],
                                  ),
                                ))
                            .toList(),
                      ),
              ),
              const SizedBox(height: 12),
              _sectionTitle('Skills'),
              _sectionCard(
                skills.isEmpty
                    ? const Text('No skills yet.')
                    : Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: skills.map((s) => Chip(label: Text(s.toString()))).toList(),
                      ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Apply: скоро добавим отправку заявки ✅')),
                    );
                  },
                  icon: const Icon(Icons.send),
                  label: const Text('Apply'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
    );
  }

  static Widget _sectionCard(Widget child) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: child,
      ),
    );
  }

  static Widget _chip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class InternshipCard extends StatelessWidget {
  final String title;
  final String company;
  final String city;
  final String format;
  final bool paid;
  final VoidCallback? onTap;

  const InternshipCard({
    super.key,
    required this.title,
    required this.company,
    required this.city,
    required this.format,
    required this.paid,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _chip(text: paid ? 'Paid' : 'Unpaid', icon: paid ? Icons.attach_money : Icons.money_off),
                  ],
                ),
                const SizedBox(height: 6),
                Text(company, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (city.isNotEmpty) _chip(text: city, icon: Icons.location_on_outlined),
                    _chip(text: format, icon: Icons.work_outline),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text('Tap to view details', style: TextStyle(color: Colors.black.withOpacity(0.55), fontSize: 12)),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _chip({required String text, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
