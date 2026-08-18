import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../home/providers/home_provider.dart';
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
  String? _openMajlisId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  String get _heading => widget.heading.trim().isEmpty
      ? 'Registration for Jaman Izan'
      : widget.heading.trim();

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
    if (ok) {
      await context.read<HomeProvider>().load(
            token: auth.token ?? '',
            itsId: auth.itsId ?? '',
            preview: auth.isDesignPreview,
          );
    }
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
    final auth = context.watch<AuthProvider>();
    final izan = context.watch<IzanProvider>();
    final home = context.watch<HomeProvider>().details;
    final loggedInIts = auth.itsId ?? '';

    IzanEventCard? openCard;
    if (_openMajlisId != null) {
      final match = izan.cards.where((c) => c.id == _openMajlisId).toList();
      if (match.isNotEmpty) openCard = match.first;
    }

    final displayTitle =
        widget.title.trim().isEmpty ? 'Izan' : widget.title.trim();

    return ColoredBox(
      color: const Color(0xFFF6EDE3),
      child: Column(
        children: [
          _Header(
            title: openCard != null ? _heading : displayTitle,
            onBack: openCard != null
                ? () => setState(() => _openMajlisId = null)
                : widget.onBack,
            leadingLabel: openCard != null ? displayTitle : null,
          ),
          Expanded(
            child: auth.isDesignPreview
                ? const Center(child: Text('Design preview — login for live RSVP.'))
                : izan.isLoading && izan.cards.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: openCard == null
                            ? _LandingList(
                                heading: _heading,
                                error: izan.errorMessage,
                                cards: izan.cards,
                                loggedInIts: loggedInIts,
                                onRegister: (id) => setState(() => _openMajlisId = id),
                              )
                            : _RegisterFlow(
                                card: openCard,
                                loggedInIts: loggedInIts,
                                fallbackName: home?.user.itsName ?? '',
                                onToggle: (its, v) =>
                                    izan.toggleMember(openCard!.id, its, v),
                                onAddGuest: () => _showAddGuest(openCard!.id),
                                onRemoveGuest: (i) =>
                                    izan.removeGuest(openCard!.id, i),
                                onSave: () => _save(openCard!.id),
                              ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _LandingList extends StatelessWidget {
  const _LandingList({
    required this.heading,
    required this.cards,
    required this.loggedInIts,
    required this.onRegister,
    this.error,
  });

  final String heading;
  final String? error;
  final List<IzanEventCard> cards;
  final String loggedInIts;
  final ValueChanged<String> onRegister;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (error != null && cards.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(error!, style: const TextStyle(color: Colors.red)),
          ),
        if (cards.isEmpty)
          _LandingEventCard(
            heading: heading,
            title: 'Not active.',
            date: '',
            hijri: '',
            buttonLabel: null,
            onRegister: null,
          )
        else
          for (final card in cards) ...[
            _LandingEventCard(
              heading: heading,
              title: card.event.title.isEmpty ? 'RSVP Event' : card.event.title,
              date: card.event.date,
              hijri: card.event.misriDateLabel,
              loading: card.isLoading,
              buttonLabel: card.isUserRegistered(loggedInIts)
                  ? 'View Registration'
                  : 'Register Now',
              onRegister: card.isLoading ? null : () => onRegister(card.id),
            ),
            const SizedBox(height: 14),
          ],
      ],
    );
  }
}

class _LandingEventCard extends StatelessWidget {
  const _LandingEventCard({
    required this.heading,
    required this.title,
    required this.date,
    required this.hijri,
    required this.buttonLabel,
    required this.onRegister,
    this.loading = false,
  });

  final String heading;
  final String title;
  final String date;
  final String hijri;
  final String? buttonLabel;
  final VoidCallback? onRegister;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),
                _DateRow(date: date, hijri: hijri),
                if (buttonLabel != null) ...[
                  const SizedBox(height: 16),
                  _SendButton(
                    label: buttonLabel!,
                    onPressed: onRegister,
                  ),
                ],
              ],
            ),
    );
  }
}

class _RegisterFlow extends StatelessWidget {
  const _RegisterFlow({
    required this.card,
    required this.loggedInIts,
    required this.fallbackName,
    required this.onToggle,
    required this.onAddGuest,
    required this.onRemoveGuest,
    required this.onSave,
  });

  final IzanEventCard card;
  final String loggedInIts;
  final String fallbackName;
  final void Function(String its, bool value) onToggle;
  final VoidCallback onAddGuest;
  final void Function(int index) onRemoveGuest;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final event = card.event;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _WhiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title.isEmpty ? 'RSVP Event' : event.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              _DateRow(date: event.date, hijri: event.misriDateLabel),
            ],
          ),
        ),
        if (card.errorMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            card.errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'Users Pass',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (card.members.isEmpty)
          const _WhiteCard(
            child: Text('No family members found.', style: TextStyle(color: AppColors.gray500)),
          )
        else
          for (final m in card.members) ...[
            _PersonCard(
              name: m.name.isNotEmpty
                  ? m.name
                  : (m.its.trim() == loggedInIts.trim() ? fallbackName : m.its),
              its: m.its,
              trailing: Text(
                m.persistedRegistered ? 'Registered' : 'Not Registered',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: m.persistedRegistered
                      ? const Color(0xFF15803D)
                      : const Color(0xFFDC2626),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        if (!card.event.onlyHof &&
            card.guests.any((g) => g.persisted)) ...[
          const SizedBox(height: 10),
          Text(
            'Guest Pass',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          for (final g in card.guests.where((g) => g.persisted)) ...[
            _PersonCard(
              name: g.name,
              its: g.its,
              subtitle: '${g.gender} · ${g.misaq} · Guest',
              trailing: const Text(
                'Registered',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF15803D),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                card.event.onlyHof ? 'HOF Registration' : 'User Registration',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (!card.event.onlyHof)
              TextButton(
                onPressed: onAddGuest,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
                child: const Text(
                  '+ Add Guest',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (card.members.isEmpty)
          const _WhiteCard(
            child: Text('No family members found.', style: TextStyle(color: AppColors.gray500)),
          )
        else
          for (final m in card.members) ...[
            _PersonCard(
              name: m.name.isNotEmpty
                  ? m.name
                  : (m.its.trim() == loggedInIts.trim() ? fallbackName : m.its),
              its: m.its,
              trailing: Checkbox(
                value: m.registered,
                activeColor: AppColors.primary,
                onChanged: (v) => onToggle(m.its, v ?? false),
              ),
            ),
            const SizedBox(height: 8),
          ],
        if (!card.event.onlyHof)
          for (var i = 0; i < card.guests.length; i++) ...[
            _PersonCard(
              name: card.guests[i].name,
              its: card.guests[i].its,
              subtitle: '${card.guests[i].gender} · ${card.guests[i].misaq} · Guest',
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                onPressed: () => onRemoveGuest(i),
              ),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 12),
        _SendButton(
          label: 'Save',
          onPressed: card.isSaving ? null : onSave,
          loading: card.isSaving,
          filled: false,
        ),
      ],
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.date, required this.hijri});

  final String date;
  final String hijri;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (date.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    date,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                ),
              ],
            ),
          ),
        if (hijri.isNotEmpty)
          Expanded(
            child: Row(
              children: [
                Icon(Icons.brightness_2_outlined, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    hijri,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.name,
    required this.its,
    required this.trailing,
    this.subtitle,
  });

  final String name;
  final String its;
  final String? subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFEEF2FF),
            child: Icon(Icons.person, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? its : name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle == null ? its : '$its  ·  $subtitle',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.filled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.primary : const Color(0xFFE8D5B5);
    final fg = filled ? Colors.white : AppColors.primary;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.7),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.send, size: 18, color: fg),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                      color: fg,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    this.leadingLabel,
  });

  final String title;
  final VoidCallback onBack;
  final String? leadingLabel;

  @override
  Widget build(BuildContext context) {
    final titleStyle = const TextStyle(
      color: AppColors.accent,
      fontSize: 16,
      fontWeight: FontWeight.w700,
    );

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
          if (leadingLabel != null) ...[
            Text(leadingLabel!, style: titleStyle.copyWith(fontSize: 14)),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle.copyWith(fontSize: 15),
              ),
            ),
            const SizedBox(width: 64),
          ] else
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: titleStyle,
              ),
            ),
        ],
      ),
    );
  }
}
