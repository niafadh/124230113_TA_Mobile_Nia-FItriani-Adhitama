import 'package:flutter/material.dart';
import 'api_service.dart' as api_service;
import 'detail_page.dart';
import 'profile_page.dart';
import 'trending_page.dart';
import 'activity_page.dart';
import 'package:hive_flutter/hive_flutter.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}
 class _HomePageState extends State<HomePage> {
  final api_service.ApiService _newsApi = api_service.ApiService();
  late Future<List<dynamic>> futureNews;
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  String? userName;

  @override
  void initState() {
    super.initState();
    futureNews = _newsApi.fetchNews();
    _loadUserName();
  }
  void _loadUserName() {
    final box = Hive.box('userBox');
    final user = box.get('user');
    if (user != null && mounted) {
      setState(() {
        userName = user['name'];
      });
    }
  }

  void _searchNews() {
    setState(() {
      final query = _searchController.text.trim();
      futureNews = _newsApi.fetchNews(
        query: query.isEmpty ? "indonesia" : query,
      );
    });
  }

  void _onItemTapped(int index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TrendingPage()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  /// 🔹 Fungsi bantu untuk menentukan lokasi peta dari sumber berita
  String _getLocationFromSource(String source) {
    if (source.toLowerCase().contains('bbc')) return "London, UK";
    if (source.toLowerCase().contains('cnn')) return "Atlanta, USA";
    if (source.toLowerCase().contains('kompas')) return "Jakarta, Indonesia";
    if (source.toLowerCase().contains('nhk')) return "Tokyo, Japan";
    if (source.toLowerCase().contains('kbs')) return "Seoul, South Korea";
    if (source.toLowerCase().contains('al jazeera')) return "Doha, Qatar";
    return "Jakarta, Indonesia";
  }

  Widget _buildHomeTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            "Selamat datang, ${userName ?? 'User'} 👋",
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B2B2B),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Cari berita...",
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFC92E36),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFC92E36),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: _searchNews,
                  icon: const Icon(Icons.search, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: FutureBuilder<List<dynamic>>(
            future: futureNews,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.red,
                          size: 40,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Gagal memuat berita. Cek API Key/Limit.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Pesan: ${snapshot.error}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(child: Text("Tidak ada berita ditemukan."));
              }

              final articles = snapshot.data!
                  .where(
                    (article) =>
                        article['description'] != null &&
                        article['description'].toString().trim().isNotEmpty &&
                        article['url'] != null,
                  )
                  .toList();

              if (articles.isEmpty) {
                return const Center(child: Text("Tidak ada berita tersedia."));
              }

              return ListView.builder(
                itemCount: articles.length,
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final bool isPremium = index % 4 == 0;
                  final sourceName = article['source']?['name'] ?? 'Unknown';

                  // ✅ Kirim langsung article dan isPremium ke DetailPage
                  return InkWell(
                    onTap: () {
                      article['location'] = _getLocationFromSource(sourceName);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DetailPage(
                            article: article,
                            isPremium: isPremium,
                          ),
                        ),
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      elevation: 6,
                      shadowColor: Colors.black.withOpacity(0.15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 100,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                bottomLeft: Radius.circular(12),
                              ),
                              image: article['urlToImage'] != null
                                  ? DecorationImage(
                                      image: NetworkImage(
                                        article['urlToImage'],
                                      ),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                              color: Colors.grey[300],
                            ),
                            child: article['urlToImage'] == null
                                ? const Icon(Icons.image_not_supported)
                                : null,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article['title'] ?? 'No Title',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    sourceName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isPremium)
                            const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.lock,
                                    color: Color.fromARGB(255, 195, 52, 52),
                                    size: 16,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "Premium",
                                    style: TextStyle(
                                      color: Color.fromARGB(255, 194, 54, 54),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab() => const ActivityPage();
  Widget _buildProfileTab() => const ProfilePage();

  @override
  Widget build(BuildContext context) {
    final List<Widget> _pages = [
      _buildHomeTab(),
      const SizedBox(),
      _buildActivityTab(),
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFC92E36),
        elevation: 0,
        title: const Text(
          "Newsly",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white70,
        backgroundColor: const Color(0xFFC92E36),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.trending_up),
            label: 'Trending',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Activity',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
