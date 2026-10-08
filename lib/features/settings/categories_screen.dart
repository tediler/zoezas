import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/sheets.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  CategoryKind _kind = CategoryKind.expense;

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(categoriesProvider).value ?? const <Category>[];
    final list = all.where((c) => c.kind == _kind && !c.archived).toList();
    final archived = all.where((c) => c.kind == _kind && c.archived).toList();

    return Scaffold(
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop()),
                      const Spacer(),
                      RoundIconButton(
                        icon: Icons.add_rounded,
                        onPressed: () => showCategoryEditor(context, kind: _kind),
                        tooltip: 'Neue Kategorie',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Kategorien', style: ZText.screenTitle),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text('Gedrückt halten und ziehen, um die Reihenfolge zu ändern.', style: ZText.secondary),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ZPill(
                        label: 'Ausgaben',
                        selected: _kind == CategoryKind.expense,
                        onTap: () => setState(() => _kind = CategoryKind.expense),
                      ),
                      const SizedBox(width: 8),
                      ZPill(
                        label: 'Einnahmen',
                        selected: _kind == CategoryKind.income,
                        onTap: () => setState(() => _kind = CategoryKind.income),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
              itemCount: list.length,
              proxyDecorator: (child, _, _) => Material(color: Colors.transparent, child: child),
              onReorder: (oldIndex, newIndex) {
                final items = [...list];
                if (newIndex > oldIndex) newIndex--;
                items.insert(newIndex, items.removeAt(oldIndex));
                final others = all.where((c) => !items.contains(c)).toList();
                ref.read(categoriesRepoProvider).reorder([...items, ...others]);
              },
              footer: archived.isEmpty
                  ? null
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 18),
                        const SectionHeader(title: 'Archiviert', subtitle: 'Bleiben für die Statistik erhalten'),
                        for (final c in archived)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Opacity(
                              opacity: 0.6,
                              child: _CategoryCard(
                                category: c,
                                trailing: TextButton(
                                  onPressed: () =>
                                      ref.read(categoriesRepoProvider).updateCategory(c.copyWith(archived: false)),
                                  child: const Text('Zurückholen'),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
              itemBuilder: (_, i) => Padding(
                key: ValueKey(list[i].id),
                padding: const EdgeInsets.only(bottom: 10),
                child: _CategoryCard(
                  category: list[i],
                  onTap: () => context.push('/category/${list[i].id}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: ZColors.textSecondary),
                    onPressed: () => showCategoryEditor(context, existing: list[i], kind: _kind),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, this.onTap, this.trailing});

  final Category category;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      onTap: onTap,
      child: Row(
        children: [
          EmojiTile(emoji: category.emoji, color: Color(category.color), size: 42),
          const SizedBox(width: 14),
          Expanded(child: Text(category.name, style: ZText.itemTitle)),
          ?trailing,
        ],
      ),
    );
  }
}

/// Kategorie anlegen oder bearbeiten. Gibt die ID einer neuen Kategorie zurück.
Future<int?> showCategoryEditor(BuildContext context, {Category? existing, required CategoryKind kind}) {
  return showZSheet<int>(
    context,
    builder: (_) => _CategoryEditor(existing: existing, kind: kind),
  );
}

class _CategoryEditor extends ConsumerStatefulWidget {
  const _CategoryEditor({this.existing, required this.kind});
  final Category? existing;
  final CategoryKind kind;

  @override
  ConsumerState<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends ConsumerState<_CategoryEditor> {
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late String _emoji = widget.existing?.emoji ?? (widget.kind == CategoryKind.expense ? '🌸' : '💰');
  late int _color = widget.existing?.color ?? ZColors.pastels[7].toARGB32();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showToast(context, 'Wie soll die Kategorie heißen?');
      return;
    }
    final repo = ref.read(categoriesRepoProvider);
    if (widget.existing == null) {
      final id = await repo.add(name: name, emoji: _emoji, color: _color, kind: widget.kind);
      if (mounted) Navigator.pop(context, id);
    } else {
      await repo.updateCategory(widget.existing!.copyWith(name: name, emoji: _emoji, color: _color));
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _remove() async {
    final c = widget.existing!;
    final repo = ref.read(categoriesRepoProvider);
    final used = await repo.isUsed(c.id);
    if (!mounted) return;
    final ok = await confirm(
      context,
      title: used ? 'Kategorie archivieren?' : 'Kategorie löschen?',
      message: used
          ? '„${c.name}“ wird schon verwendet. Sie verschwindet aus der Auswahl, bleibt aber in der Statistik erhalten.'
          : '„${c.name}“ wird entfernt.',
      confirmLabel: used ? 'Archivieren' : 'Löschen',
      destructive: !used,
    );
    if (!ok) return;
    await repo.removeOrArchive(c);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    return SheetScaffold(
      title: isNew ? 'Neue Kategorie' : 'Kategorie bearbeiten',
      subtitle: widget.kind == CategoryKind.expense ? 'Für Ausgaben' : 'Für Einnahmen',
      primaryLabel: 'Speichern',
      onPrimary: _save,
      secondary: isNew
          ? null
          : TextButton(
              onPressed: _remove,
              child: const Text('Entfernen', style: TextStyle(color: ZColors.negative)),
            ),
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: () async {
                final e = await pickEmoji(context, current: _emoji);
                if (e != null) setState(() => _emoji = e);
              },
              child: EmojiTile(emoji: _emoji, color: Color(_color), size: 56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                autofocus: isNew,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'z. B. Haustier'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text('Tipp aufs Emoji, um es zu ändern.', style: ZText.small),
        ),
        const SizedBox(height: 16),
        const FieldLabel('Farbe'),
        PastelPicker(value: _color, onChanged: (c) => setState(() => _color = c)),
      ],
    );
  }
}
