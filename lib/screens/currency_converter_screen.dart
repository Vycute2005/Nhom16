import 'package:hcm_explorer/widgets/app_ui.dart';

class CurrencyConverterScreen extends StatefulWidget {
  const CurrencyConverterScreen({super.key});

  @override
  State<CurrencyConverterScreen> createState() => _CurrencyConverterScreenState();
}

class _CurrencyConverterScreenState extends State<CurrencyConverterScreen> with AppLocaleAwareState<CurrencyConverterScreen> {
  double _vnd = 1000000;
  String _selected = 'USD';
  final Map<String, double> _rates = {
    'USD': 25400,
    'EUR': 27500,
    'JPY': 165,
    'KRW': 18.5,
  };

  @override
  Widget build(BuildContext context) {
    double result = _vnd / (_rates[_selected] ?? 1);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: const Text('Quy đổi tỷ giá ngoại tệ', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _rates.keys.map((curr) {
                final isSel = curr == _selected;
                return ChoiceChip(
                  label: Text(curr),
                  selected: isSel,
                  selectedColor: const Color(0xFF0F5B49),
                  labelStyle: TextStyle(color: isSel ? Colors.white : Colors.black),
                  onSelected: (_) => setState(() => _selected = curr),
                );
              }).toList(),
            ),
            const SizedBox(height: 30),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Việt Nam Đồng (VND)'),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _vnd = double.tryParse(val) ?? 0);
              },
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F5B49),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tỷ giá tương đương ($_selected)', style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text(
                    result.toStringAsFixed(2),
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}