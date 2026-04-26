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
      await _storage.saveHistory({
        'id': 'TXT_${DateTime.now().millisecondsSinceEpoch}',
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
      await _storage.saveHistory({
        'id': 'IMG_${DateTime.now().millisecondsSinceEpoch}',
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
      await _storage.saveHistory({
        'id': 'PDF_${DateTime.now().millisecondsSinceEpoch}',
        'type': 'pdf_print',
        'file_name': filePath.split('/').last,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    return allBytes;
  }

  Future<List<int>> generateAwbTicket(Map<String, dynamic> data) async {
    final profile = await CapabilityProfile.load();
    final paperSize = await _getPaperSizeEnum();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Header
    bytes += generator.text('PANTAS PRINT', styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    bytes += generator.text('AIRWAY BILL', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.feed(1);
    
    // AWB ID & Date
    bytes += generator.text('ID: ${data['airway_id']}', styles: const PosStyles(bold: true));
    bytes += generator.text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(data['created_at']))}');
    bytes += generator.hr();

    // Sender Info
    bytes += generator.text('FROM (SENDER):', styles: const PosStyles(bold: true));
    bytes += generator.text(data['sender_name'].toString().toUpperCase());
    bytes += generator.feed(1);

    // Recipient Info
    bytes += generator.text('TO (RECIPIENT):', styles: const PosStyles(bold: true));
    bytes += generator.text(data['recipient']['name'].toString().toUpperCase(), styles: const PosStyles(bold: true));
    bytes += generator.text('Tel: ${data['recipient']['phone']}');
    bytes += generator.text('Address:', styles: const PosStyles(bold: true));
    bytes += generator.text(data['recipient']['address'].toString().toUpperCase());
    bytes += generator.hr();

    // QR Code for Handover
    bytes += generator.text('SECURE HANDOVER QR', styles: const PosStyles(align: PosAlign.center, bold: true));
    bytes += generator.qrcode(data['airway_id'], size: QRSize.size4);
    bytes += generator.feed(1);
    bytes += generator.text('Scan to update status', styles: const PosStyles(align: PosAlign.center));
    
    bytes += generator.hr();
    if (data['reference'] != null && data['reference'].toString().isNotEmpty) {
      bytes += generator.text('REF: ${data['reference']}');
    }
    bytes += generator.text('--- Watermark: PANTAS PRINT ---', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(2);
    bytes += generator.cut();

    // Save to History
    await _storage.saveHistory({
      ...data,
      'id': data['airway_id'],
      'type': 'secure_handover',
    });

    return bytes;
  }
}
