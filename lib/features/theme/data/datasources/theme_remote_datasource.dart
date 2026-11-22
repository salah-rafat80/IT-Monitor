import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/palette_entity.dart';
import '../models/palette_model.dart';

abstract class ThemeRemoteDataSource {
  Future<PaletteModel> fetchRemotePalette({String? url});
}

@LazySingleton(as: ThemeRemoteDataSource)
class ThemeRemoteDataSourceImpl implements ThemeRemoteDataSource {
  final Dio _dio;

  ThemeRemoteDataSourceImpl()
      : _dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3)));

  @override
  Future<PaletteModel> fetchRemotePalette({String? url}) async {
    if (url == null || url.trim().isEmpty) {
      return PaletteModel.fromEntity(PaletteEntity.defaultPalette);
    }
    try {
      final response = await _dio.get<dynamic>(url);
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data is String
            ? jsonDecode(response.data as String) as Map<String, dynamic>
            : response.data as Map<String, dynamic>;
        return PaletteModel.fromJson(data);
      }
    } catch (_) {
      // Fallback gracefully on network / parsing error
    }
    return PaletteModel.fromEntity(PaletteEntity.defaultPalette);
  }
}
