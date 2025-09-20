import 'package:flutter/material.dart';
import 'package:guidey1/services/gemini_services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class RoadmapLevel {
  final String title;
  final List<String> topics;
  final List<String> resources;
  final List<String> projects;

  RoadmapLevel({
    required this.title,
    required this.topics,
    required this.resources,
    required this.projects,
  });
}

class RoadmapScreen extends StatefulWidget {
  final String? careerName;
  final String? roadmapData;

  const RoadmapScreen({this.careerName, this.roadmapData, Key? key})
      : super(key: key);

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  late GeminiService _geminiService;
  List<RoadmapLevel> levels = [];
  bool isLoading = false;
  String? error;
  Set<int> completedLevels = {};
  String? rawResponse;

  @override
  void initState() {
    super.initState();
    _geminiService = GeminiService();
    _loadProgress();

    if (widget.roadmapData == null || widget.roadmapData!.isEmpty) {
      if (widget.careerName != null && widget.careerName!.trim().isNotEmpty) {
        _fetchRoadmap(widget.careerName!.trim());
      }
    } else {
      levels = _parseRoadmap(widget.roadmapData!);
    }
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      completedLevels =
          prefs.getStringList('completedLevels')?.map(int.parse).toSet() ?? {};
    });
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setStringList(
        'completedLevels', completedLevels.map((e) => e.toString()).toList());
  }

  // ✅ تم التعديل هنا بس
  Future<void> _fetchRoadmap(String careerName) async {
    setState(() {
      isLoading = true;
      error = null;
      rawResponse = null;
    });

    while (true) {
      try {
        final result = await _geminiService.getCareerRoadmap(careerName);

        if (result.isNotEmpty && result != 'No roadmap generated.') {
          rawResponse = result;
          final parsedLevels = _parseRoadmap(result);

          if (parsedLevels.isNotEmpty) {
            setState(() {
              levels = parsedLevels;
              error = null;
              isLoading = false; // وقف اللودينج بعد النجاح
            });
            break; // خرج من اللوب
          }
        }
      } catch (e) {
        print('⚠ Error fetching roadmap, retrying... $e');
      }

      await Future.delayed(const Duration(seconds: 2));
    }
  }

  Future<void> _testGeminiConnection() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final isConnected = await _geminiService.testGeminiConnection();

      if (isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Gemini API connection successful!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Gemini API connection failed!'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Test error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  List<RoadmapLevel> _parseRoadmap(String roadmapText) {
    print('🔍 Parsing roadmap text: ${roadmapText.length} characters');

    final sections =
    roadmapText.split('##').where((s) => s.trim().isNotEmpty).toList();

    print('📊 Found ${sections.length} sections');

    final parsedLevels = <RoadmapLevel>[];

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      print(
          '🔍 Processing section $i: ${section.substring(0, section.length > 50 ? 50 : section.length)}...');

      final lines = section
          .trim()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        print('⚠ Section $i has no lines, skipping');
        continue;
      }

      final title = _stripMarkdown(lines.first).trim();
      print('📝 Section $i title: $title');

      final topics = <String>[];
      final resources = <String>[];
      final projects = <String>[];

      List<String>? currentList;

      for (int j = 1; j < lines.length; j++) {
        final raw = lines[j];
        final line = _stripMarkdown(raw);

        if (RegExp(r'^topics\s*:\s*$', caseSensitive: false).hasMatch(line)) {
          currentList = topics;
          print('📚 Section $i: Found topics section');
          continue;
        }
        if (RegExp(r'^resources\s*:\s*$', caseSensitive: false)
            .hasMatch(line)) {
          currentList = resources;
          print('🔗 Section $i: Found resources section');
          continue;
        }
        if (RegExp(r'^projects\s*:\s*$', caseSensitive: false).hasMatch(line)) {
          currentList = projects;
          print('🏗 Section $i: Found projects section');
          continue;
        }

        if (currentList != null) {
          final item = line
              .replaceFirst(RegExp(r'^\d+\.\s*'), '')
              .replaceFirst(RegExp(r'^[-\•]\s*'), '')
              .trim();

          if (item.isNotEmpty && !item.contains(':')) {
            currentList.add(item);
            print(
                '➕ Section $i: Added item to ${currentList == topics ? 'topics' : currentList == resources ? 'resources' : 'projects'}: $item');
          }
        }
      }

      print(
          '📊 Section $i summary: ${topics.length} topics, ${resources.length} resources, ${projects.length} projects');

      if (topics.isNotEmpty || resources.isNotEmpty || projects.isNotEmpty) {
        parsedLevels.add(RoadmapLevel(
          title: title,
          topics: topics,
          resources: resources,
          projects: projects,
        ));
        print('✅ Section $i added as level');
      } else {
        print('⚠ Section $i has no content, skipping');
      }
    }

    print('🎯 Final result: ${parsedLevels.length} levels parsed');
    return parsedLevels;
  }

  String _stripMarkdown(String s) {
    return s
        .replaceAll('*', '')
        .replaceAll('`', '')
        .replaceAll('', '')
        .trim();
  }

  ({String? title, String? url}) _extractTitleAndUrl(String input) {
    final text = _stripMarkdown(input);

    final md = RegExp(r'👦(.?)👦👦(.?)👦').firstMatch(text);
    if (md != null) {
      return (title: md.group(1)!.trim(), url: md.group(2)!.trim());
    }

    final plain = RegExp(r'(https?://[^\s]+)').firstMatch(text);
    if (plain != null) {
      final url = plain.group(0)!.trim();
      final title = text.replaceAll(url, '').trim();
      return (title: title.isEmpty ? null : title, url: url);
    }

    return (title: text.isEmpty ? null : text, url: null);
  }

  void _toggleLevelCompletion(int index) {
    setState(() {
      if (completedLevels.contains(index)) {
        completedLevels.remove(index);
      } else {
        completedLevels.add(index);
      }
    });
    _saveProgress();
  }

  Color _getLevelColor(String title) {
    final t = title.toLowerCase();
    if (t.contains('beginner')) return Colors.green;
    if (t.contains('intermediate')) return Colors.blue;
    if (t.contains('advanced')) return Colors.purple;
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final trackToShow = widget.careerName ?? 'No track selected';

    return Scaffold(
      appBar: AppBar(
        title: Text('Learning Roadmap - $trackToShow'),
        backgroundColor: Colors.deepPurple,
        actions: [
          if (widget.careerName != null && widget.careerName!.trim().isNotEmpty)
            ...[
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _fetchRoadmap(widget.careerName!.trim()),
                tooltip: 'Refresh Roadmap',
              ),
              IconButton(
                icon: const Icon(Icons.bug_report),
                onPressed: () => _testGeminiConnection(),
                tooltip: 'Test Gemini API',
              ),
            ],
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : levels.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : InteractiveViewer(
        panEnabled: true,
        scaleEnabled: true,
        maxScale: 3.0,
        child: ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: levels.length,
          itemBuilder: (context, index) {
            final level = levels[index];
            final color = _getLevelColor(level.title);

            return Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ExpansionTile(
                leading: IconButton(
                  icon: Icon(
                    completedLevels.contains(index)
                        ? Icons.check_circle_outline
                        : Icons.circle_outlined,
                    color: completedLevels.contains(index)
                        ? Colors.green
                        : Colors.grey,
                  ),
                  onPressed: () => _toggleLevelCompletion(index),
                ),
                title: Text(
                  level.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                children: [
                  if (level.topics.isNotEmpty)
                    _buildSection(
                      'Skills you\'ll learn:',
                      level.topics,
                      Icons.lightbulb_outline,
                    ),
                  if (level.resources.isNotEmpty)
                    _buildResources(level.resources),
                  if (level.projects.isNotEmpty)
                    _buildSection(
                      'Practice Projects:',
                      level.projects,
                      Icons.build_outlined,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> skills, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: skills.map((skill) {
              return ElevatedButton.icon(
                onPressed: null,
                icon: Icon(Icons.lightbulb_outline,
                    size: 18, color: Colors.amber),
                label: Text(skill,
                    style: const TextStyle(
                      fontSize: 14,
                    )),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey.shade100,
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildResources(List<String> resources) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learning Resources:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...resources.map((r) {
            final extracted = _extractTitleAndUrl(r);
            final title = (extracted.title ?? '').trim();
            final url = extracted.url;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Stack(
                children: [
                  ElevatedButton.icon(
                    onPressed: url != null ? () => _launchUrl(url) : null,
                    icon: const Icon(Icons.link,
                        size: 18, color: Colors.blue),
                    label: Text(
                      title.isNotEmpty ? title : (url ?? 'Resource'),
                      style: const TextStyle(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 8,
                    child: Text(
                      'Free',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade300,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _showRawResponse() {
    if (rawResponse != null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Raw Response'),
            content: SingleChildScrollView(
              child: Text(rawResponse!),
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('Close'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          );
        },
      );
    }
  }
}