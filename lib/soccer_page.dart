import 'package:flutter/material.dart';

// スライド遷移先の白紙ページ
class BlankPage extends StatelessWidget {
  const BlankPage({super.key});

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
        automaticallyImplyLeading: false, // 左上のデフォルトの戻るボタンを消す
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
      
    );
  }
}
