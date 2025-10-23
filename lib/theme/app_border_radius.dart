import 'package:flutter/material.dart';

// 与KT UI对齐的圆角系统
class AppBorderRadius {
  // 基础圆角
  static const double xs = 4;
  static const double s = 8;
  static const double m = 12;
  static const double l = 16;
  static const double xl = 20;
  static const double full = 9999;
  
  // 常用圆角
  static const cardBorderRadius = BorderRadius.all(Radius.circular(m));
  static const buttonBorderRadius = BorderRadius.all(Radius.circular(m));
  static const dialogBorderRadius = BorderRadius.all(Radius.circular(l));
}
