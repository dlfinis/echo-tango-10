/// ADMIN screen — full config editor.
///
/// Sections (top-to-bottom):
///   1. Mensajes de invitación — editable TextField list, add/remove.
///   2. Sub-frases (sub-taglines) — same pattern as mensajes.
///   3. Intervalos de rotación — three numeric fields (1..3600):
///      mensajes, sub-frases, leaderboard.
///   4. Colores — three "siguiente color preset" cycles (full picker is
///      overkill for PR2; Diego can pick from a curated palette).
///   5. Result timeout — how long the RESULT screen stays before
///      auto-returning to WAITING (1..60 seconds).
///   6. Rango de victoria — two numeric fields (start, end) defining
///      the inclusive window that fires the VICTORIA verdict.
///   7. Zona peligrosa — "Borrar base de datos" with confirm dialog.
///   8. Salir — returns to WAITING.
///
/// Edits save on blur (or on a "Guardar" tap for numeric fields). The
/// caller passes the [ConfigStore] and [Leaderboard] in; this widget
/// never touches `SharedPreferences` directly.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/config_store.dart';
import '../services/leaderboard.dart';
import '../utils/constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({
    super.key,
    required this.configStore,
    required this.leaderboard,
    required this.onExit,
    this.onConnectUsb,
  });

  final ConfigStore configStore;
  final Leaderboard leaderboard;
  final VoidCallback onExit;

  /// Optional dev-only hook (see [AdminScreen._handleConnectUsb]).
  /// When null the "Connect USB (Web Serial)" button is hidden.
  final Future<void> Function()? onConnectUsb;

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  // Text controllers — recreated on every build from the store so the
  // form always reflects the persisted truth.
  late List<TextEditingController> _messageControllers;
  late List<TextEditingController> _subTaglineControllers;
  late TextEditingController _messageIntervalController;
  late TextEditingController _subTaglineIntervalController;
  late TextEditingController _leaderboardIntervalController;
  late TextEditingController _resultTimeoutController;
  late TextEditingController _victoryStartController;
  late TextEditingController _victoryEndController;

  // Working copy of the current color indices into the preset palette.
  int _bgIndex = 0;
  int _textIndex = 0;
  int _accentIndex = 0;

  // Fixed, curated palette (PR2). Future PR may swap in a real picker.
  static const List<Color> _bgPalette = <Color>[
    Color(0xFF121212),
    Color(0xFF000000),
    Color(0xFF1A237E),
    Color(0xFF263238),
    Color(0xFF3E2723),
  ];
  static const List<Color> _textPalette = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFFEB3B),
    Color(0xFFFF4081),
    Color(0xFF80DEEA),
  ];
  static const List<Color> _accentPalette = <Color>[
    Color(0xFF00FF00),
    Color(0xFFFFC107),
    Color(0xFFFF1744),
    Color(0xFF00E5FF),
  ];

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    _messageControllers = widget.configStore
        .invitationMessages()
        .map((String s) => TextEditingController(text: s))
        .toList();
    _subTaglineControllers = widget.configStore
        .subTaglines()
        .map((String s) => TextEditingController(text: s))
        .toList();
    _messageIntervalController = TextEditingController(
      text: widget.configStore.messageRotationSeconds().toString(),
    );
    _subTaglineIntervalController = TextEditingController(
      text: widget.configStore.subTaglineRotationSeconds().toString(),
    );
    _leaderboardIntervalController = TextEditingController(
      // Clamp the persisted value to the new [3,15] range so any
      // legacy entry above 15 (e.g. set when the upper bound was
      // 120) is shown to the operator at 15 — the next save will
      // then persist the clamped value back.
      text: widget.configStore
          .leaderboardRotationSeconds()
          .clamp(kMinLeaderboardRotationSeconds, kMaxLeaderboardRotationSeconds)
          .toString(),
    );
    _resultTimeoutController = TextEditingController(
      text: widget.configStore.resultAutoReturnSeconds().toString(),
    );
    _victoryStartController = TextEditingController(
      text: widget.configStore.victoryRangeStart().toStringAsFixed(4),
    );
    _victoryEndController = TextEditingController(
      text: widget.configStore.victoryRangeEnd().toStringAsFixed(4),
    );
    _bgIndex = _findClosest(widget.configStore.bgColorArgb(), _bgPalette);
    _textIndex =
        _findClosest(widget.configStore.textColorArgb(), _textPalette);
    _accentIndex =
        _findClosest(widget.configStore.accentColorArgb(), _accentPalette);
  }

  int _findClosest(int targetArgb, List<Color> palette) {
    int bestIdx = 0;
    int bestDistance = 1 << 30;
    for (int i = 0; i < palette.length; i++) {
      final int d = (palette[i].toARGB32() & 0xFFFFFF) -
          (targetArgb & 0xFFFFFF); // ignore alpha
      final int dist = d.abs();
      if (dist < bestDistance) {
        bestDistance = dist;
        bestIdx = i;
      }
    }
    return bestIdx;
  }

  @override
  void dispose() {
    for (final TextEditingController c in _messageControllers) {
      c.dispose();
    }
    for (final TextEditingController c in _subTaglineControllers) {
      c.dispose();
    }
    _messageIntervalController.dispose();
    _subTaglineIntervalController.dispose();
    _leaderboardIntervalController.dispose();
    _resultTimeoutController.dispose();
    _victoryStartController.dispose();
    _victoryEndController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Mutation handlers
  // ---------------------------------------------------------------------------

  Future<void> _saveMessages() async {
    await widget.configStore.setInvitationMessages(
      _messageControllers.map((TextEditingController c) => c.text).toList(),
    );
  }

  Future<void> _saveSubTaglines() async {
    await widget.configStore.setSubTaglines(
      _subTaglineControllers.map((TextEditingController c) => c.text).toList(),
    );
  }

  Future<void> _saveIntervals() async {
    final int? msg = int.tryParse(_messageIntervalController.text.trim());
    final int? sub = int.tryParse(_subTaglineIntervalController.text.trim());
    if (msg != null && msg >= 1 && msg <= 3600) {
      await widget.configStore.setMessageRotationSeconds(msg);
    }
    if (sub != null && sub >= 1 && sub <= 3600) {
      await widget.configStore.setSubTaglineRotationSeconds(sub);
    }
  }

  Future<void> _saveLeaderboardRotation() async {
    final int? v =
        int.tryParse(_leaderboardIntervalController.text.trim());
    if (v == null) return;
    if (v < kMinLeaderboardRotationSeconds ||
        v > kMaxLeaderboardRotationSeconds) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB71C1C),
          content: Text(
            'Tiempo del ranking debe estar entre '
            '3 y 15 segundos',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }
    try {
      await widget.configStore.setLeaderboardRotationSeconds(v);
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB71C1C),
          content: Text('Tiempo del ranking inválido: ${e.message}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Tiempo del ranking guardado ($v s)',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _saveResultTimeout() async {
    final int? v = int.tryParse(_resultTimeoutController.text.trim());
    if (v != null && v >= 1 && v <= 60) {
      await widget.configStore.setResultAutoReturnSeconds(v);
    }
  }

  /// Reads both victory-range fields, validates the bounds, and persists
  /// them atomically. The validator runs in the UI (cheap, sync) so a
  /// bad input never reaches the store — the [ArgumentError] inside
  /// [ConfigStore.setVictoryRange] is a defense-in-depth backstop.
  Future<void> _saveVictoryRange() async {
    final String startRaw = _victoryStartController.text.trim();
    final String endRaw = _victoryEndController.text.trim();
    final double? start = double.tryParse(startRaw);
    final double? end = double.tryParse(endRaw);

    final bool invalid = start == null ||
        end == null ||
        start <= 0 ||
        end <= 0 ||
        start >= end;

    if (!mounted) return;
    if (invalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Color(0xFFB71C1C),
          content: Text(
            'Victoria desde debe ser menor que Victoria hasta '
            '(ambos positivos)',
          ),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      await widget.configStore.setVictoryRange(
        start: start,
        end: end,
      );
    } on ArgumentError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFB71C1C),
          content: Text('Rango de victoria inválido: ${e.message}'),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rango de victoria guardado'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _cycleBg() async {
    setState(() {
      _bgIndex = (_bgIndex + 1) % _bgPalette.length;
    });
    await widget.configStore.setBgColorArgb(_bgPalette[_bgIndex].toARGB32());
  }

  Future<void> _cycleText() async {
    setState(() {
      _textIndex = (_textIndex + 1) % _textPalette.length;
    });
    await widget.configStore
        .setTextColorArgb(_textPalette[_textIndex].toARGB32());
  }

  Future<void> _cycleAccent() async {
    setState(() {
      _accentIndex = (_accentIndex + 1) % _accentPalette.length;
    });
    await widget.configStore
        .setAccentColorArgb(_accentPalette[_accentIndex].toARGB32());
  }

  Future<void> _confirmWipe() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(kDefaultBgColorHex),
          title: const Text(
            '¿Borrar base de datos?',
            style: TextStyle(color: Color(kDefaultTextColorHex)),
          ),
          content: const Text(
            'Se eliminarán todos los mensajes, intervalos, colores y los registros del leaderboard. Esta acción no se puede deshacer.',
            style: TextStyle(color: Color(kDefaultTextColorHex)),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFFF1744),
              ),
              child: const Text('Borrar todo'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    if (!mounted) return;

    // Clear everything at the SharedPreferences level, then the
    // in-memory Leaderboard mirror, then re-hydrate the form.
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await widget.leaderboard.clear();

    if (!mounted) return;
    setState(() {
      for (final TextEditingController c in _messageControllers) {
        c.dispose();
      }
      for (final TextEditingController c in _subTaglineControllers) {
        c.dispose();
      }
      _hydrate();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Base de datos borrada'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Web Serial dev gate (PR2 stretch; see keyboard_input.dart).
  // ---------------------------------------------------------------------------
  Future<void> _handleConnectUsb() async {
    if (widget.onConnectUsb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Web Serial no disponible en esta build',
          ),
        ),
      );
      return;
    }
    try {
      await widget.onConnectUsb!();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('USB conectado')),
      );
    } on Object catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error USB: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(kDefaultBgColorHex),
      appBar: AppBar(
        title: const Text(
          'Administración',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: const Color(kDefaultBgColorHex),
        foregroundColor: const Color(kDefaultTextColorHex),
        // Big visible close button (X) on the right.
        actions: <Widget>[
          IconButton(
            tooltip: 'Salir',
            iconSize: 40,
            color: const Color(kDefaultAccentColorHex),
            icon: const Icon(Icons.close),
            onPressed: widget.onExit,
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _sectionHeader('Mensajes de invitación'),
              ..._buildMessagesSection(),
              const SizedBox(height: 24),

              _sectionHeader('Sub-frases (call to action)'),
              ..._buildSubTaglinesSection(),
              const SizedBox(height: 24),

              _sectionHeader('Intervalos de rotación (segundos)'),
              _numericField(
                label: 'Rotación de mensajes',
                controller: _messageIntervalController,
                onSave: _saveIntervals,
              ),
              const SizedBox(height: 12),
              _numericField(
                label: 'Rotación de sub-frases',
                controller: _subTaglineIntervalController,
                onSave: _saveIntervals,
              ),
              const SizedBox(height: 12),
              _numericField(
                label: 'Tiempo del ranking',
                controller: _leaderboardIntervalController,
                onSave: _saveLeaderboardRotation,
                helperText: 'Segundos. Mínimo 3, máximo 15.',
              ),
              const SizedBox(height: 24),

              _sectionHeader('Tiempo en pantalla de resultado'),
              _numericField(
                label: 'Auto-retorno a waiting (segundos)',
                controller: _resultTimeoutController,
                onSave: _saveResultTimeout,
                helperText: 'Entre 1 y 60. Tap acelera el retorno.',
              ),
              const SizedBox(height: 24),

              _sectionHeader('Rango de victoria'),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _decimalNumericField(
                      label: 'Victoria desde',
                      controller: _victoryStartController,
                      onSave: _saveVictoryRange,
                      helperText: 'En segundos. Ej: 9.9990',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _decimalNumericField(
                      label: 'Victoria hasta',
                      controller: _victoryEndController,
                      onSave: _saveVictoryRange,
                      helperText: 'En segundos. Ej: 10.0010',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saveVictoryRange,
                  icon: const Icon(
                    Icons.save_outlined,
                    color: Color(kDefaultAccentColorHex),
                  ),
                  label: const Text(
                    'Guardar rango',
                    style: TextStyle(color: Color(kDefaultAccentColorHex)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(kDefaultAccentColorHex),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              _sectionHeader('Colores'),
              _colorRow(
                label: 'Fondo',
                color: _bgPalette[_bgIndex],
                onCycle: _cycleBg,
              ),
              _colorRow(
                label: 'Texto',
                color: _textPalette[_textIndex],
                onCycle: _cycleText,
              ),
              _colorRow(
                label: 'Acento',
                color: _accentPalette[_accentIndex],
                onCycle: _cycleAccent,
              ),
              const SizedBox(height: 24),

              _sectionHeader('Zona peligrosa'),
              OutlinedButton.icon(
                onPressed: _confirmWipe,
                icon: const Icon(Icons.delete_forever,
                    color: Color(0xFFFF1744)),
                label: const Text(
                  'Borrar base de datos',
                  style: TextStyle(color: Color(0xFFFF1744)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFF1744)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Entradas en leaderboard: ${widget.leaderboard.length}',
                style: const TextStyle(
                  color: Color(0xFFAAAAAA),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),

              // Dev section — only visible when the host wired a callback.
              if (widget.onConnectUsb != null) ...<Widget>[
                _sectionHeader('Dev'),
                OutlinedButton.icon(
                  // WEB SERIAL DEV GATE — requires Chrome HTTPS or localhost
                  onPressed: _handleConnectUsb,
                  icon: const Icon(Icons.usb,
                      color: Color(kDefaultAccentColorHex)),
                  label: Text(
                    !kIsWeb
                        ? 'Conectar Arduino'
                        : 'Connect USB (Web Serial)',
                    style: TextStyle(
                      color: Color(kDefaultAccentColorHex),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(
                      color: Color(kDefaultAccentColorHex),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      // Sticky bottom action bar — always visible regardless of scroll
      // position, so the operator can always reach "Salir" and
      // "Cerrar juego" without hunting through the form.
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            color: Color(kDefaultBgColorHex),
            border: Border(
              top: BorderSide(
                color: Color(0xFF333333),
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onExit,
                  icon: const Icon(Icons.arrow_back, size: 28),
                  label: const Text(
                    'Salir',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(kDefaultAccentColorHex),
                    foregroundColor: const Color(kDefaultBgColorHex),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _confirmCloseApp,
                  icon: const Icon(Icons.power_settings_new, size: 28),
                  label: const Text(
                    'Cerrar juego',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCloseApp() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          '¿Cerrar el juego?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'La aplicación se va a cerrar. En la tablet, volve a abrirla desde el launcher.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Color(0xFFFF5252)),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // On Web there is no way to terminate the browser tab, so we just
    // show a snackbar. On Android (PR3) we'll wire SystemNavigator.pop.
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'En la tablet usá el botón de atrás del sistema. '
          'Cierre real en PR3.',
        ),
        backgroundColor: Color(0xFFB71C1C),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Section helpers
  // ---------------------------------------------------------------------------

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(kDefaultTextColorHex),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Widget> _buildMessagesSection() {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _messageControllers.length; i++) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _messageControllers[i],
                  style: const TextStyle(color: Color(kDefaultTextColorHex)),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: 'Mensaje ${i + 1}',
                    labelStyle:
                        const TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                  onChanged: (_) => _saveMessages(),
                ),
              ),
              IconButton(
                onPressed: _messageControllers.length <= 1
                    ? null
                    : () {
                        setState(() {
                          _messageControllers[i].dispose();
                          _messageControllers.removeAt(i);
                        });
                        _saveMessages();
                      },
                icon: const Icon(Icons.remove_circle_outline,
                    color: Color(0xFFFF1744)),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      );
    }
    out.add(
      TextButton.icon(
        onPressed: () {
          setState(() {
            _messageControllers.add(TextEditingController());
          });
        },
        icon: const Icon(Icons.add_circle_outline,
            color: Color(kDefaultAccentColorHex)),
        label: const Text(
          'Agregar mensaje',
          style: TextStyle(color: Color(kDefaultAccentColorHex)),
        ),
      ),
    );
    return out;
  }

  /// Same pattern as [_buildMessagesSection] but for the
  /// sub-tagline list (the "call to action" text that appears
  /// under the main message on the WAITING screen).
  List<Widget> _buildSubTaglinesSection() {
    final List<Widget> out = <Widget>[];
    for (int i = 0; i < _subTaglineControllers.length; i++) {
      out.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _subTaglineControllers[i],
                  style: const TextStyle(color: Color(kDefaultAccentColorHex)),
                  decoration: InputDecoration(
                    isDense: true,
                    border: const OutlineInputBorder(),
                    labelText: 'Sub-frase ${i + 1}',
                    labelStyle:
                        const TextStyle(color: Color(0xFFAAAAAA)),
                  ),
                  onChanged: (_) => _saveSubTaglines(),
                ),
              ),
              IconButton(
                onPressed: _subTaglineControllers.length <= 1
                    ? null
                    : () {
                        setState(() {
                          _subTaglineControllers[i].dispose();
                          _subTaglineControllers.removeAt(i);
                        });
                        _saveSubTaglines();
                      },
                icon: const Icon(Icons.remove_circle_outline,
                    color: Color(0xFFFF1744)),
                tooltip: 'Eliminar',
              ),
            ],
          ),
        ),
      );
    }
    out.add(
      TextButton.icon(
        onPressed: () {
          setState(() {
            _subTaglineControllers.add(TextEditingController());
          });
        },
        icon: const Icon(Icons.add_circle_outline,
            color: Color(kDefaultAccentColorHex)),
        label: const Text(
          'Agregar sub-frase',
          style: TextStyle(color: Color(kDefaultAccentColorHex)),
        ),
      ),
    );
    return out;
  }

  Widget _numericField({
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onSave,
    String helperText = 'Entre 1 y 3600 segundos',
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.digitsOnly,
      ],
      style: const TextStyle(color: Color(kDefaultTextColorHex)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        border: const OutlineInputBorder(),
        helperText: helperText,
        helperStyle: const TextStyle(color: Color(0xFFAAAAAA)),
      ),
      onFieldSubmitted: (_) => onSave(),
      onEditingComplete: onSave,
    );
  }

  /// Same as [_numericField] but allows a single decimal point so the
  /// operator can enter fractional seconds (e.g. 9.9990) for the
  /// victory range.
  Widget _decimalNumericField({
    required String label,
    required TextEditingController controller,
    required Future<void> Function() onSave,
    required String helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      style: const TextStyle(color: Color(kDefaultTextColorHex)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        border: const OutlineInputBorder(),
        helperText: helperText,
        helperStyle: const TextStyle(color: Color(0xFFAAAAAA)),
      ),
      onFieldSubmitted: (_) => onSave(),
      onEditingComplete: onSave,
    );
  }

  Widget _colorRow({
    required String label,
    required Color color,
    required Future<void> Function() onCycle,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              border: Border.all(color: const Color(kDefaultTextColorHex)),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(kDefaultTextColorHex),
                fontSize: 18,
              ),
            ),
          ),
          OutlinedButton(
            onPressed: onCycle,
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }
}
