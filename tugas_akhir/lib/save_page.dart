import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'detail_page.dart';

class SavePage extends StatefulWidget {
  const SavePage({super.key});

  @override
  State<SavePage> createState() => _SavePageState();
}

class _SavePageState extends State<SavePage> {
  late Box _box;

  @override
  void initState() {
    super.initState();
    _box = Hive.box('savedNewsBox');
  }

  void _remove(String key) {
    _box.delete(key);
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dihapus dari koleksi')));
  }

  @override
  Widget build(BuildContext context) {
    final keys = _box.keys.toList().reversed.toList(); // newest first

    return Scaffold(
      appBar: AppBar(
        title: const Text('Koleksi Berita'),
        backgroundColor: const Color(0xFFC92E36),
      ),
      body: keys.isEmpty
          ? const Center(child: Text('Belum ada berita tersimpan.'))
          : ListView.builder(
              itemCount: keys.length,
              itemBuilder: (context, index) {
                final key = keys[index];
                final dynamic raw = _box.get(key);
                Map<String, dynamic> article;
                if (raw is String) {
                  article = Map<String, dynamic>.from(json.decode(raw) as Map<String, dynamic>);
                } else if (raw is Map) {
                  article = Map<String, dynamic>.from(raw);
                } else {
                  article = {'title': 'Unknown', 'urlToImage': null, 'source': {'name': 'Unknown'}};
                }

                final image = article['urlToImage'] as String?;
                final title = article['title'] ?? 'No title';
                final source = article['source']?['name'] ?? '';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: ListTile(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DetailPage(article: article, isPremium: false)),
                      );
                    },
                    leading: image != null
                        ? CachedNetworkImage(
                            imageUrl: image,
                            width: 72,
                            height: 56,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(color: Colors.grey[300], width: 72, height: 56),
                            errorWidget: (c, u, e) => Container(color: Colors.grey[300], width: 72, height: 56, child: const Icon(Icons.broken_image, color: Colors.grey)),
                          )
                        : Container(width: 72, height: 56, color: Colors.grey[300], child: const Icon(Icons.image_not_supported)),
                    title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: Text(source, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _remove(key.toString()),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
