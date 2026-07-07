import 'package:flutter/material.dart';
import 'l10n/app_localizations.dart';
import 'services/controller_monitor.dart';
import 'state/app_state.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.create();
  runApp(N64LauncherApp(state: state));
}

class N64LauncherApp extends StatefulWidget {
  const N64LauncherApp({super.key, required this.state});

  final AppState state;

  @override
  State<N64LauncherApp> createState() => _N64LauncherAppState();
}

class _N64LauncherAppState extends State<N64LauncherApp> {
  final ControllerMonitor _controllers = ControllerMonitor();

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: widget.state,
      child: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) {
          final settings = widget.state.settings;
          return MaterialApp(
            onGenerateTitle: (context) => L10n.of(context).appTitle,
            debugShowCheckedModeBanner: false,
            themeMode: settings.themeMode,
            theme: _buildTheme(Brightness.light),
            darkTheme: _buildTheme(Brightness.dark),
            locale: settings.locale,
            localizationsDelegates: L10n.localizationsDelegates,
            supportedLocales: L10n.supportedLocales,
            home: HomeScreen(controllers: _controllers),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) => ThemeData(
        useMaterial3: true,
        brightness: brightness,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3DA9FC),
          brightness: brightness,
        ),
      );
}
