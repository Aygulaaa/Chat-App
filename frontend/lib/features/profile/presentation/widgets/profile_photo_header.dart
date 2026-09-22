import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:my_chat_app/core/theme/app_colors.dart';
import 'package:my_chat_app/core/theme/theme_ext.dart';

/// Telegram-style collapsing profile header. Fully open, the photo fills the
/// area edge to edge with the name and status over a scrim. Scrolling up makes
/// it shorter — and once it is down to the bar, the page swaps to a frosted
/// nav bar with a small round avatar.
///
/// That swap is deliberately a **switch, not a morph**: the photo never
/// shrinks and slides across the screen while you drag. One layout replaces
/// the other in a single frame, so the change reads as instant however fast
/// or slow the finger moves. (The photo itself stays mounted throughout, so
/// nothing is re-decoded on the way.)
///
/// It draws itself from whatever height it is given, between
/// [collapsedHeight] and [expandedHeight] (taller while overscrolled, which
/// just zooms the photo).
///
/// Tapping the photo opens it full-screen. With [onChangePhoto] a camera
/// button sits in the corner. Used for people and groups alike.
class ProfilePhotoHeader extends StatelessWidget {
  /// Name of the person or group; its first letter stands in for the photo.
  final String title;
  final String subtitle;

  /// Draws the subtitle in the "online" color.
  final bool highlightSubtitle;
  final String? imageUrl;
  final double expandedHeight;
  final double collapsedHeight;

  /// Space kept free at the bar's edges for the page's floating buttons.
  final double leadingInset;
  final double trailingInset;

  final VoidCallback? onChangePhoto;
  final bool uploadingPhoto;

  /// Lets the full-screen view save this photo. Only ever true for a photo
  /// that belongs to the person looking at it.
  final bool allowDownload;

  const ProfilePhotoHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.expandedHeight,
    required this.collapsedHeight,
    this.highlightSubtitle = false,
    this.leadingInset = 16,
    this.trailingInset = 16,
    this.onChangePhoto,
    this.uploadingPhoto = false,
    this.allowDownload = false,
  });

  /// Height of the bar the header collapses into, below the status bar.
  static const double barHeight = 56;

  static const double _avatarSize = 38;

  /// How much of the header's travel is left when it flips to the bar.
  static const double _switchAt = 0.06;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) =>
          _buildAt(context, constraints.maxWidth, constraints.maxHeight),
    );
  }

  Widget _buildAt(BuildContext context, double width, double height) {
    final url = imageUrl;
    final hasPhoto = url != null && url.isNotEmpty;
    final topInset = MediaQuery.paddingOf(context).top;

    // 1 = fully open, 0 = collapsed into the bar
    final open =
        ((height - collapsedHeight) / (expandedHeight - collapsedHeight)).clamp(
          0.0,
          1.0,
        );
    final bool folded = open <= _switchAt;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status bar icons while they sit on the photo
      value: folded && context.isLight
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The photo. Full width the whole way down — it only gets shorter,
          // and the bar is drawn on top of its last sliver.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: height,
            child: GestureDetector(
              onTap: hasPhoto ? () => _openPhoto(context, url) : null,
              child: _Photo(
                url: url,
                title: title,
                height: height,
                // The bar brings its own background; a scrim under it would
                // only muddy the blur.
                showScrim: !folded,
              ),
            ),
          ),

          // Name and status over the photo.
          if (!folded)
            Positioned(
              left: 20,
              right: onChangePhoto != null ? 76 : 20,
              top: height - 72,
              child: IgnorePointer(
                child: _Titles(
                  title: title,
                  subtitle: subtitle,
                  titleSize: 27,
                  subtitleSize: 14.5,
                  titleColor: Colors.white,
                  subtitleColor: highlightSubtitle
                      ? AppColors.online
                      : Colors.white.withValues(alpha: 0.82),
                  titleWeight: FontWeight.w700,
                  letterSpacing: -0.6,
                  shadowed: true,
                ),
              ),
            ),

          if (onChangePhoto != null && !folded)
            Positioned(
              right: 16,
              top: height - 16 - 46,
              child: PhotoGlassButton(
                icon: Icons.camera_alt_rounded,
                tooltip: 'Change photo',
                size: 46,
                busy: uploadingPhoto,
                onTap: onChangePhoto!,
              ),
            ),

          // The frosted bar. Taps fall through to the photo behind it, so the
          // small avatar still opens the picture.
          if (folded)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: collapsedHeight,
              child: IgnorePointer(
                child: _CollapsedBar(
                  title: title,
                  subtitle: subtitle,
                  highlightSubtitle: highlightSubtitle,
                  url: url,
                  topInset: topInset,
                  leadingInset: leadingInset,
                  trailingInset: trailingInset,
                  avatarSize: _avatarSize,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _openPhoto(BuildContext context, String url) {
    context.push(
      '/image-viewer',
      extra: {'url': url, 'title': title, 'canDownload': allowDownload},
    );
  }
}

/// First letter on the brand gradient — used whenever there is no photo, and
/// while one is loading.
class _Fallback extends StatelessWidget {
  final String title;
  final double fontSize;

  const _Fallback({required this.title, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: Center(
        child: Text(
          title.isEmpty ? '?' : title[0].toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String? url;
  final String title;
  final double height;
  final bool showScrim;

  const _Photo({
    required this.url,
    required this.title,
    required this.height,
    required this.showScrim,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;
    final fallback = _Fallback(title: title, fontSize: height * 0.2);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (hasPhoto)
          CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            placeholder: (_, _) => fallback,
            errorWidget: (_, _, _) => fallback,
          )
        else
          fallback,

        // Scrim: keeps the status bar and the name readable on any photo.
        // The plain gradient fallback only needs a touch at the bottom.
        if (showScrim)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: hasPhoto
                    ? const [
                        Color(0x59000000),
                        Color(0x00000000),
                        Color(0x99000000),
                      ]
                    : const [
                        Color(0x00000000),
                        Color(0x00000000),
                        Color(0x47000000),
                      ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
      ],
    );
  }
}

/// What the header turns into: blurred bar, small round avatar, name beside it.
class _CollapsedBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool highlightSubtitle;
  final String? url;
  final double topInset;
  final double leadingInset;
  final double trailingInset;
  final double avatarSize;

  const _CollapsedBar({
    required this.title,
    required this.subtitle,
    required this.highlightSubtitle,
    required this.url,
    required this.topInset,
    required this.leadingInset,
    required this.trailingInset,
    required this.avatarSize,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = url != null && url!.isNotEmpty;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.appBg.withValues(alpha: 0.55),
            border: Border(
              bottom: BorderSide(color: context.glassEdge, width: 0.5),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(
              top: topInset,
              left: leadingInset,
              right: trailingInset,
            ),
            child: SizedBox(
              height: ProfilePhotoHeader.barHeight,
              child: Row(
                children: [
                  ClipOval(
                    child: SizedBox(
                      width: avatarSize,
                      height: avatarSize,
                      child: hasPhoto
                          ? CachedNetworkImage(
                              imageUrl: url!,
                              fit: BoxFit.cover,
                              placeholder: (_, _) =>
                                  _Fallback(title: title, fontSize: 17),
                              errorWidget: (_, _, _) =>
                                  _Fallback(title: title, fontSize: 17),
                            )
                          : _Fallback(title: title, fontSize: 17),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Titles(
                      title: title,
                      subtitle: subtitle,
                      titleSize: 17,
                      subtitleSize: 12.5,
                      titleColor: context.textPrimary,
                      subtitleColor: highlightSubtitle
                          // The brand mint is unreadable on the light bar
                          ? (context.isLight
                                ? const Color(0xFF1E9E74)
                                : AppColors.online)
                          : context.textTertiary,
                      titleWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                      shadowed: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  final String title;
  final String subtitle;
  final double titleSize;
  final double subtitleSize;
  final Color titleColor;
  final Color subtitleColor;
  final FontWeight titleWeight;
  final double letterSpacing;
  final bool shadowed;

  const _Titles({
    required this.title,
    required this.subtitle,
    required this.titleSize,
    required this.subtitleSize,
    required this.titleColor,
    required this.subtitleColor,
    required this.titleWeight,
    required this.letterSpacing,
    required this.shadowed,
  });

  @override
  Widget build(BuildContext context) {
    final shadows = shadowed
        ? [Shadow(blurRadius: 8, color: Colors.black.withValues(alpha: 0.4))]
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: titleColor,
            fontSize: titleSize,
            height: 1.2,
            fontWeight: titleWeight,
            letterSpacing: letterSpacing,
            shadows: shadows,
          ),
        ),
        SizedBox(height: shadowed ? 2 : 0),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: subtitleColor,
            fontSize: subtitleSize,
            height: 1.2,
            shadows: shadows,
          ),
        ),
      ],
    );
  }
}

/// Round frosted button that stays legible on top of any photo.
class PhotoGlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final double size;
  final bool busy;

  const PhotoGlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.size = 40,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Material(
            color: Colors.black.withValues(alpha: 0.28),
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.22),
                width: 0.6,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: busy ? null : onTap,
              child: SizedBox(
                width: size,
                height: size,
                child: Center(
                  child: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(icon, color: Colors.white, size: size * 0.48),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
