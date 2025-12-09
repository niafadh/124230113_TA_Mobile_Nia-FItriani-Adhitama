import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'premium_helper.dart'; // Import helper premium

class TrendingPage extends StatefulWidget {
  const TrendingPage({super.key});

  @override
  State<TrendingPage> createState() => _TrendingPageState();
}

class _TrendingPageState extends State<TrendingPage> {
  final ApiService _apiService = ApiService();
  late Future<List<dynamic>> trendingNews;
  String selectedCategory = 'general';

  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _allArticles = [];
  final List<Map<String, dynamic>> _displayArticles = [];
  static const int _pageSize = 10;

  bool _isLoadingMore = false;
  bool _isFetching = false;
  String userEmail = '';

  // Kategori Chips
  final List<Map<String, dynamic>> categories = [
    {'key': 'general', 'label': 'All'},
    {'key': 'technology', 'label': 'Tech'},
    {'key': 'business', 'label': 'Business'},
    {'key': 'entertainment', 'label': 'Entertainment'},
    {'key': 'health', 'label': 'Health'},
    {'key': 'science', 'label': 'Science'},
    {'key': 'sports', 'label': 'Sports'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchTrending(selectedCategory);
    _scrollController.addListener(_onScroll);
  }

  void _loadUser() {
    final box = Hive.box('userBox');
    final user = box.get('user');
    if (user != null && mounted) {
      setState(() {
        userEmail = user['email'] ?? '';
      });
    }
  }

  // 🔹 LOGIKA CEK PREMIUM (Sama seperti di Home Page)
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

  void _fetchTrending(String category) {
    if (_isFetching) return;
    setState(() {
      _isFetching = true;
      _allArticles.clear();
      _displayArticles.clear();
      _isLoadingMore = false;
    });

    trendingNews = _apiService.fetchTrendingNews(category: category).whenComplete(() {
      if (mounted) setState(() => _isFetching = false);
    });
  }

  void _onCategorySelected(String category) {
    if (_isFetching || selectedCategory == category) return;
    setState(() {
      selectedCategory = category;
    });
    _fetchTrending(category);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      _loadMore();
    }
  }

  void _loadMore() {
    if (_displayArticles.length >= _allArticles.length) return;
    setState(() {
      _isLoadingMore = true;
      final nextItems = _allArticles
          .skip(_displayArticles.length)
          .take(_pageSize)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _displayArticles.addAll(nextItems);
      _isLoadingMore = false;
    });
  }

  void _fillRemainingInBackground() async {
    await Future.delayed(const Duration(milliseconds: 300));
    int current = _displayArticles.length;
    while (current < _allArticles.length) {
      if (!mounted) return;
      final nextChunk = _allArticles
          .skip(current)
          .take(_pageSize)
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      setState(() {
        _displayArticles.addAll(nextChunk);
      });
      current = _displayArticles.length;
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  String _getLocationFromSource(String source) {
    if (source.toLowerCase().contains('bbc')) return "London, UK";
    if (source.toLowerCase().contains('cnn')) return "Atlanta, USA";
    return "Jakarta, Indonesia";
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFFC92E36);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Header Simple & Clean
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Trending News",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B2B2B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Most popular stories worldwide",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            // 2. Category Chips
            SizedBox(
              height: 50,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: categories.length,
                physics: const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final bool isSelected = cat['key'] == selectedCategory;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(cat['label']),
                      selected: isSelected,
                      selectedColor: primaryColor,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      onSelected: (_) => _onCategorySelected(cat['key']),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: isSelected ? primaryColor : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // 3. List Content
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: trendingNews,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && _displayArticles.isEmpty) {
                    return const Center(child: CircularProgressIndicator(color: primaryColor));
                  } else if (snapshot.hasError) {
                    return Center(child: Text("Gagal memuat berita", style: TextStyle(color: Colors.grey.shade500)));
                  }

                  // Init data
                  if (_allArticles.isEmpty && snapshot.hasData) {
                    final articles = snapshot.data!
                        .where((a) => a['title'] != null && a['urlToImage'] != null)
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                    _allArticles.addAll(articles);
                    
                    for (var item in _allArticles) {
                      item['location'] = _getLocationFromSource(item['source']?['name'] ?? '');
                    }

                    _displayArticles.addAll(articles.take(_pageSize));
                    _fillRemainingInBackground();
                  }

                  if (_displayArticles.isEmpty) {
                    return const Center(child: Text("Tidak ada berita."));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(top: 10, bottom: 20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _displayArticles.length + (_isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _displayArticles.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                            ),
                          ),
                        );
                      }

                      final article = _displayArticles[index];
                      // 🔹 Cek Premium pakai logika yang sama dengan Home
                      final bool isPremium = _checkIsArticlePremium(article);
                      // 🔹 Cek User Access (perlu PremiumHelper)
                      final bool isUserPremium = PremiumHelper.isPremiumActive(userEmail);
                      final bool isLocked = isPremium && !isUserPremium;

                      return _buildModernCard(article, isPremium, isLocked);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 WIDGET KARTU BERITA MODERN
  Widget _buildModernCard(Map<String, dynamic> article, bool isPremium, bool isLocked) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetailPage(
              article: article,
              isArticlePremiumLabel: isPremium, // Kirim status premium
              userEmail: userEmail,
            ),
          ),
        );
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
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Gambar (Kiri)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                  child: CachedNetworkImage(
                    imageUrl: article['urlToImage'] ?? '',
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey.shade100),
                    errorWidget: (context, url, error) => const Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
                // Gembok kalau dikunci
                if (isLocked)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.lock, color: Colors.red, size: 24),
                      ),
                    ),
                  ),
              ],
            ),

            // 2. Konten Teks (Kanan)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Label Kategori/Source
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFC92E36).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            article['source']?['name'] ?? 'News',
                            style: const TextStyle(
                              color: Color(0xFFC92E36),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        // Badge Exclusive
                        if (isPremium)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.workspace_premium, size: 10, color: Colors.amber),
                                SizedBox(width: 2),
                                Text(
                                  "Exclusive",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Judul
                    Text(
                      article['title'] ?? 'No Title',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lokasi / Tanggal
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            article['location'] ?? 'Global',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}