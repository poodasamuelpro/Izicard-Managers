import 'package:flutter/material.dart';

/// Centre le contenu sur les grands écrans tout en conservant une marge
/// confortable sur téléphone et tablette en mode portrait.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    super.key,
    required this.child,
    this.maxWidth = 1180,
    this.padding = const EdgeInsets.fromLTRB(20, 14, 20, 32),
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Padding(padding: padding, child: child),
    ),
  );
}
