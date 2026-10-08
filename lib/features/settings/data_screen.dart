import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format/dates.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/backup.dart';

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

  Future<File> _writeExport() async {
    final json = await ref.read(backupServiceProvider).exportJson();
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _fileName));
    await file.writeAsString(json, flush: true);
    return file;
  }

  Future<void> _share() async {
    await _run(() async {
      final file = await _writeExport();
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Zoëzas-Sicherung',
          title: 'Zoëzas-Sicherung',
        ),
      );
    });
  }

  Future<void> _saveToFile() async {
    await _run(() async {
      final json = await ref.read(backupServiceProvider).exportJson();
      final path = await FilePicker.saveFile(
        dialogTitle: 'Sicherung speichern',
        fileName: _fileName,
        bytes: utf8.encode(json),
      );
      if (path != null && mounted) showToast(context, 'Gespeichert ✓');
    });
  }

  Future<void> _import() async {
    final result = await FilePicker.pickFiles(type: FileType.any, withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    final f = result.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) return;
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
              'Zoëzas speichert alles nur auf diesem Gerät. Mit einer Sicherung nimmst du deine Daten mit – aufs neue Handy oder einfach zur Sicherheit.',
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
                const SizedBox(height: 16),
                PrimaryButton(label: 'Teilen …', icon: Icons.ios_share_rounded, onPressed: _busy ? null : _share),
                const SizedBox(height: 10),
                SoftButton(
                  label: 'Als Datei speichern',
                  icon: Icons.save_alt_rounded,
                  onPressed: _busy ? null : _saveToFile,
                ),
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
