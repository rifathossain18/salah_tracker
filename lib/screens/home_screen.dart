import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/date_formatters.dart';
import '../domain/prayer_day.dart';
import '../domain/prayer_schedule.dart';
import '../domain/tracker_backup.dart';
import '../domain/tracker_dates.dart';
import '../services/prayer_repository.dart';
import '../theme/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final PrayerRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  int _selectedTab = 0;
  Map<String, PrayerDay> _entries = <String, PrayerDay>{};
  PrayerSchedule _schedule = PrayerSchedule.empty();
  late DateTime _selectedDate;
  String? _storageWarning;
  Timer? _clockTimer;

  String get _selectedKey => TrackerDates.dateKey(_selectedDate);
  bool get _isToday => _selectedKey == TrackerDates.dateKey(DateTime.now());
  PrayerDay get _selectedEntry => _entries[_selectedKey] ?? PrayerDay.empty();
  ({String id, DateTime time})? get _nextPrayer {
    final now = DateTime.now();
    String? nextId;
    DateTime? nextTime;
    for (final id in prayerIds) {
      final value = _schedule.timeFor(id);
      if (value == null) continue;
      final parts = value.split(':');
      var candidate = DateTime(
        now.year,
        now.month,
        now.day,
        int.parse(parts[0]),
        int.parse(parts[1]),
      );
      if (!candidate.isAfter(now)) {
        candidate = DateTime(
          now.year,
          now.month,
          now.day + 1,
          int.parse(parts[0]),
          int.parse(parts[1]),
        );
      }
      if (nextTime == null || candidate.isBefore(nextTime)) {
        nextId = id;
        nextTime = candidate;
      }
    }
    return nextId == null || nextTime == null
        ? null
        : (id: nextId, time: nextTime);
  }

  String? get _todayBadge {
    final todayKey = TrackerDates.dateKey(DateTime.now());
    final today = _entries[todayKey] ?? PrayerDay.empty();
    final count = today.completedCount;
    if (count == 0) return null;
    if (count == prayerIds.length) return '✓';
    return '$count/${prayerIds.length}';
  }

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _loadEntries();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadEntries() async {
    var failed = false;
    try {
      final loaded = await widget.repository.load();
      if (!mounted) return;
      setState(() => _entries = Map<String, PrayerDay>.of(loaded));
    } catch (_) {
      failed = true;
    }
    try {
      final schedule = await widget.repository.loadSchedule();
      if (!mounted) return;
      setState(() => _schedule = schedule);
    } catch (_) {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _storageWarning = failed
          ? 'Some offline data could not be loaded. Check device storage.'
          : null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<bool> _persist() async {
    try {
      await widget.repository.save(Map<String, PrayerDay>.of(_entries));
      if (mounted && _storageWarning != null) {
        setState(() => _storageWarning = null);
      }
      return true;
    } catch (_) {
      if (!mounted) return false;
      setState(() {
        _storageWarning = 'Could not save data. Check device storage.';
      });
      _showMessage('Prayer record could not be saved.');
      return false;
    }
  }

  Future<void> _togglePrayer(String prayerId) async {
    HapticFeedback.lightImpact();
    final wasComplete = _selectedEntry.isComplete;
    final changed = _selectedEntry.toggle(prayerId);
    setState(() => _entries[_selectedKey] = changed);
    await _persist();
    if (!wasComplete && changed.isComplete) {
      HapticFeedback.mediumImpact();
      _showMessage('All five prayers complete! 🤲');
    }
  }

  Future<void> _editPrayerTime(String prayerId) async {
    final savedTime = _schedule.timeFor(prayerId);
    final parts = savedTime?.split(':');
    final initialTime = TimeOfDay(
      hour: parts == null ? 5 : int.parse(parts[0]),
      minute: parts == null ? 0 : int.parse(parts[1]),
    );

    final selected = await _showPremium12hTimePicker(
      context: context,
      initialTime: initialTime,
      title: '${prayerNames[prayerId]} time',
    );

    if (selected == null || !mounted) return;
    final time =
        '${selected.hour.toString().padLeft(2, '0')}:'
        '${selected.minute.toString().padLeft(2, '0')}';
    final previous = _schedule;
    final updated = _schedule.withTime(prayerId, time);
    setState(() => _schedule = updated);
    try {
      await widget.repository.saveSchedule(updated);
      if (!mounted) return;
      HapticFeedback.selectionClick();
      setState(() => _storageWarning = null);
      _showMessage('${prayerNames[prayerId]} time saved.');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _schedule = previous;
        _storageWarning = 'Prayer schedule could not be saved.';
      });
      _showMessage('Prayer schedule could not be saved.');
    }
  }

  Future<TimeOfDay?> _showPremium12hTimePicker({
    required BuildContext context,
    required TimeOfDay initialTime,
    required String title,
  }) async {
    final initialDateTime = DateTime(
      2024,
      1,
      1,
      initialTime.hour,
      initialTime.minute,
    );
    var selected = initialDateTime;

    return showModalBottomSheet<TimeOfDay>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 6),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 14, 6),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: () => Navigator.pop(
                          context,
                          TimeOfDay(
                            hour: selected.hour,
                            minute: selected.minute,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(72, 40),
                        ),
                        child: const Text('Set'),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppColors.border),
                SizedBox(
                  height: 220,
                  child: CupertinoTheme(
                    data: const CupertinoThemeData(
                      primaryColor: AppColors.green,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: AppColors.ink,
                          fontSize: 21,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    child: CupertinoDatePicker(
                      mode: CupertinoDatePickerMode.time,
                      use24hFormat: false,
                      initialDateTime: initialDateTime,
                      onDateTimeChanged: (dt) {
                        selected = dt;
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _markAll() async {
    HapticFeedback.mediumImpact();
    setState(() => _entries[_selectedKey] = _selectedEntry.markAll(true));
    if (await _persist()) _showMessage('All five prayers marked for this day.');
  }

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    HapticFeedback.selectionClick();
    setState(() => _selectedTab = index);
  }

  void _shiftDay(int amount) {
    HapticFeedback.selectionClick();
    setState(
      () => _selectedDate = TrackerDates.shiftDay(_selectedDate, amount),
    );
  }

  void _shiftMonth(int amount) {
    try {
      HapticFeedback.selectionClick();
      setState(
        () => _selectedDate = TrackerDates.shiftMonth(_selectedDate, amount),
      );
    } on RangeError {
      _showMessage('That date is outside the supported range.');
    }
  }

  void _jumpToToday() {
    HapticFeedback.selectionClick();
    final now = DateTime.now();
    setState(() => _selectedDate = DateTime(now.year, now.month, now.day));
  }

  Future<void> _exportBackup() async {
    try {
      final backup = TrackerBackup.encode(_entries);
      final result = await FilePicker.saveFile(
        fileName:
            'salah-tracker-backup-${TrackerDates.dateKey(DateTime.now())}.json',
        bytes: Uint8List.fromList(utf8.encode(backup)),
        mimeType: 'application/json',
        dialogTitle: 'Save prayer tracker backup',
      );
      if (!mounted || result == null) return;
      _showMessage('JSON backup saved.');
    } catch (_) {
      if (mounted) _showMessage('Could not create backup. Please try again.');
    }
  }

  Future<void> _importBackup() async {
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Choose a prayer tracker JSON backup',
        type: FileType.custom,
        allowedExtensions: const <String>['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 5 * 1024 * 1024) {
        throw const FormatException('Backup file is too large.');
      }
      final imported = TrackerBackup.decode(utf8.decode(bytes));
      if (!mounted) return;
      final shouldImport = await _confirmImport(imported.length);
      if (shouldImport != true || !mounted) return;

      setState(() {
        _entries = Map<String, PrayerDay>.of(
          TrackerBackup.merge(_entries, imported),
        );
      });
      if (await _persist()) {
        _showMessage('Imported ${imported.length} days from backup.');
      }
    } on FormatException {
      if (mounted) _showMessage('The backup file is not valid JSON.');
    } catch (_) {
      if (mounted) {
        _showMessage('Could not read backup. Check the file and try again.');
      }
    }
  }

  Future<bool?> _confirmImport(int dayCount) => showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Restore backup?'),
      content: Text(
        'This backup contains $dayCount days. Existing records for matching dates '
        'will be replaced; records for other dates will remain unchanged.',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restore'),
        ),
      ],
    ),
  );

  void _showMessage(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _progressMessage(int count) {
    if (count == prayerIds.length) {
      return _isToday
          ? 'All five prayers are complete for today.'
          : 'All five prayers are complete for this day.';
    }
    if (count == 0) return 'Mark each prayer as you complete it.';
    return '$count of 5 prayers completed.';
  }

  String _formatScheduleTime(String time) => PrayerSchedule.formatTime12h(time);

  String _formatCountdown(Duration d) {
    if (d.inSeconds <= 0) return 'now';
    if (d.inDays > 0) return 'in ${d.inDays}d ${d.inHours % 24}h';
    if (d.inHours > 0) return 'in ${d.inHours}h ${d.inMinutes % 60}m';
    if (d.inMinutes > 0) return 'in ${d.inMinutes}m ${d.inSeconds % 60}s';
    return 'in ${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.canvas,
        body: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.8,
              color: AppColors.green,
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final primary = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 38 : 20,
                vertical: 14,
              ),
              child: _buildTopBar(showMark: !wide),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(child: _buildCurrentPage(wide ? 760 : 680)),
          ],
        );

        return Scaffold(
          backgroundColor: AppColors.canvas,
          body: SafeArea(
            bottom: false,
            child: wide
                ? Row(
                    children: <Widget>[
                      SizedBox(
                        width: 92,
                        child: ColoredBox(
                          color: AppColors.surface,
                          child: Column(
                            children: <Widget>[
                              const SizedBox(height: 18),
                              _buildBrandMark(),
                              const SizedBox(height: 20),
                              Expanded(child: _buildNavigationRail()),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 1,
                        child: ColoredBox(color: AppColors.border),
                      ),
                      Expanded(child: primary),
                    ],
                  )
                : primary,
          ),
          bottomNavigationBar: wide ? null : _buildBottomNavigation(),
        );
      },
    );
  }

  Widget _buildTopBar({required bool showMark}) => Row(
    children: <Widget>[
      if (showMark) ...<Widget>[_buildBrandMark(), const SizedBox(width: 10)],
      const Text(
        'Salah Tracker',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -.2,
        ),
      ),
      const Spacer(),
      const Icon(Icons.wifi_off_rounded, color: AppColors.gold, size: 15),
      const SizedBox(width: 7),
      const Text(
        'OFFLINE',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: .3,
        ),
      ),
    ],
  );

  Widget _buildBrandMark() => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: <Color>[AppColors.green, AppColors.greenDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(11),
      boxShadow: <BoxShadow>[
        BoxShadow(
          color: AppColors.greenDeep.withValues(alpha: .28),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: Image.asset(
        'assets/icon/logo.png',
        key: const Key('brand-mark-logo'),
        width: 34,
        height: 34,
        fit: BoxFit.cover,
        semanticLabel: 'Salah Tracker logo',
      ),
    ),
  );

  Widget _buildNavigationRail() => NavigationRail(
    key: const Key('main-navigation-rail'),
    selectedIndex: _selectedTab,
    onDestinationSelected: _selectTab,
    labelType: NavigationRailLabelType.all,
    minWidth: 88,
    backgroundColor: AppColors.surface,
    indicatorColor: AppColors.greenSoft,
    indicatorShape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    ),
    selectedIconTheme: const IconThemeData(color: AppColors.greenDeep),
    unselectedIconTheme: const IconThemeData(color: AppColors.muted),
    selectedLabelTextStyle: const TextStyle(
      color: AppColors.greenDeep,
      fontSize: 11,
      fontWeight: FontWeight.w700,
    ),
    unselectedLabelTextStyle: const TextStyle(
      color: AppColors.muted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    destinations: const <NavigationRailDestination>[
      NavigationRailDestination(
        icon: Icon(Icons.checklist_outlined),
        selectedIcon: Icon(Icons.checklist_rounded),
        label: Text('Today', key: Key('nav-today')),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.calendar_month_outlined),
        selectedIcon: Icon(Icons.calendar_month_rounded),
        label: Text('History', key: Key('nav-history')),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.tune_rounded),
        selectedIcon: Icon(Icons.tune_rounded),
        label: Text('Data', key: Key('nav-data')),
      ),
    ],
  );

  Widget _buildBottomNavigation() {
    return Container(
      key: const Key('main-navigation'),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border.withValues(alpha: .7)),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .07),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppColors.ink.withValues(alpha: .02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: _PremiumNavItem(
                        key: const Key('nav-today'),
                        icon: Icons.checklist_outlined,
                        selectedIcon: Icons.checklist_rounded,
                        label: 'Today',
                        selected: _selectedTab == 0,
                        onTap: () => _selectTab(0),
                        badge: _todayBadge,
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        key: const Key('nav-history'),
                        icon: Icons.calendar_month_outlined,
                        selectedIcon: Icons.calendar_month_rounded,
                        label: 'History',
                        selected: _selectedTab == 1,
                        onTap: () => _selectTab(1),
                      ),
                    ),
                    Expanded(
                      child: _PremiumNavItem(
                        key: const Key('nav-data'),
                        icon: Icons.tune_rounded,
                        selectedIcon: Icons.tune_rounded,
                        label: 'Data',
                        selected: _selectedTab == 2,
                        onTap: () => _selectTab(2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage(double maxWidth) {
    final Widget content = switch (_selectedTab) {
      0 => _buildTodayPage(),
      1 => _buildHistoryPage(),
      _ => _buildDataPage(),
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              child: KeyedSubtree(
                key: ValueKey<int>(_selectedTab),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TODAY PAGE
  // ---------------------------------------------------------------------------

  Widget _buildTodayPage() {
    final day = _selectedEntry;
    final count = day.completedCount;
    final summary = TrackerDates.summarizeMonth(
      _entries,
      _selectedDate.year,
      _selectedDate.month,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .03),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildDateSelector(),
        ),
        const SizedBox(height: 18),
        _buildTodayHero(count),
        const SizedBox(height: 22),
        _buildNextPrayerCard(),
        const SizedBox(height: 22),
        Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'DAILY PRAYER TRACKER',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            Text(
              '$count / 5 completed',
              style: const TextStyle(
                color: AppColors.green,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: <Widget>[
              for (
                var index = 0;
                index < prayerIds.length;
                index++
              ) ...<Widget>[
                _PrayerRow(
                  prayerId: prayerIds[index],
                  name: prayerNames[prayerIds[index]]!,
                  completed: day.isCompleted(prayerIds[index]),
                  time: _schedule.timeFor(prayerIds[index]),
                  onEditTime: () => _editPrayerTime(prayerIds[index]),
                  onPressed: () => _togglePrayer(prayerIds[index]),
                ),
                if (index != prayerIds.length - 1)
                  const Divider(
                    height: 1,
                    indent: 72,
                    endIndent: 20,
                    color: AppColors.border,
                  ),
              ],
            ],
          ),
        ),
        if (!day.isComplete) ...<Widget>[
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFFE9F4EE), Color(0xFFD4E8DC)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.green.withValues(alpha: .15),
                ),
              ),
              child: InkWell(
                key: const Key('mark-all'),
                borderRadius: BorderRadius.circular(14),
                onTap: _markAll,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Icon(
                        Icons.done_all_rounded,
                        color: AppColors.greenDeep,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Mark all complete',
                        style: TextStyle(
                          color: AppColors.greenDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: AppColors.border),
            borderRadius: BorderRadius.circular(18),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: const Key('open-history'),
            onTap: () => _selectTab(1),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[Color(0xFFE9F4EE), Color(0xFFD4E8DC)],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.greenDeep,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          DateFormatters.month(_selectedDate),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${summary.totalCompleted} prayers · '
                          '${summary.fullDays} complete days',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'History',
                    style: TextStyle(
                      color: AppColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.muted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTodayHero(int count) {
    final allDone = count == prayerIds.length;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF2E7D5B), Color(0xFF154533)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF154533).withValues(alpha: .28),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: <Widget>[
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      Colors.white.withValues(alpha: .08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            if (allDone)
              Positioned(
                top: 18,
                right: 18,
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: AppColors.gold.withValues(alpha: .9),
                  size: 20,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              _isToday ? 'TODAY' : 'SELECTED DAY',
                              style: const TextStyle(
                                color: Color(0xFFC8D8CB),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              _isToday ? 'Prayer tracker' : 'Prayer record',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _progressMessage(count),
                              style: const TextStyle(
                                color: Color(0xFFD6E1D8),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      _ProgressRing(count: count, total: prayerIds.length),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: List<Widget>.generate(prayerIds.length, (index) {
                      final filled = index < count;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 320),
                          curve: Curves.easeOutCubic,
                          height: 5,
                          margin: EdgeInsets.only(
                            right: index == prayerIds.length - 1 ? 0 : 6,
                          ),
                          decoration: BoxDecoration(
                            color: filled
                                ? const Color(0xFFE6D5A9)
                                : const Color(0xFF527764),
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List<Widget>.generate(prayerIds.length, (index) {
                      final id = prayerIds[index];
                      final done =
                          _entries[_selectedKey]?.isCompleted(id) ?? false;
                      return _HeroDot(
                        initial: prayerNames[id]!.substring(0, 1),
                        done: done,
                      );
                    }),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    final next = _nextPrayer;
    if (next == null) {
      return Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: const Key('schedule-empty'),
          onTap: () => _editPrayerTime(prayerIds.first),
          child: const Padding(
            padding: EdgeInsets.all(18),
            child: Row(
              children: <Widget>[
                _IconBubble(
                  icon: Icons.access_time_rounded,
                  color: AppColors.green,
                ),
                SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'PRAYER TIMES',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Add your local prayer times',
                        style: TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppColors.green,
                  size: 19,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isTomorrow =
        TrackerDates.dateKey(next.time) != TrackerDates.dateKey(DateTime.now());
    final remaining = next.time.difference(DateTime.now());
    final countdown = _formatCountdown(remaining);

    return Container(
      key: const Key('next-prayer-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF1C644B), Color(0xFF0F3D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0F3D2E).withValues(alpha: .22),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: .06)),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColors.gold,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'UP NEXT  ·  ${isTomorrow ? 'TOMORROW' : 'TODAY'}',
                  style: const TextStyle(
                    color: Color(0xFFC5D8CC),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prayerNames[next.id]!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  countdown,
                  style: const TextStyle(
                    color: Color(0xFFE6D5A9),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatScheduleTime(
              '${next.time.hour.toString().padLeft(2, '0')}:'
              '${next.time.minute.toString().padLeft(2, '0')}',
            ),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: .3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() => Row(
    children: <Widget>[
      _PillIconButton(
        key: const Key('previous-day'),
        icon: Icons.chevron_left_rounded,
        onTap: () => _shiftDay(-1),
        tooltip: 'Previous day',
      ),
      Expanded(
        child: Column(
          children: <Widget>[
            Text(
              DateFormatters.dateMain(_selectedDate),
              key: const Key('selected-date'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -.2,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              DateFormatters.dateSub(_selectedDate),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.muted,
                fontSize: 11,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      ),
      if (!_isToday)
        TextButton(
          key: const Key('jump-today'),
          onPressed: _jumpToToday,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.greenDeep,
            minimumSize: const Size(40, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text(
            'Today',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      _PillIconButton(
        key: const Key('next-day'),
        icon: Icons.chevron_right_rounded,
        onTap: () => _shiftDay(1),
        tooltip: 'Next day',
      ),
    ],
  );

  // ---------------------------------------------------------------------------
  // HISTORY PAGE — PREMIUM
  // ---------------------------------------------------------------------------

  int _currentStreak() {
    var streak = 0;
    var day = DateTime.now();
    final todayKey = TrackerDates.dateKey(day);
    final todayEntry = _entries[todayKey];
    if (todayEntry == null || !todayEntry.isComplete) {
      day = day.subtract(const Duration(days: 1));
    }
    while (true) {
      final key = TrackerDates.dateKey(day);
      final entry = _entries[key];
      if (entry == null || !entry.isComplete) break;
      streak++;
      day = day.subtract(const Duration(days: 1));
      if (streak > 3650) break;
    }
    return streak;
  }

  Widget _buildHistoryPage() {
    final year = _selectedDate.year;
    final month = _selectedDate.month;
    final offset = DateTime(year, month, 1).weekday % 7;
    final days = TrackerDates.daysInMonth(year, month);
    final summary = TrackerDates.summarizeMonth(_entries, year, month);
    final streak = _currentStreak();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'YOUR PRAYER JOURNAL',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Prayer history',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.6,
                    ),
                  ),
                ],
              ),
            ),
            if (streak > 0) _StreakBadge(streak: streak),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: <Color>[Colors.white, Color(0xFFF8FAF9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .03),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          child: Row(
            children: <Widget>[
              _PillIconButton(
                key: const Key('previous-month'),
                icon: Icons.chevron_left_rounded,
                onTap: () => _shiftMonth(-1),
                tooltip: 'Previous month',
              ),
              Expanded(
                child: Column(
                  children: <Widget>[
                    Text(
                      DateFormatters.month(_selectedDate),
                      key: const Key('calendar-month'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$days days · ${summary.fullDays}/${summary.trackedDays == 0 ? days : summary.trackedDays} tracked',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: .1,
                      ),
                    ),
                  ],
                ),
              ),
              _PillIconButton(
                key: const Key('next-month'),
                icon: Icons.chevron_right_rounded,
                onTap: () => _shiftMonth(1),
                tooltip: 'Next month',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.ink.withValues(alpha: .03),
                blurRadius: 14,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: GridView.builder(
            key: const Key('month-calendar'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 7 + offset + days,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisExtent: 54,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemBuilder: (context, index) {
              if (index < 7) {
                const weekdays = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];
                return Center(
                  child: Text(
                    weekdays[index],
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .4,
                    ),
                  ),
                );
              }

              final calendarIndex = index - 7;
              if (calendarIndex < offset) return const SizedBox.shrink();
              final dayNumber = calendarIndex - offset + 1;
              if (dayNumber > days) return const SizedBox.shrink();

              return _buildPremiumCalendarDay(year, month, dayNumber);
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: <Widget>[
              Expanded(
                child: _LegendChip(
                  gradient: <Color>[Color(0xFF2E7D5B), Color(0xFF154533)],
                  label: 'Complete',
                ),
              ),
              Expanded(
                child: _LegendChip(
                  color: AppColors.greenSoft,
                  label: 'Partial',
                ),
              ),
              Expanded(
                child: _LegendChip(
                  color: Colors.transparent,
                  borderColor: AppColors.border,
                  label: 'No record',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildSelectedDayPreview(),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.check_circle_rounded,
                value: summary.totalCompleted,
                label: 'Prayers',
                color: AppColors.green,
                gradient: const <Color>[Color(0xFFE9F4EE), Color(0xFFD4E8DC)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.event_available_rounded,
                value: summary.fullDays,
                label: 'Full days',
                color: AppColors.goldDeep,
                gradient: const <Color>[Color(0xFFFFF5DE), Color(0xFFF4E4B9)],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _PremiumStatCard(
                icon: Icons.calendar_today_rounded,
                value: summary.trackedDays,
                label: 'Tracked',
                color: AppColors.greenDeep,
                gradient: const <Color>[Color(0xFFE6EDEB), Color(0xFFD0DCD7)],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPremiumCalendarDay(int year, int month, int dayNumber) {
    final date = DateTime(year, month, dayNumber);
    final key = TrackerDates.dateKey(date);
    final count = (_entries[key] ?? PrayerDay.empty()).completedCount;
    final selected = key == _selectedKey;
    final today = key == TrackerDates.dateKey(DateTime.now());
    final complete = count == prayerIds.length;
    final partial = count > 0 && !complete;

    return Tooltip(
      message: '${DateFormatters.fullDate(date)}, $count/5 prayers',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('calendar-day-$key'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _selectedDate = date;
              _selectedTab = 0;
            });
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              gradient: complete
                  ? const LinearGradient(
                      colors: <Color>[Color(0xFF2E7D5B), Color(0xFF154533)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : partial
                  ? LinearGradient(
                      colors: <Color>[
                        AppColors.greenSoft,
                        AppColors.greenSoft.withValues(alpha: .65),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.gold
                    : today
                    ? AppColors.green.withValues(alpha: .35)
                    : Colors.transparent,
                width: selected ? 2 : 1,
              ),
              boxShadow: complete
                  ? <BoxShadow>[
                      BoxShadow(
                        color: AppColors.greenDeep.withValues(alpha: .18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  DateFormatters.digits(dayNumber),
                  style: TextStyle(
                    color: complete ? Colors.white : AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                _MiniProgressDots(
                  count: count,
                  total: prayerIds.length,
                  onDark: complete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedDayPreview() {
    final entry = _entries[_selectedKey] ?? PrayerDay.empty();
    final count = entry.completedCount;
    final complete = count == prayerIds.length;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.ink.withValues(alpha: .03),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: complete
                        ? const <Color>[AppColors.green, AppColors.greenDeep]
                        : const <Color>[
                            AppColors.greenSoft,
                            AppColors.greenTint,
                          ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  complete
                      ? Icons.check_rounded
                      : Icons.calendar_today_outlined,
                  size: 18,
                  color: complete ? Colors.white : AppColors.greenDeep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _isToday
                          ? 'Today'
                          : DateFormatters.fullDate(_selectedDate),
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      complete
                          ? 'All 5 prayers complete'
                          : count == 0
                          ? 'No prayers logged yet'
                          : '$count of 5 prayers complete',
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => _selectTab(0),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Open',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List<Widget>.generate(prayerIds.length, (i) {
              final id = prayerIds[i];
              return Expanded(
                child: _PrayerStatusChip(
                  name: prayerNames[id]!,
                  done: entry.isCompleted(id),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DATA PAGE
  // ---------------------------------------------------------------------------

  Widget _buildDataPage() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: <Widget>[
      const Text(
        'YOUR DATA',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 4),
      const Text(
        'Backup & storage',
        style: TextStyle(
          color: AppColors.ink,
          fontSize: 27,
          fontWeight: FontWeight.w700,
          letterSpacing: -.6,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Your prayer records and manually entered prayer times stay on this device. '
        'No account or internet connection is required.',
        style: TextStyle(color: AppColors.muted, fontSize: 13, height: 1.6),
      ),
      const SizedBox(height: 22),
      Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: <Widget>[
            _DataAction(
              key: const Key('export-backup'),
              icon: Icons.download_outlined,
              title: 'Export backup',
              subtitle: 'Save your prayer records as a JSON file',
              onPressed: _exportBackup,
            ),
            const Divider(height: 1, indent: 72, color: AppColors.border),
            _DataAction(
              key: const Key('import-backup'),
              icon: Icons.upload_file_outlined,
              title: 'Import backup',
              subtitle: 'Restore records from a JSON backup',
              onPressed: _importBackup,
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Icon(
              Icons.circle,
              size: 8,
              color: _storageWarning == null ? AppColors.green : AppColors.red,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              _storageWarning ??
                  'Saved locally · Available offline · No cloud sync',
              style: TextStyle(
                color: _storageWarning == null
                    ? AppColors.muted
                    : AppColors.red,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[Color(0xFFE9F4EE), Color(0xFFDDEEE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.green.withValues(alpha: .12)),
        ),
        child: const Row(
          children: <Widget>[
            Icon(
              Icons.lock_outline_rounded,
              color: AppColors.greenDeep,
              size: 20,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your data stays on this device. Export a backup before '
                'changing or resetting devices.',
                style: TextStyle(
                  color: AppColors.greenDeep,
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

// -----------------------------------------------------------------------------
// PREMIUM NAV ITEM
// -----------------------------------------------------------------------------

class _PremiumNavItem extends StatelessWidget {
  const _PremiumNavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final isCheckBadge = badge == '✓';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                height: 26,
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: <Widget>[
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      width: selected ? 44 : 0,
                      height: selected ? 26 : 0,
                      decoration: BoxDecoration(
                        gradient: selected
                            ? const LinearGradient(
                                colors: <Color>[
                                  Color(0xFFE9F4EE),
                                  Color(0xFFD4E8DC),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    AnimatedScale(
                      scale: selected ? 1.0 : .92,
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: Icon(
                        selected ? selectedIcon : icon,
                        size: 21,
                        color: selected ? AppColors.greenDeep : AppColors.muted,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -8,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          constraints: const BoxConstraints(minWidth: 16),
                          decoration: BoxDecoration(
                            color: isCheckBadge
                                ? AppColors.gold
                                : AppColors.green,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            badge!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isCheckBadge
                                  ? AppColors.ink
                                  : Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                style: TextStyle(
                  color: selected ? AppColors.greenDeep : AppColors.muted,
                  fontSize: 10.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: .1,
                ),
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HERO PRAYER DOT
// -----------------------------------------------------------------------------

class _HeroDot extends StatelessWidget {
  const _HeroDot({required this.initial, required this.done});

  final String initial;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: done
            ? const Color(0xFFE6D5A9)
            : Colors.white.withValues(alpha: .07),
        shape: BoxShape.circle,
        border: Border.all(
          color: done
              ? Colors.transparent
              : Colors.white.withValues(alpha: .12),
          width: 1,
        ),
      ),
      child: Center(
        child: Icon(
          done ? Icons.check_rounded : Icons.circle_outlined,
          size: done ? 16 : 10,
          color: done
              ? AppColors.greenDeep
              : Colors.white.withValues(alpha: .5),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PRAYER ROW
// -----------------------------------------------------------------------------

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.prayerId,
    required this.name,
    required this.completed,
    required this.time,
    required this.onEditTime,
    required this.onPressed,
  });

  final String prayerId;
  final String name;
  final bool completed;
  final String? time;
  final VoidCallback onEditTime;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final iconColors = _iconGradientFor(prayerId);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      color: completed
          ? AppColors.greenSoft.withValues(alpha: .35)
          : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 78,
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: iconColors.last.withValues(alpha: .28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _iconForPrayer(prayerId),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    style: TextStyle(
                      color: completed ? AppColors.greenDeep : AppColors.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  InkWell(
                    key: Key('schedule-time-$prayerId'),
                    onTap: onEditTime,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            time == null
                                ? Icons.add_circle_outline_rounded
                                : Icons.access_time_rounded,
                            color: AppColors.green,
                            size: 13,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time == null
                                ? 'Add prayer time'
                                : _formatTime(time!),
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              label: '$name ${completed ? 'completed' : 'mark as complete'}',
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: Key('prayer-$prayerId'),
                  customBorder: const CircleBorder(),
                  onTap: onPressed,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: completed ? AppColors.green : Colors.transparent,
                      border: Border.all(
                        color: completed
                            ? AppColors.green
                            : const Color(0xFFC9D0C8),
                        width: 1.4,
                      ),
                      boxShadow: completed
                          ? <BoxShadow>[
                              BoxShadow(
                                color: AppColors.green.withValues(alpha: .35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      size: 22,
                      color: completed ? Colors.white : Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForPrayer(String id) => switch (id) {
    'fajr' => Icons.wb_twilight_rounded,
    'dhuhr' => Icons.wb_sunny_outlined,
    'asr' => Icons.wb_sunny_rounded,
    'maghrib' => Icons.wb_twilight_outlined,
    _ => Icons.nights_stay_outlined,
  };

  static List<Color> _iconGradientFor(String id) => switch (id) {
    'fajr' => const <Color>[Color(0xFF7D82C9), Color(0xFF9F7DC9)],
    'dhuhr' => const <Color>[Color(0xFFE8B94A), Color(0xFFE8964A)],
    'asr' => const <Color>[Color(0xFFD4B857), Color(0xFFC9A94E)],
    'maghrib' => const <Color>[Color(0xFFE8876E), Color(0xFFD4728A)],
    _ => const <Color>[Color(0xFF4A6B9E), Color(0xFF5A4B8E)],
  };

  static String _formatTime(String value) =>
      PrayerSchedule.formatTime12h(value);
}

// -----------------------------------------------------------------------------
// PROGRESS RING
// -----------------------------------------------------------------------------

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : (count / total).clamp(0.0, 1.0);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: 96,
          height: 96,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              CustomPaint(
                size: const Size(96, 96),
                painter: _RingPainter(
                  progress: value,
                  backgroundColor: Colors.white.withValues(alpha: .12),
                  progressColor: const Color(0xFFE6D5A9),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 320),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: .7, end: 1).animate(
                            CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: Text(
                      '$count',
                      key: ValueKey<int>(count),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '/ $total',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.backgroundColor,
    required this.progressColor,
  });

  final double progress;
  final Color backgroundColor;
  final Color progressColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 5;
    const strokeWidth = 7.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if (progress <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.progressColor != progressColor;
}

// -----------------------------------------------------------------------------
// PREMIUM STAT CARD
// -----------------------------------------------------------------------------

class _PremiumStatCard extends StatelessWidget {
  const _PremiumStatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.gradient,
  });

  final IconData icon;
  final int value;
  final String label;
  final Color color;
  final List<Color> gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .6),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 10),
          Text(
            DateFormatters.digits(value),
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -.6,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: .9),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// STREAK BADGE
// -----------------------------------------------------------------------------

class _StreakBadge extends StatelessWidget {
  const _StreakBadge({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFFFF2D6), Color(0xFFF4E1B5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: .4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.gold.withValues(alpha: .22),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(
            Icons.local_fire_department_rounded,
            size: 15,
            color: Color(0xFFC77E1A),
          ),
          const SizedBox(width: 5),
          Text(
            '$streak day${streak == 1 ? '' : 's'}',
            style: const TextStyle(
              color: Color(0xFF8B5A12),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: -.1,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// MINI PROGRESS DOTS (used in calendar cells)
// -----------------------------------------------------------------------------

class _MiniProgressDots extends StatelessWidget {
  const _MiniProgressDots({
    required this.count,
    required this.total,
    this.onDark = false,
  });

  final int count;
  final int total;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final filledColor = onDark ? const Color(0xFFE6D5A9) : AppColors.green;
    final emptyColor = onDark
        ? Colors.white.withValues(alpha: .3)
        : AppColors.muted.withValues(alpha: .18);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(total, (i) {
        final filled = i < count;
        return Container(
          width: 3.5,
          height: 3.5,
          margin: const EdgeInsets.symmetric(horizontal: 0.75),
          decoration: BoxDecoration(
            color: filled ? filledColor : emptyColor,
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

// -----------------------------------------------------------------------------
// PRAYER STATUS CHIP (used in selected-day preview)
// -----------------------------------------------------------------------------

class _PrayerStatusChip extends StatelessWidget {
  const _PrayerStatusChip({required this.name, required this.done});

  final String name;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: done
                ? AppColors.green
                : AppColors.greenSoft.withValues(alpha: .5),
            shape: BoxShape.circle,
            border: done ? null : Border.all(color: AppColors.border, width: 1),
            boxShadow: done
                ? <BoxShadow>[
                    BoxShadow(
                      color: AppColors.green.withValues(alpha: .28),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle_outlined,
            size: done ? 16 : 10,
            color: done ? Colors.white : AppColors.muted.withValues(alpha: .5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name.substring(0, 3),
          style: TextStyle(
            color: done ? AppColors.greenDeep : AppColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: .1,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// LEGEND CHIP
// -----------------------------------------------------------------------------

class _LegendChip extends StatelessWidget {
  const _LegendChip({
    this.gradient,
    this.color,
    this.borderColor,
    required this.label,
  });

  final List<Color>? gradient;
  final Color? color;
  final Color? borderColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            gradient: gradient != null
                ? LinearGradient(colors: gradient!)
                : null,
            color: gradient == null ? (color ?? Colors.transparent) : null,
            borderRadius: BorderRadius.circular(4),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1)
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// PILL ICON BUTTON
// -----------------------------------------------------------------------------

class _PillIconButton extends StatelessWidget {
  const _PillIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: AppColors.greenSoft,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icon, color: AppColors.greenDeep, size: 20),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// -----------------------------------------------------------------------------
// SMALL BUBBLE
// -----------------------------------------------------------------------------

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: color, size: 20),
  );
}

// -----------------------------------------------------------------------------
// DATA ACTION
// -----------------------------------------------------------------------------

class _DataAction extends StatelessWidget {
  const _DataAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onPressed,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    leading: Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFFE9F4EE), Color(0xFFD4E8DC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: AppColors.greenDeep, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -.1,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: AppColors.muted, fontSize: 11.5),
    ),
    trailing: Container(
      width: 30,
      height: 30,
      decoration: const BoxDecoration(
        color: AppColors.greenSoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.arrow_forward_rounded,
        color: AppColors.greenDeep,
        size: 15,
      ),
    ),
  );
}
