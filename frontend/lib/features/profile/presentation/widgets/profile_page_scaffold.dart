import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';
import 'package:my_chat_app/core/widgets/glass_backdrop.dart';
import 'package:my_chat_app/features/profile/presentation/widgets/profile_photo_header.dart';

/// The page every profile is built on — mine, someone else's, a group's.
///
/// A photo takes a little over half the screen and collapses into a pinned bar
/// as the page scrolls; [children] (glass sections) scroll beneath it, and the
/// round [leading] / [trailing] buttons float over the top.
class ProfilePageScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlightSubtitle;
  final String? imageUrl;

  final Widget? leading;
  final Widget? trailing;

  final VoidCallback? onChangePhoto;
  final bool uploadingPhoto;

  /// Lets the full-screen view save the photo — only for your own.
  final bool allowPhotoDownload;

  /// Enables pull-to-refresh.
  final Future<void> Function()? onRefresh;

  final List<Widget> children;
  final double bottomPadding;

  const ProfilePageScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.children,
    this.highlightSubtitle = false,
    this.leading,
    this.trailing,
    this.onChangePhoto,
    this.uploadingPhoto = false,
    this.allowPhotoDownload = false,
    this.onRefresh,
    this.bottomPadding = 40,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final expanded = media.size.height * 0.56;
    final collapsed = media.padding.top + ProfilePhotoHeader.barHeight;

    Widget scroll = CustomScrollView(
      // Bounce everywhere: pulling down stretches the photo
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _PhotoHeaderDelegate(
            expanded: expanded,
            collapsed: collapsed,
            child: ProfilePhotoHeader(
              title: title,
              subtitle: subtitle,
              highlightSubtitle: highlightSubtitle,
              imageUrl: imageUrl,
              expandedHeight: expanded,
              collapsedHeight: collapsed,
              // Clear of the floating buttons
              leadingInset: leading == null ? 16 : 62,
              trailingInset: trailing == null ? 16 : 62,
              onChangePhoto: onChangePhoto,
              uploadingPhoto: uploadingPhoto,
              allowDownload: allowPhotoDownload,
            ),
          ),
        ),
        SliverToBoxAdapter(
          // At least a screenful, so even a short page can collapse the photo
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: media.size.height - collapsed,
            ),
            child: Padding(
              padding: EdgeInsets.only(top: 20, bottom: bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ],
    );

    if (onRefresh != null) {
      scroll = RefreshIndicator.adaptive(
        color: AppColors.primary,
        onRefresh: onRefresh!,
        child: scroll,
      );
    }

    return Scaffold(
      backgroundColor: context.appBg,
      body: GlassBackdrop(
        child: Stack(
          children: [
            Positioned.fill(child: scroll),
            if (leading != null || trailing != null)
              Positioned(
                top: media.padding.top + 8,
                left: 12,
                right: 12,
                child: Row(children: [?leading, const Spacer(), ?trailing]),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhotoHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double expanded;
  final double collapsed;
  final Widget child;

  const _PhotoHeaderDelegate({
    required this.expanded,
    required this.collapsed,
    required this.child,
  });

  @override
  double get maxExtent => expanded;

  @override
  double get minExtent => collapsed;

  @override
  OverScrollHeaderStretchConfiguration get stretchConfiguration =>
      OverScrollHeaderStretchConfiguration();

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      child;

  @override
  bool shouldRebuild(_PhotoHeaderDelegate old) =>
      expanded != old.expanded ||
      collapsed != old.collapsed ||
      child != old.child;
}
