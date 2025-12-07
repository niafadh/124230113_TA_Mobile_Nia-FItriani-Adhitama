import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'premium_helper.dart';
import 'subscribe_page.dart';
import 'package:intl/intl.dart';

class CommunityTalkPage extends StatefulWidget {
  final String articleUrl;
  final String articleTitle;

  const CommunityTalkPage({
    super.key,
    required this.articleUrl,
    required this.articleTitle,
  });

  @override
  State<CommunityTalkPage> createState() => _CommunityTalkPageState();
}

class _CommunityTalkPageState extends State<CommunityTalkPage> {
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _ctrl = TextEditingController();
  bool _loading = true;
  bool _isPremium = false;
  Box? _box;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _isPremium = await PremiumHelper.isPremiumActive();

    if (!_isPremium) {
      setState(() => _loading = false);
      return;
    }

    _box = await Hive.openBox('communityTalk');
    final stored = _box?.get(widget.articleUrl);

    if (stored is List) {
      _messages = List<Map<String, dynamic>>.from(
        stored.map((e) => Map<String, dynamic>.from(e)),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _box == null) return;

    final userBox = Hive.box('userBox');
    final user = userBox.get('user');
    final userName = user?['name'] ?? 'Anonymous';

    final newMsg = {
      'user': userName,
      'message': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    setState(() => _messages.add(newMsg));
    await _box!.put(widget.articleUrl, _messages);
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Community Talk"),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 80, color: Colors.red.shade300),
              const SizedBox(height: 20),
              const Text(
                "Fitur Premium",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Community Talk hanya untuk pengguna premium.",
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubscribePage()),
                  );
                },
                child: const Text("Upgrade Premium"),
              )
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.articleTitle),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(child: Text("Belum ada pesan"))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final msg = _messages[index];

                      final timeStr = DateFormat('dd/MM HH:mm')
                          .format(DateTime.parse(msg['timestamp']));

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(msg['user'][0].toUpperCase()),
                          ),
                          title: Text(msg['user']),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(msg['message']),
                              Text(timeStr,
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              decoration: InputDecoration(
                hintText: "Tulis pesan...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            child: IconButton(
              icon: const Icon(Icons.send),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
