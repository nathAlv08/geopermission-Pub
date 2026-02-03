import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "REPLACE_WITH_YOURS",
        authDomain: "geotagtime.firebaseapp.com",
        projectId: "geotagtime",
        messagingSenderId: "5698991280",
        appId: "1:5698991280:web:545dc46f8e3408f1ca3775",
        measurementId: "G-87ZL7H9J6F",
      ),
    );
  } catch (e) {
    await Firebase.initializeApp();
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoTagging',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
          secondary: const Color(0xFF004D40),
        ),
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: Color(0xFF00695C),
              fontWeight: FontWeight.bold,
              fontSize: 22
          ),
          iconTheme: IconThemeData(color: Color(0xFF00695C)),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasData) return const HomeScreen();
          return const LoginScreen();
        },
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _auth() async {
    setState(() => _isLoading = true);
    try {
      if (_isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text.trim());
      } else {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: _email.text.trim(), password: _pass.text.trim());
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.location_on, size: 60, color: Color(0xFF00695C)),
              ),
              const SizedBox(height: 24),
              Text(
                _isLogin ? "GeoTagging Masuk" : "Daftar Akun",
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _email,
                decoration: InputDecoration(
                  labelText: "Email",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _pass,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Password",
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _auth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(_isLogin ? "MASUK" : "DAFTAR", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: Text(_isLogin ? "Belum punya akun? Daftar" : "Sudah punya akun? Masuk"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _del(BuildContext context, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hapus Data?"),
        content: const Text("Data ini akan dihapus permanen dari database."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          TextButton(
            onPressed: () {
              FirebaseFirestore.instance.collection('reports').doc(id).delete();
              Navigator.pop(ctx);
            },
            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text("GeoTagging"),
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: "Logout",
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddReportPage())),
        backgroundColor: const Color(0xFF00695C),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add, size: 30),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('reports')
            .where('userId', isEqualTo: user?.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          if (snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade300),
                  const SizedBox(height: 10),
                  Text("Belum ada data tagging", style: TextStyle(color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final d = doc.data() as Map<String, dynamic>;

              Uint8List? imageBytes;
              try {
                if (d['imageBase64'] != null) {
                  imageBytes = base64Decode(d['imageBase64']);
                }
              } catch (e) {
                // ignore
              }

              String timeStr = "-";
              if (d['timestamp'] != null) {
                timeStr = DateFormat('EEEE, d MMM yyyy • HH:mm:ss').format((d['timestamp'] as Timestamp).toDate());
              }

              double? lat = d['latitude'];
              double? long = d['longitude'];
              String coordStr = (lat != null && long != null)
                  ? "$lat, $long"
                  : "Koordinat tidak tersedia";

              return Card(
                elevation: 4,
                shadowColor: Colors.black12,
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          const Icon(Icons.place, color: Colors.redAccent, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d['address'] ?? "Lokasi tidak diketahui",
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.my_location, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      coordStr,
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: () => _del(context, doc.id),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                            ),
                          )
                        ],
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        if (imageBytes != null) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => FullScreenImage(imageBytes: imageBytes!)));
                        }
                      },
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        color: Colors.grey.shade200,
                        child: imageBytes != null
                            ? Hero(
                          tag: doc.id,
                          child: Image.memory(imageBytes, fit: BoxFit.cover),
                        )
                            : const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                      ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(12),
                      width: double.infinity,
                      color: Colors.white,
                      child: Row(
                        children: [
                          const Icon(Icons.access_time_filled, size: 16, color: Color(0xFF00695C)),
                          const SizedBox(width: 8),
                          Text(
                            timeStr,
                            style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FullScreenImage extends StatelessWidget {
  final Uint8List imageBytes;
  const FullScreenImage({super.key, required this.imageBytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text("Detail Foto"),
      ),
      body: Center(
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4.0,
          child: Image.memory(imageBytes),
        ),
      ),
    );
  }
}

class AddReportPage extends StatefulWidget {
  const AddReportPage({super.key});
  @override
  State<AddReportPage> createState() => _AddReportPageState();
}

class _AddReportPageState extends State<AddReportPage> {
  File? _img;
  String _addr = "Sedang mencari lokasi...";
  Position? _currentPosition;
  bool _ready = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Geolocator.requestPermission();
    try {
      Position p = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium);
      List<Placemark> pl = await placemarkFromCoordinates(p.latitude, p.longitude);
      if(mounted) {
        setState(() {
          _currentPosition = p;
          _addr = "${pl[0].street}, ${pl[0].subLocality}, ${pl[0].locality}";
          _ready = true;
        });
        _cam();
      }
    } catch (e) {
      if(mounted) setState(() => _addr = "Gagal mengambil GPS. Pastikan GPS aktif.");
    }
  }

  Future<void> _cam() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(source: ImageSource.camera);
    if (x != null) {
      final dir = await getTemporaryDirectory();
      final target = "${dir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg";

      var res = await FlutterImageCompress.compressAndGetFile(
        x.path,
        target,
        minWidth: 600,
        quality: 40,
      );

      if(mounted) setState(() => _img = File(res!.path));
    }
  }

  Future<void> _saveToDb() async {
    if (_img == null) return;
    setState(() => _loading = true);
    try {
      List<int> imageBytes = await _img!.readAsBytes();
      String base64Image = base64Encode(imageBytes);

      if (base64Image.length > 950000) {
        throw "Ukuran foto terlalu besar untuk database. Silakan ambil ulang.";
      }

      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('reports').add({
        'userId': uid,
        'imageBase64': base64Image,
        'address': _addr,
        'latitude': _currentPosition?.latitude,
        'longitude': _currentPosition?.longitude,
        'timestamp': FieldValue.serverTimestamp()
      });

      if(mounted) Navigator.pop(context);
    } catch(e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
          title: const Text("Ambil Foto"),
          backgroundColor: Colors.black,
          foregroundColor: Colors.white
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _img != null
                  ? Image.file(_img!, fit: BoxFit.contain)
                  : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt, color: Colors.white54, size: 50),
                  SizedBox(height: 10),
                  Text("Menunggu Kamera...", style: TextStyle(color: Colors.white54))
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_pin, color: Color(0xFF00695C)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _addr,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 4),
                          if (_currentPosition != null)
                            Text(
                              "Lat: ${_currentPosition!.latitude}, Long: ${_currentPosition!.longitude}",
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                            )
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: (_ready && !_loading) ? _saveToDb : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00695C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                  ),
                  child: _loading
                      ? const Text("MENYIMPAN DATA...", style: TextStyle(fontWeight: FontWeight.bold))
                      : const Text("SIMPAN DATA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                if (_img != null && !_loading)
                  TextButton(
                    onPressed: _cam,
                    child: const Text("Ambil Ulang Foto"),
                  )
              ],
            ),
          )
        ],
      ),
    );
  }
}