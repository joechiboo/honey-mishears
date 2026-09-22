import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../core/character_pose.dart';
import '../data/mishear_discovery.dart';
import '../data/mishear_repository.dart';
import '../data/mishear_rule.dart';
import '../services/lottery_generator.dart';
import '../services/mishear_engine.dart';
import '../services/speech_service.dart';
import 'widgets/character_renderer.dart';
import 'widgets/character_stage.dart';
import 'widgets/dialogue_bubble.dart';
import 'widgets/language_pack_sheet.dart';
import 'widgets/mishear_codex.dart';
import 'widgets/notice_sheet.dart';
import 'widgets/push_to_talk_button.dart';

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
  final MishearDiscoveryStore _discoveryStore = MishearDiscoveryStore();

  MishearEngine? _engine;
  MishearConfig? _config;

  /// 已經被觸發過的梗。梗圖鑑只攤開這些，其餘留謎面。
  MishearDiscovery _discovery = MishearDiscovery.empty;

  /// 設定檔讀完了沒（讀完才允許按按鈕）
  bool _ready = false;

  /// 掃描到的角色素材：Rive > 圖片 > 佔位角色
  CharacterAssets _assets = CharacterAssets.placeholderOnly;

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

  /// 晾太久之後她自己滑手機。每次互動都重新計時。
  Timer? _idleTimer;
  final Random _random = Random();

  /// 這一輪辨識引擎回報的錯誤代碼；有值代表「不是聽不懂，是根本沒辨識成功」
  String? _sttError;

  /// 按下去之後、真正開始收音之前的準備期
  bool _warmingUp = false;

  /// 這一輪是使用者在暖機期間就放手而中止的——不是錯誤，不要報錯
  bool _abortedBeforeListening = false;

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
    _idleTimer?.cancel();
    _speech.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // 回到前台重新計時：不然切出去泡個茶回來，她已經在滑手機了
      _restartIdleTimer();
      return;
    }

    _idleTimer?.cancel();

    // 切到背景時一定要停掉麥克風，不然系統會一直顯示錄音中
    if (_listening) {
      _speech.cancel();
      setState(() {
        _listening = false;
        _pressing = false;
        _pose = CharacterPose.idle;
      });
    }
  }

  // ── 晾太久 ────────────────────────────────────────────────

  void _restartIdleTimer() {
    _idleTimer?.cancel();
    final idle = _config?.idle;
    if (idle == null || !idle.enabled) return;
    _idleTimer = Timer(idle.after, _goIdle);
  }

  /// 沒人理她夠久了，自己找事做。
  ///
  /// 這不是錯誤也不是裝傻，是她閒著——所以不能走 fallback 那條路，
  /// 也不進梗圖鑑：被撞見的時候才有意思，列在清單上就變成一項功能說明了。
  void _goIdle() {
    final idle = _config?.idle;
    // 計時器在互動一開始就取消了，這裡只是保險：真的還在講話就不要冒出來
    if (!mounted || idle == null || !idle.enabled) return;
    if (_listening || _warmingUp || _pressing) return;

    setState(() {
      _pose = CharacterPose.scrolling;
      _effect = StageEffect.none;
      _draw = null;
      _mishearAs = null;
      _spokenShown = null;
      _line = idle.lines[_random.nextInt(idle.lines.length)];
    });
  }

  /// 啟動時的準備：讀設定檔、掃描角色素材
  Future<void> _bootstrap() async {
    // 先問辨識器它怎麼稱呼中文（不需要權限），讓第一次按下說話鈕不用等
    unawaited(_speech.prewarm());

    final config = await _repository.load();
    final assets = await resolveCharacterAssets();
    final discovery = await _discoveryStore.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _engine = MishearEngine(config);
      _assets = assets;
      _discovery = discovery;
      _ready = true;
    });
    _restartIdleTimer();
  }

  // ── 按住說話 ──────────────────────────────────────────────

  Future<void> _onPressStart() async {
    if (!_ready || _listening || _warmingUp) return;
    _pressing = true;
    _abortedBeforeListening = false;
    _idleTimer?.cancel();

    setState(() {
      _warmingUp = true;
      _line = '等我一下下…';
      _effect = StageEffect.none;
      _draw = null;
      _mishearAs = null;
      _spokenShown = null;
    });

    try {
      // 1. 麥克風權限
      final permission = await _speech.requestPermission();
      if (!mounted) return;
      if (permission != MicPermission.granted) {
        await _showPermissionNotice(permission);
        return;
      }

      // 2. 初始化辨識引擎（第一次按才做，避免一開 App 就跳權限）
      final available = await _speech.initialize(
        onStatus: (status) => debugPrint('[STT] status=$status'),
        onError: _onSpeechError,
      );
      if (!mounted) return;
      if (!available) {
        await showNoticeSheet(
          context,
          emoji: '😢',
          title: '這台裝置沒辦法聽你說話',
          message: '找不到可用的語音辨識服務。',
          primaryLabel: '我知道了',
        );
        return;
      }

      // 3. 暖機期間就放手了 —— 安靜收手，不要 start 完馬上 stop。
      //    之前沒擋這一段，換來 error_client，接著連按再撞 error_busy，
      //    而錯誤訊息把它講成「辨識服務忙碌中」，完全指不到真正的原因。
      if (!_pressing) {
        _abortedBeforeListening = true;
        setState(() => _line = '你放太快了，按住久一點再說話喔。');
        return;
      }

      // 4. 開始收音
      _transcript = '';
      _sttError = null;
      _resolved = false;
      setState(() {
        _listening = true;
        _pose = CharacterPose.listening;
        _line = '嗯嗯，我在聽…';
      });

      await _speech.start(onResult: _onSpeechResult);

      // start() 期間又放手了：直接取消，這一輪沒有任何音訊，不必結算
      if (!_pressing && mounted) {
        _abortedBeforeListening = true;
        _resolved = true;
        await _speech.cancel();
        if (!mounted) return;
        setState(() {
          _listening = false;
          _pose = CharacterPose.idle;
          _line = '你放太快了，按住久一點再說話喔。';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _warmingUp = false);
      } else {
        _warmingUp = false;
      }
    }
  }

  Future<void> _onPressEnd() async {
    _pressing = false;
    // 還在暖機 → 交給 _onPressStart 自己收尾（它會看 _pressing）
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

  /// 辨識引擎回報錯誤。
  ///
  /// 這條路徑一定要跟「聽不懂」分開：引擎報錯時我們根本沒拿到任何文字，
  /// 卻讓角色歪頭裝傻的話，畫面上跟「有聽到但沒命中關鍵字」長得一模一樣，
  /// 使用者（和我們自己）會往錯的方向查。
  void _onSpeechError(String message) {
    debugPrint('[STT] error=$message');

    // 這是我們自己中止造成的，不是使用者需要知道的事
    if (_abortedBeforeListening) return;

    _sttError = message;

    // 錯誤發生時不會再有最終結果，直接結算
    if (!_resolved) {
      _speech.cancel();
      _resolve();
    }
  }

  /// 把引擎的錯誤代碼翻成人看得懂的話
  static String _describeSttError(String code) {
    switch (code) {
      case 'error_language_unavailable':
      case 'error_language_not_supported':
        return '這台手機的語音辨識沒有中文語言包，所以它直接拒絕辨識。';
      case 'error_no_match':
      case 'error_speech_timeout':
        return '有在聽，但沒聽到聽得懂的內容。';
      case 'error_network':
      case 'error_network_timeout':
        return '辨識服務要連網，但連不上。';
      case 'error_audio':
        return '收音失敗，麥克風可能被其他 App 佔用。';
      case 'error_busy':
        return '辨識服務忙碌中，稍等一下再試。';
      default:
        return '辨識服務回報錯誤。';
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

    // 引擎報錯而且什麼都沒聽到 → 誠實說壞了，不要假裝在裝傻
    final error = _sttError;
    if (error != null && _transcript.isEmpty) {
      setState(() {
        _listening = false;
        _pose = CharacterPose.confused;
        _effect = StageEffect.none;
        _draw = null;
        _mishearAs = null;
        _line = _describeSttError(error);
        _spokenShown = '辨識錯誤：$error';
      });

      // 語言包缺失是唯一「使用者自己修得好」的錯誤，直接把下載流程端到他面前
      if (_isLanguagePackError(error)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _offerLanguagePack();
        });
      }
      _restartIdleTimer();
      return;
    }

    final result = engine.interpret(_transcript);
    final rule = result.rule;

    // 命中就解鎖圖鑑那一筆。unlock() 對已解鎖的回傳自己，
    // 所以 identical 就是「這輪是不是第一次發現」，順便省掉重複寫檔。
    final unlocked = result.matched ? _discovery.unlock(rule.id) : _discovery;
    final firstTime = !identical(unlocked, _discovery);

    setState(() {
      _discovery = unlocked;
      _listening = false;
      _pose = characterPoseFromTrigger(rule.animationTrigger);
      _effect = rule.effect;
      _line = result.line;
      _mishearAs = result.matched ? rule.mishearAs : null;
      _spokenShown = _transcript.isEmpty ? null : _transcript;
      // 每次報明牌都重新抽一組
      _draw = rule.effect == StageEffect.lottery ? _lottery.draw() : null;
    });

    if (firstTime) unawaited(_discoveryStore.save(unlocked));
    _restartIdleTimer();
  }

  static bool _isLanguagePackError(String code) =>
      code == 'error_language_unavailable' ||
      code == 'error_language_not_supported';

  /// 缺中文語音包時，帶使用者走完下載流程
  Future<void> _offerLanguagePack() async {
    final ready = await showLanguagePackSheet(
      context,
      locale: _speech.localeId ?? 'zh-TW',
    );
    if (!mounted || !ready) return;

    setState(() {
      _pose = CharacterPose.idle;
      _line = '好了，再按著跟我說一次話吧。';
      _mishearAs = null;
      _spokenShown = null;
    });
    _restartIdleTimer();
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

  // ── 梗圖鑑 ────────────────────────────────────────────────

  void _showCodex() {
    final config = _config;
    if (config == null) return;

    showMishearCodex(
      context,
      config: config,
      discovery: _discovery,
      diagnostics: _diagnostics(),
    );
  }

  /// 語音辨識診斷資訊。查「為什麼她聽不到」時看這裡，比翻 logcat 快。
  /// 藏在梗圖鑑的長按之後，跟整本翻開同一個手勢。
  Widget _diagnostics() {
    final locales = _speech.availableLocales;
    final chinese = locales
        .where((l) => l.toLowerCase().startsWith('zh') || l.toLowerCase().startsWith('cmn'))
        .toList();

    final lines = <String>[
      '辨識引擎：${_speech.isInitialized ? '已初始化' : '尚未初始化（按一次說話鈕）'}',
      '使用語系：${_speech.localeId ?? '系統預設'}',
      '可用語系：${locales.length} 個'
          '${chinese.isEmpty ? '，其中沒有任何中文' : '，中文有 ${chinese.join('、')}'}',
      if (_speech.lastError != null) '最後錯誤：${_speech.lastError}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('語音診斷', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
        const SizedBox(height: 4),
        for (final line in lines)
          Text(
            line,
            style: TextStyle(fontSize: 11, height: 1.5, color: AppTheme.ink.withOpacity(0.6)),
          ),
      ],
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
                  assets: _assets,
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
            onPressed: _ready ? _showCodex : null,
            icon: const Icon(Icons.menu_book_outlined),
            color: AppTheme.deepRose,
            tooltip: '梗圖鑑',
          ),
        ],
      ),
    );
  }
}
