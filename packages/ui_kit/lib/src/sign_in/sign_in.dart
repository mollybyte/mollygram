import 'package:flutter/material.dart';

import '../forms/underline_field.dart';
import '../icon_button.dart';
import '../icons.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

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
                      child: SizedBox(width: columnWidth, child: child),
                    ),
                  ),
                ),
              ),
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
  const QrFrame({super.key, required this.qr, this.center, this.size = 200});

  /// The QR code itself, drawn by the app in black.
  final Widget qr;

  /// A small mark over the middle, such as the app icon.
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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: center,
            ),
        ],
      ),
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
