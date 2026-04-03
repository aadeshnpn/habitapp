import 'package:flutter/material.dart';

/// Displays freeze token slots (0–3) using ice crystal icons.
/// Filled slots represent available tokens; greyed slots are spent tokens.
/// A tooltip explains the feature on tap.
class FreezeTokenDisplay extends StatelessWidget {
  final int tokenCount;
  final int maxTokens;

  const FreezeTokenDisplay({
    super.key,
    required this.tokenCount,
    this.maxTokens = 3,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = tokenCount.clamp(0, maxTokens);

    return Tooltip(
      message: 'Streak freeze tokens — used when you miss a day',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                  'Streak freeze tokens — protect your streak when you miss a day'),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(maxTokens, (i) {
            final isAvailable = i < available;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: _FreezeIcon(
                isAvailable: isAvailable,
                color: isAvailable
                    ? const Color(0xFF40C4FF)
                    : theme.colorScheme.onSurface.withOpacity(0.15),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _FreezeIcon extends StatelessWidget {
  final bool isAvailable;
  final Color color;

  const _FreezeIcon({required this.isAvailable, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isAvailable ? color.withOpacity(0.15) : Colors.transparent,
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          '❄️',
          style: TextStyle(
            fontSize: 14,
            color: isAvailable ? null : Colors.grey,
          ),
        ),
      ),
    );
  }
}
