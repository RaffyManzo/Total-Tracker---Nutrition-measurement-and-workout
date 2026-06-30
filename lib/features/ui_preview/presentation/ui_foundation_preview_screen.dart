import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../shared/widgets/tt_app_card.dart';
import '../../../shared/widgets/tt_filter_chip.dart';
import '../../../shared/widgets/tt_primary_button.dart';
import '../../../shared/widgets/tt_search_field.dart';
import '../../../shared/widgets/tt_section_header.dart';

class UiFoundationPreviewScreen extends StatefulWidget {
  const UiFoundationPreviewScreen({super.key});

  @override
  State<UiFoundationPreviewScreen> createState() =>
      _UiFoundationPreviewScreenState();
}

class _UiFoundationPreviewScreenState extends State<UiFoundationPreviewScreen> {
  int selectedFilter = 0;

  static const List<String> filters = <String>[
    'Tutti',
    'Manuali',
    'Barcode',
  ];

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;

    return Scaffold(
      appBar: AppBar(
        title: const Text('UI foundation'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.screenVertical,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        children: <Widget>[
          const TtSectionHeader(
            title: 'Total Tracker',
            subtitle: 'Anteprima dei componenti condivisi della UI definitiva.',
          ),
          const SizedBox(height: AppSpacing.xl),
          const TtSearchField(
            hintText: 'Cerca alimento o esercizio...',
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List<Widget>.generate(
                filters.length,
                (int index) => Padding(
                  padding: EdgeInsets.only(
                    right: index == filters.length - 1 ? 0 : AppSpacing.xs,
                  ),
                  child: TtFilterChip(
                    label: filters[index],
                    selected: selectedFilter == index,
                    onSelected: (_) {
                      setState(() {
                        selectedFilter = index;
                      });
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          TtAppCard(
            semanticLabel: 'Anteprima card ingrediente',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Card ingrediente selezionata'),
                ),
              );
            },
            child: Row(
              children: <Widget>[
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: brightness == Brightness.light
                        ? AppColors.lightPrimarySoft
                        : AppColors.darkPrimarySoft,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Y',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Yogurt Greco',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Mila Â· confezione 150 g',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '62 kcal / 100 g',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'P 10,0 Â· C 3,6 Â· G 0,2',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sectionGap),
          const TtPrimaryButton(
            label: 'Azione principale',
            icon: Icons.add_rounded,
            onPressed: null,
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Azione secondaria'),
            ),
          ),
        ],
      ),
    );
  }
}
