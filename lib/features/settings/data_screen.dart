import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show Uint8List, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/dates.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/backup.dart';
import '../../data/providers.dart';
import '../../platform/web_support.dart';

/// Datenhoheit: exportieren, importieren, zurücksetzen.
class DataScreen extends ConsumerStatefulWidget {
  const DataScreen({super.key});

  @override
  ConsumerState<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends ConsumerState<DataScreen> {
  bool _busy = false;

  String get _fileName {
    final now = DateTime.now();
    return 'zoezas-sicherung-${Dates.dayKey(now)}.json';
  }

  Future<Uint8List> _exportBytes() async => utf8.encode(await ref.read(backupServiceProvider).exportJson());

  /// Merkt sich das Datum der letzten Sicherung (für Finas Erinnerung).
  Future<void> _remember() =>
      ref.read(settingsRepoProvider).set(SettingKeys.lastBackup, DateTime.now().toIso8601String());

  /// Teilen-Menü: auf dem iPhone z. B. „In Dateien sichern“ oder an sich selbst
  /// schicken. Im Browser ohne Teilen-Funktion wird stattdessen geladen.
  Future<void> _share() async {
    await _run(() async {
      final bytes = await _exportBytes();
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'application/json', name: _fileName)],
          fileNameOverrides: [_fileName],
          subject: 'Zoëzas-Sicherung',
          title: 'Zoëzas-Sicherung',
          downloadFallbackEnabled: true,
        ),
      );
      if (result.status != ShareResultStatus.dismissed) await _remember();
    });
  }

  Future<void> _saveToFile() async {
    await _run(() async {
      final path = await FilePicker.saveFile(
        dialogTitle: 'Sicherung speichern',
        fileName: _fileName,
        bytes: await _exportBytes(),
      );
      // Im Browser startet ein Download und es kommt kein Pfad zurück.
      if (path != null || kIsWeb) {
        await _remember();
        if (mounted) showToast(context, kIsWeb ? 'Download gestartet ✓' : 'Gespeichert ✓');
      }
    });
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null) {
      if (mounted) showToast(context, 'Die Datei ließ sich nicht lesen.');
      return;
    }
    final json = utf8.decode(bytes, allowMalformed: true);
    final service = ref.read(backupServiceProvider);
    BackupSummary summary;
    try {
      summary = service.inspect(json);
    } on BackupFormatException catch (e) {
      if (mounted) showToast(context, e.message);
      return;
    }
    if (!mounted) return;
    final ok = await confirm(
      context,
      title: 'Sicherung einspielen?',
      message:
          'Vom ${summary.exportedAt == null ? '?' : Dates.numeric(summary.exportedAt!)}: '
          '${summary.accounts} Konten, ${summary.bookings} Buchungen, ${summary.goals} Ziele, ${summary.debts} Schulden.\n\n'
          'Deine aktuellen Daten werden dabei vollständig ersetzt. Tipp: Exportiere sie vorher.',
      confirmLabel: 'Ersetzen',
      destructive: true,
    );
    if (!ok) return;
    await _run(() async {
      await service.importJson(json);
      if (mounted) {
        showToast(context, 'Willkommen zurück 💗 Daten wiederhergestellt');
        context.go('/');
      }
    });
  }

  Future<void> _reset() async {
    final ok = await confirm(
      context,
      title: 'Wirklich alles löschen?',
      message:
          'Alle Konten, Buchungen, Ziele, Budgets und dein Profil werden unwiderruflich gelöscht. Exportiere vorher eine Sicherung, wenn du sie behalten willst.',
      confirmLabel: 'Alles löschen',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final sure = await confirm(
      context,
      title: 'Letzte Frage 🥺',
      message: 'Das kann nicht rückgängig gemacht werden.',
      confirmLabel: 'Ja, löschen',
      destructive: true,
    );
    if (!sure) return;
    await _run(() async {
      await ref.read(backupServiceProvider).resetAll();
      if (mounted) context.go('/onboarding');
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showToast(context, 'Das hat leider nicht geklappt: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = DateTime.tryParse(ref.watch(settingsProvider).value?[SettingKeys.lastBackup] ?? '');
    // Im Browser am Rechner/Android ist der Download der natürliche Weg, auf dem
    // iPhone das Teilen-Menü („In Dateien sichern“).
    final downloadFirst = kIsWeb && !WebSupport.isAppleMobile;
    Widget shareButton(bool primary) => primary
        ? PrimaryButton(
            label: WebSupport.isAppleMobile ? 'Teilen / In Dateien sichern' : 'Teilen …',
            icon: Icons.ios_share_rounded,
            onPressed: _busy ? null : _share,
          )
        : SoftButton(label: 'Teilen …', icon: Icons.ios_share_rounded, onPressed: _busy ? null : _share);
    Widget saveButton(bool primary) => primary
        ? PrimaryButton(label: 'Herunterladen', icon: Icons.download_rounded, onPressed: _busy ? null : _saveToFile)
        : SoftButton(
            label: kIsWeb ? 'Herunterladen' : 'Als Datei speichern',
            icon: Icons.save_alt_rounded,
            onPressed: _busy ? null : _saveToFile,
          );
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 40),
        children: [
          Row(
            children: [
              RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
              const Spacer(),
              if (_busy)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: ZColors.accent),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text('Deine Daten', style: ZText.screenTitle),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              kIsWeb
                  ? 'Zoëzas speichert alles nur in diesem Browser auf diesem Gerät – nichts liegt auf einem Server. '
                        'Eine Sicherung schützt dich, falls der Browser-Speicher einmal gelöscht wird, und bringt deine '
                        'Daten auch in die Android-App.'
                  : 'Zoëzas speichert alles nur auf diesem Gerät. Mit einer Sicherung nimmst du deine Daten mit – aufs '
                        'neue Handy, in die Web-App oder einfach zur Sicherheit.',
              style: ZText.secondary,
            ),
          ),
          const SizedBox(height: 22),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📤  Exportieren', style: ZText.sectionTitle),
                const SizedBox(height: 6),
                Text(
                  'Eine lesbare JSON-Datei mit allem: Konten, Buchungen, Planungen, Zielen, Schulden und Profil.',
                  style: ZText.secondary,
                ),
                const SizedBox(height: 8),
                Text(
                  last == null ? 'Noch keine Sicherung erstellt.' : 'Letzte Sicherung: ${Dates.relative(last)}',
                  style: ZText.small.copyWith(color: last == null ? ZColors.accentDeep : ZColors.textSecondary),
                ),
                const SizedBox(height: 16),
                downloadFirst ? saveButton(true) : shareButton(true),
                const SizedBox(height: 10),
                downloadFirst ? shareButton(false) : saveButton(false),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('📥  Importieren', style: ZText.sectionTitle),
                const SizedBox(height: 6),
                Text('Spielt eine Sicherung ein und ersetzt dabei die aktuellen Daten.', style: ZText.secondary),
                const SizedBox(height: 16),
                SoftButton(
                  label: 'Sicherung auswählen',
                  icon: Icons.file_open_outlined,
                  onPressed: _busy ? null : _import,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ZCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🧹  Neu anfangen', style: ZText.sectionTitle),
                const SizedBox(height: 6),
                Text('Löscht alle Daten auf diesem Gerät und startet das Kennenlernen neu.', style: ZText.secondary),
                const SizedBox(height: 16),
                SoftButton(
                  label: 'Alles zurücksetzen',
                  color: ZColors.negativeLight,
                  textColor: ZColors.negative,
                  onPressed: _busy ? null : _reset,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
