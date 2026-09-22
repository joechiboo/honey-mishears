import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/app_theme.dart';

/// 使用者在「你是說…？」面板上挑了哪個名字
enum NameChoice {
  /// 接受她聽錯的版本——這才是這個 App 的精神
  misheard,

  /// 用使用者原本說的那個
  spoken,

  /// 都不對，改用打字
  typeIt,
}

/// 確認名字的面板。
///
/// [misheard] 是她聽成的名字，null 代表她這次剛好聽對了（面板就少一個選項）。
/// 面板被關掉時回 null——取名隨時可以放棄，不取名要能一直玩下去。
Future<NameChoice?> showNameConfirmSheet(
  BuildContext context, {
  required String spoken,
  required String? misheard,
}) {
  final heardRight = misheard == null;

  return showModalBottomSheet<NameChoice>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(heardRight ? '🎀' : '🤔', style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              heardRight ? '「$spoken」對嗎？' : '你是說…「$misheard」？',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              heardRight
                  ? '這次我好像聽對了。'
                  : '我聽到的是「$misheard」。\n你剛剛說的是「$spoken」。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppTheme.ink.withOpacity(0.75),
              ),
            ),
            const SizedBox(height: 22),
            _choiceButton(
              context,
              label: heardRight ? '對，就叫「$spoken」' : '就叫「$misheard」吧',
              choice: heardRight ? NameChoice.spoken : NameChoice.misheard,
              filled: true,
            ),
            if (!heardRight) ...[
              const SizedBox(height: 10),
              _choiceButton(
                context,
                label: '不是，是「$spoken」',
                choice: NameChoice.spoken,
                filled: false,
              ),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(NameChoice.typeIt),
              child: Text(
                '都不對，我自己打',
                style: TextStyle(color: AppTheme.ink.withOpacity(0.6)),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _choiceButton(
  BuildContext context, {
  required String label,
  required NameChoice choice,
  required bool filled,
}) {
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(14));
  const padding = EdgeInsets.symmetric(vertical: 14);
  void select() => Navigator.of(context).pop(choice);

  return SizedBox(
    width: double.infinity,
    child: filled
        ? FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.rose,
              padding: padding,
              shape: shape,
            ),
            onPressed: select,
            child: Text(label),
          )
        : OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.deepRose,
              side: const BorderSide(color: AppTheme.blush, width: 1.5),
              padding: padding,
              shape: shape,
            ),
            onPressed: select,
            child: Text(label),
          ),
  );
}

/// 手動輸入名字的面板。
///
/// 這條路徑不能省：人名的語音辨識連錯三次就不好笑了，
/// 一定要有一個走得通的出口。回 null 代表放棄。
Future<String?> showNameInputSheet(
  BuildContext context, {
  String? initial,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => _NameInputForm(initial: initial),
  );
}

class _NameInputForm extends StatefulWidget {
  const _NameInputForm({this.initial});

  final String? initial;

  @override
  State<_NameInputForm> createState() => _NameInputFormState();
}

class _NameInputFormState extends State<_NameInputForm> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // 鍵盤推上來時面板要跟著上移，不然輸入框會被蓋住
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✍️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text(
            '那你打給我看',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            maxLength: AppConfig.maxWifeNameLength,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 20, color: AppTheme.ink),
            decoration: InputDecoration(
              hintText: '她的名字',
              counterText: '',
              filled: true,
              fillColor: AppTheme.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.blush, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.blush, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppTheme.rose, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.rose,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _controller.text.trim().isEmpty ? null : _submit,
              child: const Text('就叫這個'),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              '算了，先不取',
              style: TextStyle(color: AppTheme.ink.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }
}
