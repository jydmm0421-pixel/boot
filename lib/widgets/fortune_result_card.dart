import 'package:flutter/material.dart';
import '../models/fortune_result.dart';

/// 算命结果展示组件 — 八字四柱 + 紫微十二宫
class FortuneResultCard extends StatelessWidget {
  final FortuneResult result;

  const FortuneResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 出生信息摘要
          _buildInfoCard(context),
          const SizedBox(height: 16),

          // 八字四柱
          if (result.baZi != null) ...[
            _buildSectionTitle('八字四柱'),
            const SizedBox(height: 8),
            _buildBaZiSection(context, result.baZi!),
            const SizedBox(height: 20),
          ],

          // 紫微命盘
          if (result.chart != null) ...[
            _buildSectionTitle('紫微斗数十二宫'),
            const SizedBox(height: 8),
            ...result.chart!.palaces.map((p) => _buildPalaceCard(context, p)),
          ],

          const SizedBox(height: 16),
          Text(
            '计算结果由 dart_iztro 引擎生成，仅供娱乐参考',
            style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context) {
    final input = result.birthInput;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primaryContainer
                    .withAlpha(100),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.person,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$input',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${result.calculatedAt.month}/${result.calculatedAt.day} '
                    '${result.calculatedAt.hour.toString().padLeft(2, '0')}:'
                    '${result.calculatedAt.minute.toString().padLeft(2, '0')} 排盘',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaZiSection(BuildContext context, BaZiResult baZi) {
    final labels = ['年柱', '月柱', '日柱', '时柱'];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(4, (i) {
          final pillar = baZi.pillars[i];
          return Container(
            width: 100,
            margin: const EdgeInsets.only(right: 10),
            child: Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      pillar.heavenlyStem,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.red[300] : Colors.red[700],
                      ),
                    ),
                    Text(
                      pillar.earthlyBranch,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.blue[300] : Colors.blue[700],
                      ),
                    ),
                    if (pillar.hiddenStems != null &&
                        pillar.hiddenStems!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        pillar.hiddenStems!,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPalaceCard(BuildContext context, Palace palace) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allStars = [
      ...palace.majorStars,
      ...palace.minorStars,
      ...palace.adjectiveStars,
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: palace.isBodyPalace
            ? BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 1.5,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 宫位名称 + 地支
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    palace.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  if (palace.earthlyBranch != null) ...[
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[700]
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        palace.earthlyBranch!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                  ],
                  if (palace.isBodyPalace) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '身宫',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // 星曜列表
            Expanded(
              child: allStars.isEmpty
                  ? Text(
                      '—',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    )
                  : Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: allStars.map((star) {
                        final isMajor = palace.majorStars.contains(star);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isMajor
                                ? Theme.of(context)
                                    .colorScheme
                                    .primaryContainer
                                    .withAlpha(80)
                                : (isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100]),
                            borderRadius: BorderRadius.circular(6),
                            border: isMajor
                                ? Border.all(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withAlpha(80),
                                  )
                                : null,
                          ),
                          child: Text(
                            star,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  isMajor ? FontWeight.w600 : FontWeight.normal,
                              color: isMajor
                                  ? Theme.of(context).colorScheme.primary
                                  : (isDark ? Colors.white60 : Colors.black54),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
