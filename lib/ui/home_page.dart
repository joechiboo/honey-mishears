import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../core/character_pose.dart';
import '../data/mishear_repository.dart';
import '../data/mishear_rule.dart';
import '../services/lottery_generator.dart';
import '../services/mishear_engine.dart';
import '../services/speech_service.dart';
import 'widgets/character_stage.dart';
import 'widgets/dialogue_bubble.dart';
import 'widgets/notice_sheet.dart';
import 'widgets/push_to_talk_button.dart';
import 'widgets/rive_character.dart';

/// 主畫面：角色區 + 台詞對話框 + 按住說話按鈕
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final SpeechService _speech = SpeechService();
  final LotteryGenerator _lottery = LotteryGenerator();
  final MishearRepository _repository = MishearRepository();

  MishearEngine? _engine;
  MishearConfig? _config;

  /// 設定檔讀完了沒（讀完才允許按按鈕）
  bool _ready = false;

  /// Rive 素材是否存在；沒有就用佔位角色
  bool _useRive = false;

  // ── 畫面狀態 ──────────────────────────────────────────────
  CharacterPose _pose = CharacterPose.idle;
  StageEffect _effect = StageEffect.none;
  String _line = '嗨～按住下面的按鈕，跟我說說話吧。';
  String? _mishearAs;
  String? _spokenShown;
  LotteryDraw? _draw;

  // ── 收音流程狀態 ──────────────────────────────────────────
  bool _listening = false;

  /// 手指是否還按著（權限詢問是非同步的，可能還沒開始收音就放開了）
  bool _pressing = false;

  /// 這一輪是否已經結算過，避免最終結果與逾時計時器重複觸發
  bool _resolved = true;

  String _transcript = '';
  Timer? _finalTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finalTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 切到背景時一定要停掉麥克風，不然系統會一直顯示錄音中
    if (state != AppLifecycleState.resumed && _listening) {
      _speech.cancel();
      setState(() {
        _listening = false;
        _pressing = false;
        _pose = CharacterPose.idle;
      });
    }
  }

  /// 啟動時的準備：讀設定檔、確認 Rive 素材在不在
  Future<void> _bootstrap() async {
    final config = await _repository.load();
    final useRive = await isRiveAssetAvailable();
    if (!mounted) return;
    setState(() {
      _config = config;
      _engine = MishearEngine(config);
      _useRive = useRive;
      _ready = true;
    });
  }

  // ── 按住說話 ──────────────────────────────────────────────

  Future<void> _onPressStart() async {
    if (!_ready || _listening) return;
    _pressing = true;

    // 1. 麥克風權限
    final permission = await _speech.requestPermission();
    if (!mounted) return;
    if (permission != MicPermission.granted) {
      _pressing = false;
      await _showPermissionNotice(permission);
      return;
    }

    // 2. 初始化辨識引擎（第一次按才做，避免一開 App 就跳權限）
    final available = await _speech.initialize(
      onStatus: (status) => debugPrint('[STT] status=$status'),
      onError: (message) => debugPrint('[STT] error=$message'),
    );
    if (!mounted) return;
    if (!available) {
      _pressing = false;
      await showNoticeSheet(
        context,
        emoji: '😢',
        title: '這台裝置沒辦法聽你說話',
        message: '找不到可用的語音辨識服務。\n請確認已安裝「Google」App 並在系統設定中啟用語音服務。',
        primaryLabel: '我知道了',
      );
      return;
    }

    // 3. 開始收音
    _transcript = '';
    _resolved = false;
    setState(() {
      _listening = true;
      _pose = CharacterPose.listening;
      _effect = StageEffect.none;
      _draw = null;
      _mishearAs = null;
      _spokenShown = null;
      _line = '嗯嗯，我在聽…';
    });

    await _speech.start(onResult: _onSpeechResult);

    // 權限對話框拖太久，使用者可能已經放開手了
    if (!_pressing) {
      await _onPressEnd();
    }
  }

  Future<void> _onPressEnd() async {
    _pressing = false;
    if (!_listening) return;

    setState(() {
      _listening = false;
      _pose = CharacterPose.idle;
      _line = '……';
    });

    await _speech.stop();

    // 放開後再等一下下最終結果；逾時就用目前拿到的逐字稿結算
    _finalTimer?.cancel();
    _finalTimer = Timer(AppConfig.finalResultTimeout, _resolve);
  }

  void _onSpeechResult(String text, bool isFinal) {
    _transcript = text;

    if (isFinal) {
      _resolve();
      return;
    }

    // 逐字結果：即時顯示，讓使用者知道有在聽
    if (_listening && mounted) {
      setState(() => _spokenShown = text);
    }
  }

  /// 結算這一輪：比對關鍵字 → 切換動畫與台詞
  void _resolve() {
    if (_resolved) return;
    _resolved = true;

    _finalTimer?.cancel();
    _finalTimer = null;

    final engine = _engine;
    if (engine == null || !mounted) return;

    final result = engine.interpret(_transcript);
    final rule = result.rule;

    setState(() {
      _listening = false;
      _pose = characterPoseFromTrigger(rule.animationTrigger);
      _effect = rule.effect;
      _line = result.line;
      _mishearAs = result.matched ? rule.mishearAs : null;
      _spokenShown = _transcript.isEmpty ? null : _transcript;
      // 每次報明牌都重新抽一組
      _draw = rule.effect == StageEffect.lottery ? _lottery.draw() : null;
    });
  }

  // ── 權限提示 ──────────────────────────────────────────────

  Future<void> _showPermissionNotice(MicPermission permission) async {
    final permanentlyDenied = permission == MicPermission.permanentlyDenied;

    final action = await showNoticeSheet(
      context,
      emoji: '🎤',
      title: permanentlyDenied ? '需要你到設定裡開麥克風' : '想聽你說話，需要麥克風權限',
      message: permanentlyDenied
          ? '麥克風權限已被永久拒絕，系統不會再跳出詢問。\n請到「設定 → 應用程式 → AI 老婆 → 權限」把麥克風打開。'
          : '沒有麥克風的話，她就聽不到你說什麼了。\n權限只用來做語音辨識，不會錄音存檔。',
      primaryLabel: permanentlyDenied ? '前往設定' : '再試一次',
    );

    if (action != NoticeAction.primary) return;

    if (permanentlyDenied) {
      await _speech.openSettings();
    } else {
      await _onPressStart();
    }
  }

  // ── 玩法說明（順便當測試用的關鍵字清單）──────────────────

  void _showHowToPlay() {
    final config = _config;
    if (config == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('可以對她說…'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final rule in config.rules) ...[
              Text(
                rule.keywords.join('、'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '→ 她會聽成「${rule.mishearAs}」，然後${rule.label}',
                style: TextStyle(color: AppTheme.ink.withOpacity(0.7)),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              '其他內容她一律歪頭裝傻。',
              style: TextStyle(color: AppTheme.ink.withOpacity(0.5), fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: CharacterStage(
                  pose: _pose,
                  effect: _effect,
                  useRive: _useRive,
                  lotteryDraw: _draw,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DialogueBubble(
                  text: _line,
                  mishearAs: _mishearAs,
                  spokenText: _spokenShown,
                ),
              ),
              const SizedBox(height: 20),
              PushToTalkButton(
                isListening: _listening,
                enabled: _ready,
                onPressStart: _onPressStart,
                onPressEnd: _onPressEnd,
              ),
              const SizedBox(height: 10),
              Text(
                _ready ? '按住按鈕說話，放開後她會回應' : '準備中…',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.ink.withOpacity(0.45),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          const Text(
            AppConfig.appName,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.deepRose,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _ready ? _showHowToPlay : null,
            icon: const Icon(Icons.help_outline),
            color: AppTheme.deepRose,
            tooltip: '玩法',
          ),
        ],
      ),
    );
  }
}
