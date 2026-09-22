import 'package:flutter/material.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// What every screen's glass sits on: the app gradient with two soft glows in
/// the palette's colors. It is smooth, so the cards on top only need a
/// translucent fill — no per-card [BackdropFilter].
class GlassBackdrop extends StatelessWidget {
  final Widget child;

  const GlassBackdrop({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: context.appBgGradient),
            child: const _Glows(),
          ),
        ),
        child,
      ],
    );
  }
}

class _Glows extends StatelessWidget {
  const _Glows();

  @override
  Widget build(BuildContext context) {
    final strength = context.isLight ? 0.30 : 0.16;

    return Stack(
      fit: StackFit.expand,
      children: [
        _glow(const Alignment(-1.1, -0.9), context.primaryColor, strength),
        _glow(const Alignment(1.2, 0.55), context.accentColor, strength * 0.8),
      ],
    );
  }

  Widget _glow(Alignment center, Color color, double alpha) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: 0.9,
          colors: [
            color.withValues(alpha: alpha),
            color.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
