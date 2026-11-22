// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final fontFile = File(r'C:\Windows\Fonts\segoeui.ttf');
    if (fontFile.existsSync()) {
      final fontData = fontFile.readAsBytesSync();
      final fontLoader = FontLoader('Segoe UI');
      fontLoader.addFont(Future.value(ByteData.view(fontData.buffer)));
      await fontLoader.load();
      print('Loaded Segoe UI font for real glyph rendering in tests!');
    }
  });

  final pages = [
    ('first_floor.svg', 'page_0_first_floor_flutter.png'),
    ('ground_floor_warehouses.svg', 'page_1_ground_floor_flutter.png'),
    ('security_gates.svg', 'page_2_security_gates_flutter.png'),
  ];

  for (final entry in pages) {
    test('Render ${entry.$1} with flutter_svg to image', () async {
      final file = File('assets/topology/rnf/pages/${entry.$1}');
      final content = file.readAsStringSync();

      final pictureInfo = await vg.loadPicture(SvgStringLoader(content), null);
      final picture = pictureInfo.picture;
      final size = pictureInfo.size;
      print('${entry.$1} parsed size: $size');

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      // Dedicated dark blueprint background
      canvas.drawRect(
        ui.Rect.fromLTWH(0, 0, size.width, size.height),
        ui.Paint()..color = const ui.Color(0xFF0B111E),
      );

      // Draw SVG picture
      canvas.drawPicture(picture);

      final finalPicture = recorder.endRecording();
      final image = await finalPicture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      final outDir = Directory('test/features/network_blueprint/renders');
      if (!outDir.existsSync()) outDir.createSync(recursive: true);
      final outFile = File('test/features/network_blueprint/renders/${entry.$2}');
      outFile.writeAsBytesSync(byteData!.buffer.asUint8List());
      print('Saved rendered SVG image to ${outFile.path} (${outFile.lengthSync()} bytes)');
      expect(outFile.existsSync(), isTrue);
      expect(outFile.lengthSync(), greaterThan(10000));
    });
  }
}
