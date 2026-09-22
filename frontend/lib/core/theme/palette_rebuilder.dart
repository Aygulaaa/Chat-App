import 'package:flutter/widgets.dart';

/// Rebuilds everything below it once whenever [paletteId] changes.
///
/// Most widgets pick a new palette up through `Theme.of`. But plenty read
/// `AppColors.primary` directly, and a `const` widget that does only that has
/// no reason to rebuild — it would keep the old palette's color until it was
/// next recreated. Marking the whole subtree dirty once per switch fixes that
/// without remounting anything (scroll positions, routes and state survive).
class PaletteRebuilder extends StatefulWidget {
  final String paletteId;
  final Widget child;

  const PaletteRebuilder({
    super.key,
    required this.paletteId,
    required this.child,
  });

  @override
  State<PaletteRebuilder> createState() => _PaletteRebuilderState();
}

class _PaletteRebuilderState extends State<PaletteRebuilder> {
  @override
  void didUpdateWidget(PaletteRebuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paletteId == widget.paletteId) return;

    // After this frame: the new palette is active by then
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.visitChildElements(_markDirty);
    });
  }

  static void _markDirty(Element element) {
    element.markNeedsBuild();
    element.visitChildren(_markDirty);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
