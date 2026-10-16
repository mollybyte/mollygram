import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../forms/underline_field.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import '../theme/tokens.dart';

/// A sign-in screen as in the official Telegram apps: a plain window
/// background with one centered column, no wallpaper and no glass.
class SignInPage extends StatelessWidget {
  const SignInPage({
    super.key,
    required this.child,
    this.onBack,
    this.backTooltip,
    this.titleBarFill,
    this.titleBarInset = 76,
    this.footer,
  });

  /// The step: usually a [SignInHeader] followed by fields and a button.
  final Widget child;

  /// Shows a back button under the title bar.
  final VoidCallback? onBack;
  final String? backTooltip;

  /// Fills the 44 px title bar (the app's window drag area).
  final Widget? titleBarFill;

  /// Room for the system window buttons on the left of the title bar.
  final double titleBarInset;

  /// A quiet control centered at the bottom of the window, such as the
  /// proxy settings.
  final Widget? footer;

  /// Width of the centered column.
  static const double columnWidth = 320;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return ColoredBox(
      color: c.windowBackground,
      child: DefaultTextStyle.merge(
        style: mgTextStyle(c),
        child: Stack(
          children: [
            if (titleBarFill != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 44,
                child: titleBarFill!,
              ),
            Positioned.fill(
              top: 44,
              child: LayoutBuilder(
                builder: (context, box) => SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: box.maxHeight - 44),
                    child: Center(
                      child: SizedBox(
                        width: columnWidth,
                        child: _StepSwitcher(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (footer case final footer?)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Center(child: footer),
              ),
            if (onBack != null)
              Positioned(
                top: 52,
                left: 16,
                child: MgIconButton(
                  icon: MgIcons.back,
                  tooltip: backTooltip ?? '',
                  iconSize: 20,
                  onPressed: onBack,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The top of a sign-in step: an optional picture (the QR code, the app
/// icon), a title and a gray explanation, all centered.
class SignInHeader extends StatelessWidget {
  const SignInHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (leading != null) ...[
          Center(child: leading),
          const SizedBox(height: 28),
        ],
        Text(
          title,
          textAlign: TextAlign.center,
          style: mgTextStyle(
            c,
            size: 22,
            weight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 10),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: mgTextStyle(c, size: 14, color: c.fg2, height: 1.45),
          ),
        ],
      ],
    );
  }
}

/// The QR code on a white rounded square, with an optional mark in the
/// middle. The QR stays dark on white in both themes so phones can read it.
class QrFrame extends StatelessWidget {
  const QrFrame({
    super.key,
    required this.qr,
    this.center = const AppMark(size: 44),
    this.size = 200,
  });

  /// The QR code itself, drawn by the app in black.
  final Widget qr;

  /// The mark over the middle; defaults to [AppMark].
  final Widget? center;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MgColors.of(context).separator),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: qr),
          if (center != null)
            Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
              child: center,
            ),
        ],
      ),
    );
  }
}

/// The Mollygram mark in the theme accent: a white chat bubble with an "m"
/// on an accent circle, like the plane in the middle of Telegram's QR code.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 44, this.color});

  final double size;

  /// Defaults to the theme accent.
  final Color? color;

  static String _svg(Color accent) {
    final hex = (accent.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">'
        '<circle cx="50" cy="50" r="50" fill="#$hex"/>'
        '<path fill="#fff" d="M50 24c-16 0-28 10.5-28 24 0 7.2 3.4 13.5 9 17.9'
        '-.5 3.9-2.3 7.4-5.4 9.9 5.8.3 10.8-1.4 14.6-4.4 3.1.9 6.3 1.4 9.8 1.4'
        ' 16 0 28-10.5 28-24.8S66 24 50 24z"/>'
        '<path fill="none" stroke="#$hex" stroke-width="6" '
        'stroke-linecap="round" stroke-linejoin="round" '
        'd="M37.5 57V45.8a6.3 6.3 0 0 1 12.5 0V57M50 45.8a6.3 6.3 0 0 1 12.5 0'
        'V57"/></svg>';
  }

  @override
  Widget build(BuildContext context) {
    final accent = color ?? MgColors.of(context).accent;
    return SvgPicture.string(
      _svg(accent),
      width: size,
      height: size,
      excludeFromSemantics: true,
    );
  }
}

/// The numbered "how to scan" instructions under the QR code.
class SignInSteps extends StatelessWidget {
  const SignInSteps({super.key, required this.steps});

  /// Localized step texts, without numbers.
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    final style = mgTextStyle(c, size: 14, height: 1.4);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: mgTextStyle(
                      c,
                      size: 12,
                      weight: FontWeight.w600,
                      color: c.onAccent,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(steps[i], style: style),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The phone number form: the country on its own line, then the country
/// code and the number side by side, all underlined.
class PhoneNumberField extends StatelessWidget {
  const PhoneNumberField({
    super.key,
    required this.country,
    required this.codeController,
    required this.numberController,
    this.numberHint,
    this.onCountryTap,
    this.numberFocusNode,
    this.errorText,
    this.onSubmitted,
    this.autofocus = true,
  });

  /// The country name, or a localized "Country" placeholder.
  final String country;
  final VoidCallback? onCountryTap;

  /// Holds "+7" and the like.
  final TextEditingController codeController;
  final TextEditingController numberController;

  /// A sample number for the chosen country, such as "900 123 45 67".
  final String? numberHint;
  final FocusNode? numberFocusNode;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final c = MgColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          button: true,
          label: country,
          onTap: onCountryTap,
          excludeSemantics: true,
          child: MouseRegion(
            cursor: onCountryTap == null
                ? MouseCursor.defer
                : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onCountryTap,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.fg2.withValues(alpha: 0.3)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        country,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: mgTextStyle(c, size: 16, height: 1.25),
                      ),
                    ),
                    MgIcon(MgIcons.chevron, size: 16, color: c.fg2),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 64,
              child: MgUnderlineField(
                controller: codeController,
                keyboardType: TextInputType.phone,
                errorText: errorText == null ? null : '',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: MgUnderlineField(
                controller: numberController,
                focusNode: numberFocusNode,
                hintText: numberHint,
                keyboardType: TextInputType.phone,
                autofocus: autofocus,
                autofillHints: const [AutofillHints.telephoneNumberNational],
                errorText: errorText,
                onSubmitted: onSubmitted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One sign-in step gives way to the next: the old one fades out and the
/// new one fades in rising a few pixels, so the column never cuts.
class _StepSwitcher extends StatelessWidget {
  const _StepSwitcher({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : MgMotion.standard,
    switchInCurve: MgMotion.settle,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.center, children: [...previous, ?current]),
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 6 * (1 - animation.value)),
          child: child,
        ),
        child: child,
      ),
    ),
    child: child,
  );
}
