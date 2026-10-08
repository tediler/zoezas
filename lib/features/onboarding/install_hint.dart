import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../platform/web_support.dart';

/// Hinweis nur für Safari auf iPhone/iPad, solange Zoëzas im normalen Tab
/// läuft: Dort haben Safari-Tab und Home-Bildschirm-App getrennte Speicher.
/// Wer im Tab anfängt und erst später installiert, findet seine Daten in der
/// App nicht wieder.
class SafariInstallHint extends StatelessWidget {
  const SafariInstallHint({super.key, this.padding = EdgeInsets.zero});

  final EdgeInsetsGeometry padding;

  static bool get shouldShow => kIsWeb && WebSupport.isAppleMobile && !WebSupport.isStandalone;

  @override
  Widget build(BuildContext context) {
    if (!shouldShow) return const SizedBox.shrink();
    return Padding(
      padding: padding,
      child: ZCard(
        color: ZColors.warningLight,
        shadow: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('📲', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Erst auf den Home-Bildschirm', style: ZText.itemTitle),
                  const SizedBox(height: 4),
                  Text(
                    'Tippe unten auf Teilen (Quadrat mit Pfeil) → „Zum Home-Bildschirm“ und starte Zoëzas von dort. '
                    'Safari und die Home-Bildschirm-App speichern getrennt – was du hier im Tab einträgst, '
                    'ist in der App nicht da.',
                    style: ZText.secondary.copyWith(color: ZColors.text),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
