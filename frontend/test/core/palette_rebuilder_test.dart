import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/palette_rebuilder.dart';

/// Reads the palette statically and has no Theme dependency — the kind of
/// widget that used to keep the previous palette's color after a switch.
class _StaticSwatch extends StatelessWidget {
  const _StaticSwatch();

  @override
  Widget build(BuildContext context) => ColoredBox(color: AppColors.primary);
}

void main() {
  tearDown(() => AppColors.active = const DarkColors());

  testWidgets('a palette switch repaints const widgets that read AppColors directly', (tester) async {
    Widget app(AppColorScheme palette) {
      AppColors.active = palette;
      return PaletteRebuilder(
        paletteId: palette.id,
        child: const Directionality(
          textDirection: TextDirection.ltr,
          child: _StaticSwatch(),
        ),
      );
    }

    Color shown() => tester.widget<ColoredBox>(find.byType(ColoredBox)).color;

    await tester.pumpWidget(app(const DarkColors()));
    expect(shown(), const DarkColors().primary);

    await tester.pumpWidget(app(const BurgundyColors()));
    await tester.pump();
    expect(shown(), const BurgundyColors().primary);
  });
}
