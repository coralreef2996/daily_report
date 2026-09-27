import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

// =============================================================================
// 日報作成 (Daily Report Creation) - すべてのコードを1つにまとめたファイル
// =============================================================================
// このファイルには、アプリのすべての機能（モデル、サービス、UI、状態管理）が含まれています。
// 初心者の方でも理解しやすいように、各セクションに詳細なコメントを付けています。

// -----------------------------------------------------------------------------
// 1. モデルと列挙型 (Models & Enums)
// アプリで扱うデータの形式を定義します。
// -----------------------------------------------------------------------------

/// バブルの種類を定義します
enum BubbleType {
  good, // 良いこと
  normal, // 普通のこと
  bad, // 悪いこと
  freeInput, // 自由入力
}

/// 雲（AI）の感情を定義します
enum CloudEmotion {
  happy, // 嬉しい
  neutral, // 普通
  sad, // 悲しい
  thinking, // 考え中
}

/// バブルの広がる速度を定義します
enum BubbleSpeed {
  slow, // ゆっくり
  normal, // ふつう
  fast, // はやい
}

/// 個別のバブルのデータを保持するクラスです
class BubbleModel {
  final String id;
  final String text;
  final BubbleType type;
  final Offset initialPosition;
  final double size;
  final double speed;
  final double angle; // 移動方向（ラジアン）

  BubbleModel({
    String? id,
    required this.text,
    required this.type,
    required this.initialPosition,
    required this.size,
    this.speed = 1.0,
    this.angle = 0.0,
  }) : id = id ?? const Uuid().v4();
}

/// 会話の1項目（質問と回答）を保持するクラスです
class ConversationEntry {
  final String question;
  final String answer;
  final String? freeInputContent; // 選択肢ではなく自分で入力した内容

  ConversationEntry({
    required this.question,
    required this.answer,
    this.freeInputContent,
  });
}

/// 1日分の記録（日記エントリ）を保持するクラスです
class DiaryEntry {
  final String id;
  final DateTime date;
  final int score;
  final CloudEmotion emotion;
  final List<ConversationEntry> conversationHistory;
  final String? aiSummary;
  final List<String> tags;

  DiaryEntry({
    required this.id,
    required this.date,
    required this.score,
    required this.emotion,
    required this.conversationHistory,
    this.aiSummary,
    this.tags = const [],
  });

  // 保存のためにデータをJSON形式に変換します
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'score': score,
      'emotion': emotion.toString().split('.').last,
      'conversationHistory':
          conversationHistory
              .map(
                (entry) => {
                  'question': entry.question,
                  'answer': entry.answer,
                  'freeInputContent': entry.freeInputContent,
                },
              )
              .toList(),
      'aiSummary': aiSummary,
      'tags': tags,
    };
  }

  // 保存されたJSONデータからDiaryEntryオブジェクトを作成します
  factory DiaryEntry.fromJson(Map<String, dynamic> json) {
    return DiaryEntry(
      id: json['id'] as String,
      date: DateTime.parse(json['date'] as String),
      score: json['score'] as int,
      emotion: CloudEmotion.values.firstWhere(
        (e) => e.toString().split('.').last == json['emotion'],
        orElse: () => CloudEmotion.neutral,
      ),
      conversationHistory:
          (json['conversationHistory'] as List)
              .map(
                (e) => ConversationEntry(
                  question: e['question'] as String,
                  answer: e['answer'] as String,
                  freeInputContent: e['freeInputContent'] as String?,
                ),
              )
              .toList(),
      aiSummary: json['aiSummary'] as String?,
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
    );
  }
}

/// シナリオの各ステップ（質問と選択肢）を定義するクラスです
class Scenario {
  final String id;
  final String question;
  final List<ScenarioOption> options;
  final CloudEmotion emotion;

  Scenario({
    required this.id,
    required this.question,
    required this.options,
    this.emotion = CloudEmotion.neutral,
  });
}

/// シナリオの選択肢を定義するクラスです
class ScenarioOption {
  final String text;
  final BubbleType type;
  final String? nextScenarioId;

  ScenarioOption({required this.text, required this.type, this.nextScenarioId});
}

// -----------------------------------------------------------------------------
// 2. シナリオデータ (Scenario Data)
// 雲（AI）の質問と、それに対する選択肢のデータベースです。
// -----------------------------------------------------------------------------

class ScenarioData {
  static final Map<String, Scenario> scenarios = {
    // 基点となる最初の質問
    'root': Scenario(
      id: 'root',
      question: '今日1日はどんな日でしたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '良い',
          type: BubbleType.good,
          nextScenarioId: 'good_root',
        ),
        ScenarioOption(
          text: '普通',
          type: BubbleType.normal,
          nextScenarioId: 'normal_root',
        ),
        ScenarioOption(
          text: '悪い',
          type: BubbleType.bad,
          nextScenarioId: 'bad_root',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'free_root',
        ),
      ],
    ),

    // ========== 良い日（GOOD）ブランチ ==========
    'good_root': Scenario(
      id: 'good_root',
      question: '何が良かったですか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '作業が上手くできた',
          type: BubbleType.good,
          nextScenarioId: 'good_work',
        ),
        ScenarioOption(
          text: '疲れなかった',
          type: BubbleType.good,
          nextScenarioId: 'good_health',
        ),
        ScenarioOption(
          text: '良いことがあった',
          type: BubbleType.good,
          nextScenarioId: 'good_event',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'free_good',
        ),
      ],
    ),

    'good_work': Scenario(
      id: 'good_work',
      question: '今日の作業は何でしたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'イラスト',
          type: BubbleType.normal,
          nextScenarioId: 'work_illustration',
        ),
        ScenarioOption(
          text: 'DTM',
          type: BubbleType.normal,
          nextScenarioId: 'work_music',
        ),
        ScenarioOption(
          text: '3Dモデリング',
          type: BubbleType.normal,
          nextScenarioId: 'work_3d',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_other',
        ),
      ],
    ),

    'work_illustration': Scenario(
      id: 'work_illustration',
      question: 'どんなイラストを描きましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'キャラクター',
          type: BubbleType.good,
          nextScenarioId: 'work_detail_character',
        ),
        ScenarioOption(
          text: '風景',
          type: BubbleType.good,
          nextScenarioId: 'work_detail_landscape',
        ),
        ScenarioOption(
          text: 'デザイン',
          type: BubbleType.good,
          nextScenarioId: 'work_detail_design',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_detail_character': Scenario(
      id: 'work_detail_character',
      question: '満足のいく仕上がりになりましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'とても満足',
          type: BubbleType.good,
          nextScenarioId: 'satisfaction_high',
        ),
        ScenarioOption(
          text: 'まあまあ',
          type: BubbleType.normal,
          nextScenarioId: 'satisfaction_medium',
        ),
        ScenarioOption(
          text: 'やり直したい',
          type: BubbleType.bad,
          nextScenarioId: 'satisfaction_low',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_detail_landscape': Scenario(
      id: 'work_detail_landscape',
      question: '何時間くらいかかりましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '1-2時間',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '3-4時間',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '5時間以上',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_detail_design': Scenario(
      id: 'work_detail_design',
      question: 'どこで使うデザインですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'SNS用',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: 'お仕事',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '趣味',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_music': Scenario(
      id: 'work_music',
      question: 'どんなジャンルの曲ですか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'ポップス',
          type: BubbleType.good,
          nextScenarioId: 'music_mood',
        ),
        ScenarioOption(
          text: 'ロック',
          type: BubbleType.good,
          nextScenarioId: 'music_mood',
        ),
        ScenarioOption(
          text: '環境音楽',
          type: BubbleType.normal,
          nextScenarioId: 'music_mood',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'music_mood',
        ),
      ],
    ),

    'music_mood': Scenario(
      id: 'music_mood',
      question: '曲の雰囲気はどうでしたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '明るい',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '落ち着いた',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '激しい',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_3d': Scenario(
      id: 'work_3d',
      question: '何をモデリングしましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'キャラクター',
          type: BubbleType.good,
          nextScenarioId: 'model_progress',
        ),
        ScenarioOption(
          text: '建物',
          type: BubbleType.normal,
          nextScenarioId: 'model_progress',
        ),
        ScenarioOption(
          text: '小物',
          type: BubbleType.normal,
          nextScenarioId: 'model_progress',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'model_progress',
        ),
      ],
    ),

    'model_progress': Scenario(
      id: 'model_progress',
      question: 'どこまで進みましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '完成した',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '半分くらい',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: 'まだ始めたばかり',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_other': Scenario(
      id: 'work_other',
      question: '集中できましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'すごく集中した',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: 'まあまあ',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '散漫だった',
          type: BubbleType.bad,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'satisfaction_high': Scenario(
      id: 'satisfaction_high',
      question: 'どこが一番良かったですか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '色使い',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '構図',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '全体的に',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'satisfaction_medium': Scenario(
      id: 'satisfaction_medium',
      question: '改善したい点はありますか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'ある',
          type: BubbleType.normal,
          nextScenarioId: 'improvement_plan',
        ),
        ScenarioOption(
          text: 'ない',
          type: BubbleType.good,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: 'わからない',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'satisfaction_low': Scenario(
      id: 'satisfaction_low',
      question: '次はどう改善しますか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '下描きをもっと',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '時間をかける',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '参考資料を見る',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'improvement_plan': Scenario(
      id: 'improvement_plan',
      question: '具体的にどこを改善しますか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '線画',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '塗り',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: 'バランス',
          type: BubbleType.normal,
          nextScenarioId: 'work_complete',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'work_complete',
        ),
      ],
    ),

    'work_complete': Scenario(
      id: 'work_complete',
      question: '明日も続けますか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '続ける',
          type: BubbleType.good,
          nextScenarioId: 'tomorrow_plan',
        ),
        ScenarioOption(
          text: '別のことをする',
          type: BubbleType.normal,
          nextScenarioId: 'tomorrow_different',
        ),
        ScenarioOption(
          text: '休む',
          type: BubbleType.normal,
          nextScenarioId: 'tomorrow_rest',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'good_health': Scenario(
      id: 'good_health',
      question: '体調が良い理由はなんだと思いますか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'よく寝た',
          type: BubbleType.good,
          nextScenarioId: 'health_sleep',
        ),
        ScenarioOption(
          text: '運動した',
          type: BubbleType.good,
          nextScenarioId: 'health_exercise',
        ),
        ScenarioOption(
          text: '食事が美味しかった',
          type: BubbleType.good,
          nextScenarioId: 'health_food',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_summary',
        ),
      ],
    ),

    'health_sleep': Scenario(
      id: 'health_sleep',
      question: '睡眠時間はどれくらいでしたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '8時間以上',
          type: BubbleType.good,
          nextScenarioId: 'sleep_quality',
        ),
        ScenarioOption(
          text: '6-7時間',
          type: BubbleType.normal,
          nextScenarioId: 'sleep_quality',
        ),
        ScenarioOption(
          text: '5時間以下',
          type: BubbleType.bad,
          nextScenarioId: 'sleep_quality',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'sleep_quality',
        ),
      ],
    ),

    'sleep_quality': Scenario(
      id: 'sleep_quality',
      question: 'ぐっすり眠れましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'ぐっすり',
          type: BubbleType.good,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '普通',
          type: BubbleType.normal,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '浅かった',
          type: BubbleType.bad,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_summary',
        ),
      ],
    ),

    'health_exercise': Scenario(
      id: 'health_exercise',
      question: 'どんな運動をしましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '散歩',
          type: BubbleType.good,
          nextScenarioId: 'exercise_duration',
        ),
        ScenarioOption(
          text: 'ストレッチ',
          type: BubbleType.good,
          nextScenarioId: 'exercise_duration',
        ),
        ScenarioOption(
          text: 'ランニング',
          type: BubbleType.good,
          nextScenarioId: 'exercise_duration',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'exercise_duration',
        ),
      ],
    ),

    'exercise_duration': Scenario(
      id: 'exercise_duration',
      question: 'どれくらいの時間運動しましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '15分未満',
          type: BubbleType.normal,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '15-30分',
          type: BubbleType.good,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '30分以上',
          type: BubbleType.good,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_summary',
        ),
      ],
    ),

    'health_food': Scenario(
      id: 'health_food',
      question: '何を食べましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '和食',
          type: BubbleType.good,
          nextScenarioId: 'food_enjoyment',
        ),
        ScenarioOption(
          text: '洋食',
          type: BubbleType.normal,
          nextScenarioId: 'food_enjoyment',
        ),
        ScenarioOption(
          text: 'その他',
          type: BubbleType.normal,
          nextScenarioId: 'food_enjoyment',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'food_enjoyment',
        ),
      ],
    ),

    'food_enjoyment': Scenario(
      id: 'food_enjoyment',
      question: 'どれくらい楽しめましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'とても楽しめた',
          type: BubbleType.good,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: 'まあまあ',
          type: BubbleType.normal,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: 'あまり',
          type: BubbleType.bad,
          nextScenarioId: 'health_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_summary',
        ),
      ],
    ),

    'health_summary': Scenario(
      id: 'health_summary',
      question: '明日も健康的に過ごせそうですか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'はい',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'たぶん',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(text: '心配', type: BubbleType.bad, nextScenarioId: 'end'),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'good_event': Scenario(
      id: 'good_event',
      question: 'どんな良いことがありましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '褒められた',
          type: BubbleType.good,
          nextScenarioId: 'event_praise',
        ),
        ScenarioOption(
          text: '発見があった',
          type: BubbleType.good,
          nextScenarioId: 'event_discovery',
        ),
        ScenarioOption(
          text: '話が弾んだ',
          type: BubbleType.good,
          nextScenarioId: 'event_talk',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'event_summary',
        ),
      ],
    ),

    'event_praise': Scenario(
      id: 'event_praise',
      question: '誰に褒められましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '上司',
          type: BubbleType.good,
          nextScenarioId: 'praise_detail',
        ),
        ScenarioOption(
          text: '同僚',
          type: BubbleType.good,
          nextScenarioId: 'praise_detail',
        ),
        ScenarioOption(
          text: '家族',
          type: BubbleType.good,
          nextScenarioId: 'praise_detail',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'praise_detail',
        ),
      ],
    ),

    'praise_detail': Scenario(
      id: 'praise_detail',
      question: '何を褒められましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '仕事',
          type: BubbleType.good,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '態度',
          type: BubbleType.good,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '成果',
          type: BubbleType.good,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'event_summary',
        ),
      ],
    ),

    'event_discovery': Scenario(
      id: 'event_discovery',
      question: 'どんな発見でしたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '新しい方法',
          type: BubbleType.good,
          nextScenarioId: 'discovery_impact',
        ),
        ScenarioOption(
          text: '面白い場所',
          type: BubbleType.good,
          nextScenarioId: 'discovery_impact',
        ),
        ScenarioOption(
          text: '役立つ情報',
          type: BubbleType.good,
          nextScenarioId: 'discovery_impact',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'discovery_impact',
        ),
      ],
    ),

    'discovery_impact': Scenario(
      id: 'discovery_impact',
      question: 'その発見は役に立ちそうですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'とても',
          type: BubbleType.good,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: 'まあまあ',
          type: BubbleType.normal,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: 'わからない',
          type: BubbleType.normal,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'event_summary',
        ),
      ],
    ),

    'event_talk': Scenario(
      id: 'event_talk',
      question: '誰と話しましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '友人',
          type: BubbleType.good,
          nextScenarioId: 'talk_topic',
        ),
        ScenarioOption(
          text: '家族',
          type: BubbleType.good,
          nextScenarioId: 'talk_topic',
        ),
        ScenarioOption(
          text: '同僚',
          type: BubbleType.good,
          nextScenarioId: 'talk_topic',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'talk_topic',
        ),
      ],
    ),

    'talk_topic': Scenario(
      id: 'talk_topic',
      question: 'どんな話をしましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '趣味の話',
          type: BubbleType.good,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '仕事の話',
          type: BubbleType.normal,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '日常の話',
          type: BubbleType.normal,
          nextScenarioId: 'event_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'event_summary',
        ),
      ],
    ),

    'event_summary': Scenario(
      id: 'event_summary',
      question: 'また同じような良いことがあるといいですね',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'そう思う',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'きっとある',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'どうかな',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    // ========== 普通の日（NORMAL）ブランチ ==========
    'normal_root': Scenario(
      id: 'normal_root',
      question: 'いつも通り過ごせましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: 'はい',
          type: BubbleType.normal,
          nextScenarioId: 'normal_yes',
        ),
        ScenarioOption(
          text: '少し忙しかった',
          type: BubbleType.normal,
          nextScenarioId: 'normal_busy',
        ),
        ScenarioOption(
          text: '少し暇だった',
          type: BubbleType.normal,
          nextScenarioId: 'normal_bored',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_yes': Scenario(
      id: 'normal_yes',
      question: '穏やかに過ごせるのは良いことですね。何をしましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '仕事',
          type: BubbleType.normal,
          nextScenarioId: 'normal_work',
        ),
        ScenarioOption(
          text: '趣味',
          type: BubbleType.good,
          nextScenarioId: 'normal_hobby',
        ),
        ScenarioOption(
          text: '家事',
          type: BubbleType.normal,
          nextScenarioId: 'normal_housework',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_work': Scenario(
      id: 'normal_work',
      question: 'どんな仕事でしたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: 'いつもの',
          type: BubbleType.normal,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '新しい',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '難しい',
          type: BubbleType.bad,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_hobby': Scenario(
      id: 'normal_hobby',
      question: 'どんな趣味を楽しみましたか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '読書',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: 'ゲーム',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '創作活動',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_housework': Scenario(
      id: 'normal_housework',
      question: 'どんな家事をしましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '掃除',
          type: BubbleType.normal,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '料理',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '洗濯',
          type: BubbleType.normal,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_busy': Scenario(
      id: 'normal_busy',
      question: '何で忙しかったですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '仕事',
          type: BubbleType.normal,
          nextScenarioId: 'busy_handle',
        ),
        ScenarioOption(
          text: '用事',
          type: BubbleType.normal,
          nextScenarioId: 'busy_handle',
        ),
        ScenarioOption(
          text: '予定',
          type: BubbleType.normal,
          nextScenarioId: 'busy_handle',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'busy_handle',
        ),
      ],
    ),

    'busy_handle': Scenario(
      id: 'busy_handle',
      question: '上手く対応できましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'できた',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: 'まあまあ',
          type: BubbleType.normal,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '大変だった',
          type: BubbleType.bad,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_bored': Scenario(
      id: 'normal_bored',
      question: 'どう過ごしましたか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: 'ゆっくり休んだ',
          type: BubbleType.good,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '何かを探した',
          type: BubbleType.normal,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '退屈だった',
          type: BubbleType.bad,
          nextScenarioId: 'normal_summary',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'normal_summary',
        ),
      ],
    ),

    'normal_summary': Scenario(
      id: 'normal_summary',
      question: '明日は何をする予定ですか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: '同じ作業',
          type: BubbleType.normal,
          nextScenarioId: 'tomorrow_plan',
        ),
        ScenarioOption(
          text: '新しいこと',
          type: BubbleType.good,
          nextScenarioId: 'tomorrow_different',
        ),
        ScenarioOption(
          text: '休む',
          type: BubbleType.normal,
          nextScenarioId: 'tomorrow_rest',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    // ========== 悪い日（BAD）ブランチ ==========
    'bad_root': Scenario(
      id: 'bad_root',
      question: '何か辛いことがありましたか？',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(
          text: '体調が悪い',
          type: BubbleType.bad,
          nextScenarioId: 'bad_health',
        ),
        ScenarioOption(
          text: '失敗した',
          type: BubbleType.bad,
          nextScenarioId: 'bad_failure',
        ),
        ScenarioOption(
          text: '人間関係',
          type: BubbleType.bad,
          nextScenarioId: 'bad_relation',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'free_bad',
        ),
      ],
    ),

    'bad_health': Scenario(
      id: 'bad_health',
      question: 'どこか痛みますか？',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(
          text: '頭痛',
          type: BubbleType.bad,
          nextScenarioId: 'health_care',
        ),
        ScenarioOption(
          text: '腹痛',
          type: BubbleType.bad,
          nextScenarioId: 'health_care',
        ),
        ScenarioOption(
          text: '倦怠感',
          type: BubbleType.bad,
          nextScenarioId: 'health_care',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_care',
        ),
      ],
    ),

    'health_care': Scenario(
      id: 'health_care',
      question: '薬は飲みましたか？または休みましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '飲んだ/休んだ',
          type: BubbleType.normal,
          nextScenarioId: 'health_recovery',
        ),
        ScenarioOption(
          text: 'まだ',
          type: BubbleType.bad,
          nextScenarioId: 'health_advice',
        ),
        ScenarioOption(
          text: '我慢している',
          type: BubbleType.bad,
          nextScenarioId: 'health_advice',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'health_recovery',
        ),
      ],
    ),

    'health_recovery': Scenario(
      id: 'health_recovery',
      question: '少しは良くなりましたか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '良くなった',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'まだ辛い',
          type: BubbleType.bad,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '変わらない',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'health_advice': Scenario(
      id: 'health_advice',
      question: '無理しないでくださいね。今日は早めに休めそうですか？',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(
          text: 'はい',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'たぶん',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '難しい',
          type: BubbleType.bad,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'bad_failure': Scenario(
      id: 'bad_failure',
      question: 'リカバリーできそうですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'なんとかなりそう',
          type: BubbleType.normal,
          nextScenarioId: 'failure_recover',
        ),
        ScenarioOption(
          text: '助けが必要',
          type: BubbleType.bad,
          nextScenarioId: 'failure_help',
        ),
        ScenarioOption(
          text: 'もう無理',
          type: BubbleType.bad,
          nextScenarioId: 'failure_support',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'failure_recover',
        ),
      ],
    ),

    'failure_recover': Scenario(
      id: 'failure_recover',
      question: 'どうやってリカバリーしますか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'やり直す',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '別の方法',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '時間をかける',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'failure_help': Scenario(
      id: 'failure_help',
      question: '誰かに相談できそうですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'できる',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '考える',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '難しい',
          type: BubbleType.bad,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'failure_support': Scenario(
      id: 'failure_support',
      question: '一人で抱え込まないでくださいね。今日はゆっくり休めますか？',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(
          text: 'はい',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'わからない',
          type: BubbleType.bad,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '考える',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'bad_relation': Scenario(
      id: 'bad_relation',
      question: 'どんなことがありましたか？',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(
          text: '意見の違い',
          type: BubbleType.bad,
          nextScenarioId: 'relation_solve',
        ),
        ScenarioOption(
          text: '誤解',
          type: BubbleType.bad,
          nextScenarioId: 'relation_solve',
        ),
        ScenarioOption(
          text: '距離を感じた',
          type: BubbleType.bad,
          nextScenarioId: 'relation_solve',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'relation_solve',
        ),
      ],
    ),

    'relation_solve': Scenario(
      id: 'relation_solve',
      question: '解決できそうですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: 'できそう',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'わからない',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '難しい',
          type: BubbleType.bad,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    // ========== 明日の予定（TOMORROW PLANNING） ==========
    'tomorrow_plan': Scenario(
      id: 'tomorrow_plan',
      question: '明日の目標は何ですか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '今日の続き',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '新しいこと',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'まだ決めてない',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'tomorrow_different': Scenario(
      id: 'tomorrow_different',
      question: 'どんなことをしたいですか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '新しい趣味',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '別のプロジェクト',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'リフレッシュ',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'tomorrow_rest': Scenario(
      id: 'tomorrow_rest',
      question: 'ゆっくり休んでくださいね。何か楽しみはありますか？',
      emotion: CloudEmotion.neutral,
      options: [
        ScenarioOption(
          text: 'ある',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '探す',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '特にない',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    // ========== 自由入力用ブランチ（FREE INPUT） ==========
    'free_root': Scenario(
      id: 'free_root',
      question: 'そうなんですね。もう少し詳しく教えてもらえますか？',
      emotion: CloudEmotion.thinking,
      options: [
        ScenarioOption(
          text: '良い感じ',
          type: BubbleType.good,
          nextScenarioId: 'good_root',
        ),
        ScenarioOption(
          text: '普通',
          type: BubbleType.normal,
          nextScenarioId: 'normal_root',
        ),
        ScenarioOption(
          text: '辛い',
          type: BubbleType.bad,
          nextScenarioId: 'bad_root',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'free_good': Scenario(
      id: 'free_good',
      question: 'なるほど。それは良かったですね！',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: 'ありがとう',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'そうなんです',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '嬉しい',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    'free_bad': Scenario(
      id: 'free_bad',
      question: 'そうだったんですね。大変でしたね',
      emotion: CloudEmotion.sad,
      options: [
        ScenarioOption(text: 'はい', type: BubbleType.bad, nextScenarioId: 'end'),
        ScenarioOption(
          text: '少し楽になった',
          type: BubbleType.normal,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: 'ありがとう',
          type: BubbleType.good,
          nextScenarioId: 'end',
        ),
        ScenarioOption(
          text: '自由入力',
          type: BubbleType.freeInput,
          nextScenarioId: 'end',
        ),
      ],
    ),

    // ========== 終了（END） ==========
    'end': Scenario(
      id: 'end',
      question: '教えてくれてありがとう。日誌を記録しますか？',
      emotion: CloudEmotion.happy,
      options: [
        ScenarioOption(
          text: '記録する',
          type: BubbleType.good,
          nextScenarioId: 'finish',
        ),
        ScenarioOption(
          text: 'まだ続ける',
          type: BubbleType.normal,
          nextScenarioId: 'root',
        ),
      ],
    ),
  };

  /// 指定されたIDのシナリオを取得します。見つからない場合はrootを返します。
  static Scenario getScenario(String id) {
    return scenarios[id] ?? scenarios['root']!;
  }
}

// -----------------------------------------------------------------------------
// 3. サービス (Services)
// 音、AI（要約・感情分析）、データ保存などの機能を担当します。
// -----------------------------------------------------------------------------

/// 音とバイブレーションを管理するクラスです
class SoundManager {
  static AudioPlayer? _audioPlayer;
  static AudioPlayer get audioPlayer => _audioPlayer ??= AudioPlayer();
  static const bool _useCustomSound = false;

  /// バブルが弾ける音を再生します
  static Future<void> playBubblePop() async {
    try {
      if (_useCustomSound) {
        await audioPlayer.play(AssetSource('sounds/bubble_pop.mp3'));
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (e) {
      await SystemSound.play(SystemSoundType.click);
    }
  }

  /// 短いバイブレーションを実行します
  static Future<void> vibrate() async {
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        await Vibration.vibrate(duration: 50);
      }
    } catch (e) {
      debugPrint('Vibration error: $e');
    }
  }

  /// バブルがタップされた時の効果音と振動を同時に実行します
  static Future<void> onBubbleTap() async {
    await Future.wait([playBubblePop(), vibrate()]);
  }

  static Future<void> dispose() async {
    await _audioPlayer?.dispose();
  }
}

/// AIのような処理（要約や感情分析のシミュレーション）を行うクラスです
class AIService {
  // AIが生成する可能性のある要約メッセージ
  static Future<String> generateSummary(int score) async {
    await Future.delayed(const Duration(seconds: 1)); // 処理待ちのシミュレート

    if (score > 1000) {
      return "今日は素晴らしい一日でしたね！ポジティブなエネルギーに満ち溢れています。この調子で明日も楽しみましょう。";
    } else if (score > 500) {
      return "穏やかな一日だったようですね。無理せず自分のペースで過ごせたことが素晴らしいです。";
    } else {
      return "少し疲れが溜まっているかもしれません。今日はゆっくり休んで、自分を労ってあげてください。";
    }
  }

  // スコアに基づいたタグの生成
  static List<String> generateTags(int score) {
    if (score > 1000) {
      return ['#絶好調', '#達成感', '#笑顔'];
    } else if (score > 500) {
      return ['#穏やか', '#マイペース', '#順調'];
    } else {
      return ['#お疲れ気味', '#休息が必要', '#頑張った'];
    }
  }

  // 入力テキストから感情を分析（シミュレート）
  static CloudEmotion analyzeEmotion(String input) {
    if (input.contains('良い') || input.contains('楽し') || input.contains('嬉し')) {
      return CloudEmotion.happy;
    } else if (input.contains('悪い') ||
        input.contains('疲') ||
        input.contains('悲')) {
      return CloudEmotion.sad;
    } else if (input.contains('考') || input.contains('？')) {
      return CloudEmotion.thinking;
    }
    return CloudEmotion.neutral;
  }
}

/// データの保存と読み込み（永続化）を管理するクラスです
class StorageService {
  static const String _diaryEntriesKey = 'diary_entries';

  /// 日誌エントリを保存します
  static Future<void> saveDiaryEntry(DiaryEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await getAllDiaryEntries();

    // 同じ日のエントリがあれば削除して上書きします
    entries.removeWhere((e) => _isSameDay(e.date, entry.date));
    entries.add(entry);

    // 日付順（新しい順）に並べ替えます
    entries.sort((a, b) => b.date.compareTo(a.date));

    final jsonList = entries.map((e) => e.toJson()).toList();
    await prefs.setString(_diaryEntriesKey, jsonEncode(jsonList));
  }

  /// すべての日誌エントリを取得します
  static Future<List<DiaryEntry>> getAllDiaryEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_diaryEntriesKey);

    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((json) => DiaryEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// 特定の日付のエントリを取得します
  static Future<DiaryEntry?> getDiaryEntryByDate(DateTime date) async {
    final entries = await getAllDiaryEntries();
    try {
      return entries.firstWhere((entry) => _isSameDay(entry.date, date));
    } catch (e) {
      return null;
    }
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

// -----------------------------------------------------------------------------
// 4. デザインとテーマ (Design & Theme)
// アプリの色やフォント、全体のスタイルを定義します。
// -----------------------------------------------------------------------------

/// アプリで使用する色の定数です
class AppColors {
  static const Color primary = Color(0xFFE3F2FD); // メインの薄い青
  static const Color secondary = Color(0xFFFFF9C4); // サブの薄い黄
  static const Color accent = Color(0xFFF8BBD0); // アクセントの薄いピンク

  static const Color textPrimary = Color(0xFF1A237E); // 基本の文字色
  static const Color textSecondary = Color(0xFF5C6BC0); // 補足の文字色

  static const Color bubbleGood = Color(0xFFE8F5E9); // 良いバブルの色
  static const Color bubbleNormal = Color(0xFFE3F2FD); // 普通バブルの色
  static const Color bubbleBad = Color(0xFFFBE9E7); // 悪いバブルの色
  static const Color bubbleFree = Color(0xFFE1F5FE); // 自由入力バブルの色
}

/// アプリ全体のデザインテーマを定義します
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: Color(0xFF1A1A1A),
        elevation: 0,
        toolbarHeight: 56.0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 20.0,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          elevation: 2,
        ),
      ),
      textTheme: GoogleFonts.sawarabiGothicTextTheme().copyWith(
        displayLarge: GoogleFonts.sawarabiGothic(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
        bodyLarge: GoogleFonts.sawarabiGothic(
          fontSize: 18,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 5. 状態管理 (State Management - Riverpod)
// ゲームの進行状況（スコア、バブル、会話履歴）を管理します。
// -----------------------------------------------------------------------------

/// ゲームの現在の状態を保持するデータクラスです
class GameState {
  final List<BubbleModel> bubbles;
  final String currentQuestion;
  final CloudEmotion currentEmotion;
  final String currentScenarioId;
  final int score;
  final int combo;
  final List<ConversationEntry> conversationHistory;
  final bool isGameOver;
  final BubbleSpeed bubbleSpeed;

  GameState({
    required this.bubbles,
    required this.currentQuestion,
    required this.currentEmotion,
    required this.currentScenarioId,
    this.score = 0,
    this.combo = 0,
    this.conversationHistory = const [],
    this.isGameOver = false,
    this.bubbleSpeed = BubbleSpeed.normal,
  });

  // 状態の一部だけを変更した新しいGameStateを作成します（イミュータブルな設計）
  GameState copyWith({
    List<BubbleModel>? bubbles,
    String? currentQuestion,
    CloudEmotion? currentEmotion,
    String? currentScenarioId,
    int? score,
    int? combo,
    List<ConversationEntry>? conversationHistory,
    bool? isGameOver,
    BubbleSpeed? bubbleSpeed,
  }) {
    return GameState(
      bubbles: bubbles ?? this.bubbles,
      currentQuestion: currentQuestion ?? this.currentQuestion,
      currentEmotion: currentEmotion ?? this.currentEmotion,
      currentScenarioId: currentScenarioId ?? this.currentScenarioId,
      score: score ?? this.score,
      combo: combo ?? this.combo,
      conversationHistory: conversationHistory ?? this.conversationHistory,
      isGameOver: isGameOver ?? this.isGameOver,
      bubbleSpeed: bubbleSpeed ?? this.bubbleSpeed,
    );
  }
}

/// ゲームの状態を操作するロジックを担当するクラスです
class GameNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return _createInitialState();
  }

  // 初期状態を作成します
  GameState _createInitialState() {
    final scenario = ScenarioData.getScenario('root');
    // 初期化時はデフォルトの速度を使用
    final bubbles = _generateBubblesFromScenario(scenario, BubbleSpeed.normal);
    return GameState(
      bubbles: bubbles,
      currentQuestion: scenario.question,
      currentEmotion: scenario.emotion,
      currentScenarioId: scenario.id,
    );
  }

  /// バブルの速度設定を変更します
  void setBubbleSpeed(BubbleSpeed speed) {
    state = state.copyWith(bubbleSpeed: speed);
    // 既存のバブルも新しい速度で再生成します
    final scenario = ScenarioData.getScenario(state.currentScenarioId);
    final newBubbles = _generateBubblesFromScenario(scenario, speed);
    state = state.copyWith(bubbles: newBubbles);
  }

  // 速度設定に応じた倍率を返します
  static double _getSpeedMultiplier(BubbleSpeed speed) {
    switch (speed) {
      case BubbleSpeed.slow:
        return 0.3;
      case BubbleSpeed.normal:
        return 0.7;
      case BubbleSpeed.fast:
        return 1.2;
    }
  }

  // シナリオからバブルのリストを生成します
  List<BubbleModel> _generateBubblesFromScenario(
    Scenario scenario,
    BubbleSpeed speed,
  ) {
    final random = Random();
    final List<BubbleModel> newBubbles = [];
    final int count = scenario.options.length;

    // バブルが重ならないように、円周上に均等に配置するための計算です
    final double baseAngleStep = (2 * pi) / count;
    final double startAngle = random.nextDouble() * 2 * pi;

    for (var i = 0; i < count; i++) {
      final option = scenario.options[i];
      final double jitter = (random.nextDouble() - 0.5) * (baseAngleStep * 0.8);
      final double angle = startAngle + (baseAngleStep * i) + jitter;

      newBubbles.add(
        BubbleModel(
          text: option.text,
          type: option.type,
          initialPosition: Offset.zero,
          size: 80.0 + random.nextDouble() * 40.0,
          angle: angle,
          speed: _getSpeedMultiplier(speed) + random.nextDouble() * 0.3,
        ),
      );
    }
    return newBubbles;
  }

  /// バブルをタップした時の処理です
  Future<void> popBubble(BubbleModel bubble, {String? freeInputContent}) async {
    // 終了処理
    final currentScenario = ScenarioData.getScenario(state.currentScenarioId);
    final option = currentScenario.options.firstWhere(
      (o) => o.text == bubble.text,
    );

    // スコア計算（コンボに応じたボーナス付き）
    int points = 100;
    if (bubble.type == BubbleType.good) points = 150;
    if (bubble.type == BubbleType.bad) points = 50;

    final newCombo = state.combo + 1;
    final bonus = (newCombo > 1) ? (newCombo * 10) : 0;
    final newScore = state.score + points + bonus;

    // 次のシナリオへ
    final nextScenarioId = option.nextScenarioId ?? 'root';

    if (nextScenarioId == 'finish') {
      state = state.copyWith(
        score: newScore,
        combo: newCombo,
        isGameOver: true,
      );
      return;
    }

    final nextScenario = ScenarioData.getScenario(nextScenarioId);
    final newBubbles = _generateBubblesFromScenario(
      nextScenario,
      state.bubbleSpeed,
    );

    // 履歴に追加
    final newHistory = [
      ...state.conversationHistory,
      ConversationEntry(
        question: state.currentQuestion,
        answer: bubble.text,
        freeInputContent: freeInputContent,
      ),
    ];

    state = state.copyWith(
      bubbles: newBubbles,
      currentQuestion: nextScenario.question,
      currentEmotion: nextScenario.emotion,
      currentScenarioId: nextScenarioId,
      score: newScore,
      combo: newCombo,
      conversationHistory: newHistory,
    );
  }

  /// ゲームをリセットします
  void reset() {
    state = _createInitialState();
  }
}

/// Providerを通じて、アプリのどこからでもゲームの状態にアクセスできるようにします
final gameProvider = NotifierProvider<GameNotifier, GameState>(
  GameNotifier.new,
);

// -----------------------------------------------------------------------------
// 6. ウィジェット (Widgets)
// 雲やバブルなど、画面上の個々の部品を定義します。
// -----------------------------------------------------------------------------

/// 質問を表示する雲のウィジェットです
class CloudWidget extends StatelessWidget {
  final String text;
  final CloudEmotion emotion;

  const CloudWidget({super.key, required this.text, required this.emotion});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 雲の形を描画します
          CustomPaint(size: const Size(300, 200), painter: CloudPainter()),
          // 雲の中のテキストと顔アイコン
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildFace(emotion),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 感情に応じた顔アイコンを返します
  Widget _buildFace(CloudEmotion emotion) {
    IconData icon;
    Color color;

    switch (emotion) {
      case CloudEmotion.happy:
        icon = Icons.sentiment_very_satisfied_rounded;
        color = Colors.amber;
        break;
      case CloudEmotion.sad:
        icon = Icons.sentiment_dissatisfied_rounded;
        color = Colors.blueGrey;
        break;
      case CloudEmotion.thinking:
        icon = Icons.lightbulb_outline_rounded;
        color = Colors.orangeAccent;
        break;
      case CloudEmotion.neutral:
        icon = Icons.sentiment_neutral_rounded;
        color = Colors.grey;
        break;
    }

    return Icon(icon, size: 40, color: color);
  }
}

/// 雲の形を数学的に描画するクラスです
class CloudPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final path = Path();

    // ベジェ曲線を使って雲のモコモコ感を表現します
    path.moveTo(size.width * 0.2, size.height * 0.7);
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.8,
      size.width * 0.05,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 0.0,
      size.height * 0.4,
      size.width * 0.15,
      size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 0.2,
      size.height * 0.1,
      size.width * 0.4,
      size.height * 0.15,
    );
    path.quadraticBezierTo(
      size.width * 0.5,
      size.height * 0.0,
      size.width * 0.6,
      size.height * 0.15,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.1,
      size.width * 0.85,
      size.height * 0.3,
    );
    path.quadraticBezierTo(
      size.width * 1.0,
      size.height * 0.4,
      size.width * 0.95,
      size.height * 0.6,
    );
    path.quadraticBezierTo(
      size.width * 1.0,
      size.height * 0.8,
      size.width * 0.8,
      size.height * 0.7,
    );
    path.quadraticBezierTo(
      size.width * 0.7,
      size.height * 0.9,
      size.width * 0.5,
      size.height * 0.85,
    );
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.9,
      size.width * 0.2,
      size.height * 0.7,
    );

    path.close();

    // 影を描いて立体感を出します
    canvas.drawPath(
      path.shift(const Offset(2, 4)),
      Paint()
        ..color = Colors.black12
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// ふわふわ動くバブルウィジェットです
class BubbleWidget extends StatefulWidget {
  final BubbleModel bubble;
  final VoidCallback onPop;
  final bool isExiting; // 画面から消える時のフラグ
  final bool isTapped; // 自分がタップされたバブルかどうかのフラグ

  const BubbleWidget({
    super.key,
    required this.bubble,
    required this.onPop,
    this.isExiting = false,
    this.isTapped = false,
  });

  @override
  State<BubbleWidget> createState() => _BubbleWidgetState();
}

class _BubbleWidgetState extends State<BubbleWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _distanceAnimation;

  @override
  void initState() {
    super.initState();
    // バブルの速度設定に基づいて、アニメーションの時間を計算します
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: (10 / widget.bubble.speed).round()),
    );

    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );

    // 中心から外側に向かって移動するアニメーション
    _distanceAnimation = Tween<double>(begin: 0, end: 400).animate(_controller)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (!isTesting) {
            _controller.repeat(); // 画面端まで行ったらまた中心から出てきます
          }
        }
      });

    if (!isTesting) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bubbleColor;

    // バブルの種類に応じて色を変えます
    switch (widget.bubble.type) {
      case BubbleType.good:
        bubbleColor = AppColors.bubbleGood;
        break;
      case BubbleType.freeInput:
        bubbleColor = AppColors.bubbleFree;
        break;
      case BubbleType.normal:
        bubbleColor = AppColors.bubbleNormal;
        break;
      case BubbleType.bad:
        bubbleColor = AppColors.bubbleBad;
        break;
    }

    Widget content = Container(
      width: widget.bubble.size,
      height: widget.bubble.size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bubbleColor,
        boxShadow: [
          BoxShadow(
            color: bubbleColor.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
        // グラデーションでバブルの透明感を出します
        gradient: RadialGradient(
          colors: [Colors.white.withValues(alpha: 0.8), bubbleColor],
          center: const Alignment(-0.3, -0.3),
          radius: 1.2,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            widget.bubble.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: widget.bubble.size * 0.2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    // 良いバブルや自由入力バブルは、特別に少し震える（パルス）アニメーションを追加します
    final isTesting = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    if ((widget.bubble.type == BubbleType.good ||
            widget.bubble.type == BubbleType.freeInput) &&
        !isTesting) {
      content = content
          .animate(onPlay: (controller) => controller.repeat(reverse: true))
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
            duration: 1.seconds,
          );
    }

    // タップされた時や次の質問に移る時の「消える」アニメーション
    if (widget.isExiting) {
      if (widget.isTapped) {
        // パチンと弾けるようなアニメーション
        content = content
            .animate()
            .scale(
              end: const Offset(3.0, 3.0),
              duration: 250.ms,
              curve: Curves.easeOut,
            )
            .fadeOut(duration: 250.ms);
      } else {
        // 他のバブルはふわっと消えます
        content = content
            .animate()
            .fadeOut(duration: 400.ms)
            .scale(end: const Offset(0.8, 0.8), duration: 400.ms);
      }
    }

    // 移動のアニメーションを適用して描画します
    return AnimatedBuilder(
      animation: _distanceAnimation,
      builder: (context, child) {
        final distance = _distanceAnimation.value;
        final dx = cos(widget.bubble.angle) * distance;
        final dy = sin(widget.bubble.angle) * distance;

        // 出現時と消滅時にふわっと不透明度とスケールを変えます（中央から拡大して外に広がる）
        double opacity = 1.0;
        double scale = 1.0;
        if (distance < 60) {
          opacity = distance / 60;
          scale = (distance / 60).clamp(0.1, 1.0);
        } else if (distance > 350) {
          opacity = 1.0 - ((distance - 350) / 50);
        }

        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: scale,
            child: Opacity(opacity: opacity.clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.isExiting ? null : widget.onPop,
        child: content,
      ),
    );
  }
}

// 利用者共通ヘッダー（設定・使い方）
Widget buildDailyReportUserHeader(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 12.0),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OutlinedButton.icon(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF002850),
            side: BorderSide(color: const Color(0xFF002850).withOpacity(0.5)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          icon: const Icon(Icons.settings, size: 18),
          label: const Text('設定'),
        ),
        PopupMenuButton<String>(
          color: Colors.white,
          surfaceTintColor: Colors.white,
          onSelected: (String value) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: const Color(0xFF002850),
                content: Text('$value が選択されました', style: const TextStyle(color: Colors.white)),
                duration: const Duration(seconds: 2),
              ),
            );
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: '使い方１',
              child: Text('使い方１', style: TextStyle(color: Color(0xFF002850))),
            ),
            const PopupMenuItem<String>(
              value: '使い方２',
              child: Text('使い方２', style: TextStyle(color: Color(0xFF002850))),
            ),
            const PopupMenuItem<String>(
              value: '使い方３',
              child: Text('使い方３', style: TextStyle(color: Color(0xFF002850))),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(color: const Color(0xFF002850).withOpacity(0.5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.help_outline, size: 18, color: Color(0xFF002850)),
                SizedBox(width: 6),
                Text('使い方', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF002850))),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF002850)),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// 7. スクリーン (Screens)
// アプリのメインとなる各画面（ゲーム画面、結果画面、カレンダー画面）を定義します。
// -----------------------------------------------------------------------------

/// ゲームをプレイするメイン画面です
class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  String? _tappedBubbleId; // タップされたバブルを追跡します
  bool _isExiting = false; // 次の質問への移行中かどうか

  // バブルが弾ける時のアニメーション処理
  Future<void> _handlePop(BubbleModel bubble) async {
    setState(() {
      _tappedBubbleId = bubble.id;
      _isExiting = true;
    });

    // 音と振動を実行
    await SoundManager.onBubbleTap();

    // 自由入力バブルの場合
    if (bubble.type == BubbleType.freeInput) {
      final content = await _showFreeInputDialog();
      if (content != null && content.isNotEmpty) {
        await ref
            .read(gameProvider.notifier)
            .popBubble(bubble, freeInputContent: content);
      }
    } else {
      // アニメーションを待機（250ms）
      await Future.delayed(250.ms);
      await ref.read(gameProvider.notifier).popBubble(bubble);
    }

    if (mounted) {
      setState(() {
        _tappedBubbleId = null;
        _isExiting = false;
      });
    }
  }

  // 自由入力用のダイアログを表示します
  Future<String?> _showFreeInputDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('今の気持ちを自由に書いてください'),
            content: TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: '例：今日は集中できた、少し疲れた など',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('キャンセル'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(controller.text),
                child: const Text('決定'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(gameProvider);

    // ゲーム終了時は結果画面へ自動遷移します
    if (gameState.isGameOver) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ResultScreen(gameState: gameState),
          ),
        );
        ref.read(gameProvider.notifier).reset();
      });
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
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
      },
      child: Scaffold(
      appBar: AppBar(
        title: const Text(
          '日報作成',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        toolbarHeight: 56.0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: Colors.grey.shade200, height: 1.0),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.calendar_month,
              color: AppColors.textPrimary,
              size: 28,
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CalendarScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFBFDFFF)],
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  buildDailyReportUserHeader(context),
                  SizedBox(
                    height: constraints.maxHeight,
                    child: Stack(
                      children: [
                        // 中央に配置された雲（質問）
                        Center(
                          child: CloudWidget(
                            text: gameState.currentQuestion,
                            emotion: gameState.currentEmotion,
                          ),
                        ),

          // 周囲に浮かぶバブル
          ...gameState.bubbles.map((bubble) {
            final isTapped = _tappedBubbleId == bubble.id;
            return Center(
              child: BubbleWidget(
                key: ValueKey(bubble.id),
                bubble: bubble,
                isExiting: _isExiting,
                isTapped: isTapped,
                onPop: () => _handlePop(bubble),
              ),
            );
          }),

          // 右上のメニュー（速度設定、スコア）
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // 速度設定ボタン
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSpeedButton(
                        ref,
                        BubbleSpeed.slow,
                        "遅く",
                        gameState.bubbleSpeed,
                      ),
                      _buildSpeedButton(
                        ref,
                        BubbleSpeed.normal,
                        "普通",
                        gameState.bubbleSpeed,
                      ),
                      _buildSpeedButton(
                        ref,
                        BubbleSpeed.fast,
                        "速く",
                        gameState.bubbleSpeed,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 現在のスコアとコンボ表示
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Score: ${gameState.score}',
                      style: GoogleFonts.sawarabiGothic(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (gameState.combo > 1)
                      Text(
                        '${gameState.combo} Combo!',
                        style: GoogleFonts.sawarabiGothic(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // 終了ボタン（会話が完了していない場合でも途中で終了できます）
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (context) => ResultScreen(gameState: gameState),
                    ),
                  );
                  ref.read(gameProvider.notifier).reset();
                },
                child: Text(
                  '今日はここまでにする',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
),
            );
          },
        ),
      ),
    ),
  );
}

  // 速度変更ボタンを構築するヘルパーメソッドです
  Widget _buildSpeedButton(
    WidgetRef ref,
    BubbleSpeed speed,
    String label,
    BubbleSpeed currentSpeed,
  ) {
    final isSelected = speed == currentSpeed;
    return GestureDetector(
      onTap: () {
        ref.read(gameProvider.notifier).setBubbleSpeed(speed);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.textPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

/// ゲーム終了後の結果を表示する画面です
class ResultScreen extends StatefulWidget {
  final GameState gameState;

  const ResultScreen({super.key, required this.gameState});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isSaving = false;

  // 日誌を保存する処理
  Future<void> _saveDiaryEntry(GameState gameState) async {
    try {
      final summary = await AIService.generateSummary(gameState.score);
      final tags = AIService.generateTags(gameState.score);

      final entry = DiaryEntry(
        id: const Uuid().v4(),
        date: DateTime.now(),
        score: gameState.score,
        emotion: gameState.currentEmotion,
        conversationHistory: gameState.conversationHistory,
        aiSummary: summary,
        tags: tags,
      );
      await StorageService.saveDiaryEntry(entry);
    } catch (e) {
      debugPrint('保存に失敗しました: $e');
    }
  }

  Future<void> _handleSave() async {
    setState(() {
      _isSaving = true;
    });

    await _saveDiaryEntry(widget.gameState);

    if (mounted) {
      // カレンダー画面に遷移（バックスタックをリセットしてGameScreenを配置し、その上にCalendarScreenを重ねる）
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const GameScreen()),
        (route) => false,
      );
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const CalendarScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFBFDFFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            '今日の結果',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          toolbarHeight: 56.0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              buildDailyReportUserHeader(context),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // スコア表示
                    _buildScoreSection(),
                    const SizedBox(height: 32),

                    // AIによる要約セクション（FutureBuilderを使って非同期で取得）
                    FutureBuilder<String>(
                      future: AIService.generateSummary(widget.gameState.score),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        return _buildAISection(snapshot.data ?? "");
                      },
                    ),
                    const SizedBox(height: 32),

                    // 会話履歴セクション
                    _buildHistorySection(),
                    const SizedBox(height: 40),

                    // ホームに戻るボタン
                    ElevatedButton(
                      onPressed: _isSaving ? null : _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      child:
                          _isSaving
                              ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                              : const Text('これを記録する'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreSection() {
    return Column(
      children: [
        const Text('今回のスコア', style: TextStyle(fontSize: 16)),
        Text(
          '${widget.gameState.score}',
          style: GoogleFonts.outfit(
            fontSize: 64,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildAISection(String summary) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.textPrimary),
              SizedBox(width: 8),
              Text('AIからのメッセージ', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(summary),
        ],
      ),
    );
  }

  Widget _buildHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '振り返り',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...widget.gameState.conversationHistory.map(
          (entry) => _buildHistoryCard(entry),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(ConversationEntry entry) {
    return buildQAHistoryCard(entry);
  }
}

/// 利用者のトップページ（作業選択と各種メニューへのナビゲーション）
class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final List<String> _workOptions = [
    'イラスト',
    'DTM',
    '３Dモデリング',
    'Web制作',
    'プログラミング',
    'データ入力',
    'その他',
  ];
  late String _selectedWork;

  @override
  void initState() {
    super.initState();
    _selectedWork = _workOptions.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '日報作成',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
          ),
        ),
        toolbarHeight: 56.0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFBFDFFF)],
          ),
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 12.0, left: 16.0, right: 16.0, bottom: 24.0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 「設定」「使い方」トップヘッダー (管理者カラー: ブルー)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF002850),
                          side: BorderSide(color: const Color(0xFF002850).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('設定'),
                      ),
                      PopupMenuButton<String>(
                        color: Colors.white,
                        surfaceTintColor: Colors.white,
                        onSelected: (String value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: const Color(0xFF002850),
                              content: Text('$value が選択されました', style: const TextStyle(color: Colors.white)),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: '使い方１',
                            child: Text('使い方１', style: TextStyle(color: Color(0xFF002850))),
                          ),
                          const PopupMenuItem<String>(
                            value: '使い方２',
                            child: Text('使い方２', style: TextStyle(color: Color(0xFF002850))),
                          ),
                          const PopupMenuItem<String>(
                            value: '使い方３',
                            child: Text('使い方３', style: TextStyle(color: Color(0xFF002850))),
                          ),
                        ],
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.0),
                            border: Border.all(color: const Color(0xFF002850).withOpacity(0.5)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.help_outline, size: 18, color: Color(0xFF002850)),
                              SizedBox(width: 6),
                              Text('使い方', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF002850))),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF002850)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // タイトルエリア
                Text(
                  '今日の作業選択',
                  style: GoogleFonts.sawarabiGothic(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF002850),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '今日取り組む作業を選択して日報を始めましょう',
                  style: GoogleFonts.sawarabiGothic(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 36),

                // 作業選択カード
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.work_outline, color: Color(0xFF002850)),
                            SizedBox(width: 8),
                            Text(
                              '今日の作業内容',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF002850),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF002850).withValues(alpha: 0.3)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedWork,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF002850)),
                              items: _workOptions.map((String work) {
                                return DropdownMenuItem<String>(
                                  value: work,
                                  child: Text(
                                    work,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF002850),
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                if (newValue != null) {
                                  setState(() {
                                    _selectedWork = newValue;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 日報入力スタートボタン
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF002850),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GameScreen(),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_circle_fill, size: 24),
                      SizedBox(width: 8),
                      Text(
                        '日報作成をはじめる',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // カレンダー履歴へのリンクカード
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalendarScreen(),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Color(0xFFE0F2FE),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_month,
                            color: Color(0xFF0284C7),
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'カレンダー履歴',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF002850),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                '過去の日報や記録を確認します',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Color(0xFF002850),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
    );
  }
}

/// 過去の日誌を表示するカレンダー画面です
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, DiaryEntry> _entries = {};
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEntries();
  }

  // 保存されているすべての日誌を読み込みます
  Future<void> _loadEntries() async {
    final entries = await StorageService.getAllDiaryEntries();
    final Map<DateTime, DiaryEntry> entryMap = {};
    for (var entry in entries) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);
      entryMap[date] = entry;
    }
    setState(() => _entries = entryMap);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFFFF), Color(0xFFBFDFFF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text(
            'カレンダー履歴',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 20.0,
              fontWeight: FontWeight.bold,
            ),
          ),
          toolbarHeight: 56.0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              buildDailyReportUserHeader(context),
              // カレンダーウィジェット
                    TableCalendar(
                      firstDay: DateTime.utc(2024, 1, 1),
                      lastDay: DateTime.utc(2030, 12, 31),
                      focusedDay: _focusedDay,
                      calendarFormat: _calendarFormat,
                      availableGestures: AvailableGestures.horizontalSwipe,
                      onFormatChanged: (format) {
                        setState(() {
                          _calendarFormat = format;
                        });
                      },
                      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });
                      },
                      // 日誌がある日にマーク（ドット）を表示します
                      eventLoader: (day) {
                        final d = DateTime(day.year, day.month, day.day);
                        return _entries.containsKey(d) ? [true] : [];
                      },
                      calendarStyle: const CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: BoxDecoration(
                          color: AppColors.textPrimary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    const Divider(),
                    // 選択された日の内容を表示
                    Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: _buildEntryDetail(_selectedDay),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

  Widget _buildEntryDetail(DateTime? day) {
    if (day == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('日付を選択してください')),
      );
    }

    final dateKey = DateTime(day.year, day.month, day.day);
    final entry = _entries[dateKey];

    if (entry == null) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: Text('この日の記録はありません')),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Score: ${entry.score}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Text(
            entry.aiSummary ?? "",
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: entry.tags.map((tag) => Chip(label: Text(tag))).toList(),
          ),
          if (entry.conversationHistory.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              '振り返り (Q&A)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF002850),
              ),
            ),
            const SizedBox(height: 12),
            ...entry.conversationHistory.map((qa) => buildQAHistoryCard(qa)),
          ],
        ],
      ),
    );
  }
}

/// Q&Aの振り返りカードウィジェット（白背景 #FFFFFF、角丸、影付き）
Widget buildQAHistoryCard(ConversationEntry entry) {
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.blue.shade100),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Q: ${entry.question}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF002850),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A: ${entry.answer}',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        if (entry.freeInputContent != null) ...[
          const SizedBox(height: 6),
          Text(
            '内容: ${entry.freeInputContent}',
            style: const TextStyle(
              fontStyle: FontStyle.italic,
              color: Colors.black87,
              fontSize: 13,
            ),
          ),
        ],
      ],
    ),
  );
}

// -----------------------------------------------------------------------------
// 8. アプリの起動 (App Entry Point)
// アプリ全体の初期設定と開始地点です。
// -----------------------------------------------------------------------------

void main() {
  // Flutterの初期設定を確実に実行します
  WidgetsFlutterBinding.ensureInitialized();

  // 画面の向きを縦に固定します
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // RiverpodのProviderScopeでアプリを包み、メインのウィジェットを起動します
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日報作成',
      debugShowCheckedModeBanner: false, // 右上のデバッグラベルを非表示にします
      theme: AppTheme.lightTheme, // 定義したテーマを適用します
      home: const LoginScreen(
        appName: '日報作成',
        originalHome: UserHomeScreen(),
      ), // 最初に表示する画面
    );
  }
}
