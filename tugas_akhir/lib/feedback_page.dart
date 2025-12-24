import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; // Pastikan add intl di pubspec.yaml jika belum

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  // Warna Utama Newsly
  final Color primaryColor = const Color(0xFFC92E36);
  
  String userName = "User";
  String userEmail = "";

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  void _loadUser() {
    final box = Hive.box('userBox');
    final user = box.get('user');
    if (user != null) {
      setState(() {
        userName = user['name'] ?? "User";
        userEmail = user['email'] ?? "";
      });
    }
  }

  // 🔹 Fungsi Kirim Pesan
  void _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;

    final box = await Hive.openBox('feedbackBox');
    
    final newMessage = {
      "nama": userName,
      "email": userEmail,
      "pesan": _controller.text.trim(),
      "timestamp": DateTime.now().toIso8601String(),
      "isMe": true, // Penanda ini pesan kita
    };

    await box.add(newMessage);
    _controller.clear();
    
    // Scroll ke bawah setelah kirim
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Karena kita pakai reverse: true
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Background abu sangat muda
      appBar: AppBar(
        title: const Text(
          "Kesan & Pesan",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // 🔹 LIST PESAN (Chat Area)
          Expanded(
            child: FutureBuilder(
              future: Hive.openBox('feedbackBox'),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }

                // Gunakan ValueListenableBuilder agar update realtime saat ada pesan baru
                return ValueListenableBuilder(
                  valueListenable: Hive.box('feedbackBox').listenable(),
                  builder: (context, box, _) {
                    // Ambil data dan ubah ke List
                    final List<dynamic> rawData = box.values.toList();
                    
                    // Jika kosong, isi dengan data dummy default biar gak sepi
                    if (rawData.isEmpty) {
                      _addDefaultData(box);
                      return const SizedBox(); // Re-render next frame
                    }

                    // Urutkan dari terbaru ke terlama (karena ListView reverse: true)
                    final messages = rawData.reversed.toList();

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // Biar mulai dari bawah
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        final bool isMe = msg['isMe'] ?? (msg['email'] == userEmail);
                        
                        return _buildChatBubble(msg, isMe);
                      },
                    );
                  },
                );
              },
            ),
          ),

          // 🔹 INPUT FIELD (Ketik Pesan)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: "Tulis kesan pesan...",
                          border: InputBorder.none,
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                        minLines: 1,
                        maxLines: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: CircleAvatar(
                      radius: 24,
                      backgroundColor: primaryColor,
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 WIDGET BUBBLE CHAT
  Widget _buildChatBubble(dynamic msg, bool isMe) {
    // Parsing waktu
    String timeStr = "";
    if (msg['timestamp'] != null) {
      try {
        final date = DateTime.parse(msg['timestamp']);
        timeStr = DateFormat('HH:mm').format(date);
      } catch (e) {
        timeStr = "";
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Nama Pengirim (Kecil di atas bubble)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            child: Text(
              isMe ? "You" : msg['nama'] ?? "Anonymous",
              style: TextStyle(
                fontSize: 11, 
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500
              ),
            ),
          ),
          
          // Bubble Box
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isMe ? primaryColor : Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  msg['pesan'] ?? "",
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                if (timeStr.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400,
                      ),
                    ),
                  )
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 DATA DUMMY (Biar gak kosong pas pertama kali buka)
  Future<void> _addDefaultData(Box box) async {
    // Cek dulu biar gak duplikat terus
    if (box.isNotEmpty) return;

    final defaults = [
      {
        "nama": "NIM Satu",
        "email": "admin@newsly.com",
        "pesan": "Mata kuliah ini seru banget! Mengajarkan cara berpikir sistematis.",
        "timestamp": DateTime.now().subtract(const Duration(minutes: 10)).toIso8601String(),
        "isMe": false,
      },
      {
        "nama": "Mahasiswa Andalan",
        "email": "student@upnyk.ac.id",
        "pesan": "Banyak ilmu berguna buat masa depan. Semangat!",
        "timestamp": DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        "isMe": false,
      },
    ];

    for (var d in defaults) {
      await box.add(d);
    }
  }
}