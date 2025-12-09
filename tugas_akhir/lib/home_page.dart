import 'dart:io';
import 'package:flutter/material.dart';
import 'api_service.dart' as api_service;
import 'detail_page.dart';
import 'profile_page.dart';
import 'trending_page.dart';
import 'activity_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'premium_helper.dart';

class HomePage extends StatefulWidget {
  final int initialIndex; // 🔹 Tambahkan parameter ini

  const HomePage({
    super.key, 
    this.initialIndex = 0, // Defaultnya 0 (Home)
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final api_service.ApiService _newsApi = api_service.ApiService();
  late Future<List<dynamic>> futureNews;
  final TextEditingController _searchController = TextEditingController();
  
  // 🔹 Hapus inisialisasi 0 disini
  late int _selectedIndex; 
  
  String? userName;
  String userEmail = '';
  File? _profileImage;

  @override
  void initState() {
    super.initState();
    // 🔹 Set index awal sesuai parameter yang dikirim
    _selectedIndex = widget.initialIndex; 
    
    futureNews = _newsApi.fetchNews();
    _loadUserData();
  }

  void _loadUserData() {
    final box = Hive.box('userBox');
    final user = box.get('user');
    if (user != null && mounted) {
      setState(() {
        userName = user['name'];
        userEmail = user['email'] ?? '';
      });
      _loadProfileImage(); 
    }
  }

  void _loadProfileImage() {
    if (userEmail.isEmpty) return;
    final box = Hive.box('userBox');
    final String? imagePath = box.get('profile_image_$userEmail');
    if (imagePath != null) {
      final file = File(imagePath);
      if (file.existsSync()) {
        setState(() => _profileImage = file);
      }
    } else {
      setState(() => _profileImage = null);
    }
  }

  bool _isUserPremium() {
    return PremiumHelper.isPremiumActive(userEmail);
  }

  bool _checkIsArticlePremium(Map<String, dynamic> article) {
    final String sourceName = (article['source']?['name'] ?? '').toString().toLowerCase();
    final List<String> premiumSources = [
      'bloomberg', 'wall street journal', 'the washington post', 
      'wired', 'techcrunch', 'financial times', 'the economist', 'bbc news'
    ];
    if (premiumSources.any((s) => sourceName.contains(s))) return true;

    final String title = (article['title'] ?? '').toString().toLowerCase();
    final List<String> exclusiveKeywords = [
      'exclusive', 'analysis', 'interview', 'review', 'deep dive', 'premium'
    ];
    for (var keyword in exclusiveKeywords) {
      if (title.contains(keyword)) return true;
    }
    return false;
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
    if (index == 3) {
      _navigateToProfile();
      return;
    }
    setState(() => _selectedIndex = index);
  }

  Future<void> _navigateToProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfilePage()),
    );
    _loadUserData(); 
    setState(() {}); 
  }

  // --- WIDGET BUILDERS ---

  Widget _buildHomeTab() {
    bool isPremiumUser = _isUserPremium();
    const Color primaryRed = Color(0xFFC92E36);
    const double headerHeight = 220;

    return Stack(
      children: [
        Container(color: const Color(0xFFF9F9F9)),
        FutureBuilder<List<dynamic>>(
          future: futureNews,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryRed));
            } else if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.newspaper, size: 60, color: Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text("No news found", style: TextStyle(color: Colors.grey.shade500)),
                  ],
                ),
              );
            }

            final articles = snapshot.data!
                .where((a) => a['title'] != null && a['urlToImage'] != null)
                .toList();

            return ListView.builder(
              padding: const EdgeInsets.only(top: headerHeight + 20, bottom: 20),
              itemCount: articles.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: const Text(
                      "Latest News",
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.black87
                      ),
                    ),
                  );
                }

                final article = articles[index - 1];
                final bool isPremium = _checkIsArticlePremium(article);
                final bool isLocked = isPremium && !isPremiumUser;

                return _buildNewsCard(article, isPremium, isLocked);
              },
            );
          },
        ),
        Container(
          height: headerHeight,
          decoration: const BoxDecoration(
            color: primaryRed,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(30),
              bottomRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5))
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 60, 20, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hello, ${userName?.split(' ')[0] ?? 'User'}! 👋",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPremiumUser ? "Premium Member 👑" : "Explore today's world",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _navigateToProfile(),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: _profileImage != null ? FileImage(_profileImage!) : null,
                  child: _profileImage == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 155,
          left: 20,
          right: 20,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search news, topics...",
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.filter_list, color: primaryRed),
                  onPressed: _searchNews,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onSubmitted: (_) => _searchNews(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewsCard(dynamic article, bool isPremium, bool isLocked) {
    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(
              article: article,
              isArticlePremiumLabel: isPremium,
              userEmail: userEmail,
            ),
          ),
        );
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      article['urlToImage'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          Container(color: Colors.grey.shade200),
                    ),
                  ),
                ),
                if (isPremium)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.workspace_premium, color: Colors.amber, size: 14),
                          SizedBox(width: 4),
                          Text(
                            "EXCLUSIVE",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock, color: Colors.white, size: 28),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFC92E36).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          article['source']?['name'] ?? 'News',
                          style: const TextStyle(
                            color: Color(0xFFC92E36),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(Icons.access_time, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        "Today", 
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    article['title'] ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab() => const ProfilePage();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = [
      _buildHomeTab(),
      const TrendingPage(),
      const ActivityPage(), 
      _buildProfileTab(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      // App bar null di semua kecuali Activity, tapi Activity udah punya AppBar sendiri di filenya
      // Jadi kita set null semua di sini biar handle di masing-masing page (kecuali Activity)
      // TAPI: ActivityPage kita panggil sebagai widget body, dan dia punya Scaffold+AppBar sendiri?
      // Flutter support nested scaffold, jadi aman.
      // Cuma biar rapi, karena ActivityPage SUDAH punya AppBar, di sini kita null-kan saja.
      appBar: null, 
      
      body: pages[_selectedIndex],
      
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: _onItemTapped,
          selectedItemColor: const Color(0xFFC92E36),
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded), 
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.trending_up_rounded), 
              label: 'Trending'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_rounded), 
              label: 'Activity'
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_rounded), 
              label: 'Profile'
            ),
          ],
        ),
      ),
    );
  }
}