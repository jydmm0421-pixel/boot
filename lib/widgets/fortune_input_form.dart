import 'package:flutter/material.dart';
import '../models/fortune_result.dart';

/// 算命输入表单 — 出生日期、性别、阳历/农历选择
class FortuneInputForm extends StatefulWidget {
  final Function(BirthInput) onSubmit;

  const FortuneInputForm({super.key, required this.onSubmit});

  @override
  State<FortuneInputForm> createState() => _FortuneInputFormState();
}

class _FortuneInputFormState extends State<FortuneInputForm> {
  final _yearController = TextEditingController(text: '1990');
  final _monthController = TextEditingController(text: '1');
  final _dayController = TextEditingController(text: '1');
  final _hourController = TextEditingController(text: '12');
  final _minuteController = TextEditingController(text: '0');

  bool _isLunar = false;
  String _gender = 'male'; // 'male' | 'female'
  String? _error;

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  BirthInput? _validate() {
    final year = int.tryParse(_yearController.text.trim());
    final month = int.tryParse(_monthController.text.trim());
    final day = int.tryParse(_dayController.text.trim());
    final hour = int.tryParse(_hourController.text.trim());
    final minute = int.tryParse(_minuteController.text.trim());

    if (year == null || year < 1900 || year > 2100) return null;
    if (month == null || month < 1 || month > 12) return null;
    if (day == null || day < 1 || day > 31) return null;
    if (hour == null || hour < 0 || hour > 23) return null;
    if (minute == null || minute < 0 || minute > 59) return null;

    return BirthInput(
      year: year,
      month: month,
      day: day,
      hour: hour,
      minute: minute,
      isLunar: _isLunar,
      gender: _gender,
    );
  }

  void _handleSubmit() {
    final input = _validate();
    if (input == null) {
      setState(() => _error = '请检查输入信息：年份1900-2100，月份1-12，日期1-31，小时0-23，分钟0-59');
      return;
    }
    setState(() => _error = null);
    widget.onSubmit(input);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Text(
            '紫微斗数 · 八字排盘',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            '输入出生信息，查看命盘',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // 日历类型
          _buildSectionTitle('日历类型'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: '🌞 阳历（公历）',
                  selected: !_isLunar,
                  onTap: () => setState(() => _isLunar = false),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChoiceChip(
                  label: '🌙 农历',
                  selected: _isLunar,
                  onTap: () => setState(() => _isLunar = true),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 出生日期
          _buildSectionTitle('出生日期'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildNumberField(
                  controller: _yearController,
                  label: '年',
                  hint: '1990',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  controller: _monthController,
                  label: '月',
                  hint: '1',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  controller: _dayController,
                  label: '日',
                  hint: '1',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 出生时间
          _buildSectionTitle('出生时间'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildNumberField(
                  controller: _hourController,
                  label: '时 (0-23)',
                  hint: '12',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildNumberField(
                  controller: _minuteController,
                  label: '分 (0-59)',
                  hint: '0',
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 性别
          _buildSectionTitle('性别'),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: '👨 男',
                  selected: _gender == 'male',
                  onTap: () => setState(() => _gender = 'male'),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChoiceChip(
                  label: '👩 女',
                  selected: _gender == 'female',
                  onTap: () => setState(() => _gender = 'female'),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),

          // 错误提示
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withAlpha(100)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

          // 提交按钮
          FilledButton.icon(
            onPressed: _handleSubmit,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('开始排盘'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildNumberField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(60)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
