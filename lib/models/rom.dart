import 'dart:io';
import 'package:path/path.dart' as p;

const Set<String> kRomExtensions = {'.z64', '.n64', '.v64', '.zip'};

bool isRomFile(String filePath) =>
    kRomExtensions.contains(p.extension(filePath).toLowerCase());

class Rom {
  Rom({required this.path, this.sizeBytes});

  final String path;
  final int? sizeBytes;

  String get fileName => p.basename(path);

  String get displayName => p.basenameWithoutExtension(path);

  String get format => p.extension(path).replaceFirst('.', '').toUpperCase();

  double get sizeMegabytes => (sizeBytes ?? 0) / (1024 * 1024);

  bool get exists => File(path).existsSync();

  factory Rom.fromFile(File file) =>
      Rom(path: file.path, sizeBytes: file.existsSync() ? file.lengthSync() : null);

  Map<String, dynamic> toJson() => {'path': path, 'size': sizeBytes};

  factory Rom.fromJson(Map<String, dynamic> json) =>
      Rom(path: json['path'] as String, sizeBytes: json['size'] as int?);
}
