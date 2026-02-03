import 'dart:io';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class AiService {
  late ImageLabeler _imageLabeler;
  late TextRecognizer _textRecognizer;

  AiService() {
    // Initialize the AI models
    // Confidence threshold 0.7 means "Only tell me if you are 70% sure"
    _imageLabeler = ImageLabeler(
      options: ImageLabelerOptions(confidenceThreshold: 0.7),
    );
    _textRecognizer = TextRecognizer();
  }

  /// Takes a file and returns a string of keywords (e.g., "car road wifi password")
  Future<String> analyzeImage(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    List<String> keywords = [];

    try {
      // 1. Detect Objects (Scene understanding)
      final labels = await _imageLabeler.processImage(inputImage);
      for (var label in labels) {
        keywords.add(label.label.toLowerCase());
      }

      // 2. Read Text (OCR for screenshots/documents)
      final recognizedText = await _textRecognizer.processText(inputImage);
      for (var block in recognizedText.blocks) {
        // Only add text if it's long enough to be useful (avoids random noise)
        if (block.text.length > 3) {
          keywords.add(block.text.toLowerCase());
        }
      }
    } catch (e) {
      print("AI Error for ${imageFile.path}: $e");
    }

    // Combine everything into one searchable string
    return keywords.join(" ");
  }

  void dispose() {
    _imageLabeler.close();
    _textRecognizer.close();
  }
}