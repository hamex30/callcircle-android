import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A user-chosen installed application. This is a launcher, not a calling API.
class CallingAppChoice {
  final String name;
  final String packageName;

  const CallingAppChoice({required this.name, required this.packageName});

  Map<String, String> toJson() => {'name': name, 'package': packageName};
}

class InstalledCallingAppPicker extends StatefulWidget {
  const InstalledCallingAppPicker({super.key});

  @override
  State<InstalledCallingAppPicker> createState() =>
      _InstalledCallingAppPickerState();
}

class _InstalledCallingAppPickerState extends State<InstalledCallingAppPicker> {
  static const _channel = MethodChannel('callcircle/app_launcher');
  final _search = TextEditingController();
  List<CallingAppChoice> _apps = [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(_refresh);
    _load();
  }

  @override
  void dispose() {
    _search.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await _channel.invokeListMethod<dynamic>('listApps') ?? [];
      final apps = <CallingAppChoice>[];
      final seen = <String>{};
      for (final entry in results) {
        if (entry is! Map) continue;
        final name = (entry['name'] ?? '').toString().trim();
        final packageName = (entry['package'] ?? '').toString().trim();
        if (name.isEmpty || packageName.isEmpty || !seen.add(packageName)) {
          continue;
        }
        apps.add(CallingAppChoice(name: name, packageName: packageName));
      }
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() { _apps = apps; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not list installed apps on this phone.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _apps.where((app) =>
        app.name.toLowerCase().contains(query) ||
        app.packageName.toLowerCase().contains(query)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose another calling app')),
      body: SafeArea(child: Column(children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text('Choose an installed app for this person. CallCircle will open it, but you will start the call yourself.',
            style: TextStyle(fontSize: 13)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Find an app, e.g. Telegram or Viber',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_error!),
                TextButton(onPressed: _load, child: const Text('Try again')),
              ]))
            : visible.isEmpty
              ? const Center(child: Text('No matching installed apps'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final app = visible[i];
                    return ListTile(
                      leading: const CircleAvatar(child: Icon(Icons.apps)),
                      title: Text(app.name),
                      subtitle: Text(app.packageName, maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.of(context).pop(app),
                    );
                  },
                )),
      ])),
    );
  }
}
