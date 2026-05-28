import 'package:flutter/material.dart';

final ThemeData adminLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  fontFamily: 'unageo',
  // 🎨 Enterprise Color Scheme
  colorScheme: const ColorScheme.light(
    primary: Color.fromARGB(255, 42, 146, 231), // Indigo 800
    secondary: Color.fromARGB(255, 232, 232, 232), // Teal 700
    surface: Color(0xFFFFFFFF),
    background: Color(0xFFF1F5F9), // Slate 100
    error: Color(0xFFB91C1C),
    onPrimary: Colors.white,
    onSecondary: Colors.white,
    onSurface: Color(0xFF0F172A),
    onBackground: Color(0xFF0F172A),
    onError: Colors.white,
  ),

  // 🖋 Admin Typography (dense & readable)
  textTheme: const TextTheme(
    displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
    displayMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    bodyLarge: TextStyle(fontSize: 14),
    bodyMedium: TextStyle(fontSize: 13),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    labelMedium: TextStyle(fontSize: 12),
  ),

  // 🧱 AppBar (Dashboard Header)
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Color(0xFF0F172A),
    elevation: 1,
    centerTitle: false,
    
    titleTextStyle: TextStyle(
      fontSize: 16,
      fontFamily: 'unageo',
      fontWeight: FontWeight.w600,
      color: Color(0xFF0F172A),
    ),
  ),


  // 🔘 Buttons (less rounded, admin feel)
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      foregroundColor: Colors.white,
      minimumSize: const Size(96, 40),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
    
      textStyle: const TextStyle(
        fontFamily: 'unageo',
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  

  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(96, 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
      ),
      side: const BorderSide(color: Color(0xFFCBD5E1)),
      textStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    ),
  ),

  // 🧾 Input Fields (forms-heavy)
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(6),
      borderSide: const BorderSide(color: Color(0xFF1E40AF)),
    ),
    labelStyle: const TextStyle(fontSize: 12),
    hintStyle: const TextStyle(fontSize: 12),
  ),

  // 📊 Data-heavy UI helpers
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE2E8F0),
    thickness: 1,
    space: 1,
  ),

  dataTableTheme: DataTableThemeData(
    headingRowColor: MaterialStateProperty.all(
      const Color(0xFFF8FAFC),
    ),
    dataRowMinHeight: 44,
    headingTextStyle: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Color(0xFF334155),
    ),
    dataTextStyle: const TextStyle(
      fontSize: 13,
      color: Color(0xFF0F172A),
    ),
  ),

  // 🧭 Navigation (Sidebar / Drawer)
  navigationRailTheme: const NavigationRailThemeData(
    backgroundColor: Colors.white,
    selectedIconTheme: IconThemeData(color: Color(0xFF1E40AF)),
    selectedLabelTextStyle: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF1E40AF),
    ),
    unselectedIconTheme: IconThemeData(color: Color(0xFF64748B)),
    unselectedLabelTextStyle: TextStyle(
      fontSize: 12,
      color: Color(0xFF64748B),
    ),
  ),

  drawerTheme: const DrawerThemeData(
    backgroundColor: Colors.white,
  ),

  // 🌐 Web-friendly density
  visualDensity: VisualDensity.compact,

  scaffoldBackgroundColor: const Color(0xFFF1F5F9),
);
