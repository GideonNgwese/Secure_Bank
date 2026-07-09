import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/header_provider.dart';
import '../theme/app_theme.dart';
import '../theme/design_system.dart';

enum HeaderVariant { glass, gradient }

enum HeaderLeading { auto, avatar, back, none }

const _heroAvatarTag = 'securebank-header-avatar';

/// One figure in the header's module-adaptive summary row (e.g. "Balance"
/// → "850,000 FCFA"). The caller pre-formats [value] — the header stays
/// agnostic of currency formatting/domain models so it can be reused by
/// any module.
class HeaderStat {
  final String label;
  final String value;
  final Color? valueColor;
  const HeaderStat(this.label, this.value, {this.valueColor});
}

/// The single reusable app header — a premium, animated, dark-mode-aware
/// bar used at the top of every screen in place of ad-hoc [AppBar]s.
///
/// Placed as the first child of a screen's body [Column] (not
/// [Scaffold.appBar]) so it can genuinely collapse as the user scrolls when
/// a [scrollController] is supplied, instead of living in a fixed-height
/// app-bar slot. Pass the same controller you give your `ListView`/
/// `CustomScrollView` and the header shrinks + blurs more as the user
/// scrolls, expanding back on the way up.
class PremiumHeader extends ConsumerStatefulWidget {
  final String userId;
  final String title;
  final String? subtitle;
  final HeaderVariant variant;
  final HeaderLeading leading;
  final ScrollController? scrollController;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNotificationsTap;
  final VoidCallback? onSettingsTap;
  final List<Widget>? extraActions;
  final bool showSecurityIndicator;

  /// Module-adaptive financial summary shown under the title (e.g. Dashboard
  /// passes Balance/Income/Expenses, Accounts passes just Total balance,
  /// Budgets passes Remaining). Null/empty means no summary row — the
  /// header falls back to just the title (and [subtitle] on Dashboard).
  final List<HeaderStat>? stats;

  const PremiumHeader({
    super.key,
    required this.userId,
    required this.title,
    this.subtitle,
    this.variant = HeaderVariant.glass,
    this.leading = HeaderLeading.auto,
    this.scrollController,
    this.onAvatarTap,
    this.onNotificationsTap,
    this.onSettingsTap,
    this.extraActions,
    this.showSecurityIndicator = true,
    this.stats,
  });

  @override
  ConsumerState<PremiumHeader> createState() => _PremiumHeaderState();
}

class _PremiumHeaderState extends ConsumerState<PremiumHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PremiumHeader old) {
    super.didUpdateWidget(old);
    if (old.scrollController != widget.scrollController) {
      old.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  void _onScroll() => setState(() {});

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    _pulse.dispose();
    super.dispose();
  }

  double get _collapseT {
    final c = widget.scrollController;
    if (c == null || !c.hasClients) return 0;
    return (c.offset / 80).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final t = _collapseT;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = Navigator.canPop(context);
    final showAvatar = widget.leading == HeaderLeading.avatar ||
        (widget.leading == HeaderLeading.auto && !canPop);
    final showBack = widget.leading == HeaderLeading.back ||
        (widget.leading == HeaderLeading.auto && canPop);

    final hasStats = widget.stats != null && widget.stats!.isNotEmpty;
    // Generous enough to fit title + subtitle + stat row at larger system
    // text-scale settings without the inner Column overflowing — the
    // previous, tighter budget (128/86 + 34) clipped on devices with
    // increased accessibility text scaling.
    final baseHeight =
        (widget.subtitle != null ? 140.0 : 92.0) + (hasStats ? 44.0 : 0.0);
    const minHeight = 72.0;
    final height = lerpDouble(baseHeight, minHeight, t)!;
    final avatarRadius = lerpDouble(24, 18, t)!;
    final blurSigma = lerpDouble(8, 20, t)!;
    final bgAlpha = lerpDouble(isDark ? 0.55 : 0.65, isDark ? 0.9 : 0.94, t)!;
    final subtitleOpacity = (1 - t * 2.2).clamp(0.0, 1.0);
    final titleStyle = TextStyle.lerp(
      AppTextStyles.headerTitle,
      AppTextStyles.headerTitleCompact,
      t,
    )!
        .copyWith(
            color: isDark || widget.variant == HeaderVariant.gradient
                ? Colors.white
                : const Color(0xFF0A1B3D));

    return SafeArea(
      bottom: false,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        builder: (context, entrance, child) => Opacity(
          opacity: entrance.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - entrance) * -14),
            child: child,
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: height,
          margin: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xs),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
              child: Container(
                decoration: _decoration(isDark, bgAlpha),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Row(
                  children: [
                    if (showBack)
                      HeaderIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        isDark:
                            isDark || widget.variant == HeaderVariant.gradient,
                        onTap: () => Navigator.of(context).maybePop(),
                      )
                    else if (showAvatar)
                      _Avatar(
                        userId: widget.userId,
                        radius: avatarRadius,
                        isDark: isDark,
                        onTap: widget.onAvatarTap,
                        showSecurityIndicator: widget.showSecurityIndicator,
                      )
                    else
                      const SizedBox(width: 4),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: titleStyle),
                          if (widget.subtitle != null && subtitleOpacity > 0)
                            Opacity(
                              opacity: subtitleOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(widget.subtitle!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.headerSubtitle
                                        .copyWith(
                                            color: isDark ||
                                                    widget.variant ==
                                                        HeaderVariant.gradient
                                                ? Colors.white70
                                                : const Color(0xFF5B6472))),
                              ),
                            ),
                          if (hasStats && subtitleOpacity > 0)
                            Opacity(
                              opacity: subtitleOpacity,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Row(
                                  children: [
                                    for (var i = 0;
                                        i < widget.stats!.length;
                                        i++) ...[
                                      // Expanded so 3+ stat blocks (e.g.
                                      // Balance/Income/Expenses with long
                                      // FCFA values) share the row's width
                                      // instead of each taking its natural
                                      // width and overflowing off the right
                                      // edge on narrower phones.
                                      Expanded(
                                        child: _StatBlock(
                                          stat: widget.stats![i],
                                          isDark: isDark ||
                                              widget.variant ==
                                                  HeaderVariant.gradient,
                                        ),
                                      ),
                                      if (i != widget.stats!.length - 1)
                                        const SizedBox(width: 12),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (widget.extraActions != null) ...[
                      for (final action in widget.extraActions!) ...[
                        action,
                        const SizedBox(width: 8),
                      ],
                    ],
                    _NotificationBell(
                      userId: widget.userId,
                      isDark:
                          isDark || widget.variant == HeaderVariant.gradient,
                      pulse: _pulse,
                      onTap: widget.onNotificationsTap,
                    ),
                    const SizedBox(width: 8),
                    HeaderIconButton(
                      icon: Icons.settings_outlined,
                      isDark:
                          isDark || widget.variant == HeaderVariant.gradient,
                      onTap: widget.onSettingsTap,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _decoration(bool isDark, double alpha) {
    if (widget.variant == HeaderVariant.gradient) {
      return BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1B3D), Color(0xFF2348C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF0A1B3D).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      );
    }
    final base = isDark ? const Color(0xFF141634) : Colors.white;
    return BoxDecoration(
      color: base.withValues(alpha: alpha),
      border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.6)),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8)),
      ],
    );
  }
}

// ----------------------------- Stat block -----------------------------

/// One "Label / Value" pair in the module-adaptive summary row.
class _StatBlock extends StatelessWidget {
  final HeaderStat stat;
  final bool isDark;
  const _StatBlock({required this.stat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? Colors.white60 : const Color(0xFF7A8699);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 10.5,
                color: mutedColor,
                fontWeight: FontWeight.w500)),
        Text(stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: stat.valueColor ??
                    (isDark ? Colors.white : const Color(0xFF0A1B3D)))),
      ],
    );
  }
}

// ----------------------------- Avatar -----------------------------

class _Avatar extends ConsumerWidget {
  final String userId;
  final double radius;
  final bool isDark;
  final VoidCallback? onTap;
  final bool showSecurityIndicator;

  const _Avatar({
    required this.userId,
    required this.radius,
    required this.isDark,
    required this.onTap,
    required this.showSecurityIndicator,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProfileProvider(userId));
    final photo = userAsync.valueOrNull?.photoUrl ?? '';
    final name = userAsync.valueOrNull?.name ?? '';
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final status = ref.watch(headerSecurityStatusProvider(userId));

    return GestureDetector(
      onTap: onTap,
      child: Hero(
        tag: _heroAvatarTag,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white,
                    width: 2),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4)),
                ],
              ),
              child: ClipOval(
                child: photo.isEmpty
                    ? _initials(initials)
                    : Image.network(
                        photo,
                        key: ValueKey(photo),
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _initials(initials, loading: true);
                        },
                        errorBuilder: (_, __, ___) => _initials(initials),
                      ),
              ),
            ),
            if (showSecurityIndicator)
              Positioned(
                right: -2,
                bottom: -2,
                child: Tooltip(
                  message: status == SecurityStatus.secure
                      ? 'Secure'
                      : 'Risk detected',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141634) : Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      status == SecurityStatus.secure
                          ? Icons.verified_user_rounded
                          : Icons.gpp_maybe_rounded,
                      size: 13,
                      color: status == SecurityStatus.secure
                          ? AppTokens.success
                          : AppTokens.danger,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String initials, {bool loading = false}) {
    return Container(
      color: AppTokens.brand.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: loading
          ? SizedBox(
              width: radius * 0.7,
              height: radius * 0.7,
              child: const CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(initials,
              style: TextStyle(
                  color: AppTokens.brand,
                  fontWeight: FontWeight.bold,
                  fontSize: radius * 0.65)),
    );
  }
}

// ----------------------------- Notification bell -----------------------------

class _NotificationBell extends ConsumerWidget {
  final String userId;
  final bool isDark;
  final AnimationController pulse;
  final VoidCallback? onTap;

  const _NotificationBell({
    required this.userId,
    required this.isDark,
    required this.pulse,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(headerUnreadCountProvider(userId));
    return AnimatedBuilder(
      animation: pulse,
      builder: (context, _) => HeaderIconButton(
        icon: Icons.notifications_none_rounded,
        isDark: isDark,
        onTap: onTap,
        badge: count > 0 ? (count > 9 ? '9+' : '$count') : null,
        pulseScale: count > 0 ? 1 + pulse.value * 0.35 : 1,
      ),
    );
  }
}

// ----------------------------- Shared circular icon button -----------------------------

/// The same circular glass icon button [PremiumHeader] uses for its bell
/// and settings icons — exposed so screens can pass a matching-styled
/// action (e.g. "Import CSV", "Export") via [PremiumHeader.extraActions].
class HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback? onTap;
  final String? badge;
  final double pulseScale;

  const HeaderIconButton({
    super.key,
    required this.icon,
    required this.isDark,
    this.onTap,
    this.badge,
    this.pulseScale = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon,
                  size: 20, color: isDark ? Colors.white : AppTokens.brand),
              if (badge != null)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Transform.scale(
                    scale: pulseScale,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      constraints:
                          const BoxConstraints(minWidth: 15, minHeight: 15),
                      decoration: BoxDecoration(
                        color: AppTokens.danger,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: AppTokens.danger.withValues(alpha: 0.5),
                              blurRadius: 5,
                              spreadRadius: (pulseScale - 1) * 3),
                        ],
                      ),
                      child: Text(badge!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold)),
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
