import 'package:flutter/material.dart';

extension WidgetExtensions on Widget {
  Widget paddingAll(double value) =>
      Padding(padding: EdgeInsets.all(value), child: this);

  Widget paddingSymmetric({double horizontal = 0, double vertical = 0}) =>
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontal,
          vertical: vertical,
        ),
        child: this,
      );

  Widget semanticsLabel(String label, {bool excludeSemantics = false}) =>
      Semantics(label: label, excludeSemantics: excludeSemantics, child: this);

  Widget animateFadeIn({Duration delay = Duration.zero}) => this;
}
