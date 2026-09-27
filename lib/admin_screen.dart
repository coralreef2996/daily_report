import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'main.dart';

// ==========================================
// 管理者用画面 (日報作成)
// ==========================================

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  static const Color iconColor = Color(0xFF002850);
  static const Color gradientBaseColor = Color(0xFFBFDFFF);

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  bool _isBubbleEditingMode = false;
  int _bubbleCurrentPage = 1;
  String _selectedGenre = '作業内容';
  String _selectedSetName = 'セット1';

  final Map<int, Map<String, dynamic>> _bubblePagesData = {
    1: {
      'question': 'Q. 今日の体調や気分はどうでしたか？',
      'answers': ['A. ☀️ 晴れ (穏やか)', 'A. ☁️ 曇り (すこし疲れ)', 'A. ☔ 雨 (しんどい)', 'A. ❄️ 雪 (非常に不調)']
    },
    2: {
      'question': 'Q. 目標時間は達成できた？',
      'answers': ['A. 達成した', 'A. あと一歩', 'A. 未達成', 'A. 設定なし']
    },
    3: {
      'question': 'Q. どの作業に主に取り組みましたか？',
      'answers': ['A. 🎨 イラスト制作', 'A. 📦 梱包作業', 'A. 🎵 DTM音源カット', 'A. 🤝 その他共同作業']
    },
    4: {
      'question': 'Q. 分からない点の相談はできましたか？',
      'answers': ['A. すぐ相談できた', 'A. 少し時間がかかった', 'A. 相談できなかった', 'A. 相談不要だった']
    },
    5: {
      'question': 'Q. 明日の目標や意気込みを教えてください',
      'answers': ['A. 時間短縮を目指す', 'A. ミスなく丁寧に', 'A. 仲間と協力する', 'A. 体調を最優先にする']
    },
  };

  final GlobalKey<_PersonalDataTabState> _personalDataTabKey =
      GlobalKey<_PersonalDataTabState>();
  final GlobalKey<_AnalysisTabState> _analysisTabKey =
      GlobalKey<_AnalysisTabState>();

  void _handleBack() {
    if (_analysisTabKey.currentState?.handleBack() == true) {
      return;
    }
    if (_personalDataTabKey.currentState?.handleBack() == true) {
      return;
    }
    if (_isBubbleEditingMode) {
      setState(() {
        _isBubbleEditingMode = false;
      });
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(
          appName: '日報作成',
          originalHome: GameScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color purpleSaveColor = Colors.purple;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: DefaultTabController(
        length: 4,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, AdminHomeScreen.gradientBaseColor],
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.white.withOpacity(0.9),
              elevation: 0,
              centerTitle: true,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: AdminHomeScreen.iconColor),
                tooltip: _isBubbleEditingMode ? '機能編集に戻る' : 'ログイン画面に戻る',
                onPressed: _handleBack,
              ),
              title: Text(
                '日報作成',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AdminHomeScreen.iconColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              ),
              actions: _isBubbleEditingMode
                  ? [
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('日報バブルの設定を下書き保存しました。', style: TextStyle(color: Colors.white)),
                              backgroundColor: purpleSaveColor,
                            ),
                          );
                        },
                        child: const Text(
                          '保存',
                          style: TextStyle(color: purpleSaveColor, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('日報バブルの設定を公開しました！', style: TextStyle(color: Colors.white)),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text(
                          '公開',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ]
                  : null,
              bottom: TabBar(
                labelColor: AdminHomeScreen.iconColor,
                unselectedLabelColor: Colors.black54,
                indicatorColor: AdminHomeScreen.iconColor,
              labelStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                height: 1.1,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: 11,
                height: 1.1,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.people_alt_outlined),
                  child: Text(
                    '個人データ\n一覧',
                    textAlign: TextAlign.center,
                  ),
                ),
                Tab(
                  icon: Icon(Icons.analytics_outlined),
                  child: Text(
                    '分析\n職員用メモ',
                    textAlign: TextAlign.center,
                  ),
                ),
                Tab(
                  icon: Icon(Icons.app_settings_alt_outlined),
                  child: Text(
                    '機能編集\n管理',
                    textAlign: TextAlign.center,
                  ),
                ),
                Tab(
                  icon: Icon(Icons.import_export_outlined),
                  child: Text(
                    '外部出力\n連携',
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _PersonalDataTab(key: _personalDataTabKey, iconColor: AdminHomeScreen.iconColor),
              _AnalysisTab(key: _analysisTabKey, iconColor: AdminHomeScreen.iconColor),
              _AppEditTab(
                iconColor: AdminHomeScreen.iconColor,
                isBubbleEditingMode: _isBubbleEditingMode,
                onModeChanged: (mode) {
                  setState(() {
                    _isBubbleEditingMode = mode;
                    if (mode) {
                      _bubbleCurrentPage = 1;
                    }
                  });
                },
                selectedGenre: _selectedGenre,
                onGenreChanged: (genre) => setState(() => _selectedGenre = genre),
                selectedSetName: _selectedSetName,
                onSetNameChanged: (name) => setState(() => _selectedSetName = name),
                currentPage: _bubbleCurrentPage,
                onPageChanged: (page) => setState(() => _bubbleCurrentPage = page),
                pagesData: _bubblePagesData,
              ),
              const _ExportTab(iconColor: AdminHomeScreen.iconColor),
            ],
          ),
        ),
      ),
    ),
  );
}
}

class _AdminSubHeader extends StatelessWidget {
  final Color iconColor;
  const _AdminSubHeader({required this.iconColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 左上：「設定」ボタン
          OutlinedButton.icon(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: iconColor,
              side: BorderSide(color: iconColor.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
            icon: const Icon(Icons.settings, size: 18),
            label: const Text('設定'),
          ),

          // 右上：「使い方」プルダウンメニューボタン
          PopupMenuButton<String>(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            onSelected: (String value) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: iconColor,
                  content: Text(
                    '$value が選択されました',
                    style: const TextStyle(color: Colors.white),
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: '使い方１',
                child: Text('使い方１', style: TextStyle(color: iconColor)),
              ),
              PopupMenuItem<String>(
                value: '使い方２',
                child: Text('使い方２', style: TextStyle(color: iconColor)),
              ),
              PopupMenuItem<String>(
                value: '使い方３',
                child: Text('使い方３', style: TextStyle(color: iconColor)),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.0),
                border: Border.all(color: iconColor.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.help_outline,
                    size: 18,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '使い方',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 18,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Mock Daily Report User Data
class ReportUser {
  final String name;
  final String moodBubble;
  final List<String> activityBubbles;
  final String comment;
  final String aiSummary;
  final List<String> completedAchievements; // Linked from work_guide
  final bool hasSubmittedToday;
  final String lastSubmitTime;
  final List<bool> calendarHistory; // Submitted days (30 days)

  ReportUser({
    required this.name,
    required this.moodBubble,
    required this.activityBubbles,
    required this.comment,
    required this.aiSummary,
    required this.completedAchievements,
    this.hasSubmittedToday = true,
    required this.lastSubmitTime,
    required this.calendarHistory,
  });
}

// ==========================================
// 1. 個人データ一覧 タブ
// ==========================================
class _PersonalDataTab extends StatefulWidget {
  final Color iconColor;
  const _PersonalDataTab({super.key, required this.iconColor});

  @override
  State<_PersonalDataTab> createState() => _PersonalDataTabState();
}

class _PersonalDataTabState extends State<_PersonalDataTab> {
  ReportUser? _selectedUser;

  final List<ReportUser> _users = [
    ReportUser(
      name: '田中 太郎',
      moodBubble: '☀️ 晴れ (おだやか)',
      activityBubbles: ['🎨 イラスト制作', '📦 梱包作業'],
      comment: '今日は初めてバトンタッチマニュアルを使いました。梱包手順が図解で分かりやすくて、ミスなくできました！',
      aiSummary: 'イラスト制作と梱包手順の学習。図解指示書のおかげでミスなく完了。達成感があり、モチベーション高。',
      completedAchievements: ['梱包作業マニュアル自立', 'バトンタッチ連携の実践'],
      lastSubmitTime: '15:20',
      calendarHistory: [true, true, true, false, true, true, true, true, true, false, true, true, true, true, true],
    ),
    ReportUser(
      name: '佐藤 花子',
      moodBubble: '☁️ 曇り (すこし疲れ)',
      activityBubbles: ['🎵 DTM音源カット'],
      comment: 'DTMの切り出し作業を順調に終わらせることができました。少し目が疲れました。',
      aiSummary: 'DTM音源カット作業の完了。目の疲労を訴える記述あり。適度に休憩を挟むよう指示。',
      completedAchievements: ['DTM音源カット自立'],
      lastSubmitTime: '15:45',
      calendarHistory: [true, true, false, true, true, true, true, false, true, true, true, true, true, true, true],
    ),
    ReportUser(
      name: '鈴木 一郎',
      moodBubble: '☔ 雨 (しんどい)',
      activityBubbles: ['📦 部材の運搬'],
      comment: '立ち作業が多くて体が重かったです。明日はもう少しゆっくり作業したいです。',
      aiSummary: '部材運搬における立ち作業負荷。肉体的な疲労がコメントに現れており、作業配分の再検討が必要。',
      completedAchievements: ['部材の安全運搬完了'],
      lastSubmitTime: '16:00',
      calendarHistory: [true, false, true, true, true, false, true, true, true, true, false, true, true, true, true],
    ),
  ];

  bool handleBack() {
    if (_selectedUser != null) {
      setState(() {
        _selectedUser = null;
      });
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return _selectedUser != null
        ? _buildUserDetailMode(_selectedUser!)
        : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _AdminSubHeader(iconColor: widget.iconColor),

        Row(
          children: [
            Icon(Icons.assignment, color: widget.iconColor, size: 20),
            const SizedBox(width: 8),
            Text(
              '登録利用者一覧 (選択してバブル・日報履歴表示)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: widget.iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        ..._users.map((u) {
          return Card(
            color: Colors.white.withOpacity(0.9),
            margin: const EdgeInsets.symmetric(vertical: 4),
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: widget.iconColor.withOpacity(0.1),
                child: Icon(Icons.description, color: widget.iconColor),
              ),
              title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(u.hasSubmittedToday ? '本日分：${u.lastSubmitTime} 送信済み' : '本日未提出'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () {
                setState(() {
                  _selectedUser = u;
                });
              },
            ),
          );
        }),
      ],
    );
  }

  // 個人メニュー読み取り (閲覧モード)
  Widget _buildUserDetailMode(ReportUser user) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back, color: widget.iconColor),
              onPressed: () {
                setState(() {
                  _selectedUser = null;
                });
              },
            ),
            Text(
              '${user.name} - 日報詳細 (閲覧モード)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: widget.iconColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. バブル選択 (気分や活動)
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('■ 選択されたバブル (気分・活動)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('今日の気分: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    Chip(
                      backgroundColor: Colors.blue[50],
                      side: BorderSide(color: widget.iconColor.withOpacity(0.3)),
                      label: Text(user.moodBubble, style: const TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('取り組んだ活動: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: user.activityBubbles.map((act) {
                          return Chip(
                            backgroundColor: Colors.green[50],
                            side: BorderSide(color: widget.iconColor.withOpacity(0.3)),
                            label: Text(act, style: const TextStyle(fontSize: 11)),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. 日報送信 & AI要約
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('■ 本人コメント & AI日報要約', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text('【本人入力コメント】', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(user.comment, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
                const Divider(),
                const Text('【AI自動要約結果】', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                const SizedBox(height: 4),
                Text(user.aiSummary, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. できたこと履歴
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('■ できたこと実績 (作業手順アプリから同期)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (user.completedAchievements.isEmpty)
                  const Text('本日の新規達成実績はありません。', style: TextStyle(fontSize: 11, color: Colors.black54))
                else
                  ...user.completedAchievements.map((ach) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline, color: Colors.green, size: 16),
                            const SizedBox(width: 6),
                            Text(ach, style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      )),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. カレンダー履歴
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('■ 直近15日間の日報提出履歴 (カレンダー)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: user.calendarHistory.asMap().entries.map((entry) {
                    int dayIndex = entry.key + 1;
                    bool submitted = entry.value;
                    return Column(
                      children: [
                        Text('$dayIndex', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                        const SizedBox(height: 4),
                        Icon(submitted ? Icons.check_circle : Icons.cancel, color: submitted ? Colors.green : Colors.grey, size: 16),
                      ],
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. 分析・職員用メモ タブ
// ==========================================
class _AnalysisTab extends StatefulWidget {
  final Color iconColor;
  const _AnalysisTab({super.key, required this.iconColor});

  @override
  State<_AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<_AnalysisTab> {
  bool _showAdminMemos = false;

  bool handleBack() {
    if (_showAdminMemos) {
      setState(() => _showAdminMemos = false);
      return true;
    }
    return false;
  }

  final TextEditingController _supportNotesController = TextEditingController(
    text: '梱包手順の自立により自信がついた模様。焦らずに進められるよう声かけを続ける。',
  );

  List<String> _talkingPoints = [
    '新しい梱包マニュアルを使って、どのステップが一番分かりやすかったですか？',
    '午後、少ししんどそうでしたが休憩時間はしっかり休めましたか？',
    '明日の作業で何か不安な点はありませんか？',
  ];

  @override
  Widget build(BuildContext context) {
    if (_showAdminMemos) {
      return AdminDailyMemosScreen(
        iconColor: widget.iconColor,
        onBack: () => setState(() => _showAdminMemos = false),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminSubHeader(iconColor: widget.iconColor),
        const SizedBox(height: 12),

        // 管理者用メモ（最優先・データ分析の要）
        Card(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: widget.iconColor.withValues(alpha: 0.35), width: 1.5),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.iconColor.withValues(alpha: 0.08),
                  Colors.white,
                ],
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.analytics_outlined, color: widget.iconColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '管理者用メモ',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: widget.iconColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade700,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  '分析の要',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'AI分析・個別支援データ蓄積と記録',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.iconColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => setState(() => _showAdminMemos = true),
                  icon: const Icon(Icons.note_alt_outlined, size: 20),
                  label: const Text(
                    '日報メモ表示',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 「案内ひろば」AI統合分析のヒント
        _buildSupportHubPromptCard(
          context: context,
          iconColor: widget.iconColor,
          crossAppPrompts: [
            '本人の自己評価と、体調記録（HP）・作業自立度（職員評価）のギャップを教えて',
            '「明日の目標」に合わせて、勤怠や作業で職員が意識すべきサポート内容を提案して',
            '次回の定期面談で本人に聞くべき「面談ヒアリング項目リスト」を日報履歴から自動作成して',
          ],
          singleAppPrompts: [
            '本人の自己評価（満足度）の月次推移と、満足度が高かった日の特徴を教えて',
            '日報で書かれた「明日の目標」の達成率と、よく選ばれる目標テーマを分析して',
          ],
        ),
      ],
    );
  }

  Widget _buildSupportHubPromptCard({
    required BuildContext context,
    required Color iconColor,
    required List<String> crossAppPrompts,
    required List<String> singleAppPrompts,
  }) {
    return Card(
      color: Colors.white,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: iconColor.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.lightbulb_outline, color: Colors.amber.shade900, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '「案内ひろば」AI分析のヒント',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_awesome, size: 11, color: Colors.blue.shade800),
                            const SizedBox(width: 3),
                            Text(
                              'Gemini連携',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'マスターアプリ「案内ひろば」のAIにこう聞いてみよう！（タップでコピー）',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.link, size: 15, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  '他のデータと掛け合わせて分析',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...crossAppPrompts.map((prompt) => _buildPromptItem(context, prompt, iconColor)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.search, size: 15, color: iconColor),
                const SizedBox(width: 4),
                Text(
                  'このアプリのデータを深掘り分析',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: iconColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...singleAppPrompts.map((prompt) => _buildPromptItem(context, prompt, iconColor)),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptItem(BuildContext context, String prompt, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Material(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {
            Clipboard.setData(ClipboardData(text: prompt));
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '質問文をコピーしました！「案内ひろば」で貼り付けて使えます',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF1E293B),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1.0),
                  child: Icon(Icons.chat_bubble_outline, size: 14, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prompt,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.copy_rounded, size: 14, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 3. 機能編集・管理 タブ
// ==========================================
class _AppEditTab extends StatelessWidget {
  final Color iconColor;
  final bool isBubbleEditingMode;
  final Function(bool) onModeChanged;
  final String selectedGenre;
  final Function(String) onGenreChanged;
  final String selectedSetName;
  final Function(String) onSetNameChanged;
  final int currentPage;
  final Function(int) onPageChanged;
  final Map<int, Map<String, dynamic>> pagesData;

  const _AppEditTab({
    required this.iconColor,
    required this.isBubbleEditingMode,
    required this.onModeChanged,
    required this.selectedGenre,
    required this.onGenreChanged,
    required this.selectedSetName,
    required this.onSetNameChanged,
    required this.currentPage,
    required this.onPageChanged,
    required this.pagesData,
  });

  @override
  Widget build(BuildContext context) {
    if (isBubbleEditingMode) {
      return _BubbleEditView(
        selectedGenre: selectedGenre,
        iconColor: iconColor,
        selectedSetName: selectedSetName,
        onSetNameChanged: onSetNameChanged,
        currentPage: currentPage,
        onPageChanged: onPageChanged,
        pagesData: pagesData,
        onBack: () => onModeChanged(false),
      );
    }

    final List<String> genres = ['作業内容', '感情・体調', 'その他の振り返り'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminSubHeader(iconColor: iconColor),

        // 日報バブルの編集タイル
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bubble_chart_outlined, color: iconColor),
                    const SizedBox(width: 8),
                    const Text(
                      '日報バブルの編集',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  '日報ジャンルを選択（作業内容を選択するように）',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedGenre,
                  dropdownColor: Colors.white,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: genres.map((genre) {
                    return DropdownMenuItem<String>(
                      value: genre,
                      child: Text(genre),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      onGenreChanged(val);
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => onModeChanged(true),
                        child: const Text('バブルの編集', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // バブル内容AI生成
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.psychology_outlined, color: iconColor),
                    const SizedBox(width: 8),
                    const Text(
                      'AIによる日報バブル選択肢の自動生成',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.blueAccent),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('利用者の作業傾向や直近の活動内容から、最も選択しやすい最適な振り返りバブル候補をAIが自動作成します。', style: TextStyle(fontSize: 12, height: 1.4)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: iconColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.bolt),
                        label: const Text('振り返り選択肢をAI生成して登録'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('AIが振り返りバブル選択肢を新規生成して登録しました。')),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// バブルの編集 ビュー
// ==========================================
class _BubbleEditView extends StatefulWidget {
  final String selectedGenre;
  final Color iconColor;
  final String selectedSetName;
  final Function(String) onSetNameChanged;
  final int currentPage;
  final Function(int) onPageChanged;
  final Map<int, Map<String, dynamic>> pagesData;

  final VoidCallback? onBack;

  const _BubbleEditView({
    required this.selectedGenre,
    required this.iconColor,
    required this.selectedSetName,
    required this.onSetNameChanged,
    required this.currentPage,
    required this.onPageChanged,
    required this.pagesData,
    this.onBack,
  });

  @override
  State<_BubbleEditView> createState() => _BubbleEditViewState();
}

class _BubbleEditViewState extends State<_BubbleEditView> {
  late TextEditingController _setNameController;

  @override
  void initState() {
    super.initState();
    _setNameController = TextEditingController(text: widget.selectedSetName);
  }

  @override
  void didUpdateWidget(covariant _BubbleEditView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedSetName != widget.selectedSetName) {
      _setNameController.text = widget.selectedSetName;
    }
  }

  @override
  void dispose() {
    _setNameController.dispose();
    super.dispose();
  }

  void _editItemDialog(String title, String initialValue, Function(String) onSave) {
    final controller = TextEditingController(text: initialValue);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('$title の編集'),
          content: TextField(
            controller: controller,
            maxLines: 2,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  onSave(controller.text);
                }
                Navigator.pop(context);
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentQuestion = widget.pagesData[widget.currentPage]?['question'] ?? '';
    final List<String> currentAnswers = List<String>.from(widget.pagesData[widget.currentPage]?['answers'] ?? []);

    const Color navyTextColor = Color(0xFF002850);
    const Color waterBlueColor = Color(0xFF03A9F4);
    const Color emeraldGreenColor = Color(0xFF10B981);

    return Stack(
      children: [
        // Main Content Area
        ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 「←バブルの編集（N/5）」ヘッダー表示
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back, color: widget.iconColor),
                  onPressed: () {
                    widget.onBack?.call();
                  },
                ),
                Text(
                  'バブルの編集（${widget.currentPage}/5）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: widget.iconColor,
                  ),
                ),
              ],
            ),

            // 1. Set Name Row (Textfield + Dropdown)
            Card(
              color: Colors.white.withOpacity(0.95),
              elevation: 1,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _setNameController,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: navyTextColor),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 4),
                        ),
                        onChanged: (val) {
                          widget.onSetNameChanged(val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(widget.selectedSetName, style: const TextStyle(color: Colors.black54, fontSize: 14)),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                      onPressed: () {
                        setState(() {
                          _setNameController.clear();
                          widget.onSetNameChanged('');
                        });
                      },
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.layers, color: navyTextColor),
                      color: Colors.white,
                      onSelected: (String value) {
                        setState(() {
                          _setNameController.text = value;
                          widget.onSetNameChanged(value);
                        });
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        const PopupMenuItem<String>(value: 'セット1', child: Text('セット1')),
                        const PopupMenuItem<String>(value: 'セット2', child: Text('セット2')),
                        const PopupMenuItem<String>(value: 'セット3', child: Text('セット3')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 2. Question Tile (Navy text, Navy border, White background)
            InkWell(
              onTap: () {
                _editItemDialog('質問項目', currentQuestion, (newVal) {
                  setState(() {
                    widget.pagesData[widget.currentPage]?['question'] = newVal;
                  });
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: navyTextColor, width: 2.0),
                ),
                child: Center(
                  child: Text(
                    currentQuestion,
                    style: const TextStyle(
                      color: navyTextColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 3. 4 Answer Tiles (Water blue text, Water blue border, White background)
            ...currentAnswers.asMap().entries.map((entry) {
              final index = entry.key;
              final ansText = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () {
                    _editItemDialog('選択肢項目', ansText, (newVal) {
                      setState(() {
                        widget.pagesData[widget.currentPage]?['answers'][index] = newVal;
                      });
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: waterBlueColor, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        ansText,
                        style: const TextStyle(
                          color: waterBlueColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 4),

            const Center(
              child: Text(
                '※各項目をタップして内容を編集できます',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            const SizedBox(height: 16),

            // 4. Save Drafts Button (Emerald green background, White text)
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存された下書きの一覧を表示します（モック）。')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: emeraldGreenColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.folder_special, color: Colors.white, size: 32),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '保存された下書き',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '下書きの編集・削除はこちらから',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),

        // Left Page Turn Button (Semi-transparent emerald green background) - hidden on page 1
        if (widget.currentPage > 1)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 40.0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (widget.currentPage > 1) {
                    widget.onPageChanged(widget.currentPage - 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('最初のページです。')),
                    );
                  }
                },
                child: Container(
                  width: 40.0,
                  height: 120,
                  decoration: BoxDecoration(
                    color: emeraldGreenColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(16),
                      left: Radius.zero,
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 0, right: 10),
                      child: Text(
                        '＜',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Right Page Turn Button (Semi-transparent emerald green background) - hidden on page 5
        if (widget.currentPage < 5)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 40.0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  if (widget.currentPage < 5) {
                    widget.onPageChanged(widget.currentPage + 1);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('最後のページです。')),
                    );
                  }
                },
                child: Container(
                  width: 40.0,
                  height: 120,
                  decoration: BoxDecoration(
                    color: emeraldGreenColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.zero,
                      left: Radius.circular(16),
                    ),
                  ),
                  child: const Center(
                    child: Padding(
                      padding: EdgeInsets.only(left: 10, right: 0),
                      child: Text(
                        '＞',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ==========================================
// 4. 外部出力・連携 タブ
// ==========================================
class _ExportTab extends StatefulWidget {
  final Color iconColor;
  const _ExportTab({required this.iconColor});

  @override
  State<_ExportTab> createState() => _ExportTabState();
}

class _ExportTabState extends State<_ExportTab> {
  String _selectedUser = '田中 太郎';

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _AdminSubHeader(iconColor: widget.iconColor),

        // 月次報告書、面談シートのワンクリック自動生成
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.task_outlined, color: widget.iconColor),
                    const SizedBox(width: 8),
                    const Text(
                      '報告書・面談用振り返りシート作成',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('利用者の日報、できたこと履歴、AI要約を統合した月次面談用ヒアリングシートを自動生成します。', style: TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('対象者: ', style: TextStyle(fontSize: 13)),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _selectedUser,
                      dropdownColor: Colors.white,
                      style: TextStyle(color: widget.iconColor, fontWeight: FontWeight.bold),
                      items: <String>['田中 太郎', '佐藤 花子', '鈴木 一郎'].map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUser = val;
                          });
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.iconColor,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('面談用シート (PDF) を一括出力', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showExportSuccess('PDF面談シート'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.iconColor,
                          side: BorderSide(color: widget.iconColor),
                        ),
                        icon: const Icon(Icons.file_present),
                        label: const Text('月次実績報告書 (CSV) をダウンロード', style: TextStyle(fontSize: 11)),
                        onPressed: () => _showExportSuccess('CSV月次報告書'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 目標設定エクスポート
        Card(
          color: Colors.white.withOpacity(0.9),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.output_outlined, color: widget.iconColor),
                    const SizedBox(width: 8),
                    const Text(
                      '目標設定データ他アプリ連携エクスポート',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('本人が日報や面談で設定したステップアップ目標を、勤怠管理（作業設定）や作業手順（できたこと目標）へ一括で連携させます。', style: TextStyle(fontSize: 12, color: Colors.black87)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: widget.iconColor,
                          side: BorderSide(color: widget.iconColor),
                        ),
                        icon: const Icon(Icons.sync),
                        label: const Text('他アプリ（作業手順等）へ目標データを同期'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: widget.iconColor,
                              content: Text('$_selectedUser の日報目標データを勤怠・作業手順アプリへ同期しました。'),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showExportSuccess(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: widget.iconColor,
        content: Text('$_selectedUser のデータを $type 形式で出力しました。'),
      ),
    );
  }
}

// ==========================================
// 日報作成：管理者用メモ画面
// ==========================================

class DailyReportMemo {
  final String id;
  final String userName;
  final String selfEvaluation;
  final String dailyMoodSummary;
  final String tomorrowGoal;
  final String notes;
  final DateTime recordedAt;

  DailyReportMemo({
    required this.id,
    required this.userName,
    required this.selfEvaluation,
    required this.dailyMoodSummary,
    required this.tomorrowGoal,
    required this.notes,
    required this.recordedAt,
  });
}

class AdminDailyMemosScreen extends StatefulWidget {
  final Color iconColor;
  final VoidCallback onBack;

  const AdminDailyMemosScreen({
    super.key,
    required this.iconColor,
    required this.onBack,
  });

  @override
  State<AdminDailyMemosScreen> createState() => _AdminDailyMemosScreenState();
}

class _AdminDailyMemosScreenState extends State<AdminDailyMemosScreen> {
  final List<String> _users = ['田中 太郎', '佐藤 花子', '鈴木 一郎'];
  late String _selectedUser;
  String _filterUser = '全員';

  final List<String> _selfEvaluationOptions = [
    '大変満足(100%)',
    '満足(80%)',
    '普通(60%)',
    '少し不安(40%)',
    '困難(20%以下)',
  ];
  late String _selectedSelfEvaluation;

  final List<String> _dailyMoodSummaryOptions = [
    '集中して取り組めた',
    '達成感を感じていた',
    '疲労感が見られた',
    'モチベーション低下',
    '体調不良の兆候',
    'その他',
  ];
  late String _selectedDailyMoodSummary;

  final List<String> _tomorrowGoalOptions = [
    'ペース維持',
    '休憩を多めに',
    '難易度調整',
    '声かけ強化',
  ];
  late String _selectedTomorrowGoal;

  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  late List<DailyReportMemo> _memos;

  @override
  void initState() {
    super.initState();
    _selectedUser = _users.first;
    _selectedSelfEvaluation = _selfEvaluationOptions[1]; // 満足(80%)
    _selectedDailyMoodSummary = _dailyMoodSummaryOptions.first;
    _selectedTomorrowGoal = _tomorrowGoalOptions.first;

    _memos = [
      DailyReportMemo(
        id: '1',
        userName: '田中 太郎',
        selfEvaluation: '満足(80%)',
        dailyMoodSummary: '達成感を感じていた',
        tomorrowGoal: 'ペース維持',
        notes: '梱包作業の全ステップを自立して完了。明日は作業スピードを意識しつつ丁寧に進めるとのこと。',
        recordedAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      DailyReportMemo(
        id: '2',
        userName: '佐藤 花子',
        selfEvaluation: '大変満足(100%)',
        dailyMoodSummary: '集中して取り組めた',
        tomorrowGoal: '難易度調整',
        notes: 'イラストの線画作業が予定より早く終了。新しいブラシの使い方にも意欲的。',
        recordedAt: DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      ),
      DailyReportMemo(
        id: '3',
        userName: '鈴木 一郎',
        selfEvaluation: '少し不安(40%)',
        dailyMoodSummary: '疲労感が見られた',
        tomorrowGoal: '休憩を多めに',
        notes: '午後から肩の痛みを訴えていた。明日は1時間ごとのストレッチ休憩を推奨。',
        recordedAt: DateTime.now().subtract(const Duration(days: 2, hours: 4)),
      ),
    ];
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveMemo() {
    final newDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final newMemo = DailyReportMemo(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userName: _selectedUser,
      selfEvaluation: _selectedSelfEvaluation,
      dailyMoodSummary: _selectedDailyMoodSummary,
      tomorrowGoal: _selectedTomorrowGoal,
      notes: _notesController.text.trim(),
      recordedAt: newDateTime,
    );

    setState(() {
      _memos.insert(0, newMemo);
      _notesController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: widget.iconColor,
        content: Text('$_selectedUser さんの日報メモを保存しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deleteMemo(String id) {
    setState(() {
      _memos.removeWhere((m) => m.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: widget.iconColor,
        content: const Text('メモを削除しました'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredMemos = _filterUser == '全員'
        ? _memos
        : _memos.where((m) => m.userName == _filterUser).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 戻るヘッダー
        Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_ios, color: widget.iconColor, size: 20),
              onPressed: widget.onBack,
              tooltip: '戻る',
            ),
            Text(
              '【管理】日報メモ (閲覧/代理記録)',
              style: TextStyle(
                color: widget.iconColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 新規メモ作成カード
        Card(
          color: Colors.white.withOpacity(0.95),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.edit_note, color: widget.iconColor),
                    const SizedBox(width: 8),
                    const Text(
                      '新規日報メモ作成',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // 1. メモ対象者
                const Text(
                  'メモ対象者',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedUser,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _users.map((user) => DropdownMenuItem(value: user, child: Text(user))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedUser = val);
                  },
                ),
                const SizedBox(height: 14),

                // 2. 本人の自己評価
                const Text(
                  '本人の自己評価',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _selfEvaluationOptions.map((eval) {
                    final isSelected = _selectedSelfEvaluation == eval;
                    return ChoiceChip(
                      label: Text(eval),
                      selected: isSelected,
                      selectedColor: widget.iconColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? widget.iconColor : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedSelfEvaluation = eval);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 3. 1日の総括・気分
                const Text(
                  '1日の総括・気分',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _selectedDailyMoodSummary,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _dailyMoodSummaryOptions.map((mood) => DropdownMenuItem(value: mood, child: Text(mood))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedDailyMoodSummary = val);
                  },
                ),
                const SizedBox(height: 14),

                // 4. 明日の目標・申し送り
                const Text(
                  '明日の目標・申し送り',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _tomorrowGoalOptions.map((goal) {
                    final isSelected = _selectedTomorrowGoal == goal;
                    return ChoiceChip(
                      label: Text(goal),
                      selected: isSelected,
                      selectedColor: widget.iconColor.withOpacity(0.2),
                      labelStyle: TextStyle(
                        color: isSelected ? widget.iconColor : Colors.black87,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedTomorrowGoal = goal);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 5. 詳細メモ
                const Text(
                  'メモ・特記事項',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: '日報の振り返りや職員所見を入力...',
                    hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 14),

                // 6. 記録日時
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          DateFormat('yyyy/MM/dd').format(_selectedDate),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _selectedDate = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(
                          _selectedTime.format(context),
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _selectedTime,
                          );
                          if (picked != null) setState(() => _selectedTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 保存ボタン
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.iconColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: _saveMemo,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('メモを保存', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // 過去のメモ一覧ヘッダー & フィルター
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.history, color: widget.iconColor),
                const SizedBox(width: 6),
                const Text(
                  '過去の日報メモ一覧',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400),
              ),
              child: DropdownButton<String>(
                value: _filterUser,
                underline: const SizedBox(),
                isDense: true,
                items: ['全員', ..._users].map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _filterUser = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // メモ一覧
        if (filteredMemos.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            child: const Text('記録されたメモはありません', style: TextStyle(color: Colors.grey)),
          )
        else
          ...filteredMemos.map((memo) {
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              color: Colors.white.withOpacity(0.95),
              elevation: 1.5,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: widget.iconColor.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                memo.userName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: widget.iconColor,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Text(
                                '自己評価: ${memo.selfEvaluation}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue.shade900,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                          onPressed: () => _deleteMemo(memo.id),
                          tooltip: '削除',
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '気分: ${memo.dailyMoodSummary}',
                            style: TextStyle(fontSize: 11, color: Colors.teal.shade900),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '目標: ${memo.tomorrowGoal}',
                            style: TextStyle(fontSize: 11, color: Colors.indigo.shade900),
                          ),
                        ),
                      ],
                    ),
                    if (memo.notes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        memo.notes,
                        style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('yyyy/MM/dd HH:mm').format(memo.recordedAt),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 20),
      ],
    );
  }
}

