import 'package:flutter/widgets.dart';
import '../l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  L10n get l10n => L10n.of(this);
}
