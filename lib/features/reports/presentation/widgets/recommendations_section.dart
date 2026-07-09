import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import 'report_card.dart';

class RecommendationsSection extends StatelessWidget {
  final List<String> recommendations;
  const RecommendationsSection({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return ReportCard(
      title: 'Recommendations',
      child: Column(
        children: [
          for (final tip in recommendations)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 5),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppTokens.brand, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(tip,
                          style: const TextStyle(fontSize: 12.5, height: 1.4))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
