import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/basics.dart';
import '../../core/widgets/fina_avatar.dart';
import '../../data/providers.dart';
import '../../domain/enums.dart';
import '../../domain/fina.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name = TextEditingController(text: ref.read(profileProvider)?.name ?? '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _set(String key, String value) => ref.read(settingsRepoProvider).set(key, value);

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    if (profile == null) return const Scaffold();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 10, 16, 40),
        children: [
          Row(
            children: [RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => context.pop())],
          ),
          const SizedBox(height: 10),
          const Center(child: FinaAvatar(mood: FinaMood.happy, size: 84)),
          const SizedBox(height: 12),
          const Center(child: Text('Dein Profil', style: ZText.screenTitle)),
          const SizedBox(height: 4),
          Center(child: Text('Nur auf diesem Gerät gespeichert.', style: ZText.secondary)),
          const SizedBox(height: 24),
          const _Label('Wie darf Fina dich nennen?'),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Dein Vorname'),
            onChanged: (v) => _set(SettingKeys.name, v.trim()),
          ),
          const SizedBox(height: 22),
          const _Label('Wie soll Fina mit dir reden?'),
          for (final t in FinaTone.values) ...[
            _Choice(
              emoji: t.emoji,
              label: t.label,
              selected: profile.tone == t,
              onTap: () => _set(SettingKeys.tone, t.name),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 14),
          const _Label('Was ist dir gerade wichtig?'),
          for (final f in MoneyFocus.values) ...[
            _Choice(
              emoji: f.emoji,
              label: f.label,
              selected: profile.focus == f,
              onTap: () => _set(SettingKeys.focus, f.name),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: ZText.label),
  );
}

class _Choice extends StatelessWidget {
  const _Choice({required this.emoji, required this.label, required this.selected, required this.onTap});

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ZCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: ZText.itemTitle)),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? ZColors.accent : ZColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
