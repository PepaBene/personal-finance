import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ledgerly_app/src/domain/entities/category.dart';
import 'package:ledgerly_app/src/domain/enums.dart';
import 'package:ledgerly_app/src/features/categories/category_visuals.dart';

CategoryEntity _cat(String id, String name) => CategoryEntity(
      id: id,
      userId: 'u',
      name: name,
      kind: CategoryKind.expense,
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test('categoryColor parses #RRGGBB and bare hex to opaque colors', () {
    expect(categoryColor('#4E79A7').toARGB32(), 0xFF4E79A7);
    expect(categoryColor('4E79A7').toARGB32(), 0xFF4E79A7);
  });

  test('categoryColor falls back on invalid input', () {
    expect(categoryColor('not-a-color').toARGB32(), 0xFF4E79A7);
  });

  test('categoryIcon returns a fallback for unknown keys', () {
    expect(categoryIcon('definitely-unknown'), Icons.category_outlined);
  });

  test('categoryById finds by id and returns null when absent', () {
    final cats = [_cat('a', 'Food'), _cat('b', 'Salary')];
    expect(categoryById(cats, 'b')?.name, 'Salary');
    expect(categoryById(cats, 'zzz'), isNull);
    expect(categoryById(cats, null), isNull);
  });
}
