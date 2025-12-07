import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // untuk compute() / debugPrint

class ApiService {
  static const String _apiKey = '99018ae3816a4cc58eca8eb05e74aa69';
  static const String _baseUrl = 'https://newsapi.org/v2';

  final Map<String, List<dynamic>> _cacheTrending = {};
  // cache sederhana untuk hasil geocoding (placeName -> {lat,lng,display_name})
  final Map<String, Map<String, dynamic>> _geocodeCache = {};

  // 🔹 Mapping lokasi sumber berita (LBS)
  static const Map<String, Map<String, dynamic>> _sourceLocations = {
    "bbc-news": {"lat": 51.5072, "lng": -0.1276, "country": "United Kingdom"},
    "cnn": {"lat": 33.7490, "lng": -84.3880, "country": "United States"},
    "kompas": {"lat": -6.2088, "lng": 106.8456, "country": "Indonesia"},
    "al-jazeera-english": {
      "lat": 25.276987,
      "lng": 51.520008,
      "country": "Qatar",
    },
    "reuters": {"lat": 51.5072, "lng": -0.1276, "country": "United Kingdom"},
    "nhk-news": {"lat": 35.6895, "lng": 139.6917, "country": "Japan"},
    "fox-news": {"lat": 40.7128, "lng": -74.0060, "country": "United States"},
    "the-hindu": {"lat": 13.0827, "lng": 80.2707, "country": "India"},
    "abc-news": {"lat": -33.8688, "lng": 151.2093, "country": "Australia"},
  };

  // 🔹 Ambil berita trending (dengan cache)
  Future<List<dynamic>> fetchTrendingNews({String category = 'general'}) async {
    if (_cacheTrending.containsKey(category)) {
      return _cacheTrending[category]!;
    }

    final url = Uri.parse(
      '$_baseUrl/top-headlines?category=$category&pageSize=20&apiKey=$_apiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
  final parsed = await compute(_parseArticles, response.body);
  // limit to 20 items for trending to avoid heavy UI work
  final limited = parsed.take(20).toList();
  // cache immediately so UI can display quickly
  _cacheTrending[category] = limited;
  // start geocode enrichment in background (don't await) to avoid blocking
  // ignore: unawaited_futures
  _enrichArticlesWithGeocode(limited);
  return limited;
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      // gunakan debugPrint agar analyzer tidak mengeluh
      debugPrint('❌ Error fetchTrendingNews($category): $e');
      return [];
    }
  }

  // 🔹 Isolate-safe parser + lokasi otomatis
  static List<dynamic> _parseArticles(String responseBody) {
    final data = json.decode(responseBody) as Map<String, dynamic>;
    final rawArticles = (data['articles'] ?? []) as List<dynamic>;

    // filter artikel yang valid (paling dasar) dan pastikan tiap item menjadi Map<String,dynamic>
    final articles = rawArticles.where((item) {
      if (item is! Map) return false;
      final hasImage = item['urlToImage'] != null && item['urlToImage'].toString().isNotEmpty;
      final hasTitle = item['title'] != null && item['title'].toString().isNotEmpty;
      final hasUrl = item['url'] != null && item['url'].toString().isNotEmpty;
      return hasImage && hasTitle && hasUrl;
    }).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    for (var a in articles) {
      final sourceId = (a['source']?['id']?.toString() ?? '').toLowerCase();
      final url = (a['url'] ?? '').toString().toLowerCase();

      if (_sourceLocations.containsKey(sourceId)) {
        final loc = _sourceLocations[sourceId]!;
        a['lat'] = loc['lat'];
        a['lng'] = loc['lng'];
        a['country'] = loc['country'];
      } else {
        // fallback pakai domain
        if (url.contains('cnn')) {
          a['lat'] = 33.7490;
          a['lng'] = -84.3880;
          a['country'] = 'United States';
        } else if (url.contains('bbc')) {
          a['lat'] = 51.5072;
          a['lng'] = -0.1276;
          a['country'] = 'United Kingdom';
        } else if (url.contains('kompas')) {
          a['lat'] = -6.2088;
          a['lng'] = 106.8456;
          a['country'] = 'Indonesia';
        } else if (url.contains('nhk')) {
          a['lat'] = 35.6895;
          a['lng'] = 139.6917;
          a['country'] = 'Japan';
        } else if (url.contains('aljazeera') || url.contains('al-jazeera')) {
          a['lat'] = 25.276987;
          a['lng'] = 51.520008;
          a['country'] = 'Qatar';
        } else if (url.contains('reuters')) {
          a['lat'] = 51.5072;
          a['lng'] = -0.1276;
          a['country'] = 'United Kingdom';
        } else {
          a['lat'] = null;
          a['lng'] = null;
          a['country'] = 'Unknown';
        }
      }
    }

    return articles.take(30).toList();
  }

  // 🔹 Currency rate (USD ke mata uang lain)
  Future<double> getExchangeRate(String currency) async {
    try {
      final target = currency.toUpperCase();
      if (target == "USD") return 1.0;
      final url = Uri.parse(
        'https://api.exchangerate.host/latest?base=USD&symbols=$target',
      );

      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final rates = data['rates'] as Map<String, dynamic>?;
        if (rates != null && rates[target] != null) {
          final v = rates[target];
          if (v is num) return v.toDouble();
        }
      }
      return 1.0;
    } catch (e) {
      debugPrint('❌ getExchangeRate error: $e');
      return 1.0;
    }
  }

  // 🔹 Regular news (home page)
  Future<List<dynamic>> fetchNews({String query = "technology"}) async {
    final url = Uri.parse(
      '$_baseUrl/everything?q=$query&sortBy=popularity&pageSize=30&apiKey=$_apiKey',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final parsed = await compute(_parseArticles, response.body);
        // cache immediately and enrich in background to avoid blocking UI
        // (home page queries can be heavier, so do not await geocode)
        final limited = parsed.take(20).toList();
        // ignore: unawaited_futures
        _enrichArticlesWithGeocode(limited);
        return parsed;
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error fetchNews: $e');
      return [];
    }
  }

  // Enrich articles list by geocoding available location strings.
  // This runs on the main isolate (network + cache) to avoid network in compute isolate.
  Future<void> _enrichArticlesWithGeocode(List<dynamic> articles) async {
    // sequentially to be polite to Nominatim (avoid rate limits); can be batched if you have a paid geocoder
    for (var a in articles) {
      try {
        if (a is! Map<String, dynamic>) continue;
        // if already have valid lat/lng skip
        final hasLat = a['lat'] is num && a['lng'] is num;
        if (hasLat) continue;

        // try explicit location field first
        final String? place = (a['location'] as String?) ?? '';
        Map<String, dynamic>? geo;
        if (place != null && place.isNotEmpty) {
          geo = await _geocodePlace(place);
        }

        // if not found, try source name (last resort)
        if (geo == null) {
          final sourceName = a['source']?['name'] as String? ?? '';
          if (sourceName.isNotEmpty) {
            geo = await _geocodePlace(sourceName);
          }
        }

        if (geo != null) {
          a['lat'] = geo['lat'];
          a['lng'] = geo['lng'];
          a['geocoded_place'] = geo['display_name'] ?? '';
        } else {
          // leave existing fallback (possibly null) — UI should handle Unknown
        }
        // small delay to avoid hammering free geocoders
        await Future.delayed(const Duration(milliseconds: 250));
      } catch (e) {
        debugPrint('❌ enrichArticles error: $e');
      }
    }
  }

  // Geocode a place name using Nominatim; uses simple in-memory cache.
  Future<Map<String, dynamic>?> _geocodePlace(String place) async {
    final key = place.trim().toLowerCase();
    if (_geocodeCache.containsKey(key)) return _geocodeCache[key];

    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': place,
        'format': 'json',
        'limit': '1',
      });
      final resp = await http.get(uri, headers: {'User-Agent': 'TA_Mobile/1.0 (dev@yourdomain.com)'}).timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final List<dynamic> data = json.decode(resp.body) as List<dynamic>;
        if (data.isNotEmpty) {
          final item = data.first as Map<String, dynamic>;
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lon = double.tryParse(item['lon']?.toString() ?? '');
          final display = item['display_name']?.toString() ?? '';
          if (lat != null && lon != null) {
            final result = {'lat': lat, 'lng': lon, 'display_name': display};
            _geocodeCache[key] = result;
            return result;
          }
        }
      }
    } catch (e) {
      debugPrint('❌ geocodePlace error for "$place": $e');
    }
    return null;
  }
}
