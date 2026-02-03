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
      final labels = await _imageLabeler.processImage(inputImage);
      for (final label in labels) {
        final t = _normalize(label.label);
        if (t.length >= 2) keywords.add(t);
      }

      // IMPORTANT: For google_mlkit_text_recognition ^0.14.0
      final recognizedText = await _textRecognizer.processImage(inputImage);

      for (final block in recognizedText.blocks) {
        final cleaned = _normalize(block.text);
        final tokens = cleaned.split(' ').where((w) => w.length >= 3).toList();
        if (tokens.isEmpty) continue;
        keywords.addAll(tokens.take(25));
      }
    } catch (_) {}

    final unique = keywords.toSet().toList();
    return unique.take(200).join(' ');
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