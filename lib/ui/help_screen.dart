import 'package:flutter/material.dart';
import 'l10n_ext.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sections = <(String, String)>[
      (l10n.helpControlsTitle, l10n.helpControlsBody),
      (l10n.helpSavesTitle, l10n.helpSavesBody),
      (l10n.helpRomsTitle, l10n.helpRomsBody),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.help)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final section in sections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.$1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(section.$2),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
