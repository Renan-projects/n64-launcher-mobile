import 'package:flutter/material.dart';

class AppSettings {
  const AppSettings({
    this.localeCode,
    this.themeMode = ThemeMode.dark,
    this.showTouchControls = true,
    this.controlsOpacity = 0.55,
    this.haptics = true,
    this.integerScaling = false,
    this.controlLayout = const {},
  });

  final String? localeCode;
  final ThemeMode themeMode;
  final bool showTouchControls;
  final double controlsOpacity;
  final bool haptics;
  final bool integerScaling;

  /// Per-element position/size overrides for the touch controls, keyed by
  /// element id. Each value is [x, y, w, h], relative (0..1). Empty = defaults.
  final Map<String, List<double>> controlLayout;

  Locale? get locale => localeCode == null ? null : Locale(localeCode!);

  AppSettings copyWith({
    String? localeCode,
    bool clearLocale = false,
    ThemeMode? themeMode,
    bool? showTouchControls,
    double? controlsOpacity,
    bool? haptics,
    bool? integerScaling,
    Map<String, List<double>>? controlLayout,
  }) =>
      AppSettings(
        localeCode: clearLocale ? null : (localeCode ?? this.localeCode),
        themeMode: themeMode ?? this.themeMode,
        showTouchControls: showTouchControls ?? this.showTouchControls,
        controlsOpacity: controlsOpacity ?? this.controlsOpacity,
        haptics: haptics ?? this.haptics,
        integerScaling: integerScaling ?? this.integerScaling,
        controlLayout: controlLayout ?? this.controlLayout,
      );

  Map<String, dynamic> toJson() => {
        'localeCode': localeCode,
        'themeMode': themeMode.name,
        'showTouchControls': showTouchControls,
        'controlsOpacity': controlsOpacity,
        'haptics': haptics,
        'integerScaling': integerScaling,
        'controlLayout':
            controlLayout.map((k, v) => MapEntry(k, v.toList())),
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        localeCode: json['localeCode'] as String?,
        themeMode: ThemeMode.values.firstWhere(
          (m) => m.name == json['themeMode'],
          orElse: () => ThemeMode.dark,
        ),
        showTouchControls: json['showTouchControls'] as bool? ?? true,
        controlsOpacity: (json['controlsOpacity'] as num?)?.toDouble() ?? 0.55,
        haptics: json['haptics'] as bool? ?? true,
        integerScaling: json['integerScaling'] as bool? ?? false,
        controlLayout: (json['controlLayout'] as Map<String, dynamic>?)?.map(
              (k, v) => MapEntry(
                k,
                (v as List).map((e) => (e as num).toDouble()).toList(),
              ),
            ) ??
            const {},
      );
}
