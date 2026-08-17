import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../broadcast/screens/broadcast_screen.dart';
import '../calendar/screens/calendar_screen.dart';
import '../committee/screens/committee_screen.dart';
import '../contact_us/screens/contact_us_screen.dart';
import '../dues/screens/dues_screen.dart';
import '../history_scan/screens/history_scan_screen.dart';
import '../home/providers/home_provider.dart';
import '../home/screens/home_screen.dart';
import '../home/widgets/qr_modal.dart';
import '../izan/providers/izan_provider.dart';
import '../izan/screens/izan_screen.dart';
import '../menu/screens/menu_drawer.dart';
import '../qibla/screens/qibla_screen.dart';
import '../scan/screens/scan_screen.dart';
import '../../core/services/push_navigation_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_provider.dart';

enum AppTab { menu, broadcast, izan, scan }

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _activeTab = AppTab.menu;
  bool _menuOpen = false;
  bool _calendarOpen = false;
  bool _duesOpen = false;
  bool _showQr = false;
  bool _historyScanOpen = false;
  bool _committeeOpen = false;
  bool _contactUsOpen = false;
  bool _qiblaOpen = false;
  String? _qiblaLocationLabel;

  @override
  void initState() {
    super.initState();
    PushNavigationController.instance.addListener(_onPushNavigation);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onPushNavigation();
      _preloadIzan();
    });
  }

  @override
  void dispose() {
    PushNavigationController.instance.removeListener(_onPushNavigation);
    super.dispose();
  }

  void _onPushNavigation() {
    if (!mounted) return;
    final nav = PushNavigationController.instance;
    if (!nav.shouldOpenBroadcast) return;
    nav.consumeOpenBroadcast();
    setState(() {
      _menuOpen = false;
      _calendarOpen = false;
      _duesOpen = false;
      _historyScanOpen = false;
      _committeeOpen = false;
      _contactUsOpen = false;
      _qiblaOpen = false;
      _showQr = false;
      _activeTab = AppTab.broadcast;
    });
  }

  void _preloadIzan() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (auth.isDesignPreview || auth.token == null || auth.itsId == null) {
      return;
    }
    context.read<IzanProvider>().load(
          token: auth.token!,
          itsId: auth.itsId!,
        );
  }

  void _openQibla(String locationLabel) {
    setState(() {
      _qiblaOpen = true;
      _qiblaLocationLabel = locationLabel;
    });
  }

  void _openContactUs() {
    setState(() {
      _menuOpen = false;
      _contactUsOpen = true;
    });
  }

  void _selectTab(AppTab tab) {
    final auth = context.read<AuthProvider>();
    if (tab == AppTab.scan && !auth.canScan) {
      return;
    }
    setState(() {
      if (tab == AppTab.menu) {
        _menuOpen = true;
        _activeTab = AppTab.menu;
      } else {
        _menuOpen = false;
        _activeTab = tab;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final home = context.watch<HomeProvider>();
    final izan = context.watch<IzanProvider>();
    final canScan = auth.canScan;
    final izanLabel = auth.izanLabel.trim().isEmpty ? 'Izan' : auth.izanLabel.trim();
    final showIzanBadge = izan.needsRegistration(auth.itsId ?? '') ||
        (izan.cards.isEmpty && (home.details?.needsIzanRegistration ?? false));

    if (!canScan && _activeTab == AppTab.scan) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_activeTab == AppTab.scan && !context.read<AuthProvider>().canScan) {
          setState(() => _activeTab = AppTab.menu);
        }
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        top: false,
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                Expanded(child: _buildBody(canScan, izanLabel, auth.izanHeading)),
                _BottomNav(
                  activeTab: _activeTab,
                  onSelect: _selectTab,
                  showScan: canScan,
                  izanLabel: izanLabel,
                  showIzanBadge: showIzanBadge,
                ),
              ],
            ),
            if (_menuOpen)
              Positioned.fill(
                child: Row(
                  children: [
                    SizedBox(
                      width: MediaQuery.of(context).size.width * 0.75,
                      child: MenuDrawer(
                        onCalendar: () {
                          setState(() {
                            _menuOpen = false;
                            _calendarOpen = true;
                          });
                        },
                        onDues: () {
                          setState(() {
                            _menuOpen = false;
                            _duesOpen = true;
                          });
                        },
                        onSelfScan: () {
                          setState(() {
                            _menuOpen = false;
                            _historyScanOpen = true;
                          });
                        },
                        onCommittee: () {
                          setState(() {
                            _menuOpen = false;
                            _committeeOpen = true;
                          });
                        },
                        onCloseMenu: () => setState(() => _menuOpen = false),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _menuOpen = false),
                        child: Container(color: Colors.black.withValues(alpha: 0.45)),
                      ),
                    ),
                  ],
                ),
              ),
            if (_calendarOpen)
              Positioned.fill(
                child: CalendarScreen(
                  onClose: () => setState(() => _calendarOpen = false),
                ),
              ),
            if (_duesOpen)
              Positioned.fill(
                child: DuesScreen(
                  onClose: () => setState(() => _duesOpen = false),
                ),
              ),
            if (_historyScanOpen)
              Positioned.fill(
                child: HistoryScanScreen(
                  onClose: () => setState(() => _historyScanOpen = false),
                ),
              ),
            if (_committeeOpen)
              Positioned.fill(
                child: CommitteeScreen(
                  onClose: () => setState(() => _committeeOpen = false),
                ),
              ),
            if (_contactUsOpen)
              Positioned.fill(
                child: ContactUsScreen(
                  onClose: () => setState(() => _contactUsOpen = false),
                ),
              ),
            if (_showQr)
              Positioned.fill(
                child: QrModal(onClose: () => setState(() => _showQr = false)),
              ),
            if (_qiblaOpen)
              Positioned.fill(
                child: QiblaScreen(
                  locationLabel: _qiblaLocationLabel,
                  onClose: () => setState(() => _qiblaOpen = false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool canScan, String izanLabel, String izanHeading) {
    switch (_activeTab) {
      case AppTab.broadcast:
        return BroadcastScreen(
          onBack: () => setState(() {
            _activeTab = AppTab.menu;
            _menuOpen = false;
          }),
        );
      case AppTab.izan:
        return IzanScreen(
          title: izanLabel,
          heading: izanHeading,
          onBack: () => setState(() {
            _activeTab = AppTab.menu;
            _menuOpen = false;
          }),
        );
      case AppTab.scan:
        if (!canScan) {
          return HomeScreen(
            onOpenQr: () => setState(() => _showQr = true),
            onOpenQibla: _openQibla,
            onOpenBroadcast: () => _selectTab(AppTab.broadcast),
            onOpenContactUs: _openContactUs,
          );
        }
        return ScanScreen(
          onBack: () => setState(() {
            _activeTab = AppTab.menu;
            _menuOpen = false;
          }),
        );
      case AppTab.menu:
        return HomeScreen(
          onOpenQr: () => setState(() => _showQr = true),
          onOpenQibla: _openQibla,
          onOpenBroadcast: () => _selectTab(AppTab.broadcast),
          onOpenContactUs: _openContactUs,
        );
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.activeTab,
    required this.onSelect,
    required this.showScan,
    required this.izanLabel,
    this.showIzanBadge = false,
  });

  final AppTab activeTab;
  final ValueChanged<AppTab> onSelect;
  final bool showScan;
  final String izanLabel;
  final bool showIzanBadge;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return Container(
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary,
        border: const Border(top: BorderSide(color: Color(0x14FFFFFF))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: 'Menu',
            icon: Icons.menu,
            selected: activeTab == AppTab.menu,
            onTap: () => onSelect(AppTab.menu),
          ),
          _NavItem(
            label: 'Broadcast',
            icon: Icons.podcasts,
            selected: activeTab == AppTab.broadcast,
            onTap: () => onSelect(AppTab.broadcast),
          ),
          _NavItem(
            label: izanLabel,
            icon: Icons.back_hand_outlined,
            selected: activeTab == AppTab.izan,
            showBadge: showIzanBadge,
            onTap: () => onSelect(AppTab.izan),
          ),
          if (showScan)
            _NavItem(
              label: 'Scan',
              icon: Icons.document_scanner_outlined,
              selected: activeTab == AppTab.scan,
              onTap: () => onSelect(AppTab.scan),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.showBadge = false,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : Colors.white.withValues(alpha: 0.45);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 20, color: color),
                if (showBadge)
                  Positioned(
                    right: -3,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE11D48),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
