import 'package:flutter/material.dart';

import '../services/app_state.dart';
import '../theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  bool signUp = false;
  bool obscurePassword = true;
  bool _submitting = false;

  final formKey = GlobalKey<FormState>();

  late final AnimationController _controller;
  late final Animation<double> _pageFade;
  late final Animation<Offset> _pageSlide;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _pageFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.0,
        0.72,
        curve: Curves.easeOutCubic,
      ),
    );

    _pageSlide = Tween<Offset>(
      begin: const Offset(0, 0.025),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.72,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(
        0.0,
        0.42,
        curve: Curves.easeOutCubic,
      ),
    );

    _logoScale = Tween<double>(
      begin: 0.965,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(
          0.0,
          0.58,
          curve: Curves.easeOutCubic,
        ),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _switchMode() {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    setState(() {
      signUp = !signUp;
      obscurePassword = true;
    });

    formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (_submitting) return;

    FocusScope.of(context).unfocus();

    final form = formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _submitting = true;
    });

    // The app currently uses local authentication state. The navigation
    // itself is handled by EntryGate, which gives the dashboard a clean
    // cross-fade/slide transition without stacking a second home route.
    AppScope.of(context).login();
  }

  Color _textColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurface;
  }

  Color _mutedColor(BuildContext context) {
    return Theme.of(context).colorScheme.onSurfaceVariant;
  }

  Color _surfaceColor(BuildContext context) {
    return Theme.of(context).colorScheme.surface;
  }

  Color _backgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _backgroundColor(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/loginbackground.jpeg',
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: Theme.of(context).brightness == Brightness.dark
                      ? [
                    const Color(0xFF171412).withOpacity(.62),
                    const Color(0xFF171412).withOpacity(.88),
                  ]
                      : [
                    const Color(0xFFFFF8F2).withOpacity(.62),
                    const Color(0xFFFFF8F2).withOpacity(.84),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -55,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: AppColors.saffron.withOpacity(.16),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -75,
            left: -65,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: AppColors.forest.withOpacity(.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 440,
                  ),
                  child: FadeTransition(
                    opacity: _pageFade,
                    child: SlideTransition(
                      position: _pageSlide,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          22,
                          20,
                          22,
                          20,
                        ),
                        decoration: BoxDecoration(
                          color: _surfaceColor(context).withOpacity(.95),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: _surfaceColor(context)
                                .withOpacity(.95),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context)
                                  .colorScheme
                                  .shadow
                                  .withOpacity(.11),
                              blurRadius: 32,
                              offset: const Offset(0, 15),
                            ),
                          ],
                        ),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              FadeTransition(
                                opacity: _logoFade,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        8,
                                        2,
                                        8,
                                        4,
                                      ),
                                      child: Image.asset(
                                        'assets/karigarkart_login_logo.png',
                                        width: 300,
                                        height: 185,
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _StaggeredEntrance(
                                animation: _controller,
                                begin: 0.12,
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 220),
                                  transitionBuilder: (child, animation) {
                                    final curved = CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutCubic,
                                    );

                                    return FadeTransition(
                                      opacity: curved,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0, .035),
                                          end: Offset.zero,
                                        ).animate(curved),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    key: ValueKey(signUp),
                                    children: [
                                      Text(
                                        signUp
                                            ? 'Create your account'
                                            : 'Welcome back',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 23,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -.4,
                                          color: _textColor(context),
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        signUp
                                            ? 'Start showcasing your craft with KarigarKart.'
                                            : 'Sign in to continue to your artisan dashboard.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: _mutedColor(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: SlideTransition(
                                      position: Tween<Offset>(
                                        begin: const Offset(0, .035),
                                        end: Offset.zero,
                                      ).animate(
                                        CurvedAnimation(
                                          parent: animation,
                                          curve: Curves.easeOutCubic,
                                        ),
                                      ),
                                      child: child,
                                    ),
                                  );
                                },
                                child: signUp
                                    ? Column(
                                  key: const ValueKey('signup-name'),
                                  children: [
                                    _StaggeredEntrance(
                                      animation: _controller,
                                      begin: 0.22,
                                      child: _buildInputField(
                                        label: 'Full name',
                                        hint: 'Enter your name',
                                        icon: Icons.person_outline_rounded,
                                        textInputAction:
                                        TextInputAction.next,
                                        validator: (value) {
                                          if (value == null ||
                                              value.trim().isEmpty) {
                                            return 'Please enter your name';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 13),
                                  ],
                                )
                                    : const SizedBox(
                                  key: ValueKey('login-no-name'),
                                ),
                              ),
                              _StaggeredEntrance(
                                animation: _controller,
                                begin: 0.30,
                                child: _buildInputField(
                                  label: 'Phone or email',
                                  hint: 'Enter your phone or email',
                                  icon: Icons.alternate_email_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Please enter your phone or email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 13),
                              _StaggeredEntrance(
                                animation: _controller,
                                begin: 0.38,
                                child: TextFormField(
                                  obscureText: obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _submit(),
                                  decoration: _inputDecoration(
                                    context: context,
                                    label: 'Password',
                                    hint: 'Enter your password',
                                    icon: Icons.lock_outline_rounded,
                                    suffixIcon: IconButton(
                                      tooltip: obscurePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: _submitting
                                          ? null
                                          : () {
                                        setState(() {
                                          obscurePassword =
                                          !obscurePassword;
                                        });
                                      },
                                      icon: Icon(
                                        obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        color: _mutedColor(context),
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.length < 4) {
                                      return 'Use at least 4 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 19),
                              _StaggeredEntrance(
                                animation: _controller,
                                begin: 0.46,
                                child: SizedBox(
                                  height: 56,
                                  child: _AnimatedButton(
                                    onTap: _submit,
                                    child: AnimatedSwitcher(
                                      duration:
                                      const Duration(milliseconds: 180),
                                      child: Container(
                                        key: ValueKey(_submitting),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                            colors: [
                                              AppColors.ink,
                                              Color(0xFF3B3530),
                                            ],
                                          ),
                                          borderRadius:
                                          BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .shadow
                                                  .withOpacity(.12),
                                              blurRadius: 12,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: _submitting
                                              ? const SizedBox(
                                            width: 21,
                                            height: 21,
                                            child:
                                            CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                              AlwaysStoppedAnimation(
                                                Colors.white,
                                              ),
                                            ),
                                          )
                                              : Row(
                                            mainAxisAlignment:
                                            MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                signUp
                                                    ? 'Create seller account'
                                                    : 'Login to your shop',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 15,
                                                  fontWeight:
                                                  FontWeight.w800,
                                                ),
                                              ),
                                              const SizedBox(width: 9),
                                              const Icon(
                                                Icons
                                                    .arrow_forward_rounded,
                                                color: Colors.white,
                                                size: 19,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              _StaggeredEntrance(
                                animation: _controller,
                                begin: 0.54,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 9,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.cream,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          signUp
                                              ? 'Already have an account?'
                                              : 'New artisan?',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: _mutedColor(context),
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.only(
                                            left: 5,
                                            right: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        onPressed:
                                        _submitting ? null : _switchMode,
                                        child: Text(
                                          signUp
                                              ? 'Login'
                                              : 'Create an account',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.clay,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      decoration: _inputDecoration(
        context: context,
        label: label,
        hint: hint,
        icon: icon,
      ),
      validator: validator,
    );
  }

  InputDecoration _inputDecoration({
    required BuildContext context,
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    final colors = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: _mutedColor(context),
      ),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: _surfaceColor(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: colors.outline.withOpacity(.065),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppColors.forest,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }
}

class _StaggeredEntrance extends StatelessWidget {
  const _StaggeredEntrance({
    required this.animation,
    required this.begin,
    required this.child,
  });

  final Animation<double> animation;
  final double begin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final end = (begin + .38).clamp(0.0, 1.0).toDouble();

    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(
        begin,
        end,
        curve: Curves.easeOutCubic,
      ),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .025),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

class _AnimatedButton extends StatefulWidget {
  const _AnimatedButton({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_AnimatedButton> createState() => _AnimatedButtonState();
}

class _AnimatedButtonState extends State<_AnimatedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        setState(() {
          _pressed = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _pressed = false;
        });
      },
      onTapUp: (_) {
        setState(() {
          _pressed = false;
        });
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
