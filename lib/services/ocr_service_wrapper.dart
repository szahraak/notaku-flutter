import 'hybrid_ocr_service.dart';
import 'cloud_ocr_service.dart';

/// Unified OCR Service dengan hybrid approach:
/// 1. Always: Extract text dengan Google ML Kit (offline)
/// 2. If internet: Try improve dengan Cloud AI (graceful fallback)
/// 3. If no internet / Cloud AI fails: Use local ML Kit result
class OcrServiceWrapper {
  final _localOcr = HybridOcrService();
  final _cloudOcr = CloudOcrService();
  bool _useCloudAI = true; // Can be toggled from settings

  /// Enable/disable Cloud AI integration
  void setCloudAIEnabled(bool enabled) {
    _useCloudAI = enabled;
  }

  /// Main OCR method: Local first, Cloud optional
  Future<OcrResult> extractAndCorrectText(String imagePath) async {
    print('\n📱 Starting OCR extraction...');
    
    // Step 1: Always extract locally (offline)
    final localResult = await _localOcr.extractText(imagePath);
    print('✅ Local OCR complete (${localResult.text.length} chars)');

    // Step 2: Try to improve dengan Cloud AI (jika enabled & internet)
    if (_useCloudAI) {
      final improvedText = await _cloudOcr.correctOCRWithCloudAI(localResult.text);
      
      if (improvedText != null) {
        // Cloud AI berhasil improve
        print('🌐 Cloud AI improved the text');
        return OcrResult(
          text: improvedText,
          confidence: (localResult.confidence * 0.95) + 0.05, // Boost confidence sedikit
          usedFallback: false,
          usedCloudAI: true,
        );
      } else {
        // Cloud AI tidak available / timeout
        print('📡 Cloud AI unavailable - using local result');
        return localResult;
      }
    }

    // Cloud AI disabled
    return localResult;
  }

  void dispose() => _localOcr.dispose();
}
