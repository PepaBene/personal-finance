import 'package:flutter/material.dart';

import '../../domain/entities/category.dart';

/// Resolves a category's stored `colorHex` (#RRGGBB) to a [Color].
Color categoryColor(String colorHex) {
  var hex = colorHex.replaceFirst('#', '');
  if (hex.length == 6) hex = 'FF$hex';
  return Color(int.tryParse(hex, radix: 16) ?? 0xFF4E79A7);
}

/// Maps a stored icon key to a Material icon (the seeded set + a safe fallback).
/// Icons must be const for tree-shaking, hence the explicit map.
IconData categoryIcon(String key) => _icons[key] ?? Icons.category_outlined;

const _icons = <String, IconData>{
  'restaurant': Icons.restaurant,
  'home': Icons.home_outlined,
  'directions_car': Icons.directions_car_outlined,
  'health_and_safety': Icons.health_and_safety_outlined,
  'sports_esports': Icons.sports_esports_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'bolt': Icons.bolt_outlined,
  'account_balance': Icons.account_balance_outlined,
  'payments': Icons.payments_outlined,
  'category': Icons.category_outlined,
  'local_grocery_store': Icons.local_grocery_store_outlined,
  'lunch_dining': Icons.lunch_dining_outlined,
  'apartment': Icons.apartment_outlined,
  'local_gas_station': Icons.local_gas_station_outlined,
  'subscriptions': Icons.subscriptions_outlined,
  'wallet': Icons.wallet_outlined,
};

/// Finds a category by id in a flat list, or null.
CategoryEntity? categoryById(List<CategoryEntity> all, String? id) {
  if (id == null) return null;
  for (final c in all) {
    if (c.id == id) return c;
  }
  return null;
}
