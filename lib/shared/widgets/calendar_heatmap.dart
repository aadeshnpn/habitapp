import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A 90-day calendar heatmap similar to GitHub's contribution graph.
/// Completed days show [accentColor]; incomplete days show a muted grey.
/// Today's cell is outlined when not completed.
class CalendarHeatmap extends StatelessWidget {
  final Map<DateTime, bool> completionMap;
  final Color accentColor;
  final int days;

  const CalendarHeatmap({
    super.key,
    required this.completionMap,
    required this.accentColor,
    this.days = 90,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = _dateOnly(DateTime.now());

    // Build ordered list of dates from oldest → newest
    final dateList = List.generate(days, (i) {
      return today.subtract(Duration(days: days - 1 - i));
    });

    // Group by week column (index 0 = oldest week)
    // Each column is 7 days (Mon–Sun or whatever alignment)
    final List<List<DateTime?>> columns = [];
    // Align so that today falls in the last row of the last column
    // We pad the front with nulls to align to week boundaries
    final startDow = dateList.first.weekday % 7; // 0=Sun,1=Mon,...,6=Sat
    final paddedFront = <DateTime?>[
      ...List<DateTime?>.filled(startDow, null),
      ...dateList.map<DateTime?>((d) => d),
    ];
    // Pad the end to fill the last column
    final remainder = paddedFront.length % 7;
    if (remainder != 0) {
      paddedFront.addAll(List<DateTime?>.filled(7 - remainder, null));
    }
    for (int i = 0; i < paddedFront.length; i += 7) {
      columns.add(paddedFront.sublist(i, i + 7));
    }

    // Collect month labels: one per column based on first non-null date
    final monthLabels = _buildMonthLabels(columns);

    final cellSize = 12.0;
    final cellGap = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month labels row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(columns.length, (ci) {
              final label = monthLabels[ci];
              return SizedBox(
                width: cellSize + cellGap,
                child: label != null
                    ? Text(
                        label,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 9,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.7),
                        ),
                      )
                    : const SizedBox.shrink(),
              );
            }),
          ),
          const SizedBox(height: 4),
          // Grid
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(columns.length, (ci) {
              return Column(
                children: List.generate(7, (ri) {
                  final date = columns[ci][ri];
                  if (date == null) {
                    return SizedBox(
                        width: cellSize + cellGap,
                        height: cellSize + cellGap);
                  }
                  return Padding(
                    padding: EdgeInsets.only(
                        right: cellGap, bottom: cellGap),
                    child: _HeatmapCell(
                      date: date,
                      isCompleted: completionMap[date] ?? false,
                      isToday: date == today,
                      accentColor: accentColor,
                      cellSize: cellSize,
                      isDark: isDark,
                    ),
                  );
                }),
              );
            }),
          ),
        ],
      ),
    );
  }

  Map<int, String?> _buildMonthLabels(List<List<DateTime?>> columns) {
    final fmt = DateFormat('MMM');
    final Map<int, String?> labels = {};
    String? lastLabel;
    for (int ci = 0; ci < columns.length; ci++) {
      final firstDate = columns[ci].firstWhere((d) => d != null,
          orElse: () => null);
      if (firstDate != null) {
        final m = fmt.format(firstDate);
        if (m != lastLabel) {
          labels[ci] = m;
          lastLabel = m;
        } else {
          labels[ci] = null;
        }
      } else {
        labels[ci] = null;
      }
    }
    return labels;
  }

  static DateTime _dateOnly(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);
}

class _HeatmapCell extends StatelessWidget {
  final DateTime date;
  final bool isCompleted;
  final bool isToday;
  final Color accentColor;
  final double cellSize;
  final bool isDark;

  const _HeatmapCell({
    required this.date,
    required this.isCompleted,
    required this.isToday,
    required this.accentColor,
    required this.cellSize,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    Color fill;
    Border? border;

    if (isCompleted) {
      fill = accentColor;
    } else if (isToday) {
      fill = Colors.transparent;
      border = Border.all(color: accentColor, width: 1.5);
    } else {
      fill = isDark
          ? Colors.white.withOpacity(0.08)
          : Colors.black.withOpacity(0.07);
    }

    final cell = GestureDetector(
      onTap: () => _showTooltip(context),
      child: Container(
        width: cellSize,
        height: cellSize,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(2),
          border: border,
        ),
      ),
    );

    return cell;
  }

  void _showTooltip(BuildContext context) {
    final fmt = DateFormat('MMM d, yyyy');
    final status = isCompleted ? 'Completed' : 'Not completed';
    final message = '${fmt.format(date)} — $status';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
