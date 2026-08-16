import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/izan_repository.dart';
import '../providers/izan_provider.dart';

class IzanScreen extends StatefulWidget {
  const IzanScreen({
    super.key,
    required this.onBack,
    this.title = 'Izan',
    this.heading = 'Registration for Jaman Izan',
  });

  final VoidCallback onBack;
  final String title;
  final String heading;

  @override
  State<IzanScreen> createState() => _IzanScreenState();
}

class _IzanScreenState extends State<IzanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final auth = context.read<AuthProvider>();
    if (auth.isDesignPreview || auth.token == null || auth.itsId == null) {
      return;
    }
    await context.read<IzanProvider>().load(
          token: auth.token!,
          itsId: auth.itsId!,
        );
  }

  Future<void> _save(String majlisId) async {
    final auth = context.read<AuthProvider>();
    final izan = context.read<IzanProvider>();
    final ok = await izan.save(
      token: auth.token ?? '',
      itsId: auth.itsId ?? '',
      majlisId: majlisId,
    );
    if (!mounted) return;
    final card = izan.cards.where((c) => c.id == majlisId).toList();
    final msg = ok
        ? (izan.successMessage ?? 'Registered Successfully')
        : (card.isNotEmpty
            ? (card.first.errorMessage ?? 'Unable to save registration.')
            : 'Unable to save registration.');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? const Color(0xFF166534) : const Color(0xFFB91C1C),
      ),
    );
  }

  Future<void> _showAddGuest(String majlisId) async {
    final itsCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    var gender = 'M';
    var misaq = 'Done';

    final guest = await showDialog<IzanGuest>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return AlertDialog(
              title: const Text('Add Guest'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: itsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ITS',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: gender,
                      decoration: const InputDecoration(
                        labelText: 'Gender',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'M', child: Text('Male')),
                        DropdownMenuItem(value: 'F', child: Text('Female')),
                      ],
                      onChanged: (v) => setLocal(() => gender = v ?? 'M'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: misaq,
                      decoration: const InputDecoration(
                        labelText: 'Misaq',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Done', child: Text('Done')),
                        DropdownMenuItem(value: 'Not Done', child: Text('Not Done')),
                      ],
                      onChanged: (v) => setLocal(() => misaq = v ?? 'Done'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () {
                    final its = itsCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    if (its.isEmpty || name.isEmpty) return;
                    Navigator.pop(
                      ctx,
                      IzanGuest(its: its, name: name, gender: gender, misaq: misaq),
                    );
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (guest != null && mounted) {
      context.read<IzanProvider>().addGuest(majlisId, guest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenTitle = widget.title.trim().isEmpty ? 'Izan' : widget.title.trim();
    final screenHeading = widget.heading.trim().isEmpty
        ? 'Registration for Jaman Izan'
        : widget.heading.trim();
    final auth = context.watch<AuthProvider>();
    final izan = context.watch<IzanProvider>();

    return Column(
      children: [
        _Header(title: screenTitle, onBack: widget.onBack),
        Expanded(
          child: auth.isDesignPreview
              ? const Center(child: Text('Design preview — login for live RSVP.'))
              : izan.isLoading && izan.cards.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                        children: [
                          if (izan.errorMessage != null && izan.cards.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                izan.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          if (izan.cards.isEmpty)
                            _EmptyCard(heading: screenHeading)
                          else ...[
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10, left: 4),
                              child: Text(
                                screenHeading,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1F2937),
                                ),
                              ),
                            ),
                            for (final card in izan.cards) ...[
                              _EventCard(
                                card: card,
                                izanLabel: screenTitle,
                                loggedInIts: auth.itsId ?? '',
                                onToggle: (its, v) =>
                                    izan.toggleMember(card.id, its, v),
                                onAddGuest: () => _showAddGuest(card.id),
                                onRemoveGuest: (i) => izan.removeGuest(card.id, i),
                                onSave: () => _save(card.id),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ],
                      ),
                    ),
        ),
      ],
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.heading});
  final String heading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            heading,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Not active.',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.card,
    required this.izanLabel,
    required this.loggedInIts,
    required this.onToggle,
    required this.onAddGuest,
    required this.onRemoveGuest,
    required this.onSave,
  });

  final IzanEventCard card;
  final String izanLabel;
  final String loggedInIts;
  final void Function(String its, bool value) onToggle;
  final VoidCallback onAddGuest;
  final void Function(int index) onRemoveGuest;
  final VoidCallback onSave;

  bool get _userRegistered {
    final its = loggedInIts.trim();
    if (its.isEmpty) {
      return card.members.any((m) => m.registered);
    }
    final self = card.members.where((m) => m.its.trim() == its);
    if (self.isNotEmpty) {
      return self.any((m) => m.registered);
    }
    // HOF-only view may hide other members; treat any registered member as yes.
    return card.members.any((m) => m.registered) ||
        card.familyAll.any((m) => m.its.trim() == its && m.registered);
  }

  @override
  Widget build(BuildContext context) {
    final event = card.event;
    final alreadyRegistered = _userRegistered;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: card.isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title.isEmpty ? 'RSVP Event' : event.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  [
                    if (event.date.isNotEmpty) event.date,
                    if (event.misriDateLabel.isNotEmpty) event.misriDateLabel,
                  ].join('  ·  '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.gray500,
                  ),
                ),
                if (alreadyRegistered) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your $izanLabel Pass is available',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF166534),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'You are already registered',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF166534),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (card.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    card.errorMessage!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 14),
                Text(
                  card.event.onlyHof ? 'HOF Registration' : 'Family',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF374151),
                  ),
                ),
                const SizedBox(height: 4),
                if (card.members.isEmpty)
                  const Text(
                    'No family members found.',
                    style: TextStyle(color: AppColors.gray500),
                  )
                else
                  ...card.members.map(
                    (m) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(
                        m.name.isEmpty ? m.its : m.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        [
                          m.its,
                          if (m.gender.isNotEmpty) m.gender,
                          if (card.event.onlyHof) 'HOF only',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: m.registered,
                      activeThumbColor: AppColors.accent,
                      onChanged: (v) => onToggle(m.its, v),
                    ),
                  ),
                if (!card.event.onlyHof) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Guests',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: onAddGuest,
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: const Text('Add'),
                      ),
                    ],
                  ),
                  if (card.guests.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8),
                      child: Text(
                        'No guests added.',
                        style: TextStyle(color: AppColors.gray500, fontSize: 13),
                      ),
                    )
                  else
                    ...List.generate(card.guests.length, (i) {
                      final g = card.guests[i];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          g.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text('${g.its} · ${g.gender} · ${g.misaq}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => onRemoveGuest(i),
                        ),
                      );
                    }),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: card.isSaving ? null : onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: card.isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            alreadyRegistered
                                ? 'Update Registration'
                                : 'Save Registration',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 8,
        right: 16,
        bottom: 12,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, color: AppColors.accent, size: 28),
          ),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
