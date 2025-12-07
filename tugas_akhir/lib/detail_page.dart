import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'subscribe_page.dart';
import 'community_talk_page.dart';
import 'premium_helper.dart';

class DetailPage extends StatefulWidget {
  final Map<String, dynamic> article;
  final bool isArticlePremiumLabel;
  final String userEmail;

  const DetailPage({
    super.key,
    required this.article,
    required this.isArticlePremiumLabel,
    required this.userEmail,
  });

  @override
  State<DetailPage> createState() => _DetailPageState();
}

class _DetailPageState extends State<DetailPage> {
  late LatLng _coords;
  final MapController _mapController = MapController();
  late String _displayLocation;
  DateTime? _publishedDate;
  String? _publishedRaw;
  String _selectedTz = 'Original';
  bool _isUserSubscribed = false;

  final Map<String, int?> _tzOffsets = {
    'Original': null,
    'WIB (UTC+7)': 7,
    'WITA (UTC+8)': 8,
    'WIT (UTC+9)': 9,
    'London (UTC+0)': 0,
  };

  @override
  void initState() {
    super.initState();
    _checkSubscription();
    _initData();
  }

  void _checkSubscription() {
    setState(() {
      _isUserSubscribed = PremiumHelper.isPremiumActive(widget.userEmail);
    });
  }

  void _initData() {
    // 1. Parsing Tanggal
    try {
      final String raw = (widget.article['publishedAt'] ?? '').toString();
      _publishedRaw = raw.isNotEmpty ? raw : null;
      if (raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) _publishedDate = parsed;
      }
    } catch (_) {
      _publishedDate = null;
      _publishedRaw = null;
    }

    // 2. Parsing Koordinat
    final double? lat = (widget.article['lat'] is num) ? (widget.article['lat'] as num).toDouble() : null;
    final double? lng = (widget.article['lng'] is num) ? (widget.article['lng'] as num).toDouble() : null;
    
    // Default ke 0,0
    _coords = const LatLng(0.0, 0.0);

    // Jika artikel punya koordinat
    if (lat != null && lng != null) {
      _coords = LatLng(lat, lng);
      _displayLocation = (widget.article['geocoded_place'] as String?) ?? 
          (widget.article['location'] as String?) ?? 
          (widget.article['source']?['name'] as String?) ?? 'Tidak diketahui';
      return;
    }

    // Jika tidak, coba mapping dari nama Source
    final String sourceName = (widget.article['source']?['name'] as String?) ?? '';
    if (sourceName.isNotEmpty) {
      final LatLng mapped = _getSourceCoordinates(sourceName);
      if (mapped.latitude != 0.0 || mapped.longitude != 0.0) {
        _coords = mapped;
        _displayLocation = sourceName;
        // _reverseGeocode(mapped); // Opsional: Implementasi API Nominatim jika mau
        return;
      }
      _displayLocation = sourceName;
      // _geocodeAndMove(sourceName); // Opsional: Implementasi API Nominatim jika mau
      return;
    }
    _displayLocation = 'Tidak diketahui';
  }

  // --- HELPER LOGIC ---

  // Menampilkan bottom sheet konten sederhana jika webview gagal
  void _showInlineArticleContent() {
    final String initial = widget.article['description'] ?? 'Konten tidak tersedia';
    showModalBottomSheet(context: context, builder: (ctx) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(initial),
      );
    });
  }

  // Membuka Webview di dalam aplikasi
  Future<void> _openInAppWebview(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(uri);

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(title: const Text("Web View"), backgroundColor: const Color(0xFFB71C1C)),
      body: WebViewWidget(controller: controller),
    )));
  }

  // Mapping lokasi statis sederhana
  LatLng _getSourceCoordinates(String sourceName) {
    if (sourceName.toLowerCase().contains('bbc')) return const LatLng(51.5072, -0.1276);
    if (sourceName.toLowerCase().contains('cnn')) return const LatLng(33.7490, -84.3880);
    if (sourceName.toLowerCase().contains('kompas')) return const LatLng(-6.2088, 106.8456);
    if (sourceName.toLowerCase().contains('nhk')) return const LatLng(35.6895, 139.6917);
    if (sourceName.toLowerCase().contains('al jazeera')) return const LatLng(25.2854, 51.5310);
    return const LatLng(0,0);
  }

  String _formatPublishedFor(String tzKey) {
    if (_publishedDate == null) return _publishedRaw ?? '-';
    final orig = _publishedDate!;
    final int? offset = _tzOffsets[tzKey];
    
    DateTime shown;
    if (tzKey == 'Original') {
      shown = orig.toLocal();
    } else if (offset != null) {
      shown = orig.toUtc().add(Duration(hours: offset));
    } else {
      shown = orig.toLocal();
    }
    
    return DateFormat("d MMMM yyyy '•' HH:mm").format(shown);
  }

  Future<void> _saveArticle() async {
    final box = Hive.box('savedNewsBox');
    final String key = widget.article['url'] ?? DateTime.now().toIso8601String();
    await box.put(key, widget.article);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berita disimpan')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔒 Logic: Locked if Premium Article AND User Not Subscribed
    final bool isLocked = widget.isArticlePremiumLabel && !_isUserSubscribed;

    final String title = widget.article['title'] ?? 'No Title';
    final String description = widget.article['description'] ?? 'Tidak ada deskripsi.';
    final String imageUrl = widget.article['urlToImage'] ?? '';
    final String source = widget.article['source']?['name'] ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(source, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFB71C1C),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            onPressed: _saveArticle,
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              if (_isUserSubscribed) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityTalkPage(
                      articleUrl: widget.article['url'] ?? '',
                      articleTitle: title,
                      userEmail: widget.userEmail,
                    ),
                  ),
                );
              } else {
                _showPremiumDialog("Fitur Community Talk hanya untuk pengguna Premium.");
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Gambar Utama
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 230,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(height: 230, color: Colors.grey[300], child: const Icon(Icons.broken_image)),
                  ),
                
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2. Judul
                      Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),

                      // 3. Info Bar (Source, Date, Timezone)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.access_time, size: 16, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text(_formatPublishedFor(_selectedTz), style: const TextStyle(fontSize: 12)),
                            const Spacer(),
                            // Timezone Selector
                            InkWell(
                              onTap: () async {
                                final selected = await showModalBottomSheet<String>(
                                  context: context,
                                  builder: (ctx) => Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: _tzOffsets.keys.map((k) => ListTile(title: Text(k), onTap: () => Navigator.pop(ctx, k))).toList(),
                                  ),
                                );
                                if (selected != null) setState(() => _selectedTz = selected);
                              },
                              child: Row(
                                children: [
                                  Text(_selectedTz, style: const TextStyle(color: Color(0xFFB71C1C), fontWeight: FontWeight.bold)),
                                  const Icon(Icons.arrow_drop_down, color: Color(0xFFB71C1C)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 4. Peta Lokasi
                      Text("Lokasi: $_displayLocation", style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              center: _coords,
                              zoom: 11,
                            ),
                            children: [
                              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: ['a', 'b', 'c']),
                              MarkerLayer(markers: [Marker(point: _coords, child: const Icon(Icons.location_pin, color: Colors.red, size: 40))]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 5. KONTEN BERITA (Logic Premium)
                      if (isLocked) 
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(description, style: const TextStyle(fontSize: 16, color: Colors.black54)), // Preview
                            const SizedBox(height: 10),
                          ],
                        )
                      else 
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (widget.article['content'] ?? description).toString().replaceAll(RegExp(r'\[\+\d+ chars\]'), ''),
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_browser),
                              label: const Text("Baca Sumber Asli"),
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: const Color(0xFFB71C1C)),
                              onPressed: () async {
                                final urlString = (widget.article['url'] ?? '').toString();
                                if (urlString.isNotEmpty) {
                                  try { await _openInAppWebview(urlString); } catch (_) { _showInlineArticleContent(); }
                                }
                              },
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 🔹 OVERLAY GEMBOK (Jika Locked)
          if (isLocked)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.92),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 15, offset: const Offset(0, 5))],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_rounded, size: 60, color: Color(0xFFB71C1C)),
                        const SizedBox(height: 16),
                        const Text("Konten Premium", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          "Akses konten eksklusif ini dan fitur chat komunitas dengan berlangganan.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB71C1C),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => SubscribePage(userEmail: widget.userEmail),
                                ),
                              ).then((_) => _checkSubscription());
                            },
                            child: const Text("Langganan Sekarang", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showPremiumDialog(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fitur Premium'),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => SubscribePage(userEmail: widget.userEmail))).then((_) => _checkSubscription());
            },
            child: const Text('Langganan'),
          ),
        ],
      ),
    );
  }
}