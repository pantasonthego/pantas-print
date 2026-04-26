import 'dart:io';
import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';
import 'package:pdfx/pdfx.dart';
import 'storage_service.dart';

class PrintService {
  final StorageService _storage = StorageService();

  Future<int> _getPaperWidth() async {
    String size = await _storage.getPaperSize();
    if (size.contains('100mm')) return 800;
    if (size.contains('80mm')) return 576;
    return 384;
  }

  Future<PaperSize> _getPaperSizeEnum() async {
    String size = await _storage.getPaperSize();
    if (size.contains('80mm') || size.contains('100mm')) return PaperSize.mm80;
    return PaperSize.mm58;
  }

  Future<List<int>> generateTextTicket(String text, {bool saveHistory = true}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = await _getPaperSizeEnum();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.text('PANTAS PRINT',
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.feed(1);
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(1);
    bytes += generator.text(text, styles: const PosStyles(align: PosAlign.left));
    bytes += generator.feed(2);
    bytes += generator.text('--- Watermark: PANTAS PRINT ---',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.cut();

    if (saveHistory) {
      await _storage.saveAirwayBill({
        'airway_id': 'TXT_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'text_print',
        'content': text,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return bytes;
  }

  Future<List<int>> generateImageTicket(Uint8List imageBytes, {bool saveHistory = true}) async {
    final profile = await CapabilityProfile.load();
    final paperSize = await _getPaperSizeEnum();
    final targetWidth = await _getPaperWidth();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    img.Image? image = img.decodeImage(imageBytes);
    if (image == null) return [];

    image = img.copyResize(image, width: targetWidth);
    image = img.grayscale(image);

    bytes += generator.text('PANTAS PRINT', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);
    bytes += generator.imageRaster(image);
    bytes += generator.feed(1);
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}',
        styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('--- Watermark: PANTAS PRINT ---', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.cut();

    if (saveHistory) {
      await _storage.saveAirwayBill({
        'airway_id': 'IMG_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'image_print',
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return bytes;
  }

  Future<List<int>> generatePdfTicket(String filePath, {bool saveHistory = true}) async {
    final document = await PdfDocument.openFile(filePath);
    final targetWidth = await _getPaperWidth();
    List<int> allBytes = [];
    
    for (int i = 1; i <= document.pagesCount; i++) {
      final page = await document.getPage(i);
      final pageImage = await page.render(
        width: targetWidth.toDouble(),
        height: page.height * (targetWidth / page.width),
        format: PdfPageImageFormat.png,
      );
      if (pageImage != null) {
        final bytes = await generateImageTicket(pageImage.bytes, saveHistory: false);
        allBytes.addAll(bytes);
      }
      await page.close();
    }
    await document.close();

    if (saveHistory) {
      await _storage.saveAirwayBill({
        'airway_id': 'PDF_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'pdf_print',
        'file_name': filePath.split('/').last,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return allBytes;
  }
}
