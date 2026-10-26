import 'package:flutter/material.dart';

/// Maps domain `iconKey`s to Material icons.
///
/// Keeping the mapping in presentation preserves the Flutter-free domain layer
/// while still allowing the category catalog to describe its own visuals.
IconData categoryIcon(String iconKey) => switch (iconKey) {
      'restaurant' => Icons.restaurant_rounded,
      'shopping_basket' => Icons.shopping_basket_rounded,
      'directions_car' => Icons.directions_car_rounded,
      'local_gas_station' => Icons.local_gas_station_rounded,
      'shopping_bag' => Icons.shopping_bag_rounded,
      'movie' => Icons.movie_rounded,
      'receipt_long' => Icons.receipt_long_rounded,
      'home' => Icons.home_rounded,
      'health_and_safety' => Icons.health_and_safety_rounded,
      'school' => Icons.school_rounded,
      'flight' => Icons.flight_rounded,
      'shield' => Icons.shield_rounded,
      'trending_up' => Icons.trending_up_rounded,
      'swap_horiz' => Icons.swap_horiz_rounded,
      'payments' => Icons.payments_rounded,
      'atm' => Icons.atm_rounded,
      'percent' => Icons.percent_rounded,
      'subscriptions' => Icons.subscriptions_rounded,
      'spa' => Icons.spa_rounded,
      'volunteer_activism' => Icons.volunteer_activism_rounded,
      'mail' => Icons.mail_rounded,
      'sms' => Icons.sms_rounded,
      'notifications' => Icons.notifications_rounded,
      'edit' => Icons.edit_rounded,
      'category' => Icons.category_rounded,
      _ => Icons.help_outline_rounded,
    };
