import 'package:flutter/material.dart';



// 与KT UI对齐的间距系统
class AppSpacing {
  // 基础间距
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
  static const double xxl = 48;
  
  // 组件内边距
  static const cardPadding = EdgeInsets.all(16);
  static const sectionPadding = EdgeInsets.all(16);
  static const screenPadding = EdgeInsets.all(16);
  static const buttonPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
}
