import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AiService {
  late final ImageLabeler _imageLabeler;
  late final TextRecognizer _textRecognizer;

  AiService() {
    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.7),
    );
    _textRecognizer = TextRecognizer();
  }

  Future<String> analyzeImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);

    final keywords = <String>[];

    try {
      // 1) Object labels
      final labels = await _imageLabeler.processImage(inputImage);
      for (final label in labels) {
        final t = _normalize(label.label);
        if (t.length >= 2) keywords.add(t);
      }

      // 2) OCR text
      final recognizedText = await _textRecognizer.processImage(inputImage);

      for (final block in recognizedText.blocks) {
        final cleaned = _normalize(block.text);

        // Break into tokens to reduce huge noise blocks
        final tokens = cleaned.split(' ').where((w) => w.length >= 3).toList();
        if (tokens.isEmpty) continue;

        // Add some tokens (limit to avoid huge DB)
        // Example: keep only first 25 tokens per block
        keywords.addAll(tokens.take(25));
      }
    } catch (e) {
      // ignore errors per file
    }

    // Remove duplicates
    final unique = keywords.toSet().toList();

    // Limit total keyword count (keeps DB small + fast)
    final limited = unique.take(200).toList();

    return limited.join(' ');
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  void dispose() {
    _imageLabeler.close();
    _textRecognizer.close();
  }
}