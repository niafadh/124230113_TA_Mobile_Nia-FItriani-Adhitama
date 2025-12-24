import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'feedback_page.dart';
import 'login_page.dart';
import 'save_page.dart';
import 'premium_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  File? _imageFile;
  final picker = ImagePicker();

  String fullName = "Loading...";
  String email = "Loading...";
  String phone = "-";
  String major = "Information Systems";
  
  bool _isPremium = false;
  DateTime? _expireDate;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // 🔹 Load data user, status premium, DAN foto profil
  void _loadUserData() {
    final box = Hive.box('userBox');
    final user = box.get('user'); // Ambil user yang sedang aktif login
    
    if (user != null) {
      final userEmail = user['email'] ?? "No Email";
      
      setState(() {
        fullName = user['name'] ?? "No Name";
        email = userEmail;
      });

      // 1. Cek Status Premium
      _checkPremiumStatus();

      // 2. Load Foto Profil Khusus Email Ini
      _loadProfileImage(userEmail);
    }
  }

  void _checkPremiumStatus() {
    final status = PremiumHelper.isPremiumActive(email);
    final expire = PremiumHelper.getExpireDate(email);
    setState(() {
      _isPremium = status;
      _expireDate = expire;
    });
  }

  // 🔹 Logika Load Foto dari Hive berdasarkan Email
  void _loadProfileImage(String userEmail) {
    final box = Hive.box('userBox');
    // Ambil path foto dengan key unik: 'profile_image_email@domain.com'
    final String? imagePath = box.get('profile_image_$userEmail');
    
    if (imagePath != null) {
      final file = File(imagePath);
      if (file.existsSync()) {
        setState(() {
          _imageFile = file;
        });
      }
    } else {
      // Jika tidak ada data, pastikan kosong (biar gak nyangkut foto akun lain)
      setState(() {
        _imageFile = null;
      });
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });

      // 🔹 Simpan path foto ke Hive agar permanen untuk akun ini
      final box = Hive.box('userBox');
      // Key-nya pakai email biar unik per user
      await box.put('profile_image_$email', pickedFile.path);
    }
  }

  void _editProfile() {
    final nameController = TextEditingController(text: fullName);
    final phoneController = TextEditingController(text: phone);
    final majorController = TextEditingController(text: major);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Edit Profil", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Nama Lengkap"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Nomor HP"),
              ),
              TextField(
                controller: majorController,
                decoration: const InputDecoration(labelText: "Jurusan / Program Studi"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Batal", style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                fullName = nameController.text;
                phone = phoneController.text;
                major = majorController.text;
              });
              
              // Update nama ke Hive userBox (session aktif)
              final box = Hive.box('userBox');
              final currentUser = box.get('user');
              
              if (currentUser != null) {
                // Update data sesi aktif
                final updatedUser = {
                  'name': fullName,
                  'email': email,
                  'password': currentUser['password']
                };
                box.put('user', updatedUser);
                
                // Update juga data di "database akun" (key = email)
                // Supaya kalau logout & login lagi, namanya tetap yang baru
                box.put(email, updatedUser);
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC92E36)),
            child: const Text("Simpan", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _logout() {
    // Opsional: Hapus sesi aktif 'user' biar bersih
    final box = Hive.box('userBox');
    box.delete('user'); 

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    const mainColor = Color(0xFFC92E36);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 56, 56),
      appBar: AppBar(
        title: const Text(
          "Profile",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: mainColor,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        children: [
          // 隼 Header foto profil
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                // 🔹 LOGIKA GAMBAR PROFIL BARU
                CircleAvatar(
                  radius: 65,
                  backgroundColor: Colors.grey.shade200, // Warna background kalau kosong
                  // Jika ada file gambar -> Tampilkan FileImage
                  // Jika TIDAK ada -> Tampilkan null (biar child Icon muncul)
                  backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                  child: _imageFile == null
                      ? const Icon(Icons.person, size: 65, color: Colors.grey) // Placeholder default
                      : null,
                ),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: mainColor,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          
          // 隼 Info user
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                    ),
                    if (_isPremium) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Colors.blue, size: 20),
                    ]
                  ],
                ),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.black54)),
                
                // 🔹 STATUS PREMIUM CARD
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isPremium ? const Color.fromARGB(255, 65, 80, 215) : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isPremium ? const Color.fromARGB(255, 62, 16, 214) : Colors.grey.shade400,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _isPremium ? "Premium Member 👑" : "Free Account",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isPremium ? Colors.amber.shade900 : Colors.grey.shade700,
                        ),
                      ),
                      if (_isPremium && _expireDate != null)
                        Text(
                          "Exp: ${DateFormat('dd MMM yyyy').format(_expireDate!)}",
                          style: TextStyle(
                            fontSize: 12,
                            color: _isPremium ? Colors.amber.shade900 : Colors.grey.shade700,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),
                Text(major, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w500)),
                Text(phone, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 25),

          // 隼 Menu aksi
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 94, 42, 42),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 2)),
              ],
            ),
            child: Column(
              children: [
                _buildMenuItem(
                  icon: Icons.edit,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  title: "Edit Profil",
                  onTap: _editProfile,
                ),
                const Divider(height: 1),
                _buildMenuItem(
                  icon: Icons.message,
                  color: const Color.fromARGB(255, 255, 250, 250),
                  title: "Kesan & Pesan Mata Kuliah",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const FeedbackPage()),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildMenuItem(
                  icon: Icons.bookmark,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  title: "Koleksi Berita Tersimpan",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavePage()),
                    );
                  },
                ),
                const Divider(height: 1),
                _buildMenuItem(
                  icon: Icons.logout,
                  color: const Color.fromARGB(255, 255, 255, 255),
                  title: "Logout",
                  onTap: _logout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}