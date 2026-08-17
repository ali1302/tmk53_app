import 'package:flutter/material.dart';

import '../../../core/services/sun_times_service.dart';
import '../../../core/theme/app_theme.dart';

/// Gold strip: Sunrise · Zawal · Maghrib (location-based).
class SunTimesBar extends StatelessWidget {
  const SunTimesBar({super.key, this.times, this.embedded = false});

  final SunTimes? times;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _Item(label: 'Sunrise', value: times?.sunriseLabel ?? '--:--'),
          ),
          Expanded(
            child: _Item(label: 'Zawal', value: times?.zawalLabel ?? '--:--'),
          ),
          Expanded(
            child: _Item(label: 'Maghrib', value: times?.maghribLabel ?? '--:--'),
          ),
        ],
      ),
    );
    if (!embedded) return bar;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: bar,
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
