import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/fortune_result.dart';
import '../services/fortune_service.dart';
import '../widgets/fortune_input_form.dart';
import '../widgets/fortune_result_card.dart';
import '../widgets/fortune_interpreter.dart';

enum FortuneMode { single, couple }

/// 算命页面 — 单人解读 + 双人合盘
class FortuneScreen extends StatefulWidget {
  const FortuneScreen({super.key});

  @override
  State<FortuneScreen> createState() => _FortuneScreenState();
}

class _FortuneScreenState extends State<FortuneScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 单人模式
  FortuneResult? _result;
  bool _loading = false;
  String? _error;

  // 双人模式
  final _meInput = _CoupleInput();
  final _taInput = _CoupleInput();

  // 解读
  bool _isInterpreting = false;
  String _interpretText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ==================== 单人排盘 ====================

  Future<void> _calculate(BirthInput input) async {
    setState(() { _loading = true; _error = null; });
    try {
      final service = context.read<FortuneService>();
      final result = await service.calculateBoth(input: input);
      if (mounted) setState(() { _result = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '计算出错: $e'; _loading = false; });
    }
  }

  // ==================== 双人合盘 ====================

  Future<void> _coupleCalculate() async {
    final me = _meInput.validate();
    final ta = _taInput.validate();
    if (me == null || ta == null) {
      setState(() => _error = '请完整填写两人信息');
      return;
    }

    setState(() { _loading = true; _error = null; _interpretText = ''; });

    try {
      final service = context.read<FortuneService>();
      final results = await Future.wait([
        service.calculateBoth(input: me),
        service.calculateBoth(input: ta),
      ]);

      final meResult = results[0];
      final taResult = results[1];

      // 开始流式合盘解读
      _isInterpreting = true;
      final stream = service.interpretCoupleStream(me: meResult, ta: taResult);
      stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _interpretText += chunk;
              _loading = false;
            });
          }
        },
        onDone: () {
          if (mounted) setState(() => _isInterpreting = false);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = '解读失败: $e';
              _loading = false;
              _isInterpreting = false;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) setState(() { _error = '出错: $e'; _loading = false; });
    }
  }

  void _reset() {
    setState(() {
      _result = null;
      _error = null;
      _interpretText = '';
      _isInterpreting = false;
    });
  }

  void _resetCouple() {
    setState(() {
      _error = null;
      _interpretText = '';
      _isInterpreting = false;
      _loading = false;
    });
  }

  // ==================== 单人解读 ====================

  Stream<String> _onInterpret(String topic) {
    final service = context.read<FortuneService>();
    return service.interpretSingleStream(fortune: _result!, topic: topic);
  }

  // ==================== UI ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('命盘'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.person), text: '单人排盘'),
            Tab(icon: Icon(Icons.favorite_border), text: '双人合盘'),
          ],
        ),
        actions: [
          if (_result != null && _tabController.index == 0)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: '重新计算',
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSingleTab(),
          _buildCoupleTab(),
        ],
      ),
    );
  }

  // ==================== 单人 Tab ====================

  Widget _buildSingleTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null && _result == null) return _buildErrorView();

    // 排盘前：输入表单
    if (_result == null) return FortuneInputForm(onSubmit: _calculate);

    // 排盘后：结果 + 解读
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FortuneResultCard(result: _result!),
          const SizedBox(height: 20),
          FortuneInterpreter(
            result: _result,
            onInterpret: _onInterpret,
            onReset: _reset,
          ),
        ],
      ),
    );
  }

  // ==================== 双人 Tab ====================

  Widget _buildCoupleTab() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '输入两人的出生信息，AI 分析配对情况',
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 我的信息
          _buildCoupleCard('我', _meInput, Icons.person, Colors.blue),
          const SizedBox(height: 12),
          // TA的信息
          _buildCoupleCard('TA', _taInput, Icons.favorite, Colors.red),

          const SizedBox(height: 24),

          // 错误
          if (_error != null && _interpretText.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13),
                    textAlign: TextAlign.center),
              ),
            ),

          // 合盘按钮
          if (_interpretText.isEmpty)
            FilledButton.icon(
              onPressed: _loading ? null : _coupleCalculate,
              icon:
                  _loading ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ) : const Icon(Icons.favorite),
              label: Text(_loading ? '分析中...' : '开始合盘分析'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Colors.red[400],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),

          // 合盘结果
          if (_interpretText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.favorite,
                                  color: Colors.red, size: 18),
                              const SizedBox(width: 6),
                              const Text('配对分析',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15)),
                            ],
                          ),
                          const Divider(),
                          SelectableText(
                            _interpretText,
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          if (_isInterpreting) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!_isInterpreting)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey[200]!,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _coupleCalculate,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('重新分析'),
                          ),
                          TextButton.icon(
                            onPressed: _resetCouple,
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('修改信息'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoupleCard(
      String label, _CoupleInput input, IconData icon, Color color) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ],
            ),
            const SizedBox(height: 10),
            // 日期行
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _buildTF(input.yearController, '年', '1990'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _buildTF(input.monthController, '月', '1'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _buildTF(input.dayController, '日', '1'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTF(input.hourController, '时(0-23)', '12'),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _buildTF(input.minuteController, '分', '0'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildMiniChip(label: '🌞阳历', selected: !input.isLunar,
                    onTap: () => setState(() => input.isLunar = false)),
                const SizedBox(width: 6),
                _buildMiniChip(label: '🌙农历', selected: input.isLunar,
                    onTap: () => setState(() => input.isLunar = true)),
                const Spacer(),
                _buildMiniChip(label: '男', selected: input.gender == 'male',
                    onTap: () => setState(() => input.gender = 'male')),
                const SizedBox(width: 6),
                _buildMiniChip(label: '女', selected: input.gender == 'female',
                    onTap: () => setState(() => input.gender = 'female')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTF(TextEditingController c, String label, String hint) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      style: const TextStyle(fontSize: 13),
    );
  }

  Widget _buildMiniChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey[400]!,
          ),
          borderRadius: BorderRadius.circular(8),
          color: selected
              ? Theme.of(context).colorScheme.primaryContainer.withAlpha(60)
              : null,
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _reset, child: const Text('重新输入')),
          ],
        ),
      ),
    );
  }
}

/// 双人输入数据容器
class _CoupleInput {
  final yearController = TextEditingController(text: '1990');
  final monthController = TextEditingController(text: '1');
  final dayController = TextEditingController(text: '1');
  final hourController = TextEditingController(text: '12');
  final minuteController = TextEditingController(text: '0');
  bool isLunar = false;
  String gender = 'male'; // 'male' | 'female'

  BirthInput? validate() {
    final year = int.tryParse(yearController.text.trim());
    final month = int.tryParse(monthController.text.trim());
    final day = int.tryParse(dayController.text.trim());
    final hour = int.tryParse(hourController.text.trim());
    final minute = int.tryParse(minuteController.text.trim());

    if (year == null || year < 1900 || year > 2100) return null;
    if (month == null || month < 1 || month > 12) return null;
    if (day == null || day < 1 || day > 31) return null;
    if (hour == null || hour < 0 || hour > 23) return null;
    if (minute == null || minute < 0 || minute > 59) return null;

    return BirthInput(
      year: year, month: month, day: day,
      hour: hour, minute: minute,
      isLunar: isLunar, gender: gender,
    );
  }
}
