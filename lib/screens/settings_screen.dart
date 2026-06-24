import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/api_service.dart';
import '../services/fcm_service.dart';
import '../services/local_notifications.dart';
import '../services/session.dart';
import '../theme.dart';
import 'auth_screen.dart';

/// 설정 메인 화면 — 메뉴 리스트 형태.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                // ── 메인 회선 설정 메뉴 ──
                _MenuTile(
                  icon: Icons.sim_card_outlined,
                  iconColor: AppColors.techBlue,
                  title: '메인 회선 설정',
                  subtitle: Platform.isIOS
                      ? 'iOS 단축어 연동 및 모니터링 회선 설정'
                      : '비상 신호 감지 모니터링 회선 설정',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const _MainLineSettingsScreen(),
                    ),
                  ),
                ),
                const _Divider(),
                // ── 테스트 & 해제 ──
                const _ResolveEmergencySection(),
              ],
            ),
          ),
          // ── 로그아웃 / 계정삭제 (최하단) ──
          const _LogoutSection(),
          const _DeleteAccountSection(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// 메인 회선 설정 서브 화면
// ──────────────────────────────────────────────────────────
class _MainLineSettingsScreen extends StatelessWidget {
  const _MainLineSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('메인 회선 설정')),
      body: Platform.isIOS
          ? const _IosMainLineSettings()
          : const _AndroidMainLineSettings(),
    );
  }
}

// ──────────────────────────────────────────────────────────
// iOS: 단축어 사용방법 + URL + 입력필드 + 저장
// ──────────────────────────────────────────────────────────
class _IosMainLineSettings extends StatefulWidget {
  const _IosMainLineSettings();

  @override
  State<_IosMainLineSettings> createState() => _IosMainLineSettingsState();
}

class _IosMainLineSettingsState extends State<_IosMainLineSettings> {
  final _ctrl = TextEditingController();
  String _url = '';
  bool _saving = false;

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
    _loadMaster();
  }

  Future<void> _loadMaster() async {
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
    setState(() => _ctrl.text = id ?? '');
  }

  Future<void> _iosSave() async {
    final id = _ctrl.text.trim();
    if (id.isEmpty) return;
    setState(() => _saving = true);
    final ok = await ApiService.setMaster(id);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '저장되었습니다.' : '저장 실패. 서버 연결을 확인하세요.')),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // 입력 + 저장
        const _SectionTitle('모니터링 회선'),
        const SizedBox(height: 8),
        const Text(
          '비상 신호를 감지할 휴대폰번호를 입력하고 저장하세요.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
          ],
          decoration: const InputDecoration(
            hintText: '예: 01012345678',
            prefixIcon: Icon(
              Icons.sim_card_outlined,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(height: 14),
        ElevatedButton.icon(
          onPressed: _saving ? null : _iosSave,
          icon: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: const Text('저장'),
        ),
        const SizedBox(height: 32),
        // iOS 단축어 설정 방법
        const _SectionTitle('iOS 단축어 사용방법'),
        const SizedBox(height: 12),
        ...List.generate(
          _steps.length,
          (i) => _StepRow(index: i + 1, text: _steps[i]),
        ),
        const SizedBox(height: 28),
        const _SectionTitle('Ping URL'),
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
              color: AppColors.techBlue,
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
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('URL을 복사했습니다.')));
                },
          icon: const Icon(Icons.copy, size: 20),
          label: const Text('URL 복사'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Android: 입력필드 + 저장
// ──────────────────────────────────────────────────────────
class _AndroidMainLineSettings extends StatefulWidget {
  const _AndroidMainLineSettings();

  @override
  State<_AndroidMainLineSettings> createState() =>
      _AndroidMainLineSettingsState();
}

class _AndroidMainLineSettingsState extends State<_AndroidMainLineSettings> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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

  Future<void> _androidSave() async {
    final id = _ctrl.text.trim();
    print('api전송함');
    if (id.isEmpty) return;
    setState(() => _saving = true);

    final ok = await ApiService.setMaster(id);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '저장되었습니다.' : '저장 실패. 서버 연결을 확인하세요.')),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accent),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        const _SectionTitle('모니터링 회선'),
        const SizedBox(height: 8),
        const Text(
          '비상 신호를 감지할 모니터링 회선(휴대폰번호)을 입력하세요.\n저장하면 해당 회선이 감지 대상(master)으로 설정됩니다.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13.5,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _ctrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(
            color: AppColors.textPrimary,
            letterSpacing: 1,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
          ],
          decoration: const InputDecoration(
            hintText: '예: 01012345678',
            prefixIcon: Icon(Icons.sms_outlined, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton.icon(
          onPressed: _saving ? null : _androidSave,
          icon: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: const Text('저장'),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────
// 테스트 푸시 + 상황 해제 섹션
// ──────────────────────────────────────────────────────────
class _ResolveEmergencySection extends StatefulWidget {
  const _ResolveEmergencySection();

  @override
  State<_ResolveEmergencySection> createState() =>
      _ResolveEmergencySectionState();
}

class _ResolveEmergencySectionState extends State<_ResolveEmergencySection> {
  bool _resolving = false;
  bool _sendingTest = false;

  Future<void> _sendTest() async {
    setState(() => _sendingTest = true);
    final result = await ApiService.sendTestPush();
    if (!mounted) return;
    setState(() => _sendingTest = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result), duration: const Duration(seconds: 4)),
    );
  }

  Future<void> _resolve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '상황 해제',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '서버의 비상 상황을 해제합니다.\n모든 사용자에게 가던 푸시가 즉시 멈춥니다.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '해제',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _resolving = true);
    final phone = await Session.getPhone();
    final ok = await ApiService.resolveEmergency(phone);
    await LocalNotifications.stopEmergencyAlert();
    FcmService.resetEmergencyHandling();
    if (!mounted) return;
    setState(() => _resolving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? '상황을 해제했습니다.' : '해제 실패. 서버 연결을 확인하세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _ActionTile(
            icon: Icons.notifications_active_outlined,
            iconColor: AppColors.techBlue,
            title: '테스트 푸시 보내기',
            loading: _sendingTest,
            onTap: _sendingTest ? null : _sendTest,
          ),
          const SizedBox(height: 8),
          _ActionTile(
            icon: Icons.notifications_off_outlined,
            iconColor: AppColors.danger,
            title: '상황 해제 (서버 푸시 중지)',
            titleColor: AppColors.danger,
            loading: _resolving,
            onTap: _resolving ? null : _resolve,
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// 로그아웃 섹션
// ──────────────────────────────────────────────────────────
class _LogoutSection extends StatefulWidget {
  const _LogoutSection();

  @override
  State<_LogoutSection> createState() => _LogoutSectionState();
}

class _LogoutSectionState extends State<_LogoutSection> {
  bool _loading = false;

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          '로그아웃',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: const Text(
          '로그아웃하면 이 기기로 비상 푸시가 발송되지 않습니다.',
          style: TextStyle(color: AppColors.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              '취소',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '로그아웃',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final phone = await Session.getPhone();
    final token = await FcmService.requestPermissionAndToken();
    if (phone != null) {
      await ApiService.unregister(phone, token);
    }
    await Session.clear();
    if (!mounted) return;

    // 루트까지 전부 pop 후 AuthScreen으로 이동
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.fieldBorder)),
      ),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _loading ? null : _logout,
        icon: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.danger,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 20),
        label: const Text(
          '로그아웃',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// 계정 삭제 섹션
// ──────────────────────────────────────────────────────────
class _DeleteAccountSection extends StatefulWidget {
  const _DeleteAccountSection();

  @override
  State<_DeleteAccountSection> createState() => _DeleteAccountSectionState();
}

class _DeleteAccountSectionState extends State<_DeleteAccountSection> {
  bool _loading = false;

  /// 숫자만 남겨 비교(하이픈/공백 무시).
  String _digits(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  Future<void> _deleteAccount() async {
    final phone = await Session.getPhone();
    if (!mounted) return;
    if (phone == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('로그인 정보를 찾을 수 없습니다.')));
      return;
    }

    final inputCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        bool matched = false;
        return StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text(
              '계정 삭제',
              style: TextStyle(color: AppColors.textPrimary),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '정말 계정을 삭제하시겠습니까?\n현재 사용자의 휴대폰번호를 입력해주세요.',
                  style: TextStyle(color: AppColors.textMuted, height: 1.4),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: inputCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-]')),
                  ],
                  onChanged: (v) =>
                      setLocal(() => matched = _digits(v) == _digits(phone)),
                  decoration: const InputDecoration(
                    hintText: '휴대폰번호 입력',
                    prefixIcon: Icon(
                      Icons.smartphone_outlined,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  '취소',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
              TextButton(
                onPressed: matched ? () => Navigator.pop(ctx, true) : null,
                child: Text(
                  '계정삭제',
                  style: TextStyle(
                    color: matched
                        ? AppColors.danger
                        : AppColors.textMuted.withValues(alpha: 0.4),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    final ok = await ApiService.deleteAccount(phone);
    if (!mounted) return;

    if (!ok) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('계정 삭제 실패. 서버 연결을 확인하세요.')));
      return;
    }

    await Session.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.danger,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: _loading ? null : _deleteAccount,
        icon: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: AppColors.danger,
                ),
              )
            : const Icon(Icons.delete_forever_outlined, size: 20),
        label: const Text(
          '계정 삭제',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────
// 공통 위젯
// ──────────────────────────────────────────────────────────
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: iconColor.withValues(alpha: 0.12),
          border: Border.all(color: iconColor.withValues(alpha: 0.35)),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted.withValues(alpha: 0.6),
      ),
      onTap: onTap,
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color titleColor;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor = AppColors.textPrimary,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: iconColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      color: AppColors.fieldBorder,
      height: 1,
      indent: 20,
      endIndent: 20,
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
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
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
              color: AppColors.techBlue.withValues(alpha: 0.15),
              border: Border.all(
                color: AppColors.techBlue.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: AppColors.techBlue,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
