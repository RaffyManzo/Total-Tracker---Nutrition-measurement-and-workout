import 'package:flutter/material.dart';

abstract final class AppShadows {
  static const List<BoxShadow> lightCard = <BoxShadow>[
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 26,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> darkCard = <BoxShadow>[
    BoxShadow(
      color: Color(0x52000000),
      blurRadius: 28,
      offset: Offset(0, 12),
    ),
  ];

  static List<BoxShadow> card(Brightness brightness) =>
      brightness == Brightness.light ? lightCard : darkCard;
}
