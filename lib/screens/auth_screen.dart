import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _violet = Color(0xFF7C3AED);
const _cyan = Color(0xFF06B6D4);

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.firebaseReady,
    required this.onAuthenticated,
  });
  final bool firebaseReady;
  final VoidCallback onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _handle = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late final _tabController = TabController(length: 2, vsync: this);
  bool _register = false;
  bool _showPassword = false;
  bool _remember = true;
  bool _acceptedTerms = false;
  bool _busy = false;
  String _passwordValue = '';

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final email = preferences.getString('partyup_remembered_email');
      if (!mounted || email == null) return;
      _email.text = email;
    } catch (_) {
      // Remembering the email is optional; Firebase sign-in must still work.
    }
  }

  int get _strength {
    final value = _passwordValue;
    if (value.isEmpty) return 0;
    var score = 0;
    if (value.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(value)) score++;
    if (RegExp(r'[0-9]').hasMatch(value)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(value)) score++;
    return score;
  }

  @override
  void dispose() {
    _handle.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _setMode(int index) {
    FocusScope.of(context).unfocus();
    setState(() => _register = index == 1);
    _tabController.animateTo(index);
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    if (_register && !_acceptedTerms) {
      _toast('กรุณายอมรับข้อกำหนดและนโยบายความเป็นส่วนตัว');
      return;
    }
    if (!widget.firebaseReady) {
      _toast('ระบบยืนยันตัวตนยังไม่ได้ตั้งค่า Firebase Auth');
      return;
    }
    setState(() => _busy = true);
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        try {
          await credential.user?.updateDisplayName(_handle.text.trim());
        } catch (_) {
          // Profile naming is optional and should not block account creation.
        }
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      _toast(_authError(error.code));
      if (mounted) setState(() => _busy = false);
      return;
    } on FirebaseException catch (error) {
      _toast('Firebase error: ${error.code}');
      if (mounted) setState(() => _busy = false);
      return;
    } on PlatformException catch (error) {
      debugPrint(
        'Firebase Auth platform error: ${error.code} ${error.message}',
      );
      _toast('เชื่อมต่อ Firebase ไม่สำเร็จ (${error.code})');
      if (mounted) setState(() => _busy = false);
      return;
    } catch (error, stackTrace) {
      debugPrint('Unexpected error while signing in: $error\n$stackTrace');
      _toast('เกิดข้อผิดพลาด กรุณาลองอีกครั้ง');
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      if (_remember) {
        await preferences.setString(
          'partyup_remembered_email',
          _email.text.trim(),
        );
      } else {
        await preferences.remove('partyup_remembered_email');
      }
    } catch (_) {
      // A local preference failure must not undo a successful Firebase login.
    }

    if (!mounted) return;
    widget.onAuthenticated();
    setState(() => _busy = false);
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _toast('กรอกอีเมลก่อนเพื่อรับลิงก์ตั้งรหัสผ่านใหม่');
      return;
    }
    if (!widget.firebaseReady) {
      _toast('ระบบยืนยันตัวตนยังไม่ได้ตั้งค่า Firebase Auth');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      _toast('ส่งลิงก์ตั้งรหัสผ่านใหม่ไปที่ $email แล้ว', isError: false);
    } on FirebaseAuthException catch (error) {
      _toast(_authError(error.code));
    }
  }

  String _authError(String code) => switch (code) {
    'invalid-email' => 'รูปแบบอีเมลไม่ถูกต้อง',
    'user-not-found' ||
    'wrong-password' ||
    'invalid-credential' => 'อีเมลหรือรหัสผ่านไม่ถูกต้อง',
    'email-already-in-use' => 'อีเมลนี้มีบัญชีแล้ว ลองเข้าสู่ระบบแทน',
    'weak-password' => 'รหัสผ่านยังไม่ปลอดภัยพอ',
    'network-request-failed' => 'เชื่อมต่ออินเทอร์เน็ตไม่ได้',
    'too-many-requests' => 'ลองหลายครั้งเกินไป กรุณารอสักครู่',
    _ => 'ยืนยันตัวตนไม่สำเร็จ ($code)',
  };

  void _toast(String message, {bool isError = true}) {
    if (!mounted) return;
    final accent = isError ? const Color(0xFFFF5C77) : const Color(0xFF34D399);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 4),
          content: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
            decoration: BoxDecoration(
              color: const Color(0xFF171923),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withValues(alpha: .38)),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: .16),
                  blurRadius: 22,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: .36),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: accent,
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isError ? 'เข้าสู่ระบบไม่สำเร็จ' : 'เรียบร้อยแล้ว',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Color(0xFFB5BDCC),
                          fontSize: 11,
                          height: 1.35,
                        ),
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

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: const Color(0xFF0B0E17),
      body: Stack(
        children: [
          const Positioned.fill(child: _NeonBackdrop()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: wide ? 32 : 20,
                  vertical: 28,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    children: [
                      _brand(),
                      const SizedBox(height: 28),
                      _glassCard(),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: widget.onAuthenticated,
                        icon: const Icon(Icons.explore_outlined, size: 16),
                        label: const Text('Continue as guest'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF929DB0),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'POWERED BY YOUR NEXT PARTY',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .35),
                          fontSize: 9,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() => Column(
    children: [
      Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          gradient: const LinearGradient(
            colors: [_violet, Color(0xFF4F46E5), _cyan],
          ),
          boxShadow: [
            BoxShadow(
              color: _violet.withValues(alpha: .4),
              blurRadius: 32,
              spreadRadius: 1,
            ),
          ],
        ),
        child: const Icon(
          Icons.sports_esports_rounded,
          color: Colors.white,
          size: 29,
        ),
      ),
      const SizedBox(height: 12),
      ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.white, Color(0xFFB9A2FF), Color(0xFF78E9F4)],
        ).createShader(bounds),
        child: const Text(
          'partyup',
          style: TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
      ),
      const SizedBox(height: 5),
      const Text(
        'Level up your squad. Find your party.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Color(0xFF929DB0), fontSize: 13),
      ),
    ],
  );

  Widget _glassCard() => ClipRRect(
    borderRadius: BorderRadius.circular(26),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          color: const Color(0xD9161B26),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withValues(alpha: .10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .28),
              blurRadius: 38,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _modeTabs(),
            const SizedBox(height: 22),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              switchInCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, .025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  key: ValueKey(_register),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _register
                          ? 'Build your player profile'
                          : 'Welcome back, player',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _register
                          ? 'Create an account and find your squad.'
                          : 'Sign in and get back in the game.',
                      style: const TextStyle(
                        color: Color(0xFF929DB0),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 19),
                    if (_register) ...[
                      _input(
                        _handle,
                        label: 'Gamer Tag',
                        hint: 'Your player name',
                        icon: Icons.sports_esports_outlined,
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'ใช้ชื่ออย่างน้อย 3 ตัวอักษร'
                            : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    _input(
                      _email,
                      label: 'Email Address',
                      hint: 'you@example.com',
                      icon: Icons.alternate_email_rounded,
                      keyboard: TextInputType.emailAddress,
                      validator: (v) =>
                          (v == null ||
                              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim()))
                          ? 'กรอกอีเมลให้ถูกต้อง'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _input(
                      _password,
                      label: 'Password',
                      hint: 'At least 8 characters',
                      icon: Icons.lock_outline_rounded,
                      obscure: !_showPassword,
                      suffix: IconButton(
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: const Color(0xFF929DB0),
                          size: 19,
                        ),
                      ),
                      onChanged: (v) {
                        if (_register) setState(() => _passwordValue = v);
                      },
                      validator: (v) => (v == null || v.length < 8)
                          ? 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'
                          : null,
                    ),
                    if (_register) ...[
                      const SizedBox(height: 9),
                      _strengthMeter(),
                      const SizedBox(height: 12),
                      _input(
                        _confirm,
                        label: 'Confirm Password',
                        hint: 'Re-enter your password',
                        icon: Icons.verified_user_outlined,
                        obscure: true,
                        validator: (v) =>
                            v != _password.text ? 'รหัสผ่านไม่ตรงกัน' : null,
                      ),
                      const SizedBox(height: 13),
                      _termsRow(),
                    ] else ...[
                      const SizedBox(height: 4),
                      _loginOptions(),
                    ],
                    const SizedBox(height: 17),
                    _primaryButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _modeTabs() => Container(
    height: 46,
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: const Color(0xFF0D111B),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withValues(alpha: .05)),
    ),
    child: TabBar(
      controller: _tabController,
      onTap: _setMode,
      indicator: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: const LinearGradient(colors: [_violet, Color(0xFF4F46E5)]),
        boxShadow: [
          BoxShadow(color: _violet.withValues(alpha: .28), blurRadius: 12),
        ],
      ),
      dividerColor: Colors.transparent,
      indicatorSize: TabBarIndicatorSize.tab,
      labelColor: Colors.white,
      unselectedLabelColor: const Color(0xFF929DB0),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      tabs: const [
        Tab(text: 'Sign In'),
        Tab(text: 'Create Account'),
      ],
    ),
  );

  Widget _input(
    TextEditingController controller, {
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    String? Function(String?)? validator,
    ValueChanged<String>? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 7, left: 2),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC7CCDA),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      TextFormField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        validator: validator,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        cursorColor: _cyan,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF687386), fontSize: 12),
          prefixIcon: Icon(icon, size: 19, color: const Color(0xFF929DB0)),
          suffixIcon: suffix,
          filled: true,
          fillColor: const Color(0xFF0D121D),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 15,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: .08)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: _cyan, width: 1.3),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: const BorderSide(color: Color(0xFFEF4444)),
          ),
        ),
      ),
    ],
  );

  Widget _loginOptions() => Row(
    children: [
      SizedBox(
        width: 20,
        height: 20,
        child: Checkbox(
          value: _remember,
          onChanged: (v) => setState(() => _remember = v ?? false),
          activeColor: _violet,
          side: const BorderSide(color: Color(0xFF5B6475)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
      const SizedBox(width: 7),
      const Text(
        'Remember me',
        style: TextStyle(color: Color(0xFF929DB0), fontSize: 11),
      ),
      const Spacer(),
      TextButton(
        onPressed: _forgotPassword,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF67DDEE),
          padding: const EdgeInsets.symmetric(horizontal: 4),
        ),
        child: const Text(
          'Forgot password?',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );

  Widget _strengthMeter() {
    final colors = [
      const Color(0xFFEF4444),
      const Color(0xFFF97316),
      const Color(0xFFEAB308),
      const Color(0xFF10B981),
    ];
    final color = _strength == 0
        ? const Color(0xFF343B4A)
        : colors[_strength - 1];
    final labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(
              4,
              (i) => Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 4,
                  margin: EdgeInsets.only(right: i == 3 ? 0 : 5),
                  decoration: BoxDecoration(
                    color: i < _strength ? color : const Color(0xFF343B4A),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          labels[_strength],
          style: TextStyle(
            color: _strength == 0 ? const Color(0xFF687386) : color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _termsRow() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 20,
        height: 20,
        child: Checkbox(
          value: _acceptedTerms,
          onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
          activeColor: _violet,
          side: const BorderSide(color: Color(0xFF5B6475)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
      ),
      const SizedBox(width: 8),
      const Expanded(
        child: Padding(
          padding: EdgeInsets.only(top: 2),
          child: Text(
            'I agree to the Terms of Service and Privacy Policy.',
            style: TextStyle(
              color: Color(0xFF929DB0),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _primaryButton() => SizedBox(
    height: 49,
    child: DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_violet, Color(0xFF4F46E5)]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _violet.withValues(alpha: .32),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _busy ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _register ? 'Create Account' : 'Sign In',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ],
              ),
      ),
    ),
  );
}

class _NeonBackdrop extends StatelessWidget {
  const _NeonBackdrop();
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-.8, -.8),
            radius: 1.3,
            colors: [Color(0xFF191334), Color(0xFF0B0E17), Color(0xFF0B0E17)],
          ),
        ),
        child: SizedBox.expand(),
      ),
      Positioned(
        top: -110,
        right: -100,
        child: _orb(260, _cyan.withValues(alpha: .10)),
      ),
      Positioned(
        bottom: -125,
        left: -105,
        child: _orb(300, _violet.withValues(alpha: .13)),
      ),
      Positioned(
        top: 100,
        left: -80,
        child: _orb(170, const Color(0xFF4338CA).withValues(alpha: .08)),
      ),
    ],
  );
  Widget _orb(double size, Color color) => ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    ),
  );
}
