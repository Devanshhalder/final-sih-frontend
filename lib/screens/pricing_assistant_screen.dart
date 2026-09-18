import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/app_state.dart';
import '../theme.dart';

class PricingAssistantScreen extends StatefulWidget {
  const PricingAssistantScreen({super.key});

  @override
  State<PricingAssistantScreen> createState() => _PricingAssistantScreenState();
}

class _PricingAssistantScreenState extends State<PricingAssistantScreen>
    with SingleTickerProviderStateMixin {
  final _materialController = TextEditingController(text: '0');
  final _hoursController = TextEditingController(text: '4');
  final _rateController = TextEditingController(text: '150');
  final _priceController = TextEditingController();

  bool _loading = false;
  int? _recommended;
  String _reason = '';
  double _control = .5;
  late final AnimationController _counterController;
  int _displayPrice = 0;

  static const _baseUrl = 'http://10.70.33.153:8000';

  @override
  void initState() {
    super.initState();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
  }

  @override
  void dispose() {
    _materialController.dispose();
    _hoursController.dispose();
    _rateController.dispose();
    _priceController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  int _money(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  double get _laborCost =>
      (double.tryParse(_hoursController.text.trim()) ?? 0) *
      (double.tryParse(_rateController.text.trim()) ?? 0);

  double get _costFloor => _money(_materialController) + _laborCost;

  Future<void> _calculate() async {
    if (_loading) return;

    final state = AppScope.of(context);
    final imagePath = state.draftImagePath;
    final description = state.draft.description.trim();

    if (imagePath == null || imagePath.isEmpty) {
      _message('Add a product photo before asking AI to value it.');
      return;
    }
    if (description.length < 15) {
      _message('Add a little more product detail before valuation.');
      return;
    }

    setState(() => _loading = true);

    try {
      final file = File(imagePath);
      if (!await file.exists()) throw Exception('Product image not found.');
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) throw Exception('Product image is empty.');

      final extension = file.path.toLowerCase().split('.').last;
      final mime = extension == 'png'
          ? 'image/png'
          : extension == 'webp'
              ? 'image/webp'
              : 'image/jpeg';

      final response = await http
          .post(
            Uri.parse('$_baseUrl/ai/pricing'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'image_base64': 'data:$mime;base64,${base64Encode(bytes)}',
              'image_url': null,
              'description': description,
              'raw_material_cost': _money(_materialController),
              'labor_hours': double.tryParse(_hoursController.text.trim()) ?? 0,
              'labor_rate': double.tryParse(_rateController.text.trim()) ?? 0,
              'labor_cost': _laborCost,
              'category': state.draft.category,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        throw Exception('Pricing service returned ${response.statusCode}.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) throw Exception('Invalid pricing response.');
      final raw = decoded['suggested_price'];
      final aiPrice = raw is num ? raw.round() : int.tryParse('$raw');
      if (aiPrice == null || aiPrice <= 0) {
        throw Exception('AI returned an invalid recommendation.');
      }

      final safeRecommendation = aiPrice < _costFloor
          ? (_costFloor * 1.15).ceil()
          : aiPrice;

      _setRecommendation(
        safeRecommendation,
        (decoded['reasoning'] ?? '').toString().trim(),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _message('Could not calculate a live AI benchmark. Please try again.');
    }
  }

  void _setRecommendation(int value, String reason) {
    final old = _displayPrice;
    _recommended = value;
    _displayPrice = value;
    _priceController.text = value.toString();
    _reason = reason.isEmpty
        ? 'Recommendation combines the AI valuation with your cost floor.'
        : reason;

    _counterController.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _loading = false);
    });

    if (old == value && mounted) setState(() {});
  }

  void _onSlider(double value) {
    if (_recommended == null) return;
    final min = mathMax(_costFloor * 1.05, _recommended! * .75);
    final max = mathMax(min + 1, _recommended! * 1.35);
    final next = (min + ((max - min) * value)).round();
    setState(() {
      _control = value;
      _displayPrice = next;
      _priceController.text = next.toString();
    });
  }

  double mathMax(double a, double b) => a > b ? a : b;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(behavior: SnackBarBehavior.floating, content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final state = AppScope.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: const Text(
          'Dynamic Pricing Assistant',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
        children: [
          const Text(
            'Price your craft with confidence',
            style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 7),
          Text(
            'AI considers your product photo and description. You keep final control.',
            style: TextStyle(color: colors.onSurfaceVariant, height: 1.45),
          ),
          const SizedBox(height: 20),
          _photoCard(state.draftImagePath),
          const SizedBox(height: 18),
          _sectionTitle('Your real costs'),
          const SizedBox(height: 10),
          _numberField(_materialController, 'Raw material cost', Icons.inventory_2_outlined),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _numberField(_hoursController, 'Hours', Icons.schedule_rounded, decimal: true)),
              const SizedBox(width: 10),
              Expanded(child: _numberField(_rateController, '₹ / hour', Icons.currency_rupee_rounded, decimal: true)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Minimum viable cost: ₹${_costFloor.round()}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _loading ? null : _calculate,
              icon: _loading
                  ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(_loading ? 'Calculating…' : 'Get AI price benchmark'),
            ),
          ),
          const SizedBox(height: 18),
          AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: AppColors.forest.withOpacity(.08),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: AppColors.forest.withOpacity(.16)),
            ),
            child: _recommended == null
                ? const Text('Your AI benchmark will appear here.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI benchmark', style: TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      AnimatedBuilder(
                        animation: _counterController,
                        builder: (_, __) {
                          final value = Tween<double>(begin: 0, end: _displayPrice.toDouble())
                              .animate(CurvedAnimation(parent: _counterController, curve: Curves.easeOutCubic))
                              .value;
                          return Text('₹${value.round()}', style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900, color: AppColors.forest));
                        },
                      ),
                      const SizedBox(height: 5),
                      Text(_reason, style: TextStyle(fontSize: 11, height: 1.45, color: colors.onSurfaceVariant)),
                      const SizedBox(height: 16),
                      Text('Adjust your final selling price', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: colors.onSurface)),
                      Slider(
                        value: _control,
                        onChanged: _onSlider,
                        divisions: 100,
                        min: 0,
                        max: 1,
                        label: '₹$_displayPrice',
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Lower', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                          Text('Higher', style: TextStyle(fontSize: 10, color: colors.onSurfaceVariant)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Final price', prefixText: '₹ '),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800));

  Widget _photoCard(String? path) {
    return Container(
      height: 170,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: AppColors.saffron.withOpacity(.12)),
      child: path != null && path.isNotEmpty
          ? Image.file(File(path), fit: BoxFit.cover)
          : const Center(child: Icon(Icons.image_outlined, size: 48, color: AppColors.clay)),
    );
  }

  Widget _numberField(TextEditingController controller, String label, IconData icon, {bool decimal = false}) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    );
  }
}
