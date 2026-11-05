import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Ilova belgisi: indigo gradientli yumaloq kvadrat ichida do'kon.
class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.3),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDeep],
        ),
      ),
      child: Icon(Icons.storefront_rounded,
          color: Colors.white, size: size * 0.54),
    );
  }
}
