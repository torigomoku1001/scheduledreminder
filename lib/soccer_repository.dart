import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class SoccerData {
  final String id;
  final String name;
  final DateTime date;
  final int goals;
  final int assists;

  SoccerData({
    required this.id,
    required this.name,
    required this.date,
    required this.goals,
    required this.assists,
  });

  factory SoccerData.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SoccerData(
      id: doc.id,
      name: data['name'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      goals: data['goals'] ?? 0,
      assists: data['assists'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'date': Timestamp.fromDate(date),
      'goals': goals,
      'assists': assists,
    };
  }
}

class SoccerRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // データの保存
  Future<void> saveSoccerData({
    required String name,
    required DateTime date,
    required int goals,
    required int assists,
  }) async {
    try {
      final String dateString = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
      final String docId = '${name}_$dateString';
      await _firestore.collection('soccer_data').doc(docId).set({
        'name': name,
        'date': Timestamp.fromDate(date),
        'goals': goals,
        'assists': assists,
      });
    } catch (e) {
      print('データの保存に失敗しました: $e');
      rethrow;
    }
  }

  // 指定した月（年と月）のデータを全ユーザー分取得
  Future<List<SoccerData>> fetchMonthlyData(int year, int month) async {
    try {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);
      
      final snapshot = await _firestore
          .collection('soccer_data')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .get();

      return snapshot.docs.map((doc) => SoccerData.fromFirestore(doc)).toList();
    } catch (e) {
      print('データの取得に失敗しました: $e');
      rethrow;
    }
  }

  // 保存されているデータから月の一覧を取得する
  Future<List<String>> fetchAvailableMonths() async {
    try {
      final snapshot = await _firestore.collection('soccer_data').get();
      Set<String> months = {};
      for (var doc in snapshot.docs) {
        final data = doc.data();
        if (data['date'] != null) {
          final date = (data['date'] as Timestamp).toDate();
          months.add('${date.year}年${date.month}月');
        }
      }
      List<String> list = months.toList();
      // 降順（新しい月順）にソート
      list.sort((a, b) {
        final aParts = a.replaceAll('年', '-').replaceAll('月', '').split('-');
        final bParts = b.replaceAll('年', '-').replaceAll('月', '').split('-');
        final aYear = int.parse(aParts[0]);
        final aMonth = int.parse(aParts[1]);
        final bYear = int.parse(bParts[0]);
        final bMonth = int.parse(bParts[1]);
        if (aYear != bYear) {
          return bYear.compareTo(aYear);
        }
        return bMonth.compareTo(aMonth);
      });
      return list;
    } catch (e) {
      print('月一覧の取得エラー: $e');
      return []; // エラー時やデータが無い場合は空のリストを返す
    }
  }

  // テスト用：6月のモックデータを生成して返す
  Future<List<SoccerData>> getMockJuneData(int year) async {
    final random = Random();
    final names = ['田中', '佐藤', '鈴木'];
    List<SoccerData> mockData = [];

    // モックの通信遅延をシミュレート
    await Future.delayed(const Duration(milliseconds: 500));

    for (String name in names) {
      // 6月の各水曜日を取得
      for (int day = 1; day <= 30; day++) {
        final date = DateTime(year, 6, day);
        if (date.weekday == DateTime.wednesday) {
          mockData.add(SoccerData(
            id: 'mock_${name}_$day',
            name: name,
            date: date,
            goals: random.nextInt(5), // 0〜4点
            assists: random.nextInt(5), // 0〜4アシスト
          ));
        }
      }
    }
    return mockData;
  }
}
