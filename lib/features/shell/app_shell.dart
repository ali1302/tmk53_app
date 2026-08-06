import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth/providers/auth_provider.dart';
import '../broadcast/screens/broadcast_screen.dart';
import '../calendar/screens/calendar_screen.dart';
import '../dues/screens/dues_screen.dart';
import '../home/screens/home_screen.dart';
import '../home/widgets/qr_modal.dart';
import '../izan/screens/izan_screen.dart';
import '../menu/screens/menu_drawer.dart';
import '../qibla/screens/qibla_screen.dart';
import '../scan/screens/scan_screen.dart';
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
  bool _qiblaOpen = false;
  String? _qiblaLocationLabel;

  void _openQibla(String locationLabel) {
    setState(() {
      _qiblaOpen = true;
      _qiblaLocationLabel = locationLabel;
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
    final canScan = context.watch<AuthProvider>().canScan;

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
                Expanded(child: _buildBody(canScan)),
                _BottomNav(
                  activeTab: _activeTab,
                  onSelect: _selectTab,
                  showScan: canScan,
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
                            _showQr = true;
                          });
                        },
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

  Widget _buildBody(bool canScan) {
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
        );
    }
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.activeTab,
    required this.onSelect,
    required this.showScan,
  });

  final AppTab activeTab;
  final ValueChanged<AppTab> onSelect;
  final bool showScan;

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
            label: 'Izan',
            icon: Icons.back_hand_outlined,
            selected: activeTab == AppTab.izan,
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
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

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
            Icon(icon, size: 20, color: color),
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
