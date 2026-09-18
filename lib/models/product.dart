import 'package:flutter/material.dart';

class Product {
  Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.category,
    required this.color,
    this.published = true,
    this.stock = 1,
  });

  String id;
  String title;
  String description;
  int price;
  String category;
  Color color;
  bool published;
  int stock;
}
