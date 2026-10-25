import 'package:hcm_explorer/widgets/app_ui.dart';

import '../models/lichtrinh.dart';
import 'account_access_screen.dart';
import '../services/favorites_store.dart';
import '../widgets/favorite_button.dart';

const Color _green = Color(0xFF1B6A5B);
const Color _red = Color(0xFFC6422D);
const List<String> _itineraryDestinations = [
  'Hà Nội', 'Cao Bằng', 'Tuyên Quang', 'Lào Cai', 'Điện Biên', 'Lai Châu',
  'Sơn La', 'Thái Nguyên', 'Lạng Sơn', 'Quảng Ninh', 'Bắc Ninh', 'Phú Thọ',
  'Hải Phòng', 'Hưng Yên', 'Ninh Bình', 'Thanh Hóa', 'Nghệ An', 'Hà Tĩnh',
  'Quảng Trị', 'Huế', 'Đà Nẵng', 'Quảng Ngãi', 'Gia Lai', 'Đắk Lắk',
  'Khánh Hòa', 'Lâm Đồng', 'TP. Hồ Chí Minh', 'Đồng Nai', 'Tây Ninh',
  'Đồng Tháp', 'Vĩnh Long', 'Cần Thơ', 'An Giang', 'Cà Mau',
];
const List<String> _stopTypes = [
  'Tham quan',
  'Ẩm thực',
  'Thiên nhiên',
  'Mua sắm',
  'Nghỉ ngơi',
  'Khác',
];

class LichTrinhScreen extends StatelessWidget {
  const LichTrinhScreen({super.key});

  void _createNew(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateItineraryScreen()),
    );
  }

  void _useTemplate(BuildContext context, ItineraryTemplate template) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateItineraryScreen(
          initialName: template.name,
          initialDestination: template.destination,
          initialDurationDays: template.durationDays,
          initialStopsByDay: template.stopsByDay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Lịch trình gợi ý',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [_green, Color(0xFF2A8975)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_rounded, color: Colors.white, size: 32),
                SizedBox(height: 14),
                Text(
                  'Chuyến đi của riêng bạn',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Chọn lịch trình mẫu để bắt đầu nhanh hoặc tự tạo hành trình theo sở thích.',
                  style: TextStyle(color: Colors.white, height: 1.4),
                ),
                SizedBox(height: 16),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: () => _createNew(context),
              style: FilledButton.styleFrom(
                backgroundColor: _red,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Tạo lịch trình của tôi', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Lịch trình mẫu',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF252525)),
          ),
          const SizedBox(height: 6),
          Text('Chọn một hành trình rồi chỉnh sửa theo ý bạn.', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          ...sampleItineraryTemplates.asMap().entries.map((entry) {
            final index = entry.key;
            final template = entry.value;
            final iconData = switch (index) {
              0 => Icons.location_city_rounded,
              1 => Icons.temple_buddhist_rounded,
              _ => Icons.travel_explore_rounded,
            };
            final iconColor = switch (index) {
              0 => _green,
              1 => _red,
              _ => const Color(0xFFB88A2B),
            };

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFECE8E1)),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(iconData, color: iconColor, size: 30),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(template.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.place_outlined, size: 15, color: _green),
                                const SizedBox(width: 4),
                                Expanded(child: Text(template.destination, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                              decoration: BoxDecoration(color: _green.withOpacity(0.09), borderRadius: BorderRadius.circular(30)),
                              child: Text('${template.durationDays} ngày ${template.durationDays - 1} đêm', style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                      FavoriteButton(entry: FavoriteEntry.forTemplate(template)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(template.description, style: TextStyle(color: Colors.grey.shade800, height: 1.4)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined, color: _red, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Chi phí dự kiến từ ${_formatMoney(template.estimatedCost)}',
                          style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: () => _useTemplate(context, template),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _green,
                        side: const BorderSide(color: _green),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sử dụng lịch trình này', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class CreateItineraryScreen extends StatefulWidget {
  final ItineraryPlan? existingPlan;
  final String? initialName;
  final String? initialDestination;
  final int? initialDurationDays;
  final Map<int, List<ItineraryStop>> initialStopsByDay;

  const CreateItineraryScreen({
    super.key,
    this.existingPlan,
    this.initialName,
    this.initialDestination,
    this.initialDurationDays,
    this.initialStopsByDay = const <int, List<ItineraryStop>>{},
  });

  @override
  State<CreateItineraryScreen> createState() => _CreateItineraryScreenState();
}

class _CreateItineraryScreenState extends State<CreateItineraryScreen> with AppLocaleAwareState<CreateItineraryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _destinationController;
  late DateTime _startDate;
  late DateTime _endDate;
  late List<ItineraryDay> _days;
  int _selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    final plan = widget.existingPlan;
    _nameController = TextEditingController(text: plan?.name ?? widget.initialName ?? '');
    _destinationController = TextEditingController(text: plan?.destination ?? widget.initialDestination ?? '');

    if (plan != null) {
      _startDate = _dateOnly(plan.startDate);
      _endDate = _dateOnly(plan.endDate);
      _days = plan.days
          .map((day) => ItineraryDay(date: day.date, stops: List<ItineraryStop>.from(day.stops)))
          .toList();
    } else {
      _startDate = _dateOnly(DateTime.now());
      final duration = (widget.initialDurationDays ?? 3).clamp(1, 30).toInt();
      _endDate = _startDate.add(Duration(days: duration - 1));
      _days = List.generate(duration, (index) {
        return ItineraryDay(
          date: _startDate.add(Duration(days: index)),
          stops: List<ItineraryStop>.from(widget.initialStopsByDay[index] ?? const <ItineraryStop>[]),
        );
      });
    }
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

  @override
  void dispose() {
    _nameController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _selectDestination() async {
    final searchController = TextEditingController();
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final query = searchController.text.trim().toLowerCase();
          final destinations = _itineraryDestinations
              .where((name) => name.toLowerCase().contains(query))
              .toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.78,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
                  child: TextField(
                    controller: searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: AppTranslations.translate('Chọn tỉnh / thành phố'),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                ),
                Expanded(
                  child: destinations.isEmpty
                      ? const Center(
                          child: Text('Không tìm thấy tỉnh/thành phố'),
                        )
                      : ListView.separated(
                          itemCount: destinations.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final destination = destinations[index];
                            final isSelected =
                                _destinationController.text.trim() ==
                                    destination;
                            return ListTile(
                              leading: Icon(
                                isSelected
                                    ? Icons.location_on
                                    : Icons.location_on_outlined,
                                color: _green,
                              ),
                              title: Text(destination),
                              trailing: isSelected
                                  ? const Icon(Icons.check, color: _green)
                                  : null,
                              onTap: () =>
                                  Navigator.pop(sheetContext, destination),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
    searchController.dispose();
    if (selected != null && mounted) {
      setState(() => _destinationController.text = selected);
    }
  }

  void _syncDays() {
    final count = (_endDate.difference(_startDate).inDays + 1).clamp(1, 30).toInt();
    final oldDays = _days;
    _days = List.generate(count, (index) {
      final date = _startDate.add(Duration(days: index));
      final stops = index < oldDays.length
          ? List<ItineraryStop>.from(oldDays[index].stops)
          : List<ItineraryStop>.from(widget.initialStopsByDay[index] ?? const <ItineraryStop>[]);
      return ItineraryDay(date: date, stops: stops);
    });
    if (_selectedDayIndex >= _days.length) _selectedDayIndex = _days.length - 1;
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      helpText: 'Chọn ngày bắt đầu',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _startDate = _dateOnly(picked);
      if (_endDate.isBefore(_startDate)) _endDate = _startDate;
      _syncDays();
    });
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate.isBefore(_startDate) ? _startDate : _endDate,
      firstDate: _startDate,
      lastDate: DateTime(_startDate.year + 2, 12, 31),
      helpText: 'Chọn ngày kết thúc',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _endDate = _dateOnly(picked);
      _syncDays();
    });
  }

  Future<void> _addStop() async {
    final nameController = TextEditingController();
    final timeController = TextEditingController(text: '09:00');
    final costController = TextEditingController(text: '0');
    String selectedType = 'Tham quan';

    final stop = await showDialog<ItineraryStop>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Thêm điểm đến - Ngày ${_selectedDayIndex + 1}'),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Tên địa điểm / quán ăn'),
                        prefixIcon: Icon(Icons.place_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: timeController,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Giờ dự kiến (VD: 09:00)'),
                        prefixIcon: Icon(Icons.access_time_rounded),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: InputDecoration(labelText: AppTranslations.translate('Loại hoạt động')),
                      items: _stopTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                      onChanged: (value) {
                        if (value != null) setDialogState(() => selectedType = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: AppTranslations.translate('Chi phí dự kiến (VNĐ)'),
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  onPressed: () {
                    final name = nameController.text.trim();
                    if (name.isEmpty) return;
                    final costText = costController.text.replaceAll('.', '').replaceAll(',', '').trim();
                    final cost = int.tryParse(costText) ?? 0;
                    Navigator.pop(
                      dialogContext,
                      ItineraryStop(
                        id: DateTime.now().microsecondsSinceEpoch.toString(),
                        placeName: name,
                        time: timeController.text.trim().isEmpty ? '09:00' : timeController.text.trim(),
                        type: selectedType,
                        estimatedCost: cost < 0 ? 0 : cost,
                      ),
                    );
                  },
                  child: const Text('Thêm điểm'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    timeController.dispose();
    costController.dispose();

    if (stop == null || !mounted) return;
    setState(() => _days[_selectedDayIndex].stops.add(stop));
  }

  void _removeStop(int index) {
    setState(() => _days[_selectedDayIndex].stops.removeAt(index));
  }

  void _reorderStops(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final stops = _days[_selectedDayIndex].stops;
      final stop = stops.removeAt(oldIndex);
      stops.insert(newIndex, stop);
    });
  }

  void _savePlan() {
    final name = _nameController.text.trim();
    final destination = _destinationController.text.trim();
    if (name.isEmpty || destination.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập tên chuyến đi và điểm đến.')),
      );
      return;
    }
    if (_days.every((day) => day.stops.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hãy thêm ít nhất một điểm đến vào lịch trình.')),
      );
      return;
    }

    final plan = ItineraryPlan(
      id: widget.existingPlan?.id,
      name: name,
      destination: destination,
      startDate: _startDate,
      endDate: _endDate,
      days: _days.map((day) => ItineraryDay(date: day.date, stops: List<ItineraryStop>.from(day.stops))).toList(),
    );

    if (widget.existingPlan != null) {
      Navigator.pop(context, plan);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ItineraryDaysScreen(plan: plan)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalCost = _days.fold<int>(
      0,
      (total, day) => total + day.stops.fold<int>(0, (sum, stop) => sum + stop.estimatedCost),
    );
    final selectedDay = _days[_selectedDayIndex];

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.existingPlan == null ? 'Tạo lịch trình' : 'Chỉnh sửa lịch trình',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _sectionTitle('Thông tin chuyến đi', Icons.luggage_outlined),
          const SizedBox(height: 12),
          _fieldCard(
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Tên lịch trình'),
                hintText: AppTranslations.translate('VD: Khám phá Đà Nẵng'),
                prefixIcon: Icon(Icons.edit_note_rounded),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          _fieldCard(
            child: TextField(
              controller: _destinationController,
              decoration: InputDecoration(
                labelText: AppTranslations.translate('Tỉnh / thành phố'),
                hintText: AppTranslations.translate('VD: Đà Nẵng'),
                prefixIcon: Icon(Icons.location_on_outlined),
                suffixIcon: IconButton(
                  tooltip: AppTranslations.translate('Chọn tỉnh / thành phố'),
                  onPressed: _selectDestination,
                  icon: const Icon(Icons.arrow_drop_down_rounded, size: 30),
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _dateButton(label: 'Ngày bắt đầu', date: _startDate, onTap: _pickStartDate)),
              const SizedBox(width: 10),
              Expanded(child: _dateButton(label: 'Ngày kết thúc', date: _endDate, onTap: _pickEndDate)),
            ],
          ),
          const SizedBox(height: 24),
          _sectionTitle('Lịch trình từng ngày', Icons.calendar_month_rounded),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_days.length, (index) {
                final active = index == _selectedDayIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Ngày ${index + 1}'),
                    selected: active,
                    selectedColor: _green,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(color: active ? Colors.white : Colors.black87, fontWeight: FontWeight.w600),
                    side: BorderSide(color: active ? _green : Colors.grey.shade300),
                    onSelected: (_) => setState(() => _selectedDayIndex = index),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE8E1))),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, color: _green),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ngày ${_selectedDayIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(_formatDate(selectedDay.date), style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                    ],
                  ),
                ),
                Text('${selectedDay.stops.length} điểm', style: const TextStyle(color: _green, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          if (selectedDay.stops.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFECE8E1))),
              child: Column(
                children: [
                  Icon(Icons.add_location_alt_outlined, size: 34, color: Colors.grey.shade500),
                  const SizedBox(height: 8),
                  Text('Chưa có điểm đến trong ngày này.', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 4),
                  Text('Thêm địa điểm hoặc quán ăn ở bên dưới.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            )
          else
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              itemCount: selectedDay.stops.length,
              onReorder: _reorderStops,
              itemBuilder: (context, index) {
                final stop = selectedDay.stops[index];
                return Container(
                  key: ValueKey(stop.id),
                  margin: const EdgeInsets.only(bottom: 9),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE8E1))),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(color: _green.withOpacity(0.09), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.place_rounded, color: _green),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(stop.placeName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text('${stop.time}  •  ${stop.type}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                                const SizedBox(height: 4),
                                Text(_formatMoney(stop.estimatedCost), style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: AppTranslations.translate('Xóa điểm đến'),
                            onPressed: () => _removeStop(index),
                            icon: const Icon(Icons.delete_outline_rounded, color: _red),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addStop,
            style: OutlinedButton.styleFrom(
              foregroundColor: _green,
              side: const BorderSide(color: _green),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
            ),
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text('Thêm địa điểm / quán ăn', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF0E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF2D3C8))),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: _red, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng chi phí dự kiến', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_formatMoney(totalCost), style: const TextStyle(color: _red, fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('Theo chi phí từng điểm đến bạn đã nhập.', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: _savePlan,
              style: FilledButton.styleFrom(backgroundColor: _red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: Text(widget.existingPlan == null ? 'Xem lịch trình' : 'Cập nhật lịch trình', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: _green, size: 22),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _fieldCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE8E1))),
      child: child,
    );
  }

  Widget _dateButton({required String label, required DateTime date, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE8E1))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 7),
            Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: _green, size: 17),
                const SizedBox(width: 5),
                Expanded(child: Text(_formatDate(date), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ItineraryDaysScreen extends StatefulWidget {
  final ItineraryPlan plan;

  const ItineraryDaysScreen({super.key, required this.plan});

  @override
  State<ItineraryDaysScreen> createState() => _ItineraryDaysScreenState();
}

class _ItineraryDaysScreenState extends State<ItineraryDaysScreen> with AppLocaleAwareState<ItineraryDaysScreen> {
  late ItineraryPlan _plan;

  @override
  void initState() {
    super.initState();
    _plan = widget.plan;
  }

  Future<void> _saveCurrentPlan() async {
    final token = userSession.token;
    if (!userSession.isSignedIn || token == null || token.isEmpty) {
      final signedIn = await requestAccountAccess(context);
      if (!signedIn || !mounted) return;
    }
    try {
      await favoritesStore.add(FavoriteEntry.forPlan(_plan));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã lưu lịch trình. Mở Đã lưu > Lịch trình để xem lại.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không lưu được lịch trình: $error')),
      );
    }
  }

  Future<void> _editPlan() async {
    final updatedPlan = await Navigator.push<ItineraryPlan>(
      context,
      MaterialPageRoute(builder: (_) => CreateItineraryScreen(existingPlan: _plan)),
    );
    if (updatedPlan != null && mounted) {
      setState(() => _plan = updatedPlan);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Lịch trình theo ngày', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          FavoriteButton(entry: FavoriteEntry.forPlan(_plan)),
          IconButton(
            onPressed: _editPlan,
            tooltip: AppTranslations.translate('Chỉnh sửa lịch trình'),
            icon: const Icon(Icons.edit_outlined, color: _green),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(colors: [_green, Color(0xFF2A8975)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(30)),
                  child: Text('${_plan.totalDays} ngày • ${_plan.destination}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(height: 12),
                Text(_plan.name, style: const TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.bold, height: 1.2)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: Colors.white70, size: 18),
                    const SizedBox(width: 7),
                    Text('${_formatDate(_plan.startDate)} – ${_formatDate(_plan.endDate)}', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _summaryCard(Icons.event_note_rounded, '${_plan.totalDays} ngày', 'Thời lượng', _green)),
              const SizedBox(width: 10),
              Expanded(child: _summaryCard(Icons.place_outlined, '${_plan.days.fold<int>(0, (sum, day) => sum + day.stops.length)} điểm', 'Điểm dừng', _red)),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFF0E9), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFF2D3C8))),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: _red, size: 27),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Tổng chi phí dự kiến', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(_formatMoney(_plan.totalEstimatedCost), style: const TextStyle(color: _red, fontSize: 22, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Kế hoạch từng ngày', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ..._plan.days.asMap().entries.map((entry) {
            final dayIndex = entry.key;
            final day = entry.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFECE8E1))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 48,
                        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(12)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${day.date.day}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                            Text(_shortMonth(day.date.month), style: const TextStyle(color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ngày ${dayIndex + 1}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 3),
                            Text(_formatDate(day.date), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      Text('${_formatMoney(day.stops.fold<int>(0, (sum, stop) => sum + stop.estimatedCost))}', style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (day.stops.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Chưa có hoạt động. Nhấn chỉnh sửa để thêm điểm đến.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    )
                  else
                    ...day.stops.asMap().entries.map((stopEntry) {
                      final stop = stopEntry.value;
                      final isLast = stopEntry.key == day.stops.length - 1;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 54,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(stop.time, style: const TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ),
                          SizedBox(
                            width: 16,
                            child: Column(
                              children: [
                                Container(width: 9, height: 9, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
                                if (!isLast) Container(width: 2, height: 50, color: const Color(0xFFE1DCD3)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 15),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(stop.placeName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(color: _green.withOpacity(0.08), borderRadius: BorderRadius.circular(20)),
                                        child: Text(stop.type, style: const TextStyle(color: _green, fontSize: 10, fontWeight: FontWeight.w600)),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(_formatMoney(stop.estimatedCost), style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                ],
              ),
            );
          }),
          const SizedBox(height: 4),
          AnimatedBuilder(
            animation: favoritesStore,
            builder: (context, _) {
              final isSaved = favoritesStore.contains(
                FavoriteEntry.forPlan(_plan).key,
              );
              return Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _saveCurrentPlan,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_add_outlined,
                        ),
                        label: Text(
                          isSaved ? 'Đã lưu' : 'Lưu lịch trình',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _editPlan,
                        style: FilledButton.styleFrom(
                          backgroundColor: _red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: const Text(
                          'Chỉnh sửa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            'Chi phí là mức dự kiến do bạn nhập, chưa bao gồm những khoản chưa khai báo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFFECE8E1))),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _shortMonth(int month) {
  const months = [
    'T1', 'T2', 'T3', 'T4', 'T5', 'T6',
    'T7', 'T8', 'T9', 'T10', 'T11', 'T12',
  ];
  return months[month - 1];
}

String _formatMoney(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) buffer.write('.');
  }
  return '${buffer.toString()}đ';
}
