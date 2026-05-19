import 'package:flutter/material.dart';

import '../core/theme/app_typography.dart';

/// Franja inferior roja cuando no hay conectividad (p. ej. tiles del mapa por red).
class MapOfflineBanner extends StatelessWidget {
  const MapOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.red.shade800,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          child: Row(
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Desconexión a internet. Los planos del mapa pueden no actualizarse.',
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
