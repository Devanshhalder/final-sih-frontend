import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart' as record;

import '../services/ai_background_service.dart';
import '../services/app_localization.dart';
import '../services/app_state.dart';
import '../services/app_transitions.dart';
import '../theme.dart';
import '../widgets/ai_error_dialog.dart';
import '../widgets/ui.dart';

const String _apiBaseUrl = 'http://10.70.33.153:8000';

String _tr(BuildContext context, String key) =>
    AppLocalization.text(AppScope.of(context).language, key);

Color _bg(BuildContext context) => Theme.of(context).scaffoldBackgroundColor;
Color _surface(BuildContext context) => Theme.of(context).colorScheme.surface;
Color _text(BuildContext context) => Theme.of(context).colorScheme.onSurface;
Color _muted(BuildContext context) =>
    Theme.of(context).colorScheme.onSurfaceVariant;
Color _outline(BuildContext context) => Theme.of(context).colorScheme.outline;

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({super.key, this.voiceFlow = false});

  final bool voiceFlow;

  static const List<String> languages = <String>[
    'English',
    'हिंदी',
    'বাংলা',
    'தமிழ்',
    'తెలుగు',
    'मराठी',
    'ગુજરાતી',
    'ಕನ್ನಡ',
  ];

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  bool _changing = false;

  String _languageKey(String language) {
    switch (language) {
      case 'English':
        return 'english';
      case 'हिंदी':
        return 'hindi';
      case 'বাংলা':
        return 'bengali';
      case 'தமிழ்':
        return 'tamil';
      case 'తెలుగు':
        return 'telugu';
      case 'मराठी':
        return 'marathi';
      case 'ગુજરાતી':
        return 'gujarati';
      case 'ಕನ್ನಡ':
        return 'kannada';
      default:
        return 'english';
    }
  }

  String _symbol(String language) {
    switch (language) {
      case 'English':
        return 'A';
      case 'हिंदी':
        return 'अ';
      case 'বাংলা':
        return 'ব';
      case 'தமிழ்':
        return 'த';
      case 'తెలుగు':
        return 'తె';
      case 'मराठी':
        return 'म';
      case 'ગુજરાતી':
        return 'ગ';
      case 'ಕನ್ನಡ':
        return 'ಕ';
      default:
        return 'A';
    }
  }

  Future<void> _select(String language) async {
    if (_changing) return;
    final state = AppScope.of(context);
    if (state.language == language) return;

    setState(() => _changing = true);
    await state.setLanguage(language);
    if (mounted) setState(() => _changing = false);
  }

  void _continue() {
    if (_changing) return;
    if (widget.voiceFlow) {
      Navigator.push(
        context,
        KarigarPageRoute(builder: (_) => const VoiceRecordingScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final language = state.language;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        title: Text(
          _tr(context, 'selectLanguage'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text(context),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _tr(context, 'languageVoiceTitle'),
                      style: TextStyle(
                        fontSize: 27,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        color: _text(context),
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      _tr(context, 'languageChoiceDescription'),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: _muted(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.forest.withOpacity(.09),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.forest,
                        size: 22,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          _tr(context, 'languageVoiceIntro'),
                          style: const TextStyle(fontSize: 11, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: LanguageScreen.languages.length,
                  itemBuilder: (BuildContext _, int index) {
                    final item = LanguageScreen.languages[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: _LanguageTile(
                        language: item,
                        subtitle: AppLocalization.text(
                          language,
                          _languageKey(item),
                        ),
                        symbol: _symbol(item),
                        selected: language == item,
                        enabled: !_changing,
                        onTap: () => _select(item),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: _bg(context),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withOpacity(.06),
                      blurRadius: 14,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: _PressButton(
                      onTap: _continue,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            widget.voiceFlow
                                ? _tr(context, 'continueToRecording')
                                : _tr(context, 'done'),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_changing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(.22),
                alignment: Alignment.center,
                child: Container(
                  width: 176,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: _surface(context),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          color: AppColors.forest,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        _tr(context, 'loading'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _text(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.language,
    required this.subtitle,
    required this.symbol,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String language;
  final String subtitle;
  final String symbol;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface(context),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(19),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: selected
                  ? AppColors.forest
                  : _outline(context).withOpacity(.12),
              width: selected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 47,
                height: 47,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.forest
                      : AppColors.saffron.withOpacity(.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  symbol,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AppColors.clay,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      language,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _text(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: _muted(context)),
                    ),
                  ],
                ),
              ),
              Container(
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.forest : Colors.transparent,
                  border: Border.all(
                    color: selected
                        ? AppColors.forest
                        : _outline(context).withOpacity(.20),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VoiceRecordingScreen extends StatefulWidget {
  const VoiceRecordingScreen({super.key});

  @override
  State<VoiceRecordingScreen> createState() => _VoiceRecordingScreenState();
}

class _VoiceRecordingScreenState extends State<VoiceRecordingScreen> {
  final record.AudioRecorder _recorder = record.AudioRecorder();
  final TextEditingController _manualTextController = TextEditingController();
  StreamSubscription<record.Amplitude>? _amplitudeSubscription;
  Timer? _timer;

  bool _recording = false;
  bool _busy = false;
  bool _useVoice = true;
  bool _hasPermission = false;
  int _seconds = 0;
  double _level = .08;
  String? _audioPath;
  String _status = '';

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_status.isEmpty) _status = _tr(context, 'tapMicStart');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _amplitudeSubscription?.cancel();
    _recorder.dispose();
    _manualTextController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final granted = await _recorder.hasPermission();
      if (!mounted) return;
      setState(() {
        _hasPermission = granted;
        _status = granted
            ? _tr(context, 'tapMicStart')
            : _tr(context, 'micPermissionUnavailable');
      });
    } catch (error) {
      debugPrint('AUDIO PERMISSION ERROR: $error');
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _status = _tr(context, 'micUnavailableType');
        });
      }
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _busy) return;

    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() {
            _hasPermission = false;
            _status = _tr(context, 'micPermissionPleaseText');
          });
        }
        return;
      }

      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/karigarkart_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const record.RecordConfig(
          encoder: record.AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 64000,
        ),
        path: path,
      );

      _audioPath = path;
      _seconds = 0;
      _level = .08;
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _recording) {
          setState(() => _seconds++);
        }
      });

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((record.Amplitude amplitude) {
        if (!mounted || !_recording) return;
        setState(() {
          _level = ((amplitude.current + 60) / 60).clamp(.05, 1.0).toDouble();
        });
      });

      if (mounted) {
        setState(() {
          _recording = true;
          _status = _tr(context, 'listening');
        });
      }
    } catch (error, stackTrace) {
      debugPrint('AUDIO RECORD START ERROR: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        setState(() {
          _recording = false;
          _status = _tr(context, 'couldNotStartRecording');
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_recording) return;

    _timer?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    try {
      final saved = await _recorder.stop();
      if (!mounted) return;
      setState(() {
        _recording = false;
        _level = .08;
        _audioPath = saved ?? _audioPath;
        _status = _audioPath == null
            ? _tr(context, 'noRecordingCaptured')
            : _tr(context, 'recordingCaptured');
      });
    } catch (error) {
      debugPrint('AUDIO RECORD STOP ERROR: $error');
      if (mounted) {
        setState(() {
          _recording = false;
          _level = .08;
          _status = _tr(context, 'recordingNotSaved');
        });
      }
    }
  }

  Future<String?> _transcribe(String path) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Recorded audio is unavailable.');
      }

      final bytes = await file.readAsBytes();
      final language = AppScope.of(context).language;
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/ai/transcribe'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'audio_base64': base64Encode(bytes),
              'audio_mime': 'audio/mp4',
              'language': language,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        debugPrint('TRANSCRIBE HTTP ${response.statusCode}: ${response.body}');
        return null;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return null;
      final text = (decoded['text'] ?? '').toString().trim();
      return text.isEmpty ? null : text;
    } catch (error, stackTrace) {
      debugPrint('AI TRANSCRIBE ERROR: $error');
      debugPrint('$stackTrace');
      return null;
    }
  }

  Future<void> _submitVoice() async {
    if (_busy) return;

    if (_recording) {
      await _stopRecording();
    }

    final path = _audioPath;
    if (path == null || path.isEmpty) {
      if (mounted) setState(() => _status = _tr(context, 'noRecordingCaptured'));
      return;
    }

    setState(() => _busy = true);
    final text = await _transcribe(path);

    if (!mounted) return;
    setState(() => _busy = false);

    if (text == null || text.isEmpty) {
      setState(() => _status = _tr(context, 'transcriptionFailed'));
      return;
    }

    await _generateCatalog(text);
  }

  Future<void> _generateCatalog(String text) async {
    final state = AppScope.of(context);

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/ai/catalog'),
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'text': text,
              'description': text,
              'category': state.draft.category,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        debugPrint('CATALOG HTTP ${response.statusCode}: ${response.body}');
        if (mounted) {
          await AiErrorDialog.show(context, code: 'aiServerError');
        }
        return;
      }

      final decoded = jsonDecode(response.body);
      final data = decoded is Map ? decoded : <String, dynamic>{};
      final result = data['result'] is Map
          ? Map<String, dynamic>.from(data['result'] as Map)
          : data;

      final title = (result['title'] ?? result['name'] ?? '').toString().trim();
      final description =
          (result['description'] ?? text).toString().trim();
      final category =
          (result['category'] ?? state.draft.category).toString().trim();
      final rawPrice = result['estimated_price'] ??
          result['price'] ??
          result['suggested_price'];
      final price = _parsePrice(rawPrice);

      state.updateDraft(
        title: title.isEmpty ? text : title,
        description: description.isEmpty ? text : description,
        category: category.isEmpty ? state.draft.category : category,
        price: price,
      );

      if (!mounted) return;
      Navigator.push(
        context,
        KarigarPageRoute(builder: (_) => const ProcessingScreen()),
      );
    } catch (error, stackTrace) {
      debugPrint('AI CATALOG ERROR: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        await AiErrorDialog.show(context, code: 'aiNetworkError');
      }
    }
  }

  int _parsePrice(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    final text = value?.toString() ?? '';
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    if (match == null) return AppScope.of(context).draft.price;
    return double.tryParse(match.group(0)!)?.round() ??
        AppScope.of(context).draft.price;
  }

  void _submitManual() {
    final text = _manualTextController.text.trim();
    if (text.isEmpty || _busy) return;
    _generateCatalog(text);
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final remaining = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        title: Text(
          _tr(context, 'voiceCatalog'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _ModeButton(
                    selected: _useVoice,
                    icon: Icons.mic_rounded,
                    label: _tr(context, 'voice'),
                    onTap: () => setState(() => _useVoice = true),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ModeButton(
                    selected: !_useVoice,
                    icon: Icons.edit_rounded,
                    label: _tr(context, 'type'),
                    onTap: () => setState(() => _useVoice = false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_useVoice) ...<Widget>[
              GestureDetector(
                onTap: _recording ? _stopRecording : _startRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _recording
                        ? AppColors.clay.withOpacity(.15)
                        : AppColors.forest.withOpacity(.10),
                    border: Border.all(
                      color: _recording ? AppColors.clay : AppColors.forest,
                      width: 3,
                    ),
                  ),
                  child: Icon(
                    _recording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 58,
                    color: _recording ? AppColors.clay : AppColors.forest,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _recording ? _formatTime(_seconds) : _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _text(context),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: List<Widget>.generate(24, (int index) {
                    final height = 6 + (_level * ((index % 5) + 1) * 7);
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Align(
                          alignment: Alignment.center,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            height: height,
                            decoration: BoxDecoration(
                              color: AppColors.forest.withOpacity(.35),
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _PressButton(
                  onTap: _busy ? () {} : _submitVoice,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _tr(context, 'continue'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ] else ...<Widget>[
              TextField(
                controller: _manualTextController,
                maxLines: 6,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: _tr(context, 'typeProductDescription'),
                  filled: true,
                  fillColor: _surface(context),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: _PressButton(
                  onTap: _busy ? () {} : _submitManual,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _tr(context, 'generateCatalog'),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
            if (!_hasPermission && _useVoice) ...<Widget>[
              const SizedBox(height: 14),
              Text(
                _tr(context, 'micPermissionUnavailable'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: _muted(context)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key});

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> {
  Timer? _pollTimer;
  String? _jobPath;
  String? _imagePath;
  double _progress = .05;
  String _status = 'Preparing AI enhancement…';
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (_started) return;
    _started = true;

    final state = AppScope.of(context);
    final imagePath = state.draftImagePath;

    if (imagePath == null || imagePath.isEmpty || !await File(imagePath).exists()) {
      if (!mounted) return;
      setState(() {
        _status = 'No product image was found.';
        _progress = 0;
      });
      return;
    }

    final documents = await getApplicationDocumentsDirectory();
    final jobPath =
        '${documents.path}/karigarkart_ai/job_${DateTime.now().millisecondsSinceEpoch}.job.json';

    _imagePath = imagePath;
    _jobPath = jobPath;

    try {
      await AiBackgroundService.createJob(
        jobPath: jobPath,
        imagePath: imagePath,
      );
      await AiBackgroundService.enqueue(jobPath: jobPath);
      if (!mounted) return;
      setState(() => _status = 'Enhancing product photo…');
      _pollTimer = Timer.periodic(
        const Duration(milliseconds: 700),
        (_) => _pollJob(),
      );
      await _pollJob();
    } catch (error, stackTrace) {
      debugPrint('AI JOB START ERROR: $error');
      debugPrint('$stackTrace');
      if (mounted) {
        await AiErrorDialog.show(context, code: 'aiUnknown');
      }
    }
  }

  Future<void> _pollJob() async {
    final path = _jobPath;
    if (path == null) return;

    final job = await AiBackgroundService.readJob(path);
    if (job == null) return;

    if (!mounted) return;
    final progressValue = job['progress'];
    final progress = progressValue is num
        ? progressValue.toDouble().clamp(0.0, 1.0).toDouble()
        : _progress;
    final status = job['status']?.toString() ?? 'processing';

    setState(() {
      _progress = progress;
      _status = status == 'queued'
          ? 'Waiting for AI processing…'
          : status == 'processing'
              ? 'Enhancing product photo…'
              : status == 'success'
                  ? 'Photo enhanced successfully.'
                  : 'Photo enhancement failed.';
    });

    if (status == 'success') {
      _pollTimer?.cancel();
      final enhancedPath = job['enhancedPath']?.toString();
      if (enhancedPath != null && enhancedPath.isNotEmpty) {
        await _finish(enhancedPath);
      } else {
        await _showError('aiServerError');
      }
    } else if (status == 'error') {
      _pollTimer?.cancel();
      await _showError(job['errorCode']?.toString() ?? 'aiUnknown');
    }
  }

  Future<void> _finish(String enhancedPath) async {
    final state = AppScope.of(context);
    state.setDraftImage(enhancedPath);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      KarigarPageRoute(builder: (_) => const ImagePreviewScreen()),
    );
  }

  Future<void> _showError(String code) async {
    if (!mounted) return;
    await AiErrorDialog.show(
      context,
      code: code,
      onRetry: () {
        _started = false;
        _start();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg(context),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress,
                          strokeWidth: 7,
                          color: AppColors.forest,
                          backgroundColor: _outline(context).withOpacity(.10),
                        ),
                      ),
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 42,
                        color: AppColors.forest,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _tr(context, 'enhancingPhoto'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    color: _text(context),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: _muted(context),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '${(_progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ImagePreviewScreen extends StatelessWidget {
  const ImagePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final path = state.draftImagePath;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        title: Text(
          _tr(context, 'preview'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text(context),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          children: <Widget>[
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: path == null || path.isEmpty
                    ? const Center(child: Icon(Icons.image_not_supported_outlined, size: 50))
                    : Image.file(
                        File(path),
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image_outlined, size: 50),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: _PressButton(
                onTap: () {
                  Navigator.push(
                    context,
                    KarigarPageRoute(builder: (_) => const ListingScreen()),
                  );
                },
                child: Text(
                  _tr(context, 'continue'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ListingScreen extends StatefulWidget {
  const ListingScreen({super.key});

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _priceController;
  late final TextEditingController _categoryController;

  bool _draftLoaded = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _priceController = TextEditingController();
    _categoryController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_draftLoaded) return;

    final draft = AppScope.of(context).draft;
    _titleController.text = draft.title;
    _descriptionController.text = draft.description;
    _priceController.text = draft.price.toString();
    _categoryController.text = draft.category;

    _draftLoaded = true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  void _saveAndContinue() {
    final state = AppScope.of(context);
    final price = int.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        state.draft.price;

    state.updateDraft(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      price: price,
      category: _categoryController.text.trim().isEmpty
          ? state.draft.category
          : _categoryController.text.trim(),
    );

    Navigator.push(
      context,
      KarigarPageRoute(builder: (_) => const PublishScreen()),
    );
  }

  InputDecoration _decoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: _surface(context),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final imagePath = state.draftImagePath;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        title: Text(
          _tr(context, 'listing'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text(context),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (imagePath != null && imagePath.isNotEmpty)
              Container(
                height: 220,
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: _surface(context),
                  borderRadius: BorderRadius.circular(22),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.file(
                  File(imagePath),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(Icons.broken_image_outlined, size: 46),
                  ),
                ),
              ),
            TextField(
              controller: _titleController,
              decoration: _decoration(context, _tr(context, 'productTitle')),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 5,
              decoration:
                  _decoration(context, _tr(context, 'productDescription')),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: _decoration(context, _tr(context, 'price')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _categoryController,
                    decoration: _decoration(context, _tr(context, 'category')),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: _PressButton(
                onTap: _saveAndContinue,
                child: Text(
                  _tr(context, 'continue'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
  }

  void _publish() {
    if (_done) return;
    AppScope.of(context).publishDraft();
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final draft = AppScope.of(context).draft;

    return Scaffold(
      backgroundColor: _bg(context),
      appBar: AppBar(
        backgroundColor: _bg(context),
        elevation: 0,
        title: Text(
          _tr(context, 'publish'),
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: _text(context),
          ),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _done ? Icons.check_circle_rounded : Icons.storefront_rounded,
                size: 78,
                color: AppColors.forest,
              ),
              const SizedBox(height: 20),
              Text(
                _done ? _tr(context, 'published') : draft.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: _text(context),
                ),
              ),
              const SizedBox(height: 9),
              Text(
                _done
                    ? _tr(context, 'productPublishedSuccessfully')
                    : _tr(context, 'readyToPublish'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: _muted(context),
                ),
              ),
              const SizedBox(height: 24),
              if (!_done)
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _PressButton(
                    onTap: _publish,
                    child: Text(
                      _tr(context, 'publish'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: _PressButton(
                    onTap: () => Navigator.popUntil(
                      context,
                      (Route<dynamic> route) => route.isFirst,
                    ),
                    child: Text(
                      _tr(context, 'done'),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _PressButton(
      onTap: onTap,
      backgroundColor:
          selected ? AppColors.forest : _surface(context),
      foregroundColor: selected ? Colors.white : _text(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 19),
          const SizedBox(width: 7),
          Text(
            label,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _PressButton extends StatefulWidget {
  const _PressButton({
    required this.onTap,
    required this.child,
    this.backgroundColor = AppColors.forest,
    this.foregroundColor = Colors.white,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  State<_PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<_PressButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? .975 : 1,
        duration: const Duration(milliseconds: 110),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: BorderRadius.circular(17),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: widget.backgroundColor.withOpacity(.18),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: DefaultTextStyle(
            style: TextStyle(color: widget.foregroundColor),
            child: IconTheme(
              data: IconThemeData(color: widget.foregroundColor),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
