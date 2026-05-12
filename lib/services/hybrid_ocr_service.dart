import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'fuzzy_matcher.dart';

class HybridOcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract text dengan hybrid approach: ML Kit + fuzzy correction + quality analysis
  Future<OcrResult> extractText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    
    // Primary: Google ML Kit dengan bounding box analysis
    final recognizedText = await _recognizer.processImage(inputImage);
    
    print('\n=== OCR SERVICE: Processing with bounding boxes ===');
    
    // Reconstructed text lebih baik dari simple concatenation
    final reconstructed = _reconstructTextWithBoundingBoxes(recognizedText);
    
    // Analisis quality
    final confidence = FuzzyMatcher.analyzeQuality(reconstructed);
    print('📊 Text quality score: ${(confidence * 100).toStringAsFixed(1)}%');
    
    // Apply fuzzy correction jika confidence rendah
    String finalText = reconstructed;
    if (confidence < 0.9) {
      print('⚠️ Low confidence - applying fuzzy corrections...');
      finalText = _applyFuzzyCorrections(reconstructed);
    }
    
    return OcrResult(
      text: finalText,
      confidence: confidence,
      usedFallback: false, // All using ML Kit, fallback untuk future
    );
  }

  /// Reconstruct text menggunakan bounding box info untuk better layout
  String _reconstructTextWithBoundingBoxes(RecognizedText recognizedText) {
    // Group blocks by Y coordinate (roughly same line)
    final blocks = recognizedText.blocks;
    if (blocks.isEmpty) return '';

    // Sort blocks by Y then X untuk natural reading order
    final sorted = List<TextBlock>.from(blocks);
    sorted.sort((a, b) {
      final yDiff = (a.boundingBox.top - b.boundingBox.top).abs();
      
      // If Y coordinates are close (within 5px), sort by X
      if (yDiff < 5) {
        return a.boundingBox.left.compareTo(b.boundingBox.left);
      }
      return a.boundingBox.top.compareTo(b.boundingBox.top);
    });

    // Reconstruct dengan smart spacing
    final lines = <String>[];
    final currentLine = <String>[];
    double? lastY;

    for (final block in sorted) {
      final y = block.boundingBox.top;
      
      // Detect line change (Y coordinate difference > threshold)
      if (lastY != null && (y - lastY).abs() > 5) {
        // Save current line
        if (currentLine.isNotEmpty) {
          lines.add(currentLine.join(' '));
          currentLine.clear();
        }
      }

      // Add text to current line
      if (block.text.isNotEmpty) {
        currentLine.add(block.text);
      }
      lastY = y;
    }

    // Add final line
    if (currentLine.isNotEmpty) {
      lines.add(currentLine.join(' '));
    }

    final result = lines.join('\n');
    print('✅ Reconstructed ${lines.length} lines from bounding boxes');
    return result;
  }

  /// Apply universal OCR error corrections (tidak store-specific)
  String _applyFuzzyCorrections(String text) {
    var corrected = text;

    // ONLY universal OCR errors that happen in ANY receipt:
    // - Digit/letter confusion (0 vs O, 1 vs l, etc)
    // - Common misrecognitions regardless of content
    final corrections = [
      // Digit-letter confusion
      (RegExp(r'\b0O(?=[A-Z])'), 'OO'),  // 0O → OO at word boundary
      
      // Currency/price formatting - standardize spacing
      (RegExp(r'(\d+)\s{2,}\.(\d+)'), r'$1.$2'), // Multiple spaces around decimal
      (RegExp(r'RP\s+\.'), 'RP.'), // "RP ." → "RP."
      
      // Generic text spacing issues
      (RegExp(r'\s{2,}'), ' '), // Multiple spaces → single space (for inline text)
    ];

    for (final (pattern, replacement) in corrections) {
      corrected = corrected.replaceAll(pattern, replacement);
    }

    print('🔧 Applied ${corrections.length} universal OCR corrections');
    return corrected;
  }

  void dispose() => _recognizer.close();
}

/// Result dari OCR extraction (local + optional cloud)
class OcrResult {
  final String text;
  final double confidence; // 0.0 - 1.0
  final bool usedFallback;
  final bool usedCloudAI; // Track jika Cloud AI digunakan untuk improvement

  OcrResult({
    required this.text,
    required this.confidence,
    required this.usedFallback,
    this.usedCloudAI = false,
  });
}
