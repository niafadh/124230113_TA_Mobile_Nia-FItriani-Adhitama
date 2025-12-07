import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'premium_helper.dart';
import 'package:intl/intl.dart';
import 'subscribe_page.dart';

class CommunityTalkPage extends StatefulWidget {
  final String articleUrl;
  final String articleTitle;
  final String userEmail; 

  const CommunityTalkPage({
    super.key,
    required this.articleUrl,
    required this.articleTitle,
    required this.userEmail,
  });

  @override
  State<CommunityTalkPage> createState() => _CommunityTalkPageState();
}

class _CommunityTalkPageState extends State<CommunityTalkPage> {
  // 🔹 HAPUS field '_box' disini karena tidak dipakai global
  final TextEditingController _ctrl = TextEditingController();
  String? userName;
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadUser();
  }

  void _loadUser() {
    final userBox = Hive.box('userBox');
    final user = userBox.get('user');
    userName = user != null ? user['name'] : 'Anonymous';
  }

  void _checkAccess() {
    setState(() {
      _isPremium = PremiumHelper.isPremiumActive(widget.userEmail);
    });
  }

  Future<void> _sendMessage() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;

    final box = await Hive.openBox('communityTalk');
    final List currentMessages = box.get(widget.articleUrl, defaultValue: []);
    
    final newMessage = {
      'user': userName,
      'email': widget.userEmail,
      'message': text,
      'timestamp': DateTime.now().toIso8601String(),
    };

    currentMessages.add(newMessage);
    await box.put(widget.articleUrl, currentMessages);
    
    _ctrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Community Talk"),
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline, size: 80, color: Colors.red.shade300),
                const SizedBox(height: 20),
                const Text(
                  "Akses Ditolak",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Fitur Community Talk hanya tersedia untuk pengguna Premium. Silakan berlangganan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubscribePage(userEmail: widget.userEmail),
                      ),
                    );
                  },
                  child: const Text("Upgrade ke Premium"),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Community Talk"),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.red.shade50,
            width: double.infinity,
            child: Text(
              "Topik: ${widget.articleTitle}",
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: FutureBuilder(
              future: Hive.openBox('communityTalk'),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final box = snapshot.data as Box;
                return ValueListenableBuilder(
                  valueListenable: box.listenable(keys: [widget.articleUrl]),
                  builder: (context, box, _) {
                    final List messages = box.get(widget.articleUrl, defaultValue: []);
                    
                    if (messages.isEmpty) {
                      return const Center(child: Text("Belum ada diskusi. Jadilah yang pertama!"));
                    }

                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[messages.length - 1 - index];
                        final isMe = msg['email'] == widget.userEmail;
                        final time = DateFormat('HH:mm').format(DateTime.parse(msg['timestamp']));

                        return Align(
                          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.red.shade100 : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)],
                            ),
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (!isMe) 
                                  Text(msg['user'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red)),
                                Text(msg['message']),
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(time, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: "Tulis pesan...",
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFFB71C1C),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}