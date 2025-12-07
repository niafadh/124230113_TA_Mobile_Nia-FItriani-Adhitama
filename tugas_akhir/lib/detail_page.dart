import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'subscribe_page.dart';
import 'community_talk_page.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:latlong2/latlong.dart';

class DetailPage extends StatefulWidget {
  final Map<String, dynamic> article;
  final bool isPremium;

  const DetailPage({super.key, required this.article, required this.isPremium});

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
    // parse published date early so it's available regardless of early returns
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
    // Prefer explicit coordinates from the article
    final double? lat = (widget.article['lat'] is num)
        ? (widget.article['lat'] as num).toDouble()
        : null;
    final double? lng = (widget.article['lng'] is num)
        ? (widget.article['lng'] as num).toDouble()
        : null;

    // default to (0,0) until we determine a better location
    _coords = const LatLng(0.0, 0.0);

    // 1) If article provides lat/lng, use it immediately
    if (lat != null && lng != null) {
      _coords = LatLng(lat, lng);
      _displayLocation = (widget.article['geocoded_place'] as String?) ??
          (widget.article['location'] as String?) ??
          (widget.article['source']?['name'] as String?) ??
          'Tidak diketahui';
      return;
    }

    // 2) Prefer mapping by source name (origin of the news) over topic location
    final String sourceName = (widget.article['source']?['name'] as String?) ?? '';
    if (sourceName.isNotEmpty) {
      final LatLng mapped = _getSourceCoordinates(sourceName);
      if (mapped.latitude != 0.0 || mapped.longitude != 0.0) {
        _coords = mapped;
        _displayLocation = sourceName;
        // try a reverse geocode to get a human-friendly place name for the source HQ
        _reverseGeocode(mapped);
        return;
      }
      // If mapping didn't provide useful coords, attempt to geocode the source name
      _displayLocation = sourceName;
      _geocodeAndMove(sourceName);
      return;
    }

    // 3) If article has a geocoded_place text, try to geocode it (topic place)
    final String? geocodedPlace = (widget.article['geocoded_place'] as String?);
    if (geocodedPlace != null && geocodedPlace.isNotEmpty) {
      _displayLocation = geocodedPlace;
      // attempt async geocode - this will call _mapController.move when done
      _geocodeAndMove(geocodedPlace);
      return;
    }

    // 4) If article provides a location string (topic location), try to geocode it
    final String? locationName = (widget.article['location'] as String?);
    if (locationName != null && locationName.isNotEmpty) {
      _displayLocation = locationName;
      _geocodeAndMove(locationName);
      return;
    }

    // 5) Last resort: unknown
    _displayLocation = 'Tidak diketahui';

    try {
      final String raw = (widget.article['publishedAt'] ?? '').toString();
      _publishedRaw = raw.isNotEmpty ? raw : null;
      if (raw.isNotEmpty) {
        // try parse, if fails keep raw string
        final parsed = DateTime.tryParse(raw);
        if (parsed != null) _publishedDate = parsed;
      }
    } catch (_) {
      _publishedDate = null;
      _publishedRaw = null;
    }
    // ensure Hive box is available
    try {
      Hive.box('savedNewsBox');
    } catch (_) {}
  }

  Future<String> _fetchFullTextFromUrl(String url) async {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return '';
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return '';
      String html = resp.body;
      String text = html.replaceAll(RegExp(r'<script[^>]*>[\s\S]*?<\/script>'), '');
      text = text.replaceAll(RegExp(r'<style[^>]*>[\s\S]*?<\/style>'), '');
      text = text.replaceAll(RegExp(r'<!--([\s\S]*?)-->'), '');
      text = text.replaceAll(RegExp(r'<[^>]+>'), '');
      text = text.replaceAll('&nbsp;', ' ');
      text = text.replaceAll('&amp;', '&');
      text = text.replaceAll('&lt;', '<');
      text = text.replaceAll('&gt;', '>');
      text = text.replaceAll(RegExp(r'\s{2,}'), ' ');
      text = text.trim();
      if (text.length > 20000) text = text.substring(0, 20000) + '\n\n[Truncated]';
      return text;
    } catch (_) {
      return '';
    }
  }

  Future<void> _showInlineArticleContent() async {
    final String initial = (() {
      final raw = widget.article['content'];
      if (raw is String && raw.trim().isNotEmpty) return raw.replaceAll(RegExp(r'\[\+\d+ chars\]'), '').trim();
      final desc = widget.article['description'];
      if (desc is String && desc.trim().isNotEmpty) return desc.trim();
      return 'Konten lengkap tidak tersedia saat ini.';
    })();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String content = initial;
        bool loading = false;
        return StatefulBuilder(builder: (c, setC) {
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Column(
                children: [
                  AppBar(
                    title: const Text('Baca - Sumber Asli'),
                    backgroundColor: const Color(0xFFB71C1C),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.open_in_browser),
                        onPressed: () async {
                          final urlString = (widget.article['url'] ?? '').toString();
                          final uri = Uri.tryParse(urlString);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka di browser.')));
                          }
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: loading
                            ? null
                            : () async {
                                setC(() => loading = true);
                                final fetched = await _fetchFullTextFromUrl((widget.article['url'] ?? '').toString());
                                if (fetched.isNotEmpty) setC(() => content = fetched);
                                setC(() => loading = false);
                              },
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: loading
                          ? const Center(child: CircularProgressIndicator())
                          : SingleChildScrollView(
                              child: Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  Future<void> _openInAppWebview(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) throw Exception('invalid url');
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(uri);

    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(
      appBar: AppBar(
        title: const Text('Sumber Asli'),
        backgroundColor: const Color(0xFFB71C1C),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            onPressed: () async {
              if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: controller),
    )));
  }

  Future<void> _reverseGeocode(LatLng coords) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
        'lat': coords.latitude.toString(),
        'lon': coords.longitude.toString(),
        'format': 'json',
      });
      final response = await http.get(uri, headers: {'User-Agent': 'TA_Mobile/1.0'}).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final String? display = data['display_name']?.toString();
        if (display != null && display.isNotEmpty && mounted) {
          setState(() => _displayLocation = display);
        }
      }
    } catch (_) {}
  }

  Future<void> _saveArticle() async {
    try {
      final box = Hive.box('savedNewsBox');
      final String key = (widget.article['url'] as String?) ?? (widget.article['title'] as String?) ?? DateTime.now().toIso8601String();
      // prevent overwriting if already saved with same key
      if (box.containsKey(key)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berita sudah ada di koleksi')));
        return;
      }
      await box.put(key, widget.article);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berita disimpan ke koleksi')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal menyimpan berita')));
    }
  }

  Future<void> _geocodeAndMove(String query) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '1',
      });
      final response = await http
          .get(uri, headers: {'User-Agent': 'TA_Mobile/1.0'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final item = data.first;
          final double lat =
              double.tryParse(item['lat']?.toString() ?? '') ?? _coords.latitude;
          final double lon =
              double.tryParse(item['lon']?.toString() ?? '') ?? _coords.longitude;
          final LatLng newCoords = LatLng(lat, lon);
          final String display = item['display_name']?.toString() ?? query;

          if (!mounted) return;
          setState(() {
            _coords = newCoords;
            _displayLocation = display;
          });
          _mapController.move(newCoords, 11);
        }
      }
    } catch (_) {}
  }

  LatLng _getSourceCoordinates(String sourceName) {
    final s = sourceName.toLowerCase();
    // common mappings (substring match)
    final Map<String, LatLng> known = {
      'bb': const LatLng(51.5072, -0.1276), // bbc
      'bbc': const LatLng(51.5072, -0.1276),
      'reuters': const LatLng(51.5072, -0.1276),
      'guardian': const LatLng(51.5072, -0.1276),
      'the guardian': const LatLng(51.5072, -0.1276),
      'new york times': const LatLng(40.7128, -74.0060),
      'nytimes': const LatLng(40.7128, -74.0060),
      'cnn': const LatLng(33.7490, -84.3880), // Atlanta (CNN HQ)
      'al jazeera': const LatLng(25.2854, 51.5310), // Doha
      'antaranews': const LatLng(-6.2088, 106.8456),
      'antara': const LatLng(-6.2088, 106.8456),
      'detik': const LatLng(-6.2088, 106.8456),
      'jakarta post': const LatLng(-6.2088, 106.8456),
      'kompas': const LatLng(-6.2000, 106.8167),
      'tribun': const LatLng(-6.2000, 106.8167),
      'jawa pos': const LatLng(-6.2000, 106.8167),
      'the straits times': const LatLng(1.3521, 103.8198),
      'eurogamer': const LatLng(51.5072, -0.1276),
      'yahoo': const LatLng(37.3769, -122.0340),
      'tipranks': const LatLng(32.0853, 34.7818),
    };

    for (final entry in known.entries) {
      if (s.contains(entry.key)) return entry.value;
    }
    return const LatLng(0.0, 0.0);
  }

  String _formatPublishedFor(String tzKey) {
    if (_publishedDate == null) {
      // If we have a raw string (unparseable), show it so user sees the info
      if (_publishedRaw != null && _publishedRaw!.isNotEmpty) return _publishedRaw!;
      return '-';
    }

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

    // display as: 11 Oktober 2025 • 00:07 (include time next to date)
    try {
      return DateFormat("d MMMM yyyy '•' HH:mm", 'id').format(shown);
    } catch (_) {
      return DateFormat("d MMMM yyyy '•' HH:mm").format(shown);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.article['title'] ?? 'No Title';
    final String description =
        widget.article['description'] ?? 'Tidak ada deskripsi.';
    final String imageUrl = widget.article['urlToImage'] ?? '';
    final String source = widget.article['source']?['name'] ?? 'Unknown';
    final LatLng coords = _coords;
    final String displayContent = (() {
      final raw = widget.article['content'];
      if (raw is String && raw.trim().isNotEmpty) {
        return raw.replaceAll(RegExp(r'\[\+\d+ chars\]'), '').trim();
      }
      return description;
    })();

    return Scaffold(
      appBar: AppBar(
        title: Text(source, style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFFB71C1C),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_border, color: Colors.white),
            onPressed: _saveArticle,
            tooltip: 'Simpan berita',
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
            onPressed: () {
              // only allow Community Talk for premium users
              if (widget.isPremium) {
                final url = (widget.article['url'] ?? '').toString();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityTalkPage(articleUrl: url, articleTitle: widget.article['title'] ?? ''),
                  ),
                );
              } else {
                // prompt to subscribe
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Community Talk - Premium'),
                    content: const Text('Fitur Community Talk hanya tersedia untuk pelanggan. Ingin berlangganan sekarang?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Batal')),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.star, color: Color(0xFFB71C1C)),
                        label: const Text('Langganan', style: TextStyle(color: Color(0xFFB71C1C))),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFB71C1C)),
                          foregroundColor: const Color(0xFFB71C1C),
                        ),
                        onPressed: () async {
                          // close dialog first then navigate to SubscribePage
                          Navigator.of(ctx).pop();
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const SubscribePage()),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // ======= Main Content (scrollable)
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Gambar + Judul
                Stack(
                  alignment: Alignment.bottomLeft,
                  children: [
                      if (imageUrl.isNotEmpty)
                        Image.network(
                          imageUrl,
                          width: double.infinity,
                          height: 230,
                          fit: BoxFit.cover,
                          // lightweight loadingBuilder to avoid heavy layout jank while image downloads
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return SizedBox(
                              width: double.infinity,
                              height: 230,
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return SizedBox(
                              width: double.infinity,
                              height: 230,
                              child: Container(
                                color: Colors.grey[300],
                                child: const Center(
                                  child: Icon(Icons.broken_image, size: 48, color: Colors.grey),
                                ),
                              ),
                            );
                          },
                        ),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.black.withOpacity(0.5),
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // 🔹 Source + Timezone
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 4,
                                  offset: Offset(0, 2)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.public,
                                      color: Color(0xFFB71C1C), size: 18),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      source,
                                      style: const TextStyle(
                                          color: Color(0xFFB71C1C),
                                          fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _formatPublishedFor(_selectedTz),
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () async {
                          final selected =
                              await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: _tzOffsets.keys
                                    .map((k) => ListTile(
                                          title: Text(k),
                                          onTap: () =>
                                              Navigator.of(ctx).pop(k),
                                        ))
                                    .toList(),
                              ),
                            ),
                          );
                          if (selected != null) {
                            setState(() => _selectedTz = selected);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border:
                                Border.all(color: const Color(0xFFB71C1C)),
                          ),
                          child: Row(
                            children: [
                              Text(_selectedTz,
                                  style: const TextStyle(
                                      color: Color(0xFFB71C1C),
                                      fontWeight: FontWeight.w600)),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_drop_down,
                                  color: Color(0xFFB71C1C)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // 🔹 Lokasi + Peta
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.red),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "Lokasi: ${_displayLocation.isNotEmpty ? _displayLocation : (source.isNotEmpty ? source : 'Tidak diketahui')}",
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 220,
                        child: InkWell(
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              builder: (ctx) {
                                final MapController modalController =
                                    MapController();
                                return SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.85,
                                  child: Scaffold(
                                    appBar: AppBar(
                                      title: Text('Peta: $_displayLocation'),
                                      backgroundColor:
                                          const Color(0xFFB71C1C),
                                    ),
                                    body: FlutterMap(
                                      mapController: modalController,
                                      options: MapOptions(
                                        center: coords,
                                        zoom: 11,
                                      ),
                                      children: [
                                        TileLayer(
                                          urlTemplate:
                                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                          subdomains: ['a', 'b', 'c'],
                                        ),
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: coords,
                                              width: 40,
                                              height: 40,
                                              child: const Icon(
                                                Icons.location_pin,
                                                color: Colors.red,
                                                size: 36,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.map,
                                      size: 36, color: Colors.grey[700]),
                                  const SizedBox(height: 8),
                                  Text('Tampilkan peta',
                                      style: TextStyle(
                                          color: Colors.grey[800])),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 🔹 Deskripsi dan detail lengkap (jika non-premium)
                if (!widget.isPremium)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if ((widget.article['author'] ?? '').toString().isNotEmpty)
                          Text('Author: ${widget.article['author']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        const SizedBox(height: 10),
                        Text(
                          // prefer content if available
                          displayContent,
                          style: const TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.open_in_browser, color: Color(0xFFB71C1C)),
                              label: const Text('Baca Sumber Asli', style: TextStyle(color: Color(0xFFB71C1C))),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: const Color(0xFFB71C1C),
                                side: const BorderSide(color: Color(0xFFB71C1C)),
                                elevation: 0,
                              ),
                              onPressed: () async {
                                final urlString = (widget.article['url'] ?? '').toString();
                                if (urlString.isEmpty) {
                                  _showInlineArticleContent();
                                  return;
                                }
                                try {
                                  await _openInAppWebview(urlString);
                                } catch (_) {
                                  // fallback to inline reader
                                  _showInlineArticleContent();
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

          // ======= Overlay Premium Centered 🔒
          if (widget.isPremium)
            Center(
  child: Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    padding: const EdgeInsets.all(20),
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.red.shade600,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.red.shade900.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.lock, color: Colors.white, size: 40),
        const SizedBox(height: 12),
        const Text(
          'Berita Premium 🔒',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Untuk membaca berita lengkap ini, silakan berlangganan terlebih dahulu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          icon: const Icon(Icons.star, color: Colors.white),
          label: const Text(
            'Langganan Sekarang',
            style: TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 4,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscribePage()),
            );
          },
        ),
      ],
    ),
  ),
),
        ],
      ),
    );
  }
}
