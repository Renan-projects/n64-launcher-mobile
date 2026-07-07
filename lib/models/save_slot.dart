class SaveSlot {
  SaveSlot({
    required this.index,
    required this.isAuto,
    this.filePath,
    this.thumbnailPath,
    this.modified,
    this.sizeBytes,
  });

  final int index;
  final bool isAuto;
  final String? filePath;
  final String? thumbnailPath;
  final DateTime? modified;
  final int? sizeBytes;

  bool get isEmpty => filePath == null;

  factory SaveSlot.fromJson(Map<String, dynamic> json) => SaveSlot(
        index: json['index'] as int,
        isAuto: json['isAuto'] as bool? ?? false,
        filePath: json['filePath'] as String?,
        thumbnailPath: json['thumbnailPath'] as String?,
        modified: json['modified'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(json['modified'] as int),
        sizeBytes: json['sizeBytes'] as int?,
      );
}
