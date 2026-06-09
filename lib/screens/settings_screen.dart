import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/session.dart';
import '../theme.dart';

/// 설정 화면. iOS 와 Android 가 다른 내용을 보여준다.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('설정', style: TextStyle(letterSpacing: 2)),
      ),
      body: SafeArea(
        child: Platform.isIOS ? const _IosSettings() : const _AndroidSettings(),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// iOS: 단축어/자동화 사용방법 안내 + ping URL + 복사 버튼
// ──────────────────────────────────────────────────────────
class _IosSettings extends StatefulWidget {
  const _IosSettings();

  @override
  State<_IosSettings> createState() => _IosSettingsState();
}

class _IosSettingsState extends State<_IosSettings> {
  String _url = '';

  static const _steps = <String>[
    '단축어 실행',
    '자동화 생성',
    '메시지 클릭',
    '보낸사람 선택',
    "'확인 후 실행'이 되어있는지 확인하고 다음",
    '새로운 단축어 생성',
    'URL 콘텐츠 가져오기 클릭',
    'url에 붙여넣기',
    '끝',
  ];

  @override
  void initState() {
    super.initState();
    Session.getPhone().then((phone) {
      setState(() => _url = ApiService.pingUrl(phone ?? 'unknown'));
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const _SectionTitle('사용방법'),
        const SizedBox(height: 12),
        ...List.generate(_steps.length, (i) => _StepRow(index: i + 1, text: _steps[i])),
        const SizedBox(height: 28),
        const _SectionTitle('URL'),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.fieldBorder),
          ),
          child: SelectableText(
            _url.isEmpty ? '불러오는 중…' : _url,
            style: const TextStyle(
              color: AppColors.accent,
              fontFamily: 'monospace',
              fontSize: 13.5,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _url.isEmpty
              ? null
              : () async {
                  await Clipboard.setData(ClipboardData(text: _url));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('URL을 복사했습니다.')),
                  );
                },
          icon: const Icon(Icons.copy, size: 20),
          label: const Text('복사하기'),
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  final int index;
  final String text;
  const _StepRow({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.accent.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.6)),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                  color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(text,
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.3)),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// Android: 메시지 파싱 대상 입력 + 저장(is_master=true)
// ──────────────────────────────────────────────────────────
class _AndroidSettings extends StatefulWidget {
  const _AndroidSettings();

  @override
  State<_AndroidSettings> createState() => _AndroidSettingsState();
}

class _AndroidSettingsState extends State<_AndroidSettings> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // device_sync_configs 의 id 값을 불러온다(없으면 자신의 번호로 채움).
    final configs = await ApiService.getConfigs();
    String? id;
    if (configs.isNotEmpty) {
      final master = configs.firstWhere(
        (c) => c['isMaster'] == true,
        orElse: () => configs.first,
      );
      id = master['id']?.toString();
    }
    id ??= await Session.getPhone();
    if (!mounted) return;
    setState(() {
      _ctrl.text = id ?? '';
      _loading = false;
    });
  }

  Future<void> _save() async {
    final id = _ctrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _saving = true);
    final ok = await ApiService.setMaster(id);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '저장되었습니다. (is_master = true)' : '저장 실패. 서버 연결을 확인하세요.')),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accent));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        const _SectionTitle('메시지 파싱 대상'),
        const SizedBox(height: 12),
        const Text(
          '비상 신호를 감지할 모니터링 회선(휴대폰번호)을 입력하세요.\n저장하면 해당 회선이 감지 대상(master)으로 설정됩니다.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13.5, height: 1.4),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary, letterSpacing: 1),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]'))],
          decoration: const InputDecoration(
            hintText: '예: 01012345678',
            prefixIcon: Icon(Icons.sms_outlined, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Color(0xFF021016)))
              : const Icon(Icons.save_outlined, size: 20),
          label: const Text('저장'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
    );
  }
}
