import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../features/habits/domain/habit_providers.dart';
import '../../../features/habits/domain/habit_repository.dart';
import '../../../features/habits/data/habit_model.dart';
import '../../../shared/widgets/celebration_overlay.dart';
import '../../../shared/theme/app_colors.dart';
import '../domain/onboarding_provider.dart';

// ---------------------------------------------------------------------------
// Emoji / color constants (mirrors AddHabitScreen)
// ---------------------------------------------------------------------------
const _kEmojis = [
  '🏃', '🏋️', '🧘', '💧', '📚', '✍️', '🎸', '🍎',
  '😴', '🧹', '💊', '🚴', '🏊', '🧠', '🎯', '💪',
  '🌅', '🫁', '🍵', '🚶', '📝', '🎨', '🌿', '💻',
  '🎵', '🤸', '🥗', '🛌', '🎮', '🐕',
];

const _kColorOptions = [
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.blue,
  Colors.pink,
  Colors.red,
];

// ---------------------------------------------------------------------------
// OnboardingScreen
// ---------------------------------------------------------------------------
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Habit creation state (pages 2 onwards)
  String _selectedEmoji = _kEmojis.first;
  Color _selectedColor = _kColorOptions.first;
  final _nameController = TextEditingController();

  // Reminder state (page 3)
  TimeOfDay? _reminderTime;

  // First check-in state (page 5)
  bool _isCompleting = false;
  bool _showCelebration = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
    setState(() => _currentPage = page);
  }

  Future<void> _completeFirstCheckIn() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    try {
      // 1. Create the habit
      final habitRepo = ref.read(habitRepositoryProvider);
      final habit = await habitRepo.createHabit(
        CreateHabitParams(
          name: _nameController.text.trim(),
          icon: _selectedEmoji,
          color: _selectedColor.value,
          frequencyType: FrequencyType.daily,
          checkInType: CheckInType.tap,
          reminderTime: _formatReminderTime(),
        ),
      );

      // 2. Record check-in
      final checkInRepo = ref.read(checkInRepositoryProvider);
      await checkInRepo.recordCheckIn(habit.id);

      // Invalidate so home screen refreshes
      ref.invalidate(activeHabitsProvider);

      // 3. Show celebration
      if (mounted) setState(() => _showCelebration = true);
    } catch (e) {
      if (mounted) {
        setState(() => _isCompleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Something went wrong: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _onCelebrationDismissed() async {
    // 4. Request notification permission after the success moment
    await NotificationService.instance.requestPermission();

    // 5. Mark onboarding complete and navigate to /home
    await markOnboardingComplete();
    if (mounted) context.go('/home');
  }

  String? _formatReminderTime() {
    if (_reminderTime == null) return null;
    final h = _reminderTime!.hour.toString().padLeft(2, '0');
    final m = _reminderTime!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _formatReminderDisplay() {
    if (_reminderTime == null) return 'Remind me at 7:00 AM';
    final period = _reminderTime!.period == DayPeriod.am ? 'AM' : 'PM';
    final hour = _reminderTime!.hourOfPeriod == 0
        ? 12
        : _reminderTime!.hourOfPeriod;
    final minute = _reminderTime!.minute.toString().padLeft(2, '0');
    return 'Remind me at $hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _WelcomePage(onGetStarted: () => _goToPage(1)),
              _PickHabitPage(
                nameController: _nameController,
                selectedEmoji: _selectedEmoji,
                selectedColor: _selectedColor,
                onEmojiSelected: (e) => setState(() => _selectedEmoji = e),
                onColorSelected: (c) => setState(() => _selectedColor = c),
                onContinue: () => _goToPage(2),
              ),
              _ReminderPage(
                reminderTime: _reminderTime,
                reminderDisplay: _formatReminderDisplay(),
                onSetReminder: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime:
                        _reminderTime ?? const TimeOfDay(hour: 7, minute: 0),
                    helpText: 'Set reminder time',
                  );
                  if (picked != null) {
                    setState(() => _reminderTime = picked);
                  }
                },
                onSkip: () => _goToPage(3),
                onContinue: () => _goToPage(3),
              ),
              _HowStreaksPage(onReady: () => _goToPage(4)),
              _FirstCheckInPage(
                habitName: _nameController.text.trim().isEmpty
                    ? 'your habit'
                    : _nameController.text.trim(),
                habitEmoji: _selectedEmoji,
                accentColor: _selectedColor,
                isCompleting: _isCompleting,
                onComplete: _completeFirstCheckIn,
              ),
            ],
          ),
          if (_showCelebration)
            CelebrationOverlay(
              message: "Day 1! Your streak starts now 🔥",
              streakCount: 1,
              tier: CelebrationTier.major,
              onDismiss: _onCelebrationDismissed,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 1 — Welcome
// ---------------------------------------------------------------------------
class _WelcomePage extends StatefulWidget {
  final VoidCallback onGetStarted;

  const _WelcomePage({required this.onGetStarted});

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scaleAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.elasticOut,
      ),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Animated flame logo
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: AppColors.orangeSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orangeAccent.withOpacity(0.4),
                      blurRadius: 30,
                      spreadRadius: 6,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    '🔥',
                    style: TextStyle(fontSize: 64),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  Text(
                    'Build habits that stick',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Track your streaks.\nOne day at a time.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const Spacer(flex: 3),
            FadeTransition(
              opacity: _fadeAnimation,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: widget.onGetStarted,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.orangePrimary,
                    foregroundColor: AppColors.orangeOnPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Get Started'),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2 — Pick your first habit
// ---------------------------------------------------------------------------
class _PickHabitPage extends StatefulWidget {
  final TextEditingController nameController;
  final String selectedEmoji;
  final Color selectedColor;
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<Color> onColorSelected;
  final VoidCallback onContinue;

  const _PickHabitPage({
    required this.nameController,
    required this.selectedEmoji,
    required this.selectedColor,
    required this.onEmojiSelected,
    required this.onColorSelected,
    required this.onContinue,
  });

  @override
  State<_PickHabitPage> createState() => _PickHabitPageState();
}

class _PickHabitPageState extends State<_PickHabitPage> {
  bool _emojiSelected = false;
  bool _nameNonEmpty = false;

  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onNameChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onNameChanged);
    super.dispose();
  }

  void _onNameChanged() {
    final nonEmpty = widget.nameController.text.trim().isNotEmpty;
    if (nonEmpty != _nameNonEmpty) {
      setState(() => _nameNonEmpty = nonEmpty);
    }
  }

  bool get _canContinue => _emojiSelected && _nameNonEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 24).copyWith(top: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What habit do you\nwant to build?',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start with one — you can add more later.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Emoji grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: _kEmojis.length,
              itemBuilder: (ctx, i) {
                final emoji = _kEmojis[i];
                final isSelected = widget.selectedEmoji == emoji && _emojiSelected;
                return GestureDetector(
                  onTap: () {
                    widget.onEmojiSelected(emoji);
                    setState(() => _emojiSelected = true);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.selectedColor.withOpacity(0.18)
                          : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? widget.selectedColor
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          // Color row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: _kColorOptions.map((color) {
                final isSelected = widget.selectedColor == color;
                return GestureDetector(
                  onTap: () => widget.onColorSelected(color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    width: isSelected ? 34 : 28,
                    height: isSelected ? 34 : 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 1,
                              )
                            ]
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Habit name field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextFormField(
              controller: widget.nameController,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Name your habit',
                hintText: 'e.g. Morning run, Read 20 minutes',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Text(
                  _emojiSelected ? widget.selectedEmoji : '✏️',
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 48, minHeight: 48),
                counterText: '',
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _canContinue ? widget.onContinue : null,
                style: FilledButton.styleFrom(
                  backgroundColor: widget.selectedColor,
                  disabledBackgroundColor:
                      theme.colorScheme.onSurface.withOpacity(0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3 — Set a reminder
// ---------------------------------------------------------------------------
class _ReminderPage extends StatelessWidget {
  final TimeOfDay? reminderTime;
  final String reminderDisplay;
  final VoidCallback onSetReminder;
  final VoidCallback onSkip;
  final VoidCallback onContinue;

  const _ReminderPage({
    required this.reminderTime,
    required this.reminderDisplay,
    required this.onSetReminder,
    required this.onSkip,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              '🕗',
              style: TextStyle(
                fontSize: 72,
                shadows: [
                  Shadow(
                    blurRadius: 20,
                    color: AppColors.orangeAccent.withOpacity(0.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'When do you want\nto be reminded?',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                reminderDisplay,
                key: ValueKey(reminderDisplay),
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: reminderTime != null
                      ? AppColors.orangePrimary
                      : theme.colorScheme.onSurface.withOpacity(0.55),
                  fontWeight: reminderTime != null
                      ? FontWeight.w600
                      : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: onSetReminder,
              icon: const Icon(Icons.alarm_outlined),
              label: const Text('Set reminder time'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orangePrimary,
                side: const BorderSide(color: AppColors.orangePrimary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onContinue,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: onSkip,
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              child: const Text('Skip for now'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 4 — How streaks work
// ---------------------------------------------------------------------------
class _HowStreaksPage extends StatelessWidget {
  final VoidCallback onReady;

  const _HowStreaksPage({required this.onReady});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          children: [
            const Spacer(flex: 2),
            Text(
              'Stay consistent,\nbuild streaks',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _StreakPoint(
              emoji: '🔥',
              text: 'Complete your habit every day',
              color: AppColors.orangePrimary,
            ),
            const SizedBox(height: 20),
            _StreakPoint(
              emoji: '🛡️',
              text:
                  'Freeze tokens protect your streak\nif you miss a day',
              color: AppColors.purplePrimary,
            ),
            const SizedBox(height: 20),
            _StreakPoint(
              emoji: '🏆',
              text: 'Hit milestones and celebrate\nyour progress',
              color: AppColors.greenPrimary,
            ),
            const Spacer(flex: 3),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: onReady,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.orangePrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: const Text("I'm ready!"),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StreakPoint extends StatelessWidget {
  final String emoji;
  final String text;
  final Color color;

  const _StreakPoint({
    required this.emoji,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(emoji, style: const TextStyle(fontSize: 30)),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Page 5 — First check-in
// ---------------------------------------------------------------------------
class _FirstCheckInPage extends StatefulWidget {
  final String habitName;
  final String habitEmoji;
  final Color accentColor;
  final bool isCompleting;
  final VoidCallback onComplete;

  const _FirstCheckInPage({
    required this.habitName,
    required this.habitEmoji,
    required this.accentColor,
    required this.isCompleting,
    required this.onComplete,
  });

  @override
  State<_FirstCheckInPage> createState() => _FirstCheckInPageState();
}

class _FirstCheckInPageState extends State<_FirstCheckInPage>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _iconEnterController;
  late Animation<double> _iconEnterScale;
  late Animation<double> _iconEnterFade;

  @override
  void initState() {
    super.initState();

    // Icon entrance animation
    _iconEnterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _iconEnterScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconEnterController,
        curve: Curves.elasticOut,
      ),
    );
    _iconEnterFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconEnterController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    _iconEnterController.forward();

    // Pulsing button
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Bounce for icon
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _pulseController.dispose();
    _iconEnterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.accentColor;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Animated habit icon
            FadeTransition(
              opacity: _iconEnterFade,
              child: ScaleTransition(
                scale: _iconEnterScale,
                child: AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (ctx, child) => Transform.translate(
                    offset: Offset(0, _bounceAnimation.value),
                    child: child,
                  ),
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        widget.habitEmoji,
                        style: const TextStyle(fontSize: 54),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 36),
            Text(
              'Start your streak\nright now',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Text(
              'Tap the button to complete\n${widget.habitName} today',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const Spacer(flex: 2),
            // Pulsing completion button
            ScaleTransition(
              scale: _pulseAnimation,
              child: GestureDetector(
                onTap: widget.isCompleting ? null : widget.onComplete,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: widget.isCompleting
                        ? color.withOpacity(0.5)
                        : color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.45),
                        blurRadius: 36,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: widget.isCompleting
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Text(
                                '✓',
                                style: TextStyle(
                                  fontSize: 56,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Done!',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            const Spacer(flex: 3),
          ],
        ),
      ),
    );
  }
}
