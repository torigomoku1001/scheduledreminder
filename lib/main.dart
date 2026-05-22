//TestFlightでの配布を行う(社員限定)
//Studioのほうに登録

//クラス作成とインスタンス化のメリット
//class Todo{
//  String title;
//}
//todo = Todo();
//todo.title = '買い物'
//可読性が上がり、補完機能も絞った予測変換を出してくれ、名前が重複するリスクがなくなる

//this.~~の使い方
//class Meisi {
//  String name = takahasi; 初期値は takahasi
//  void human(String name) {
//    外から来た「name（mitui）」を、自分の「this.name」に上書きする
//    this.name = name;
//  }
//}
//main(){
//  var user = Meisi();
//  print(user,name); →　takahasi
//  user.human('mitui');
//  print(user.name); →　mitui
//}

//Dartでは列挙の区切りを,(コンマ)で行い、命令文の終わりを;(セミコロン)で行う

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin(); //通知機能を使うためにその機能が入ってるライブラリからとりまインスタンス化しとくmain()の上でグローバルとしてどこからでも使えるように

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  tz.initializeTimeZones();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings();

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await flutterLocalNotificationsPlugin.initialize(
    //通信についてだからawaitで完了を待たせる
    initializationSettings,
  );

  runApp(const MyApp()); //これが起動の合図
}

class MyApp extends StatelessWidget {
  const MyApp({super.key}); //名札を親に引き継ぐ

  @override //上書き
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      //Googleが推奨するデザイン体系でスマホっぽい機能も多々
      title: 'きたっくま',
      theme: ThemeData(
        //設定した色に合うようにFlutter側が統一感を出してくれる
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const MyHomePage(), //初期ページの設定
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState(); //MyHomePage この画面作られたら実際にデータを管理するクラスを呼び出す
}

class _MyHomePageState extends State<MyHomePage> {
  static const String _arrivalHourKey = 'arrival_hour'; //staticは常に一つだけの変数
  static const String _arrivalMinuteKey = 'arrival_minute';
  static const String _endHourKey = 'end_hour';
  static const String _endMinuteKey = 'end_minute';
  static const String _savedDateKey = 'saved_date';

  TimeOfDay? _arrivalTime;
  TimeOfDay? _endTime;
  Timer? _timer;
  Duration _remainingTime = Duration.zero;
  String _remainingComment = '';
  String _currentDate = '';
  String _currentWeekday = '';
  String _currentVideoState = 'before_work'; // before_work, working, after_work
  bool _wasInputBlocked = false;

  // 株価関連の変数
  String _stockPrice = '---';
  String _stockTrend = '▲';
  bool _isLoadingStock = true; //株価取得中かどうか

  @override
  void initState() {
    //画面に表示される準備が整った直後に自動的に呼ばれる
    super.initState();
    _initializeState();
    _startTimer();
    _updateDateTime();
    _updateVideoState();
    _fetchStockPrice();
  }

  @override
  void dispose() {
    //この画面が消える直前に一度だけ呼ばれる
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeState() async {
    //Future = async 将来的に終わる処理に関してはFutureを含める
    await _restoreSavedState();
    await _enforceTimeWindowRules();
    _updateRemainingTime();
    if (!mounted) return; //アプリ画面がまだついているかどうかの確認
    setState(() {
      _updateVideoState();
    });
  }

  int _nowMinutes() {
    //分計算を主軸に変更する関数
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }

  bool _isNightGifWindow() {
    final nowMinutes = _nowMinutes();
    return nowMinutes >= (19 * 60 + 30) || nowMinutes < (5 * 60);
  }

  Future<void> _fetchStockPrice() async {
    setState(() {
      _isLoadingStock = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
          'https://finance.yahoo.co.jp/quote/6952.T',
        ), //URLはUri型に変換する必要がある
      );
      if (response.statusCode == 200) {
        //200はサーバーからのレスポンスに成功したっていう意味
        final document = html_parser.parse(
          response.body,
        ); //取得したHTMLテキストをDartで使える構造に変換

        // 1. 現在値の取得
        // Yahoo Finance JPの構造では、現在値は _StyledNumber__value クラスの最初のほうにある
        final numbers = document.querySelectorAll(
          'span[class*="_StyledNumber__value"]', //株価表示部分の要素をまとめて取得
        );

        String? currentPrice;
        // 最初の StyledNumber__value が現在値であることが多い　→　検証済み
        if (numbers.isNotEmpty) {
          currentPrice = numbers[0].text;
        }

        // 2. 前日終値の取得 (比較用)
        String? prevClose;
        final listItems = document.querySelectorAll(
          'li',
        ); //前日終値の表記がliタグの中にあることが多い　→　検証済み
        for (var item in listItems) {
          if (item.text.contains('前日終値')) {
            final val = item.querySelector(
              'span[class*="_StyledNumber__value"]', //前日終値の取得
            );
            if (val != null) {
              prevClose = val.text;
            }
            break;
          }
        }

        if (currentPrice != null && prevClose != null) {
          final current =
              double.tryParse(currentPrice.replaceAll(',', '')) ?? 0.0;
          final prev = double.tryParse(prevClose.replaceAll(',', '')) ?? 0.0;

          setState(() {
            _stockPrice = currentPrice!; //nullじゃないことを示す。
            _stockTrend = current >= prev ? '▲' : '▼';
            _isLoadingStock = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching stock price: $e');
    }

    setState(() {
      _isLoadingStock = false;
    });
  }

  bool _isMorningGifWindow() {
    //一旦フレックスの最短時間までtrueとする
    final nowMinutes = _nowMinutes();
    return nowMinutes >= (5 * 60) && nowMinutes < (7 * 60 + 20);
  }

  bool _isInputBlockedNow() {
    final nowMinutes = _nowMinutes();
    return nowMinutes >= (19 * 60 + 35) || nowMinutes < (7 * 60 + 20);
  }

  Future<void> _enforceTimeWindowRules() async {
    //禁止になった瞬間や解除の瞬間に処理を行うために_wasInputBlockedを比較対象に入れている
    final blocked = _isInputBlockedNow();
    if (blocked &&
        (!_wasInputBlocked || _arrivalTime != null || _endTime != null)) {
      await _resetWorkState();
    } else if (!blocked && _wasInputBlocked && mounted) {
      setState(() {
        _updateVideoState();
      });
    }
    _wasInputBlocked = blocked;
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance(); //出社もしくは退勤してなかったらリセット
    if (_arrivalTime == null || _endTime == null) {
      await _clearSavedState();
      return;
    }

    await prefs.setInt(
      _arrivalHourKey,
      _arrivalTime!.hour,
    ); //出社時間と帰宅時間をprefsを利用してカギと値の形式で保存
    await prefs.setInt(_arrivalMinuteKey, _arrivalTime!.minute);
    await prefs.setInt(_endHourKey, _endTime!.hour);
    await prefs.setInt(_endMinuteKey, _endTime!.minute);
    await prefs.setString(_savedDateKey, _todayKey());
  }

  Future<void> _restoreSavedState() async {
    final prefs = await SharedPreferences.getInstance(); //読み書きのアクセスをできる状態にする
    final savedDate = prefs.getString(_savedDateKey);
    if (savedDate != _todayKey()) {
      await _clearSavedState();
      return;
    }

    final arrivalHour = prefs.getInt(_arrivalHourKey);
    final arrivalMinute = prefs.getInt(_arrivalMinuteKey);
    final endHour = prefs.getInt(_endHourKey);
    final endMinute = prefs.getInt(_endMinuteKey);
    if (arrivalHour == null ||
        arrivalMinute == null ||
        endHour == null ||
        endMinute == null) {
      return;
    }

    _arrivalTime = TimeOfDay(hour: arrivalHour, minute: arrivalMinute);
    _endTime = TimeOfDay(hour: endHour, minute: endMinute);

    final now = DateTime.now();
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime!.hour,
      _endTime!.minute,
    );
    if (endDateTime.isAfter(now)) {
      //nowよりも定時が後なら通知を再度セットしなおす（念のため）
      await _scheduleNotifications();
    }
  }

  Future<void> _clearSavedState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_arrivalHourKey);
    await prefs.remove(_arrivalMinuteKey);
    await prefs.remove(_endHourKey);
    await prefs.remove(_endMinuteKey);
    await prefs.remove(_savedDateKey);
  }

  Future<void> _resetWorkState() async {
    //mounted（Stateクラスに入ってるプロパティ）画面の表示が確認できたら画面の状態と変数をリセット、画面消えてたら変数リセットのみ
    if (mounted) {
      setState(() {
        _arrivalTime = null;
        _endTime = null;
        _remainingTime = Duration.zero;
        _remainingComment = '';
        _updateVideoState();
      });
    } else {
      _arrivalTime = null;
      _endTime = null;
      _remainingTime = Duration.zero;
      _remainingComment = '';
      _updateVideoState();
    }
    await _clearSavedState(); //状態リセット
    await flutterLocalNotificationsPlugin.cancelAll(); //通知リセット
  }

  void _updateVideoState() {
    // ここで今の合計分を取得する
    final nowMin = _nowMinutes();

    if (_isNightGifWindow()) {
      _setVideoState('after_work');
    } else if (_isMorningGifWindow()) {
      _setVideoState('before_work');
    } else if (_arrivalTime == null ||
        (_arrivalTime!.hour * 60 + _arrivalTime!.minute) > nowMin) {
      //！は絶対にnullじゃないよって意味
      _setVideoState('before_work');
    } else if (_endTime != null && _remainingTime.inSeconds > 0) {
      _setVideoState('working');
    } else {
      _setVideoState('after_work');
    }
  }

  void _setVideoState(String state) {
    if (_currentVideoState == state) return;

    _currentVideoState = state;
  }

  String _getCurrentGifPath() {
    switch (_currentVideoState) {
      case 'before_work':
        return 'assets/gifs/bowing-beer.gif';
      case 'working':
        return 'assets/gifs/hard-work.gif';
      case 'after_work':
        return 'assets/gifs/good-bear.gif';
      default:
        return 'assets/gifs/bowing-beer.gif';
    }
  }

  void _updateDateTime() {
    final now = DateTime.now();
    _currentDate = DateFormat('yyyy年MM月dd日').format(now);
    _currentWeekday = _getWeekdayName(now.weekday);
  }

  void _startTimer() {
    //定時計算機能の心臓部
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _updateDateTime();
      });
      unawaited(_enforceTimeWindowRules());
      if (_isInputBlockedNow()) {
        setState(() {
          _remainingTime = Duration.zero;
          _remainingComment = '';
          _updateVideoState();
        });
      } else {
        _updateRemainingTime();
      }
    });
  }

  String _getWeekdayName(int weekday) {
    const weekdays = ['月', '火', '水', '木', '金', '土', '日'];
    return weekdays[weekday - 1]; //DateTimeのweekdayには１～７で月～金が格納されてる
  }

  void _updateRemainingTime() {
    if (_endTime != null) {
      final now = DateTime.now();
      final endDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        _endTime!.hour,
        _endTime!.minute,
      );
      if (endDateTime.isAfter(now)) {
        setState(() {
          _remainingTime = endDateTime.difference(now);
          _updateRemainingComment();
          _updateVideoState();
        });
      } else {
        setState(() {
          _remainingTime = Duration.zero;
          _remainingComment = '定時になりました！\n社用スマホで退勤の連絡して帰ってね';
          _updateVideoState();
        });
      }
    }
  }

  void _updateRemainingComment() {
    final minutes = _remainingTime.inMinutes;
    if (minutes > 300) {
      _remainingComment = '始まったな戦いが\n社用スマホで出勤の連絡忘れずに！';
    } else if (minutes > 180) {
      _remainingComment = 'まだまだこっから';
    } else if (minutes > 120) {
      _remainingComment = 'ここら辺から頑張れるやつが出世するぞ';
    } else if (minutes > 60) {
      _remainingComment = 'ゴールは近いぞ！';
    } else {
      _remainingComment = 'もうほぼ定時や';
    }
  }

  void _selectArrivalTime() async {
    if (_isInputBlockedNow()) {
      //入力不可時間帯かの判定
      showDialog(
        //出社時間のボタンが押せないタイミングでのコードなので基本的に出てくることはない（念のための関数）
        context: context, //どこに表示するか
        builder: (BuildContext context) {
          //ダイアログの中身の定義
          return AlertDialog(
            //タイトル、本文、ボタンがセットになったウィジェットの呼び出し
            title: const Text('入力不可'),
            content: const Text('この時間帯は出社時間を入力できません'),
            actions: [
              //ボタンのリスト
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
      return;
    }

    // 時間入力ダイアログを表示
    final TimeOfDay? picked = await showDialog<TimeOfDay>(
      context: context,
      builder: (BuildContext context) {
        TextEditingController hourController = TextEditingController();
        TextEditingController minuteController = TextEditingController();

        return AlertDialog(
          title: const Text('出社時間を入力'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: hourController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '時'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: minuteController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: '分'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                final hourText = hourController.text
                    .trim(); //時間の取り出しとtrimで前後にある空白を自動で削除する。
                final minuteText = minuteController.text.trim();

                if (hourText.isEmpty || minuteText.isEmpty) {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('エラー'),
                        content: const Text('間違ってんで'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                  return;
                }

                final hour =
                    int.tryParse(hourText) ??
                    -1; //【重要】文字としてとったものを整数に変換、整数じゃなかったらnullを返すそしてnullなら代わりに-1を返すようにする
                final minute = int.tryParse(minuteText) ?? -1;

                if (hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59) {
                  final inputMinutes = hour * 60 + minute;
                  final minAllowed = 7 * 60 + 20;
                  final maxAllowed = 10 * 60 + 50;

                  if (inputMinutes < minAllowed || inputMinutes > maxAllowed) {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('エラー'),
                          content: const Text('うそこけ'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('OK'),
                            ),
                          ],
                        );
                      },
                    );
                    return;
                  }

                  Navigator.of(
                    context,
                  ).pop(TimeOfDay(hour: hour, minute: minute));
                } else {
                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('エラー'),
                        content: const Text('そんな時間ないで'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('OK'),
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (picked != null) {
      //ユーザーが選んだ時間をアプリの各所に反映
      setState(() {
        _arrivalTime = picked;
        _calculateEndTime();
      });
      _updateVideoState();
      await _saveState();
    }
  }

  void _calculateEndTime() {
    if (_arrivalTime != null) {
      // 勤務時間: 実働7時間45分 + 休憩55分 = 8時間40分
      final int totalMinutes = 8 * 60 + 40;
      final int arrivalMinutes = _arrivalTime!.hour * 60 + _arrivalTime!.minute;
      final int endMinutes = arrivalMinutes + totalMinutes;
      final int endHour = (endMinutes ~/ 60) % 24;
      final int endMinute = endMinutes % 60;
      _endTime = TimeOfDay(hour: endHour, minute: endMinute);
      _showArrivalComment();
      unawaited(_scheduleNotifications()); //unawaited 通知予約中も他の作業を行っていいよ
    }
  }

  Future<void> _scheduleNotifications() async {
    if (_endTime == null) return;
    await flutterLocalNotificationsPlugin.cancelAll();

    final now = DateTime.now();

    final lunchTime = DateTime(now.year, now.month, now.day, 11, 0);

    // 今が11時より前なら今日のお昼を予約
    if (lunchTime.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        //flutterLocalNotificationsPlugin 通知を送るためのプラグイン　zonedSchedule　予約実行
        0, //通知の管理ID
        '食堂の注文ができるよ！', //通知の中身
        'この通知をタップしてきたっくまから食堂ページに移動しよう\nリモートワークの人は関係ないけどね',
        tz.TZDateTime.from(
          lunchTime,
          tz.local,
        ), //tz.localで時差を考慮しながら、11時に予約する時間を設定
        const NotificationDetails(
          //AndroidやiOSの別々の鳴らし方の設定
          android: AndroidNotificationDetails(
            'lunch_id',
            'Lunch Remainder',
            importance: Importance.high, //画面上部にくる通知になる
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode:
            AndroidScheduleMode.exactAllowWhileIdle, //Androidの電池節約モードでも無理に鳴らす
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // matchDateTimeComponents は書かない（出社した今日だけ鳴らしたいから）
      );
    }
    // --- ランチ通知ここまで ---

    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime!.hour,
      _endTime!.minute,
    );

    // 実際の通知: 2時間前
    final twoHoursBefore = endDateTime.subtract(const Duration(hours: 2));
    if (twoHoursBefore.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        1,
        '定時リマインド',
        '定時まであと2時間です、ここら辺から頑張れるやつが出世するぞ',
        tz.TZDateTime.from(twoHoursBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'channel_description',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 1時間前
    final oneHourBefore = endDateTime.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        2,
        '定時リマインド',
        '定時まであと1時間です、ゴールは近いぞ!',
        tz.TZDateTime.from(oneHourBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'channel_description',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 10分前
    final tenMinBefore = endDateTime.subtract(const Duration(minutes: 10));
    if (tenMinBefore.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        3,
        '定時リマインド',
        '定時まであと10分です、もうほぼ定時だ！',
        tz.TZDateTime.from(tenMinBefore, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'channel_description',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }

    // 定時
    if (endDateTime.isAfter(now)) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        4,
        '定時リマインド',
        '定時になりました！\n社用スマホで退勤の連絡して帰ってね',
        tz.TZDateTime.from(endDateTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'channel_id',
            'channel_name',
            channelDescription: 'channel_description',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  void _showArrivalComment() {
    String comment;
    final int arrivalMinutes = _arrivalTime!.hour * 60 + _arrivalTime!.minute;
    if (arrivalMinutes < 8 * 60) {
      comment = '早起きお疲れ様です\n社用スマホで出勤の連絡忘れずに！';
    } else if (arrivalMinutes < 8 * 60 + 50) {
      comment = '王道の時間帯やね\n社用スマホで出勤の連絡忘れずに！';
    } else if (arrivalMinutes < 9 * 60 + 50) {
      comment = 'いい具合のフレックスの時間帯かな？\n社用スマホで出勤の連絡忘れずに！';
    } else {
      comment = '定時でも帰る時間遅くなるよ？\n社用スマホで出勤の連絡忘れずに！';
    }
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('出社コメント'),
          content: Text(comment),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  //昼食時間判定関数
  bool _isLunchTime() {
    final nowMin = _nowMinutes();
    return nowMin >= (11 * 60) && nowMin <= (13 * 60);
  }

  //URL飛ばすランチボタンの関数
  Future<void> _launchLunchTime() async {
    final Uri url = Uri.parse('https://casio-hamura-web.goeat.jp');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  //昼食ラベル判定関数
  String _getLunchLabel() {
    if (_isLunchTime()) {
      return 'モバイルオーダーGO！';
    } else {
      return 'モバイルオーダー時間外';
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final shortSide = size.width < size.height ? size.width : size.height;
    final bool isCompact = shortSide < 360 || size.height < 700; //iPhoneSEなど
    final bool isWide = shortSide >= 430; //iPhoneProMaxなど

    final double contentMaxWidth = isWide ? 500 : 420; //レスポンシブ対応
    final double basePadding = isCompact ? 12 : 16;
    final double titleFontSize = isCompact ? 18 : 20;
    final double bodyFontSize = isCompact ? 16 : 18;
    final double endTimeFontSize = isCompact ? 22 : 24;
    final double commentFontSize = isCompact ? 15 : 16;
    final double gifSize = isCompact ? 96 : (isWide ? 132 : 120);

    return Scaffold(
      //土台
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 62, 85, 136),
        foregroundColor: Colors.white, //ウィジェットの上の文字やアイコンは白にする
        centerTitle: true, //文字の中央寄せ
        toolbarHeight: 78, //AppBarの高さの設定
        title: Column(
          mainAxisSize: MainAxisSize.min, //中身を必要な分だけ、最小限の高さにする
          crossAxisAlignment: CrossAxisAlignment.center, //中央寄せ
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center, //中央寄せ
              crossAxisAlignment:
                  CrossAxisAlignment.center, //サイズが違ってもきれいに高さがそろう
              children: [
                Text(
                  'きたっくま',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
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
              'ーCASIO版ー',
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        //スマホ特有の邪魔な部分を避けてくれる
        //ColumではなくStack（重なりOK）にbodyを登録しtことで、「コードの上から下に書く ＝ 画面の上から下に並ぶ」という縛りから自由になってバラバラに指定できる自由なレイアウトになってる
        child: Stack(
          //自由配置エリア
          children: [
            Align(
              alignment: Alignment.topLeft, //左詰め
              child: Padding(
                padding: EdgeInsets.all(basePadding),
                child: Text(
                  '$_currentDate（$_currentWeekday）',
                  style: TextStyle(
                    fontSize: bodyFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // --- 株価表示エリア ---
            Positioned(
              //ミリ単位での場所決め
              top: 120, // 日付表示の下に空間を開けて配置
              left: basePadding,
              child: GestureDetector(
                onTap: () async {
                  // データの元となっているサイト（Yahooファイナンスなど）へ飛ばす
                  final Uri url = Uri.parse(
                    "https://finance.yahoo.co.jp/quote/6952.T",
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // チャートのイメージ画像
                    Container(
                      //箱作ってボタンっぽく編集
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: ClipRRect(
                        //角を丸く切り抜く
                        borderRadius: BorderRadius.circular(4),
                        child: Image.asset(
                          'assets/image/chart_icon.png', // チャート風のアイコン画像
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.show_chart, color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // 株価情報
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const Text(
                              'CASIO株価 ',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            if (_isLoadingStock)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.blue,
                                ),
                              )
                            else
                              Text(
                                _stockPrice,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.black,
                                ),
                              ),
                            const Text(
                              ' JPY',
                              style: TextStyle(
                                fontSize: 10, // JPYは小さく
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(width: 6),
                            // 上がったら緑▲、下がったら赤▼
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Text(
                                  _stockTrend,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: _stockTrend == '▲'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                Positioned(
                                  top: 5,
                                  left: 0,
                                  child: Image.asset(
                                    'assets/gifs/pointing-bear.gif',
                                    width: 70,
                                    height: 70,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            Align(
              // 0.0 が中央、1.0 が一番下。少し下にずらすために 0.3 に設定
              alignment: const Alignment(0, 0.2),
              child: SingleChildScrollView(
                padding: EdgeInsets.all(basePadding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '出社時間を入力してください',
                        style: TextStyle(fontSize: bodyFontSize),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isCompact ? 14 : 20),
                      ElevatedButton(
                        onPressed: _isInputBlockedNow()
                            ? null
                            : _selectArrivalTime,
                        child: Text(
                          _arrivalTime != null
                              ? '出社時間: ${_arrivalTime!.format(context)}'
                              : _isInputBlockedNow()
                              ? '入力不可時間帯'
                              : '時間を選択',
                        ),
                      ),
                      SizedBox(height: isCompact ? 26 : 40),
                      if (_endTime != null)
                        Column(
                          children: [
                            Text(
                              '定時時間: ${_endTime!.format(context)}',
                              style: TextStyle(
                                fontSize: endTimeFontSize,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isCompact ? 14 : 20),
                            Text(
                              '残り時間: ${_remainingTime.inHours}時間 ${_remainingTime.inMinutes.remainder(60)}分 ${_remainingTime.inSeconds.remainder(60)}秒',
                              style: TextStyle(fontSize: bodyFontSize),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: isCompact ? 8 : 10),
                            Text(
                              _remainingComment,
                              style: TextStyle(
                                fontSize: commentFontSize,
                                color: Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),

            //右上のNewsボタン
            Positioned(
              top: 25, // 画面の一番上からの距離
              right: 15, // 画面の右端からの距離
              child: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(
                    "https://www.google.com/search?sca_esv=3879cc3584fdf07d&sxsrf=ANbL-n4Riv_16Xmf8YHnUWlsDSrv2g_oTw:1778632955080&q=%E3%82%AB%E3%82%B7%E3%82%AA+%E3%83%8B%E3%83%A5%E3%83%BC%E3%82%B9&tbm=nws&source=lnms&fbs=ADc_l-ZlCIK_ae5oKZcV5pK93vZHUyOZfINb1ICDQ-FkE6soPWKZKfFsHZP8vXX86nJmEuoGsK_pgz76642er_ieh-h6JE3fPW2Js5FIkhYTArrNwYN74E4M5osBy4AYHNo0wZMbRarHLd7-p7QKzF0QFpUKBxGJ4jwsaHcau_dJKZi5tFfpGLSODToA3_QBXm2xZEj3PWTquSi3AW0elHDahiFcrHVUqdi36vSPvuCuUr7WgzQntCE&sa=X&ved=2ahUKEwiotuSLhLWUAxUZe_UHHXqYHKAQ0pQJegQIFRAB&biw=1280&bih=585&dpr=1.5",
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Column(
                  children: [
                    Container(
                      width: 45, // ボタンのサイズ
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white, // 背景を白にして画像を目立たせる
                        shape: BoxShape.circle, // 丸型ボタン
                        border: Border.all(
                          color: const Color.fromARGB(255, 221, 221, 221),
                        ), // 枠線を追加
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/image/news_icon.png', // ここにニュース用画像
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.newspaper,
                                color: Color(0xFF0033A0),
                                size: 30,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'ニュース',
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

            //帰宅電車ボタン
            Positioned(
              top: 25, // 画面の一番上からの距離
              right: 80, // 画面の右端からの距離
              child: GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse(
                    "https://ekitan.com/timetable/railway/line-station/169-9/d1?dt=20260514",
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                child: Column(
                  children: [
                    Container(
                      width: 45, // ボタンのサイズ
                      height: 45,
                      decoration: BoxDecoration(
                        color: Colors.white, // 背景を白にして画像を目立たせる
                        shape: BoxShape.circle, // 丸型ボタン
                        border: Border.all(
                          color: const Color.fromARGB(255, 221, 221, 221),
                        ), // 枠線を追加
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 4,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/image/train_icon.png', // ここに電車時刻表用画像
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.train,
                                color: Color(0xFF0033A0),
                                size: 30,
                              ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      '電車時刻表',
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
                  _getCurrentGifPath(),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const ColoredBox(
                      color: Colors.white,
                      child: Center(
                        child: Text(
                          'GIF未設定',
                          style: TextStyle(fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            SafeArea(
              minimum: EdgeInsets.only(left: 10, bottom: 8),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min, // 必要な分だけスペースを使う
                  crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: GestureDetector(
                        onTap: _isLunchTime() ? _launchLunchTime : null,
                        child: Opacity(
                          opacity: _isLunchTime()
                              ? 1.0
                              : 0.5, // 時間外は薄くして「お休み感」を出す
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.asset(
                                  _isLunchTime()
                                      ? 'assets/gifs/lunch_eating.gif' // 11-13時は動く
                                      : 'assets/image/lunch_wait.png', // それ以外は止まる
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _getLunchLabel(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: _isLunchTime()
                                      ? Colors.orange
                                      : const Color.fromARGB(255, 54, 54, 54),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8), // ボタンとVer表記の間の隙間
                    Text(
                      'Ver.1.0.0',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
