import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_config.dart';
import '../core/app_theme.dart';
import '../core/character_pose.dart';
import '../data/mishear_repository.dart';
import '../data/mishear_rule.dart';
import '../data/telemetry_store.dart';
import '../data/wife_identity.dart';
import '../services/lottery_generator.dart';
import '../services/mishear_engine.dart';
import '../services/name_mishearer.dart';
import '../services/speech_service.dart';
import '../services/transcript_uploader.dart';
import 'widgets/character_renderer.dart';
import 'widgets/character_stage.dart';
import 'widgets/dialogue_bubble.dart';
import 'widgets/language_pack_sheet.dart';
import 'widgets/naming_sheet.dart';
import 'widgets/notice_sheet.dart';
import 'widgets/push_to_talk_button.dart';
import 'widgets/telemetry_sheet.dart';

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

  /// 逐字稿回傳。端點沒設定或使用者關掉時，record() 什麼都不做。
  TranscriptUploader? _uploader;
  TelemetryStore? _telemetryStore;
  final WifeIdentityStore _identityStore = WifeIdentityStore();
  final Random _random = Random();

  MishearEngine? _engine;
  MishearConfig? _config;
  NameMishearer? _nameMishearer;

  /// 她的名字與互動次數。沒有名字是完全合法的狀態，取名從頭到尾都不強制。
  WifeIdentity _identity = WifeIdentity.empty;

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

  /// 這一輪辨識引擎回報的錯誤代碼；有值代表「不是聽不懂，是根本沒辨識成功」
  String? _sttError;

  /// 按下去之後、真正開始收音之前的準備期
  bool _warmingUp = false;

  /// 這一輪是使用者在暖機期間就放手而中止的——不是錯誤，不要報錯
  bool _abortedBeforeListening = false;

  /// 取名模式：這一輪聽到的話要當名字解讀，不走諧音梗比對
  bool _naming = false;

  /// 上一輪命中的規則 id，讓她的台詞能接上前一個狀態（見 MishearRule.linesWhen）。
  /// 只活在記憶體裡——重開 App 就是新的一天。
  String? _lastRuleId;

  /// 她主動開口要名字的計時器（讓上一輪的反應先演完）
  Timer? _offerTimer;

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
    _offerTimer?.cancel();
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

  /// 啟動時的準備：讀設定檔、掃描角色素材
  Future<void> _bootstrap() async {
    // 先問辨識器它怎麼稱呼中文（不需要權限），讓第一次按下說話鈕不用等
    unawaited(_speech.prewarm());

    final config = await _repository.load();
    final telemetry = await SharedPrefsTelemetryStore.open();
    final assets = await resolveCharacterAssets();
    final identity = await _identityStore.load();
    if (!mounted) return;
    setState(() {
      _config = config;
      _engine = MishearEngine(config);
      _nameMishearer = NameMishearer(config.naming, random: _random);
      _assets = assets;
      _identity = identity;
      _telemetryStore = telemetry;
      _uploader = TranscriptUploader(store: telemetry);
      _ready = true;
      if (identity.hasName) {
        _line = '${identity.name}在這裡～按住下面的按鈕，跟我說說話吧。';
      }
    });

    // 首次啟動告知一次「會回傳文字」。預設是開的，所以這個面板是義務，
    // 不是禮貌——而且要讓人當場關得掉。端點沒設定時不用擾民。
    if (TranscriptUploader(store: telemetry).active && !telemetry.noticeShown) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showTelemetryNotice(context, telemetry);
      });
    }

    unawaited(_uploader?.flush() ?? Future.value());
  }

  // ── 按住說話 ──────────────────────────────────────────────

  Future<void> _onPressStart() async {
    if (!_ready || _listening || _warmingUp) return;
    _pressing = true;
    _abortedBeforeListening = false;

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

    final error = _sttError;

    // 取名模式：這一輪聽到的是名字，走另一條路。
    // 例外是缺語言包——那不是取名的問題，讓它掉到下面原本的救援流程。
    if (_naming) {
      if (error == null || !_isLanguagePackError(error)) {
        _resolveNaming();
        return;
      }
      _naming = false;
    }

    // 引擎報錯而且什麼都沒聽到 → 誠實說壞了，不要假裝在裝傻
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
      return;
    }

    // 要求取名的優先序在諧音梗之前：它不是一種反應，而是一段要再聽一次話的流程
    if (engine.isNamingRequest(_transcript)) {
      _enterNamingMode(spoken: _transcript);
      return;
    }

    final result = engine.interpret(_transcript, previousRuleId: _lastRuleId);
    final rule = result.rule;
    _lastRuleId = rule.id;

    // 回傳這一輪聽到了什麼。不 await——她該立刻反應，不能等 HTTP。
    // 取名流程在上面就 return 了，所以名字不會經過這裡。
    unawaited(_uploader?.record(
          transcript: _transcript,
          matched: result.matched,
          ruleId: result.matched ? rule.id : null,
        ) ??
        Future.value());

    setState(() {
      _listening = false;
      _pose = characterPoseFromTrigger(rule.animationTrigger);
      _effect = rule.effect;
      _line = _identity.personalize(result.line);
      _mishearAs = result.matched ? rule.mishearAs : null;
      _spokenShown = _transcript.isEmpty ? null : _transcript;
      // 每次報明牌都重新抽一組
      _draw = rule.effect == StageEffect.lottery ? _lottery.draw() : null;
    });

    _afterInteraction();
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
  }

  // ── 取名 ──────────────────────────────────────────────────
  //
  // 整條線的原則是「隨時可以不取」：她主動問的時候有「再說吧」，被打發了就把
  // 門檻往後推、推滿就不再問；取名流程中每一個面板關掉都會回到正常玩法。
  // 沒有名字時所有台詞照舊（`{name}` 會變成「我」）。

  /// 一輪對話結算完之後：累加互動次數，必要時讓她自己開口要名字
  void _afterInteraction() {
    _identity = _identity.copyWith(interactions: _identity.interactions + 1);
    unawaited(_identityStore.save(_identity));

    if (!_identity.shouldOfferNaming) return;

    // 延遲一下再問，讓上一輪的反應（掃地、明牌卡）先演完
    _offerTimer?.cancel();
    _offerTimer = Timer(AppConfig.namingOfferDelay, () {
      if (mounted && !_listening && !_naming) _offerNaming();
    });
  }

  /// 她自己開口要名字
  Future<void> _offerNaming() async {
    final config = _config;
    if (config == null || _identity.hasName) return;

    final offer = config.naming.offerLine(_random);
    setState(() {
      _line = offer;
      _mishearAs = null;
      _spokenShown = null;
    });

    final action = await showNoticeSheet(
      context,
      emoji: '🏷️',
      title: '要幫我取個名字嗎？',
      message: '取了之後我的台詞會用上這個名字。\n不取也沒關係，你想取的時候再說就好。',
      primaryLabel: '好啊，我來取',
      dismissLabel: '再說吧',
    );
    if (!mounted) return;

    if (action == NoticeAction.primary) {
      _enterNamingMode();
      return;
    }

    // 把面板關掉也算打發。不記下來的話下一輪又問，那就變成強迫了。
    _identity =
        _identity.copyWith(promptDeclines: _identity.promptDeclines + 1);
    unawaited(_identityStore.save(_identity));
    setState(() => _line = '好，那再說。你想取的時候跟我說一聲就好。');
  }

  /// 進入取名模式：下一次按住說話收到的內容會被當成名字
  void _enterNamingMode({String? spoken}) {
    final config = _config;
    if (config == null) return;

    _offerTimer?.cancel();
    HapticFeedback.selectionClick();
    setState(() {
      _naming = true;
      _listening = false;
      _pose = CharacterPose.idle;
      _effect = StageEffect.none;
      _draw = null;
      _mishearAs = null;
      _spokenShown = (spoken == null || spoken.isEmpty) ? null : spoken;
      _line = config.naming.promptLine(_random);
    });
  }

  void _exitNamingMode(String line) {
    if (!mounted) return;
    setState(() {
      _naming = false;
      _pose = CharacterPose.idle;
      _line = line;
      _mishearAs = null;
    });
  }

  /// 取名模式下的結算：把聽到的內容當名字處理
  Future<void> _resolveNaming() async {
    final config = _config;
    final mishearer = _nameMishearer;
    if (config == null || mishearer == null) return;

    final spoken = mishearer.sanitize(_transcript);

    setState(() {
      _listening = false;
      _pose = CharacterPose.idle;
      _spokenShown = _transcript.isEmpty ? null : _transcript;
    });

    // 完全沒聽到 → 直接端出打字，不要讓使用者卡在「再講一次」的迴圈裡
    if (spoken == null) {
      setState(() => _line = config.naming.unheardLine(_random));
      await _askToTypeName();
      return;
    }

    final misheard = mishearer.mishear(spoken);
    final choice = await showNameConfirmSheet(
      context,
      spoken: spoken,
      misheard: misheard,
    );
    if (!mounted) return;

    switch (choice) {
      case NameChoice.misheard:
        await _commitName(misheard!);
        break;
      case NameChoice.spoken:
        await _commitName(spoken);
        break;
      case NameChoice.typeIt:
        await _askToTypeName(initial: spoken);
        break;
      case null:
        _exitNamingMode('好，那名字先空著，我不介意。');
        break;
    }
  }

  Future<void> _askToTypeName({String? initial}) async {
    final typed = await showNameInputSheet(context, initial: initial);
    if (!mounted) return;

    if (typed == null || typed.isEmpty) {
      _exitNamingMode('好，那名字先空著，我不介意。');
      return;
    }
    await _commitName(typed);
  }

  Future<void> _commitName(String name) async {
    final config = _config;
    _identity = _identity.copyWith(name: name);
    await _identityStore.save(_identity);
    if (!mounted) return;

    setState(() {
      _naming = false;
      _pose = CharacterPose.idle;
      _effect = StageEffect.none;
      _mishearAs = null;
      _spokenShown = null;
      _line = _identity.personalize(
        config?.naming.acceptedLine(_random) ?? '{name}…嗯，我喜歡這個名字。',
      );
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
            if (config.naming.keywords.isNotEmpty) ...[
              const Divider(height: 24),
              const Text(
                '幫她取名',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                '說「${config.naming.keywords.first}」，'
                '或長按上面的「${_identity.displayName}」，都可以取名或改名。'
                '${_identity.hasName ? '' : '不取名也完全玩得下去。'}',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: AppTheme.ink.withOpacity(0.6),
                ),
              ),
            ],
            const Divider(height: 24),
            _diagnostics(),
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

  /// 語音辨識診斷資訊。查「為什麼她聽不到」時看這裡，比翻 logcat 快。
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
                !_ready
                    ? '準備中…'
                    : (_naming ? '按住按鈕，把名字說給她聽' : '按住按鈕說話，放開後她會回應'),
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
          // 長按標題就能取名／改名。這是取名環節的保底入口——
          // 她主動問過被打發之後，就只剩這裡和關鍵字兩條路。
          GestureDetector(
            onLongPress: _ready ? () => _enterNamingMode() : null,
            child: Text(
              _identity.displayName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.deepRose,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _ready && _telemetryStore != null
                ? () => showTelemetrySheet(context, _telemetryStore!)
                : null,
            icon: const Icon(Icons.settings_outlined),
            color: AppTheme.deepRose,
            tooltip: '設定',
          ),
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
