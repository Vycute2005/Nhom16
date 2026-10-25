import 'package:flutter/material.dart' as material;

import '../services/app_locale.dart';
import '../services/app_translations.dart';

export 'package:flutter/material.dart' hide Text;
export '../services/app_locale.dart' show AppLocaleAwareState;
export '../services/app_translations.dart';

class Text extends material.Text {
  const Text(
    super.data, {
    super.key,
    super.style,
    super.strutStyle,
    super.textAlign,
    super.textDirection,
    super.locale,
    super.softWrap,
    super.overflow,
    super.textScaler,
    super.maxLines,
    super.semanticsLabel,
    super.semanticsIdentifier,
    super.textWidthBasis,
    super.textHeightBehavior,
    super.selectionColor,
  });

  @override
  material.Widget build(material.BuildContext context) {
    return material.ValueListenableBuilder<String>(
      valueListenable: AppLocaleController.languageCode,
      builder: (context, _, __) => material.Text(
        AppTranslations.translate(data!),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel == null
            ? null
            : AppTranslations.translate(semanticsLabel!),
        semanticsIdentifier: semanticsIdentifier,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ),
    );
  }
}
