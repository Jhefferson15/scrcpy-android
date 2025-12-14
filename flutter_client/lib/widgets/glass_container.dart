import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final Color? color;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Border? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 10,
    this.opacity = 0.1,
    this.color,
    this.borderRadius,
    this.padding,
    this.margin,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (color ?? Colors.white).withValues(alpha: opacity),
              borderRadius: borderRadius ?? BorderRadius.circular(20),
              border: border ??
                  Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                    width: 1.5,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
