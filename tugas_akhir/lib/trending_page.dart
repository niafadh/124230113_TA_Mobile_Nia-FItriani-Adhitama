import 'package:flutter/material.dart';
import 'api_service.dart';
import 'detail_page.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  static const int _pageSize = 8;

  bool _isLoadingMore = false;
  bool _isFetching = false;

  final List<Map<String, String>> categories = [
    {'key': 'general', 'label': 'General'},
    {'key': 'technology', 'label': 'Technology'},
    {'key': 'business', 'label': 'Business'},
    {'key': 'health', 'label': 'Health'},
    {'key': 'entertainment', 'label': 'Entertainment'},
    {'key': 'science', 'label': 'Science'},
    {'key': 'sports', 'label': 'Sports'},
  ];

  @override
  void initState() {
    super.initState();
    _fetchTrending(selectedCategory);
    _scrollController.addListener(_onScroll);
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
    if (_isFetching) return;
    setState(() {
      selectedCategory = category;
    });
    _fetchTrending(category);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 150 &&
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
    await Future.delayed(const Duration(milliseconds: 250));
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
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  String _getLocationFromSource(String source) {
    if (source.toLowerCase().contains('bbc')) return "London, UK";
    if (source.toLowerCase().contains('cnn')) return "Atlanta, USA";
    if (source.toLowerCase().contains('kompas')) return "Jakarta, Indonesia";
    if (source.toLowerCase().contains('nhk')) return "Tokyo, Japan";
    if (source.toLowerCase().contains('kbs')) return "Seoul, South Korea";
    if (source.toLowerCase().contains('al jazeera')) return "Doha, Qatar";
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
    const redColor = Color(0xFFB71C1C);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Trending News 🌍",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: redColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          // 🔹 Category Chips
          SizedBox(
            height: 55,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final bool isSelected = cat['key'] == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      cat['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : redColor,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: redColor,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: redColor.withOpacity(0.4)),
                    onSelected: (_) => _onCategorySelected(cat['key']!),
                  ),
                );
              },
            ),
          ),

          // 🔹 News List
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: trendingNews,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: redColor),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        "Gagal memuat berita trending:\n${snapshot.error}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      "Belum ada berita trending untuk kategori ini.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                final articles = snapshot.data!
                    .where(
                      (article) =>
                          article['description'] != null &&
                          article['description'].toString().trim().isNotEmpty &&
                          article['url'] != null,
                    )
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();

                final capped = articles.take(12).toList();

                if (_allArticles.isEmpty) {
                  _allArticles.addAll(capped);
                  for (var i = 0; i < _allArticles.length; i++) {
                    final source =
                        _allArticles[i]['source']?['name'] ?? 'Unknown';
                    _allArticles[i]['location'] =
                        _getLocationFromSource(source);
                  }
                  _displayArticles.addAll(_allArticles.take(_pageSize).toList());
                  _fillRemainingInBackground();
                }

                if (articles.isEmpty) {
                  return const Center(
                    child: Text(
                      "Tidak ada berita tersedia.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _displayArticles.length + (_isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _displayArticles.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child:
                              CircularProgressIndicator(color: redColor),
                        ),
                      );
                    }

                    final article =
                        Map<String, dynamic>.from(_displayArticles[index]);
                    final bool isPremium = index % 4 == 0;
                    final source = article['source']?['name'] ?? 'Unknown';
                    article['location'] = _getLocationFromSource(source);

                    return InkWell(
                      onTap: () {
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
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 🖼️ Gambar
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                bottomLeft: Radius.circular(16),
                              ),
                              child: article['urlToImage'] != null
                                  ? CachedNetworkImage(
                                      imageUrl: article['urlToImage'],
                                      width: 100,
                                      height: 85,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) =>
                                          Container(
                                        width: 100,
                                        height: 85,
                                        color: Colors.grey[300],
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) =>
                                          Container(
                                        width: 100,
                                        height: 85,
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 100,
                                      height: 85,
                                      color: Colors.grey[300],
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        color: Colors.grey,
                                      ),
                                    ),
                            ),

                            // 📰 Info
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // 🔹 Judul + Premium
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            article['title'] ?? 'No Title',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        if (isPremium)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(Icons.lock,
                                                  size: 14,
                                                  color: redColor),
                                              SizedBox(width: 3),
                                              Text(
                                                "Premium",
                                                style: TextStyle(
                                                  color: redColor,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    // 🔹 Sumber
                                    Text(
                                      source,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
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
      ),
    );
  }
}
