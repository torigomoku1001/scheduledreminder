import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';
import 'soccer_repository.dart';

class SoccerPage extends StatefulWidget {
  const SoccerPage({super.key});

  @override
  State<SoccerPage> createState() => _SoccerPageState();
}

class _SoccerPageState extends State<SoccerPage> {
  final SoccerRepository _repository = SoccerRepository();
  bool _isLoading = false;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // 新しい要件：最初はグラフを非表示にする
  bool _isGraphVisible = false;

  // フォーム用
  String _selectedPlayer = 'MUHI';
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _assistController = TextEditingController();

  // ユーザーごとの月間データ
  Map<String, List<SoccerData>> _userMonthlyData = {};

  // 固定でMUHI -> YMGTの順に表示する
  final List<String> _fixedUserOrder = ['MUHI', 'YMGT'];

  @override
  void initState() {
    super.initState();
    // グラフは最初非表示のためデータの自動フェッチは行わない
  }

  Future<void> _fetchDataForMonth(int year, int month) async {
    setState(() {
      _isLoading = true;
      _selectedYear = year;
      _selectedMonth = month;
      _isGraphVisible = true;
    });

    try {
      List<SoccerData> data;
      if (month == 6) {
        // テスト用のモックデータ
        data = await _repository.getMockJuneData(year);
      } else {
        // Firestoreから取得
        data = await _repository.fetchMonthlyData(year, month);
      }

      // ユーザーごとにデータをグループ化
      Map<String, List<SoccerData>> groupedData = {};
      for (var d in data) {
        if (!groupedData.containsKey(d.name)) {
          groupedData[d.name] = [];
        }
        groupedData[d.name]!.add(d);
      }

      setState(() {
        _userMonthlyData = groupedData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _userMonthlyData = {};
        _isLoading = false;
      });
      debugPrint('データ取得エラー: $e');
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _submitData() async {
    final goalText = _goalController.text.trim();
    final assistText = _assistController.text.trim();

    if (goalText.isEmpty || assistText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ゴール数とアシスト数を入力してください')));
      return;
    }

    final int? goals = int.tryParse(goalText);
    final int? assists = int.tryParse(assistText);

    if (goals == null || assists == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('正しい数字を入力してください')));
      return;
    }

    try {
      await _repository.saveSoccerData(
        name: _selectedPlayer,
        date: DateTime.now(),
        goals: goals,
        assists: assists,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('データを保存しました！')));
      _goalController.clear();
      _assistController.clear();

      // もし現在グラフが表示されていて、今月のデータを見ているならリロードする
      if (_isGraphVisible &&
          _selectedMonth == DateTime.now().month &&
          _selectedYear == DateTime.now().year) {
        _fetchDataForMonth(_selectedYear, _selectedMonth);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
    }
  }

  void _showGraphMonthSelector() async {
    // データを取得中であることを示すためインジケータを出す
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final months = await _repository.fetchAvailableMonths();

    if (!mounted) return;
    Navigator.of(context).pop(); // ローディングを閉じる

    if (months.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('お知らせ'),
            content: const Text('データがありません。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('確認'),
              ),
            ],
          );
        },
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('グラフを表示する年月を選択'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: months.length,
              itemBuilder: (context, index) {
                final monthStr = months[index];
                return ListTile(
                  title: Text(monthStr),
                  onTap: () {
                    final parts = monthStr
                        .replaceAll('年', '-')
                        .replaceAll('月', '')
                        .split('-');
                    final year = int.parse(parts[0]);
                    final month = int.parse(parts[1]);
                    Navigator.of(context).pop();
                    _fetchDataForMonth(year, month);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTopLink() {
    return GestureDetector(
      onTap: () => _launchUrl('https://suisal.wweb.jp/#contents'),
      child: Image.asset(
        'assets/image/Site.png',
        height: 60,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Container(
          width: 200,
          height: 60,
          color: Colors.grey[300],
          alignment: Alignment.center,
          child: const Text(
            'Site.png\n(未配置)',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildDateText() {
    final now = DateTime.now();
    final weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    final dateStr =
        '${now.year}年${now.month.toString().padLeft(2, '0')}月${now.day.toString().padLeft(2, '0')}日（${weekdays[now.weekday - 1]}）';

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 24.0, top: 16.0),
        child: Text(
          dateStr,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildInputForm() {
    final bool isWednesday = DateTime.now().weekday == DateTime.wednesday;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'プレイヤー: ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _selectedPlayer,
                items: ['MUHI', 'YMGT'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedPlayer = newValue;
                    });
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _goalController,
                  enabled: isWednesday,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ゴール数',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _assistController,
                  enabled: isWednesday,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'アシスト数',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: isWednesday ? _submitData : null,
            child: Text(isWednesday ? 'データ更新' : '水曜日のみ更新可能'),
          ),
          const SizedBox(height: 48), // 下の方に移動
          const Text(
            '【ルール】\n'
            '・10人以上のメンバーがいる場合のみ計測\n'
            '・片方が参加してない→計測×\n'
            '  ※2週連続不参加→参加者の計測◯\n'
            '  ※大怪我による長期離脱は要相談\n'
            '  ※測るのめんどい日もくるけどしょうがない\n',

            style: TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.5,
            ), // 字を大きく、黒っぽく
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildChart(String userName) {
    final userData = _userMonthlyData[userName] ?? [];

    // 日付順にソート
    userData.sort((a, b) => a.date.compareTo(b.date));

    // 合計と平均を計算
    int totalGoals = 0;
    int totalAssists = 0;
    for (var d in userData) {
      totalGoals += d.goals;
      totalAssists += d.assists;
    }
    int totalPoints = totalGoals + totalAssists;
    double averagePoints = userData.isEmpty ? 0 : totalPoints / userData.length;

    List<BarChartGroupData> barGroups = [];
    double maxTotal = 0;

    for (int i = 0; i < userData.length; i++) {
      final d = userData[i];
      final total = (d.goals + d.assists).toDouble();
      if (total > maxTotal) maxTotal = total;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: total,
              rodStackItems: [
                BarChartRodStackItem(0, d.goals.toDouble(), Colors.redAccent),
                BarChartRodStackItem(
                  d.goals.toDouble(),
                  total,
                  Colors.blueAccent,
                ),
              ],
              width: 20,
              borderRadius: BorderRadius.zero,
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Text(
          '$userName の成績 ($_selectedMonth月)',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text('合計: $totalPoints (ゴール: $totalGoals, アシスト: $totalAssists)'),
        const SizedBox(height: 4),
        Text('1日平均: ${averagePoints.toStringAsFixed(1)}'),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 12, height: 12, color: Colors.redAccent),
            const SizedBox(width: 4),
            const Text('ゴール'),
            const SizedBox(width: 16),
            Container(width: 12, height: 12, color: Colors.blueAccent),
            const SizedBox(width: 4),
            const Text('アシスト'),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: userData.isEmpty
              ? const Center(child: Text('データがありません'))
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      maxY: maxTotal > 0 ? maxTotal + 2 : 10,
                      barTouchData: BarTouchData(enabled: false),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < 0 ||
                                  value.toInt() >= userData.length) {
                                return const Text('');
                              }
                              final date = userData[value.toInt()].date;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  '${date.day}日',
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value % 1 != 0) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(
                                  value.toInt().toString(),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: barGroups,
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortSide = size.width < size.height ? size.width : size.height;
    final bool isCompact = shortSide < 360 || size.height < 700;
    final bool isWide = shortSide >= 430;
    final double gifSize = isCompact ? 96 : (isWide ? 132 : 120);

    final double titleFontSize = isCompact ? 18 : 20;

    final bool isWednesday = DateTime.now().weekday == DateTime.wednesday;
    final String gifPath = isWednesday
        ? 'assets/gifs/shoot.gif'
        : 'assets/gifs/football-juggling.gif';

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false, // キーボード表示時に画面が上にずれないようにする
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 62, 85, 136),
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 78,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'きたっくま',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  ' -会社生活を、ちょっと便利に',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const Text(
              'ーフットサルページー',
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // 空白をタップしたときにキーボードを閉じる
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: Stack(
            children: [
              // メインコンテンツ
              if (!_isGraphVisible)
                Column(
                  children: [
                    const SizedBox(height: 24),
                    // 水曜フットサル リンク (Site.png)
                    _buildTopLink(),

                    // 左側に日付表示
                    _buildDateText(),

                    // 入力フォーム
                    Expanded(
                      child: SingleChildScrollView(child: _buildInputForm()),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    // グラフ表示時の戻るボタン
                    Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16.0,
                          top: 16.0,
                          bottom: 8.0,
                        ),
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _isGraphVisible = false;
                            });
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Color.fromARGB(255, 62, 85, 136),
                          ),
                          label: const Text(
                            '入力画面へ戻る',
                            style: TextStyle(
                              color: Color.fromARGB(255, 62, 85, 136),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : PageView.builder(
                              itemCount: _fixedUserOrder.length,
                              itemBuilder: (context, index) {
                                return _buildChart(_fixedUserOrder[index]);
                              },
                            ),
                    ),
                    const SizedBox(
                      height: 140,
                    ), // 下部のGIFとグラフが絶対に被らないように大きめの余白を確保
                  ],
                ),

              // 左端中央の戻るボタン（入力フォームの時だけ表示）
              if (!_isGraphVisible)
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 30,
                      height: 60,
                      decoration: const BoxDecoration(
                        color: Color.fromARGB(255, 62, 85, 136),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(2, 0),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Transform.rotate(
                          angle: 3.14159, // 180度回転
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 右上のグラフボタン（入力フォームの時だけ表示）
              if (!_isGraphVisible)
                Positioned(
                  top: 25,
                  right: 15,
                  child: GestureDetector(
                    onTap: _showGraphMonthSelector,
                    child: Column(
                      children: [
                        Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color.fromARGB(255, 221, 221, 221),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 4,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Icon(
                              Icons.bar_chart, // グラフアイコン
                              color: Colors.blue[600], // 青っぽい水色（濃いめ）
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'グラフ',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 右下のGIF
              Positioned(
                bottom: isCompact ? 14 : 20,
                right: isCompact ? 14 : 20,
                child: SizedBox(
                  width: gifSize,
                  height: gifSize,
                  child: Image.asset(
                    gifPath,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return ColoredBox(
                        color: Colors.white,
                        child: Center(
                          child: Text(
                            'GIF未設定\n${isWednesday ? "shoot.gif" : "football-juggling.gif"}',
                            style: const TextStyle(fontSize: 10),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
