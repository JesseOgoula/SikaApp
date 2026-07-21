import 'package:flutter/material.dart';

import 'package:sika_app/core/services/notification_preferences.dart';
import 'package:sika_app/core/services/notification_service.dart';
import 'package:sika_app/core/theme/app_theme.dart';

/// Écran de paramétrage des notifications
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _prefs = NotificationPreferences();
  bool _isLoading = true;

  // État local
  bool _masterEnabled = true;
  bool _debtEnabled = true;
  List<int> _debtDays = [1, 3];
  int _debtHour = 9;
  bool _lowBalanceEnabled = true;
  double _lowBalanceThreshold = 50000;
  bool _goalEnabled = true;
  int _goalDay = 7;
  int _goalHour = 10;
  bool _budgetEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    await _prefs.init();
    _masterEnabled = await _prefs.isEnabled;
    _debtEnabled = await _prefs.debtRemindersEnabled;
    _debtDays = await _prefs.debtReminderDays;
    _debtHour = await _prefs.debtReminderHour;
    _lowBalanceEnabled = await _prefs.lowBalanceEnabled;
    _lowBalanceThreshold = await _prefs.lowBalanceThreshold;
    _goalEnabled = await _prefs.goalRemindersEnabled;
    _goalDay = await _prefs.goalReminderDay;
    _goalHour = await _prefs.goalReminderHour;
    _budgetEnabled = await _prefs.budgetAlertsEnabled;

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _rescheduleNotifications() async {
    try {
      final service = NotificationService();
      await service.init();
      if (!_masterEnabled) {
        await service.cancelAll();
      }
    } catch (e) {
      /* ignore */
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackground,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.scaffoldBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              child: Column(
                children: [
                  // Master switch
                  _buildMasterSwitch(),
                  const SizedBox(height: 16),

                  // Sections désactivées si master est off
                  AnimatedOpacity(
                    opacity: _masterEnabled ? 1.0 : 0.4,
                    duration: const Duration(milliseconds: 200),
                    child: IgnorePointer(
                      ignoring: !_masterEnabled,
                      child: Column(
                        children: [
                          _buildDebtSection(),
                          const SizedBox(height: 12),
                          _buildLowBalanceSection(),
                          const SizedBox(height: 12),
                          _buildBudgetSection(),
                          const SizedBox(height: 12),
                          _buildGoalSection(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  // ==================== MASTER SWITCH ====================

  Widget _buildMasterSwitch() {
    return _buildCard(
      children: [
        _buildSwitchTile(
          icon: Icons.notifications_active_rounded,
          title: 'Notifications',
          subtitle: 'Activer toutes les notifications',
          value: _masterEnabled,
          onChanged: (val) async {
            setState(() => _masterEnabled = val);
            await _prefs.setEnabled(val);
            await _rescheduleNotifications();
          },
          isPrimary: true,
        ),
      ],
    );
  }

  // ==================== DEBT REMINDERS ====================

  Widget _buildDebtSection() {
    return _buildCard(
      children: [
        _buildSwitchTile(
          icon: Icons.receipt_long_rounded,
          title: 'Rappels Dettes & Factures',
          subtitle: 'Prévenu avant les échéances',
          value: _debtEnabled,
          onChanged: (val) async {
            setState(() => _debtEnabled = val);
            await _prefs.setDebtRemindersEnabled(val);
          },
        ),
        if (_debtEnabled) ...[
          const Divider(height: 1),
          _buildDaysSelector(),
          const Divider(height: 1),
          _buildHourPicker(
            label: 'Heure du rappel',
            value: _debtHour,
            onChanged: (hour) async {
              setState(() => _debtHour = hour);
              await _prefs.setDebtReminderHour(hour);
            },
          ),
          const Divider(height: 1),
          _buildTestButton(
            onPressed: () => NotificationService().testDebtNotification(),
          ),
        ],
      ],
    );
  }

  Widget _buildDaysSelector() {
    final availableDays = [1, 2, 3, 5, 7];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rappeler avant l\'échéance',
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: availableDays.map((day) {
              final isSelected = _debtDays.contains(day);
              return FilterChip(
                label: Text(
                  day == 1 ? '1 jour' : '$day jours',
                  style: TextStyle(
                    fontSize: 13,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                selected: isSelected,
                onSelected: (selected) async {
                  setState(() {
                    if (selected) {
                      _debtDays.add(day);
                    } else {
                      _debtDays.remove(day);
                    }
                    _debtDays.sort();
                  });
                  await _prefs.setDebtReminderDays(_debtDays);
                },
                selectedColor: AppTheme.primaryColor,
                backgroundColor: Colors.grey.shade100,
                checkmarkColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade300,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ==================== LOW BALANCE ====================

  Widget _buildLowBalanceSection() {
    return _buildCard(
      children: [
        _buildSwitchTile(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Alerte Solde Faible',
          subtitle: 'Notification quand le solde descend',
          value: _lowBalanceEnabled,
          onChanged: (val) async {
            setState(() => _lowBalanceEnabled = val);
            await _prefs.setLowBalanceEnabled(val);
          },
        ),
        if (_lowBalanceEnabled) ...[
          const Divider(height: 1),
          _buildThresholdPicker(),
          const Divider(height: 1),
          _buildTestButton(
            onPressed: () => NotificationService().testLowBalanceNotification(),
          ),
        ],
      ],
    );
  }

  Widget _buildThresholdPicker() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Seuil d\'alerte',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_formatAmount(_lowBalanceThreshold)} FCFA',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppTheme.primaryColor,
              inactiveTrackColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              thumbColor: AppTheme.primaryColor,
              overlayColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              trackHeight: 4,
            ),
            child: Slider(
              value: _lowBalanceThreshold,
              min: 10000,
              max: 500000,
              divisions: 49,
              onChanged: (val) {
                setState(() => _lowBalanceThreshold = val);
              },
              onChangeEnd: (val) async {
                await _prefs.setLowBalanceThreshold(val);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '10 000 F',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
              Text(
                '500 000 F',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== BUDGET ALERTS ====================

  Widget _buildBudgetSection() {
    return _buildCard(
      children: [
        _buildSwitchTile(
          icon: Icons.pie_chart_rounded,
          title: 'Alertes Budget',
          subtitle: 'Notification si un budget est depasse',
          value: _budgetEnabled,
          onChanged: (val) async {
            setState(() => _budgetEnabled = val);
            await _prefs.setBudgetAlertsEnabled(val);
            if (!val) {
              // Annuler les notifications budget existantes
              final service = NotificationService();
              await service.cancel(8000); // _idBudgetExceeded
              await service.cancel(9000); // _idGlobalBudgetExceeded
            }
          },
        ),
        if (_budgetEnabled) ...[
          const Divider(height: 1),
          _buildTestButton(
            onPressed: () => NotificationService().testBudgetNotification(),
          ),
        ],
      ],
    );
  }

  // ==================== GOAL REMINDERS ====================

  Widget _buildGoalSection() {
    return _buildCard(
      children: [
        _buildSwitchTile(
          icon: Icons.flag_rounded,
          title: 'Rappels Objectifs',
          subtitle: 'Rappel hebdomadaire pour épargner',
          value: _goalEnabled,
          onChanged: (val) async {
            setState(() => _goalEnabled = val);
            await _prefs.setGoalRemindersEnabled(val);
          },
        ),
        if (_goalEnabled) ...[
          const Divider(height: 1),
          _buildDayPicker(
            label: 'Jour du rappel',
            value: _goalDay,
            onChanged: (day) async {
              setState(() => _goalDay = day);
              await _prefs.setGoalReminderDay(day);
            },
          ),
          const Divider(height: 1),
          _buildHourPicker(
            label: 'Heure du rappel',
            value: _goalHour,
            onChanged: (hour) async {
              setState(() => _goalHour = hour);
              await _prefs.setGoalReminderHour(hour);
            },
          ),
          const Divider(height: 1),
          _buildTestButton(
            onPressed: () => NotificationService().testGoalNotification(),
          ),
        ],
      ],
    );
  }



  // ==================== SHARED WIDGETS ====================

  Widget _buildTestButton({required VoidCallback onPressed}) {
    return InkWell(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_active_outlined, size: 16, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            Text(
              'Tester la notification',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool isPrimary = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isPrimary
                  ? AppTheme.primaryColor.withValues(alpha: 0.12)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: isPrimary ? AppTheme.primaryColor : AppTheme.textSecondary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isPrimary ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildDayPicker({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: value,
                isDense: true,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                items: List.generate(7, (i) {
                  final day = i + 1;
                  return DropdownMenuItem(
                    value: day,
                    child: Text(NotificationPreferences.dayName(day)),
                  );
                }),
                onChanged: (val) {
                  if (val != null) onChanged(val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHourPicker({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          GestureDetector(
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: value, minute: 0),
                builder: (context, child) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primaryColor,
                      ),
                    ),
                    child: child!,
                  );
                },
              );
              if (time != null) {
                onChanged(time.hour);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    NotificationPreferences.formatHour(value),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ',
        );
  }
}
