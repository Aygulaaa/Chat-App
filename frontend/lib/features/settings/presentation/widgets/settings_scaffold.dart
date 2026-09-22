import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/widgets/glass_backdrop.dart';

/// Page chrome shared by every settings screen: the soft glass backdrop, a
/// translucent centered title bar and a back chevron.
class SettingsScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;

  const SettingsScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBg,
      // The backdrop runs behind the bar, so the bar reads as a pane of glass
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: context.glassBar,
        shape: context.glassBarShape,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        centerTitle: true,
        leading: context.canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                color: context.textPrimary,
                tooltip: 'Back',
                // maybePop (not pop) so a page's PopScope gets a say — e.g.
                // step 2 of Change Password goes back to step 1.
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null,
        title: Text(
          title,
          style: TextStyle(
            color: context.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        actions: actions,
      ),
      body: GlassBackdrop(child: SafeArea(bottom: false, child: body)),
    );
  }
}
