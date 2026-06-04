import 'package:flutter/material.dart';
import '../services/i18n_service.dart';

/// A Text widget that auto-translates and rebuilds on locale change.
class Tr extends StatelessWidget {
  final String textKey;
  final Map<String, String>? params;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const Tr(this.textKey,
      {super.key,
      this.params,
      this.style,
      this.textAlign,
      this.maxLines,
      this.overflow});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: i18n,
      builder: (_, __) {
        final translated = i18n.tr(textKey, params: params);
        return Text(translated,
            style: style,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: overflow);
      },
    );
  }
}

/// Helper extension on [BuildContext] for inline translations.
extension I18nX on BuildContext {
  String tr(String key, {Map<String, String>? params}) =>
      i18n.tr(key, params: params);
}
