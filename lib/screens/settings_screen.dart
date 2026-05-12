import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/cloud_ocr_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;
  bool _useCloudAI = true;
  bool _apiKeyValid = false;
  bool _isValidating = false;
  final _cloudOcrService = CloudOcrService();

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('gemini_api_key') ?? '';
    final useCloudAI = prefs.getBool('use_cloud_ai') ?? true;

    setState(() {
      _apiKeyController.text = apiKey;
      _useCloudAI = useCloudAI;
      _apiKeyValid = apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY';
    });
  }

  Future<void> _validateAndSaveApiKey() async {
    if (_apiKeyController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API key tidak boleh kosong')),
      );
      return;
    }

    setState(() => _isValidating = true);

    final isValid = await _cloudOcrService.validateApiKey(_apiKeyController.text);

    setState(() => _isValidating = false);

    if (!isValid) {
      // Show detailed error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('❌ API Key Tidak Valid'),
            content: const SingleChildScrollView(
              child: Text(
                'Kemungkinan masalah:\n\n'
                '1. API key tidak sesuai - periksa dari https://aistudio.google.com/app/apikey\n\n'
                '2. Generative Language API belum diaktifkan:\n'
                '   - Buka Google Cloud Console\n'
                '   - Search "Generative Language API"\n'
                '   - Click "Enable"\n\n'
                '3. API key ada restrictions:\n'
                '   - Di Cloud Console, edit API key\n'
                '   - Pastikan tidak ada application/website restrictions\n\n'
                '4. Check console untuk error detail\n\n'
                'Coba lagi atau hubungi support.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Save to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('gemini_api_key', _apiKeyController.text);

    setState(() => _apiKeyValid = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ API key berhasil disimpan!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _saveCloudAISetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_cloud_ai', _useCloudAI);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cloud AI Toggle
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '☁️ Cloud AI Enhancement',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gunakan Cloud AI untuk improve OCR accuracy (hanya jika ada internet)',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Aktifkan Cloud AI'),
                        Switch(
                          value: _useCloudAI,
                          onChanged: (value) {
                            setState(() => _useCloudAI = value);
                            _saveCloudAISetting();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Gemini API Key Configuration
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔑 Google Gemini API Key',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Gratis 60 request/menit. Dapatkan di: https://aistudio.google.com/app/apikey',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // API Key Input
                    TextField(
                      controller: _apiKeyController,
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Paste API key Anda di sini',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        suffix: _apiKeyValid
                            ? const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text('✅', style: TextStyle(fontSize: 16)),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Validate Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isValidating ? null : _validateAndSaveApiKey,
                        icon: _isValidating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isValidating ? 'Validating...' : 'Validasi & Simpan'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '📋 Cara Kerja:',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '1. App selalu extract text lokal (offline) dengan Google ML Kit\n'
                      '2. Jika Cloud AI enabled & ada internet → improve hasil dengan AI\n'
                      '3. Jika no internet / Cloud AI error → gunakan hasil lokal\n\n'
                      'Tidak ada data yang dikirim ke cloud jika internet tidak tersedia!',
                      style: TextStyle(fontSize: 12),
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
