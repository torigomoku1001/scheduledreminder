import re

with open('/Volumes/BIWIN/Flutter_Project/scheduledreminder_project/lib/main.dart', 'r') as f:
    content = f.read()

# Replace block 1
old1 = """  static const String _settingsKey = 'settings_v1';
  static const String _dailyStateKey = 'daily_state_v1';
  static const String _overtimeKey = 'overtime_records_v1';

  final _nicknameController = TextEditingController();
  final _companyController = TextEditingController();
  final _workHourController = TextEditingController();
  final _workMinuteController = TextEditingController();
  final _breakHourController = TextEditingController();
  final _breakMinuteController = TextEditingController();

  String _nickname = '';
  String _companyName = '';
  TimeOfDay? _flexStart;
  TimeOfDay? _flexEnd;
  int _workMinutes = 0;
  int _breakMinutes = 0;

  TimeOfDay? _arrivalTime;
  TimeOfDay? _endTime;"""

new1 = """  static const String _settingsKey = 'settings_v2';
  static const String _dailyStateKey = 'daily_state_v2';
  static const String _overtimeKey = 'overtime_records_v1';

  final _nicknameController = TextEditingController();
  final _companyController = TextEditingController();
  final _totalHourController = TextEditingController();
  final _totalMinuteController = TextEditingController();

  String _nickname = '';
  String _companyName = '';
  bool _hasFlex = true;
  TimeOfDay? _flexStart;
  TimeOfDay? _flexEnd;
  TimeOfDay? _fixedStart;
  TimeOfDay? _fixedEnd;
  int _totalMinutes = 0;

  TimeOfDay? _arrivalTime;
  TimeOfDay? _endTime;"""

content = content.replace(old1, new1)

old2 = """  bool get _isConfigured =>
      _nickname.isNotEmpty &&
      _companyName.isNotEmpty &&
      _flexStart != null &&
      _flexEnd != null &&
      _workMinutes > 0;"""

new2 = """  bool get _isConfigured {
    if (_nickname.isEmpty || _companyName.isEmpty) return false;
    if (_hasFlex) {
      return _flexStart != null && _flexEnd != null && _totalMinutes > 0;
    } else {
      return _fixedStart != null && _fixedEnd != null;
    }
  }"""

content = content.replace(old2, new2)

old3 = """  @override
  void dispose() {
    _timer?.cancel();
    _nicknameController.dispose();
    _companyController.dispose();
    _workHourController.dispose();
    _workMinuteController.dispose();
    _breakHourController.dispose();
    _breakMinuteController.dispose();
    super.dispose();
  }"""

new3 = """  @override
  void dispose() {
    _timer?.cancel();
    _nicknameController.dispose();
    _companyController.dispose();
    _totalHourController.dispose();
    _totalMinuteController.dispose();
    super.dispose();
  }"""

content = content.replace(old3, new3)

old4 = """  Future<void> _init() async {
    await _loadSettings();
    await _loadDailyState();
    await _loadOvertimeRecords();
    _updateDate();
    _updateRemaining();
    _updateGifState();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }"""

new4 = """  Future<void> _init() async {
    await _loadSettings();
    if (_isConfigured && !_hasFlex) {
      _arrivalTime = _fixedStart;
      _endTime = _fixedEnd;
      await _scheduleNotifications();
    } else {
      await _loadDailyState();
    }
    await _loadOvertimeRecords();
    _updateDate();
    _updateRemaining();
    _updateGifState();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }"""

content = content.replace(old4, new4)

old5 = """  void _updateGifState() {
    if (_isNightGifWindow()) {
      _gifState = 'after_work';
      return;
    }
    if (_isMorningGifWindow()) {
      _gifState = 'before_work';
      return;
    }
    if (_arrivalTime == null) {
      _gifState = 'before_work';
    } else if (_remaining.inSeconds > 0) {
      _gifState = 'working';
    } else {
      _gifState = 'after_work';
    }
  }"""

new5 = """  void _updateGifState() {
    if (_isNightGifWindow()) {
      _gifState = 'after_work';
      return;
    }
    if (_isMorningGifWindow()) {
      _gifState = 'before_work';
      return;
    }
    if (!_hasFlex && _fixedStart != null) {
      final nowMin = _nowMin();
      final startMin = _toMin(_fixedStart!);
      if (nowMin < startMin) {
        _gifState = 'before_work';
      } else if (_remaining.inSeconds > 0) {
        _gifState = 'working';
      } else {
        _gifState = 'after_work';
      }
      return;
    }

    if (_arrivalTime == null) {
      _gifState = 'before_work';
    } else if (_remaining.inSeconds > 0) {
      _gifState = 'working';
    } else {
      _gifState = 'after_work';
    }
  }"""

content = content.replace(old5, new5)

old6 = """  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _nickname = map['nickname'] as String? ?? '';
    _companyName = map['companyName'] as String? ?? '';
    final fsH = map['flexStartHour'] as int?;
    final fsM = map['flexStartMinute'] as int?;
    final feH = map['flexEndHour'] as int?;
    final feM = map['flexEndMinute'] as int?;
    if (fsH != null && fsM != null) {
      _flexStart = TimeOfDay(hour: fsH, minute: fsM);
    }
    if (feH != null && feM != null) {
      _flexEnd = TimeOfDay(hour: feH, minute: feM);
    }
    _workMinutes = map['workMinutes'] as int? ?? 0;
    _breakMinutes = map['breakMinutes'] as int? ?? 0;
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'nickname': _nickname,
      'companyName': _companyName,
      'flexStartHour': _flexStart?.hour,
      'flexStartMinute': _flexStart?.minute,
      'flexEndHour': _flexEnd?.hour,
      'flexEndMinute': _flexEnd?.minute,
      'workMinutes': _workMinutes,
      'breakMinutes': _breakMinutes,
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
  }"""

new6 = """  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_settingsKey);
    if (raw == null) return;
    final map = jsonDecode(raw) as Map<String, dynamic>;
    _nickname = map['nickname'] as String? ?? '';
    _companyName = map['companyName'] as String? ?? '';
    _hasFlex = map['hasFlex'] as bool? ?? true;

    final fsH = map['flexStartHour'] as int?;
    final fsM = map['flexStartMinute'] as int?;
    final feH = map['flexEndHour'] as int?;
    final feM = map['flexEndMinute'] as int?;
    if (fsH != null && fsM != null) {
      _flexStart = TimeOfDay(hour: fsH, minute: fsM);
    }
    if (feH != null && feM != null) {
      _flexEnd = TimeOfDay(hour: feH, minute: feM);
    }

    final fxsh = map['fixedStartHour'] as int?;
    final fxsm = map['fixedStartMinute'] as int?;
    final fxeh = map['fixedEndHour'] as int?;
    final fxem = map['fixedEndMinute'] as int?;
    if (fxsh != null && fxsm != null) {
      _fixedStart = TimeOfDay(hour: fxsh, minute: fxsm);
    }
    if (fxeh != null && fxem != null) {
      _fixedEnd = TimeOfDay(hour: fxeh, minute: fxem);
    }

    _totalMinutes = map['totalMinutes'] as int? ?? 0;
    if (_totalMinutes > 0) {
      _totalHourController.text = (_totalMinutes ~/ 60).toString();
      _totalMinuteController.text = (_totalMinutes % 60).toString();
    }
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{
      'nickname': _nickname,
      'companyName': _companyName,
      'hasFlex': _hasFlex,
      'flexStartHour': _flexStart?.hour,
      'flexStartMinute': _flexStart?.minute,
      'flexEndHour': _flexEnd?.hour,
      'flexEndMinute': _flexEnd?.minute,
      'fixedStartHour': _fixedStart?.hour,
      'fixedStartMinute': _fixedStart?.minute,
      'fixedEndHour': _fixedEnd?.hour,
      'fixedEndMinute': _fixedEnd?.minute,
      'totalMinutes': _totalMinutes,
    };
    await prefs.setString(_settingsKey, jsonEncode(payload));
  }"""

content = content.replace(old6, new6)

old7 = """  Future<void> _pickFlex({required bool isStart}) async {
    final initial = isStart
        ? (_flexStart ?? const TimeOfDay(hour: 7, minute: 20))
        : (_flexEnd ?? const TimeOfDay(hour: 10, minute: 50));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _flexStart = picked;
      } else {
        _flexEnd = picked;
      }
    });
  }

  Future<void> _saveInitialProfile() async {
    final nickname = _nicknameController.text.trim();
    final company = _companyController.text.trim();
    final wh = int.tryParse(_workHourController.text.trim()) ?? 0;
    final wm = int.tryParse(_workMinuteController.text.trim()) ?? 0;
    final bh = int.tryParse(_breakHourController.text.trim()) ?? 0;
    final bm = int.tryParse(_breakMinuteController.text.trim()) ?? 0;

    if (nickname.isEmpty ||
        company.isEmpty ||
        _flexStart == null ||
        _flexEnd == null) {
      _alert('エラー', '入力項目をすべて埋めてください');
      return;
    }
    if (_toMin(_flexEnd!) <= _toMin(_flexStart!)) {
      _alert('エラー', 'フレックス終了は開始より後にしてください');
      return;
    }
    final work = wh * 60 + wm;
    final rest = bh * 60 + bm;
    if (work <= 0 || rest < 0) {
      _alert('エラー', '勤務時間・休憩時間を正しく入力してください');
      return;
    }

    setState(() {
      _nickname = nickname;
      _companyName = company;
      _workMinutes = work;
      _breakMinutes = rest;
    });
    await _saveSettings();
  }"""

new7 = """  Future<void> _pickFlex({required bool isStart}) async {
    final initial = isStart
        ? (_flexStart ?? const TimeOfDay(hour: 7, minute: 20))
        : (_flexEnd ?? const TimeOfDay(hour: 10, minute: 50));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _flexStart = picked;
      } else {
        _flexEnd = picked;
      }
    });
  }

  Future<void> _pickFixed({required bool isStart}) async {
    final initial = isStart
        ? (_fixedStart ?? const TimeOfDay(hour: 9, minute: 0))
        : (_fixedEnd ?? const TimeOfDay(hour: 18, minute: 0));
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _fixedStart = picked;
      } else {
        _fixedEnd = picked;
      }
    });
  }

  Future<void> _saveInitialProfile() async {
    final nickname = _nicknameController.text.trim();
    final company = _companyController.text.trim();

    if (nickname.isEmpty || company.isEmpty) {
      _alert('エラー', 'ニックネームと会社名を入力してください');
      return;
    }

    if (_hasFlex) {
      final th = int.tryParse(_totalHourController.text.trim()) ?? 0;
      final tm = int.tryParse(_totalMinuteController.text.trim()) ?? 0;

      if (_flexStart == null || _flexEnd == null) {
        _alert('エラー', 'フレックス開始・終了時間を入力してください');
        return;
      }
      if (_toMin(_flexEnd!) <= _toMin(_flexStart!)) {
        _alert('エラー', 'フレックス終了は開始より後にしてください');
        return;
      }
      final total = th * 60 + tm;
      if (total <= 0) {
        _alert('エラー', '勤務時間＋休憩時間を正しく入力してください');
        return;
      }

      setState(() {
        _nickname = nickname;
        _companyName = company;
        _totalMinutes = total;
      });
    } else {
      if (_fixedStart == null || _fixedEnd == null) {
        _alert('エラー', '勤務開始・終了時間を入力してください');
        return;
      }
      if (_toMin(_fixedEnd!) <= _toMin(_fixedStart!)) {
        _alert('エラー', '勤務終了は開始より後にしてください');
        return;
      }

      setState(() {
        _nickname = nickname;
        _companyName = company;
      });
    }

    await _saveSettings();
    if (!_hasFlex) {
      _arrivalTime = _fixedStart;
      _endTime = _fixedEnd;
      _updateRemaining();
      _updateGifState();
      await _scheduleNotifications();
    }
  }"""

content = content.replace(old7, new7)

old8 = """  void _calculateEnd() {
    if (_arrivalTime == null) return;
    final total = _workMinutes + _breakMinutes;
    final end = _toMin(_arrivalTime!) + total;
    _endTime = TimeOfDay(hour: (end ~/ 60) % 24, minute: end % 60);
  }"""

new8 = """  void _calculateEnd() {
    if (!_hasFlex) {
      _endTime = _fixedEnd;
      return;
    }
    if (_arrivalTime == null) return;
    final total = _totalMinutes;
    final end = _toMin(_arrivalTime!) + total;
    _endTime = TimeOfDay(hour: (end ~/ 60) % 24, minute: end % 60);
  }"""

content = content.replace(old8, new8)

old9 = """  Widget _setupScreen(double padding, double bodyFont) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(labelText: 'ニックネーム'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: '会社名'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickFlex(isStart: true),
                  child: Text(_flexStart == null ? 'フレックス開始' : '開始: ${_flexStart!.format(context)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickFlex(isStart: false),
                  child: Text(_flexEnd == null ? 'フレックス終了' : '終了: ${_flexEnd!.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _workHourController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '勤務 時間'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('時間'),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _workMinuteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '勤務 分'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('分'),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _breakHourController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '休憩 時間'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('時間'),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _breakMinuteController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '休憩 分'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('分'),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveInitialProfile,
            child: Text('設定を保存', style: TextStyle(fontSize: bodyFont)),
          ),
        ],
      ),
    );
  }"""

new9 = """  Widget _setupScreen(double padding, double bodyFont) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nicknameController,
            decoration: const InputDecoration(labelText: 'ニックネーム'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _companyController,
            decoration: const InputDecoration(labelText: '会社名'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text('フレックス有無:'),
              const SizedBox(width: 8),
              Radio<bool>(
                value: true,
                groupValue: _hasFlex,
                onChanged: (v) => setState(() => _hasFlex = v!),
              ),
              const Text('あり'),
              Radio<bool>(
                value: false,
                groupValue: _hasFlex,
                onChanged: (v) => setState(() => _hasFlex = v!),
              ),
              const Text('なし'),
            ],
          ),
          const SizedBox(height: 14),
          if (_hasFlex) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickFlex(isStart: true),
                    child: Text(_flexStart == null ? 'フレックス開始' : '開始: ${_flexStart!.format(context)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickFlex(isStart: false),
                    child: Text(_flexEnd == null ? 'フレックス終了' : '終了: ${_flexEnd!.format(context)}'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text('勤務時間＋休憩時間'),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _totalHourController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '時間'),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('時間'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _totalMinuteController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '分'),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('分'),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickFixed(isStart: true),
                    child: Text(_fixedStart == null ? '勤務開始時間' : '開始: ${_fixedStart!.format(context)}'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickFixed(isStart: false),
                    child: Text(_fixedEnd == null ? '勤務終了時間' : '終了: ${_fixedEnd!.format(context)}'),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _saveInitialProfile,
            child: Text('設定を保存', style: TextStyle(fontSize: bodyFont)),
          ),
        ],
      ),
    );
  }"""

content = content.replace(old9, new9)

old10 = """            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.all(basePadding),
                child: Text(
                  '$_currentDate（$_currentWeekday）',
                  style: TextStyle(fontSize: bodyFont, fontWeight: FontWeight.bold),
                ),
              ),
            ),"""

new10 = """            if (_isConfigured)
              Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.all(basePadding),
                  child: Text(
                    '$_currentDate（$_currentWeekday）',
                    style: TextStyle(fontSize: bodyFont, fontWeight: FontWeight.bold),
                  ),
                ),
              ),"""

content = content.replace(old10, new10)

old11 = """                            Text(
                              '出社時間を入力してください',
                              style: TextStyle(fontSize: bodyFont),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton(
                              onPressed: _isInputBlockedNow() ? null : _selectArrival,
                              child: Text(
                                _arrivalTime != null
                                    ? '出社時間: ${_arrivalTime!.format(context)}'
                                    : _isInputBlockedNow()
                                    ? '入力不可時間帯'
                                    : '時間を選択',
                              ),
                            ),
                            const SizedBox(height: 26),"""

new11 = """                            if (_hasFlex && _arrivalTime == null) ...[
                              Text(
                                '出社時間を入力してください',
                                style: TextStyle(fontSize: bodyFont),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton(
                                onPressed: _isInputBlockedNow() ? null : _selectArrival,
                                child: Text(
                                  _isInputBlockedNow()
                                      ? '入力不可時間帯'
                                      : '出社時間を選択',
                                ),
                              ),
                              const SizedBox(height: 26),
                            ],
                            if (_arrivalTime != null) ...[
                              Text(
                                '出社時間: ${_arrivalTime!.format(context)}',
                                style: TextStyle(
                                  fontSize: bodyFont,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 26),
                            ],"""

content = content.replace(old11, new11)


old12 = """            Positioned(
              bottom: isCompact ? 14 : 20,
              right: isCompact ? 14 : 20,
              child: SizedBox(
                width: gifSize,
                height: gifSize,
                child: Image.asset(
                  _gifPath(),"""

new12 = """            if (_isConfigured)
              Positioned(
                bottom: isCompact ? 14 : 20,
                right: isCompact ? 14 : 20,
                child: SizedBox(
                  width: gifSize,
                  height: gifSize,
                  child: Image.asset(
                    _gifPath(),"""

content = content.replace(old12, new12)

with open('/Volumes/BIWIN/Flutter_Project/scheduledreminder_project/lib/main.dart', 'w') as f:
    f.write(content)

print('Updated successfully')
