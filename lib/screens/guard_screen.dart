import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../services/guard_service.dart';

class GuardScreen extends StatefulWidget {
  const GuardScreen({super.key});

  @override
  State<GuardScreen> createState() => _GuardScreenState();
}

class _GuardScreenState extends State<GuardScreen> {
  static const _dayNames = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];

  final _service = GuardService();
  GuardStatus? _status;
  bool _scheduleEnabled = false;
  List<GuardWindow> _windows = [];
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final st = await _service.status();
      final sch = await _service.loadSchedule();
      final cfg = await _service.loadSettings();
      if (!mounted) return;
      setState(() {
        _status = st;
        _scheduleEnabled = sch.enabled;
        _windows = sch.windows;
        _settings = cfg;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _setSetting(String key, Object value) async {
    setState(() => _settings[key] = value);
    try {
      final res = await _service.saveSettings({key: value});
      if (mounted) setState(() => _settings = res);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
      await _refresh();
    }
  }

  Future<void> _toggleArmed(bool value) => _run(() => _service.setArmed(value));

  Future<void> _saveSchedule() =>
      _run(() => _service.saveSchedule(_scheduleEnabled, _windows));

  Future<void> _pickTime(GuardWindow w, bool isStart) async {
    final cur = (isStart ? w.start : w.end).split(':');
    final t = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay(hour: int.parse(cur[0]), minute: int.parse(cur[1])),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    final s =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    setState(() => isStart ? w.start = s : w.end = s);
    await _saveSchedule();
  }

  Future<void> _addWindow() async {
    setState(() => _windows
        .add(GuardWindow(days: {0, 1, 2, 3, 4}, start: '08:00', end: '18:00')));
    await _saveSchedule();
  }

  Future<void> _editConnection() async {
    final url = TextEditingController(text: await _service.loadUrl());
    final token = TextEditingController(text: await _service.loadToken());
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conexão com o Guard'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: url,
                decoration: const InputDecoration(labelText: 'Endereço')),
            TextField(
              controller: token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Token da API'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salvar')),
        ],
      ),
    );
    if (ok == true) {
      await _service.saveConnection(url.text, token.text);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _status;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppConfig.backgroundColor,
        appBar: AppBar(
          title: const Text('Guard'),
          bottom: const TabBar(
            indicatorColor: AppConfig.accentColor,
            labelColor: AppConfig.accentColor,
            tabs: [Tab(text: 'Controle'), Tab(text: 'Ajustes')],
          ),
          actions: [
            IconButton(
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
                tooltip: 'Atualizar'),
            IconButton(
                onPressed: _editConnection,
                icon: const Icon(Icons.settings),
                tooltip: 'Conexão'),
          ],
        ),
        body: _loading && st == null
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(children: [_controlTab(st), _settingsTab()]),
      ),
    );
  }

  Widget _errorCard() => Card(
        color: AppConfig.alertColor.withAlpha(40),
        child: Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
      );

  Widget _controlTab(GuardStatus? st) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) _errorCard(),
        if (st != null) ...[
          Card(
            color: AppConfig.cardColor,
            child: SwitchListTile(
              title: Text(st.armed ? 'Guard armado' : 'Guard desarmado'),
              subtitle: Text(!st.armed
                  ? 'Desarmado manualmente'
                  : st.active
                      ? 'Vigiando agora (${st.cameras} câmera(s))'
                      : 'Armado, aguardando a próxima janela da agenda'),
              value: st.armed,
              activeThumbColor: AppConfig.accentColor,
              onChanged: _toggleArmed,
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: AppConfig.cardColor,
            child: SwitchListTile(
              title: const Text('Agenda automática'),
              subtitle: const Text('Só vigia dentro dos horários abaixo'),
              value: _scheduleEnabled,
              activeThumbColor: AppConfig.accentColor,
              onChanged: (v) {
                setState(() => _scheduleEnabled = v);
                _saveSchedule();
              },
            ),
          ),
          for (var i = 0; i < _windows.length; i++) _windowCard(i),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _windows.length >= 20 ? null : _addWindow,
            icon: const Icon(Icons.add),
            label: const Text('Adicionar horário'),
          ),
        ],
      ],
    );
  }

  Widget _slider(String title, String key, double min, double max,
      int divisions, String Function(num) fmt,
      {String? hint}) {
    final value = ((_settings[key] ?? min) as num).toDouble().clamp(min, max);
    return Card(
      color: AppConfig.cardColor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(title)),
              Text(fmt(value),
                  style: const TextStyle(
                      color: AppConfig.accentColor,
                      fontWeight: FontWeight.w700)),
            ]),
            if (hint != null)
              Text(hint,
                  style: const TextStyle(
                      color: AppConfig.mutedTextColor, fontSize: 12)),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              activeColor: AppConfig.accentColor,
              onChanged: (v) => setState(() => _settings[key] = v),
              onChangeEnd: (v) => _setSetting(key, v.round()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch(String title, String subtitle, String key) => Card(
        color: AppConfig.cardColor,
        child: SwitchListTile(
          title: Text(title),
          subtitle: Text(subtitle),
          value: _settings[key] == true,
          activeThumbColor: AppConfig.accentColor,
          onChanged: (v) => _setSetting(key, v),
        ),
      );

  Widget _settingsTab() {
    if (_settings.isEmpty) {
      return ListView(
          padding: const EdgeInsets.all(16),
          children: [if (_error != null) _errorCard()]);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null) _errorCard(),
        _switch('Enviar notificações', 'Desligado = só registra o histórico',
            'notify'),
        _switch('Só avisar com pessoa', 'Ignora carros, animais e sombras',
            'requirePerson'),
        _slider('Sensibilidade', 'sensitivity', 1, 10, 9, (v) => '${v.round()}',
            hint: 'Maior = detecta movimentos menores'),
        _slider('Confirmação de pessoa', 'personMinHits', 1, 5, 4,
            (v) => '${v.round()} detecções',
            hint: 'Maior = menos falsos alarmes, mais lento'),
        _slider('Pausa entre avisos', 'cooldownSeconds', 10, 600, 59,
            (v) => '${v.round()} s'),
        _slider('Máx. avisos por hora', 'maxNotificationsPerHour', 1, 60, 59,
            (v) => '${v.round()}'),
        _slider('Guardar fotos por', 'keepDays', 1, 90, 89,
            (v) => '${v.round()} dias'),
        _slider('Espaço máximo das fotos', 'maxSnapshotsMb', 50, 5000, 99,
            (v) => '${v.round()} MB'),
      ],
    );
  }

  Widget _windowCard(int i) {
    final w = _windows[i];
    return Card(
      color: AppConfig.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (var d = 0; d < 7; d++)
                  FilterChip(
                    label: Text(_dayNames[d]),
                    selected: w.days.contains(d),
                    selectedColor: AppConfig.accentColor.withAlpha(90),
                    onSelected: (sel) {
                      if (!sel && w.days.length == 1) return;
                      setState(() => sel ? w.days.add(d) : w.days.remove(d));
                      _saveSchedule();
                    },
                  ),
              ],
            ),
            Row(
              children: [
                TextButton(
                    onPressed: () => _pickTime(w, true),
                    child: Text('Das ${w.start}')),
                TextButton(
                    onPressed: () => _pickTime(w, false),
                    child: Text('às ${w.end}')),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    setState(() => _windows.removeAt(i));
                    _saveSchedule();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
