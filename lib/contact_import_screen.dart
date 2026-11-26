import 'package:flutter/material.dart';
import 'app_picker_screen.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// A lightweight copy of only the contact details the user selected.
/// Unselected phone-book entries are never sent to the WebView or stored.
class SelectedPhoneContact {
  final String name;
  final String phone;
  final String sourceContactId;
  final String frequency;
  final String method;
  final String relation;
  final String customAppName;
  final String customAppPackage;

  const SelectedPhoneContact({
    required this.name,
    required this.phone,
    required this.sourceContactId,
    required this.frequency,
    required this.method,
    required this.relation,
    this.customAppName = '',
    this.customAppPackage = '',
  });

  Map<String, String> toJson() => {
        'name': name,
        'phone': phone,
        'sourceContactId': sourceContactId,
        'frequency': frequency,
        'method': method,
        'relation': relation,
        'customAppName': customAppName,
        'customAppPackage': customAppPackage,
      };
}

class ContactImportScreen extends StatefulWidget {
  const ContactImportScreen({super.key});

  @override
  State<ContactImportScreen> createState() => _ContactImportScreenState();
}

class _ContactImportScreenState extends State<ContactImportScreen> {
  final _searchController = TextEditingController();
  List<Contact> _contacts = [];
  final Set<String> _selected = {};
  final Map<String, String> _chosenPhones = {};
  bool _loading = true;
  String? _error;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_updateSearch);
    _loadContacts();
  }

  @override
  void dispose() {
    _searchController.removeListener(_updateSearch);
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch() { if (mounted) setState(() {}); }

  String _id(Contact c) => c.id ?? '${c.displayName ?? ''}:${c.phones.isNotEmpty ? c.phones.first.number : ''}';

  Future<void> _loadContacts() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; _permissionDenied = false; });
    try {
      final status = await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _permissionDenied = true;
          _error = 'Allow CallCircle to read contacts to choose people from your phone. You can still add people manually without this permission.';
        });
        return;
      }
      final contacts = await FlutterContacts.getAll(properties: {ContactProperty.phone});
      contacts.removeWhere((c) => (c.displayName ?? '').trim().isEmpty || c.phones.every((p) => p.number.trim().isEmpty));
      contacts.sort((a, b) => (a.displayName ?? '').toLowerCase().compareTo((b.displayName ?? '').toLowerCase()));
      if (!mounted) return;
      setState(() { _contacts = contacts; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Could not load phone contacts. Please try again.'; _loading = false; });
    }
  }

  String _phone(Contact c) {
    final id = _id(c);
    if (_chosenPhones.containsKey(id)) return _chosenPhones[id]!;
    for (final phone in c.phones) {
      if (phone.isPrimary == true && phone.number.trim().isNotEmpty) return phone.number;
    }
    return c.phones.firstWhere((p) => p.number.trim().isNotEmpty).number;
  }

  Future<void> _finish() async {
    if (_selected.isEmpty) return;
    String frequency = 'weekly';
    String method = 'whatsapp';
    String relation = 'Family';
    String customAppName = '';
    String customAppPackage = '';
    final options = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, refresh) {
        return AlertDialog(
          title: Text('Import ${_selected.length} ${_selected.length == 1 ? 'person' : 'people'}'),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Choose starting settings for this group. You can change each person later.'),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: frequency,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Call frequency', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'biweekly', child: Text('Every 2 weeks')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'ramadan', child: Text('Ramadan list')),
                DropdownMenuItem(value: 'eid-fitr', child: Text('Eid al-Fitr list')),
                DropdownMenuItem(value: 'eid-adha', child: Text('Eid al-Adha list')),
              ],
              onChanged: (v) { if (v != null) refresh(() => frequency = v); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: relation,
              decoration: const InputDecoration(labelText: 'Relationship', border: OutlineInputBorder()),
              items: const ['Family', 'Relative', 'Friend', 'Other']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) { if (v != null) refresh(() => relation = v); },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: 'Calling method', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
                DropdownMenuItem(value: 'whitecalling', child: Text('White Calling')),
                DropdownMenuItem(value: 'phone', child: Text('Phone')),
                DropdownMenuItem(value: 'imo', child: Text('imo')),
                DropdownMenuItem(value: 'other', child: Text('Other installed app')),
              ],
              onChanged: (v) { if (v != null) refresh(() => method = v); },
            ),
            if (method == 'other') ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.apps),
                label: Text(customAppPackage.isEmpty
                    ? 'Choose installed calling app'
                    : customAppName),
                onPressed: () async {
                  final selected = await Navigator.of(dialogContext)
                      .push<CallingAppChoice>(MaterialPageRoute(
                          builder: (_) => const InstalledCallingAppPicker()));
                  if (dialogContext.mounted && selected != null) {
                    refresh(() {
                      customAppName = selected.name;
                      customAppPackage = selected.packageName;
                    });
                  }
                },
              ),
              const SizedBox(height: 4),
              const Text('The selected app will open, then you start the call.',
                  style: TextStyle(fontSize: 12)),
            ],
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            FilledButton(
              onPressed: method == 'other' && customAppPackage.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, {
                      'frequency': frequency,
                      'relation': relation,
                      'method': method,
                      'customAppName': customAppName,
                      'customAppPackage': customAppPackage,
                    }),
              child: const Text('Import'),
            ),
          ],
        );
      }),
    );
    if (!mounted || options == null) return;
    final choices = _contacts.where((c) => _selected.contains(_id(c))).map((c) {
      return SelectedPhoneContact(
        name: c.displayName!.trim(),
        phone: _phone(c),
        sourceContactId: _id(c),
        frequency: options['frequency']!,
        method: options['method']!,
        relation: options['relation']!,
        customAppName: options['customAppName'] ?? '',
        customAppPackage: options['customAppPackage'] ?? '',
      );
    }).toList();
    Navigator.pop(context, choices);
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchController.text.toLowerCase().trim();
    final visible = _contacts.where((c) => q.isEmpty ||
      (c.displayName ?? '').toLowerCase().contains(q) ||
      c.phones.any((p) => p.number.contains(q))).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Choose phone contacts')),
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Only people you select will be added to CallCircle. Contacts stay on your phone.',
              style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search), hintText: 'Search names or numbers',
                border: OutlineInputBorder(), isDense: true,
              ),
            ),
          ]),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.contacts_outlined, size: 48),
                  const SizedBox(height: 12),
                  Text(_error!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _loadContacts, child: const Text('Try again')),
                  if (_permissionDenied) TextButton(
                    onPressed: () => FlutterContacts.permissions.openSettings(),
                    child: const Text('Open permission settings'),
                  ),
                ])))
            : visible.isEmpty
              ? const Center(child: Text('No matching contacts with phone numbers'))
              : ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, i) {
                    final c = visible[i], id = _id(c);
                    final isSelected = _selected.contains(id);
                    final numbers = c.phones.map((p) => p.number).where((s) => s.trim().isNotEmpty).toSet().toList();
                    return Column(children: [
                      CheckboxListTile(
                        value: isSelected,
                        onChanged: (value) => setState(() {
                          if (value == true) { _selected.add(id); } else { _selected.remove(id); }
                        }),
                        title: Text(c.displayName ?? ''),
                        subtitle: Text(_phone(c), maxLines: 1, overflow: TextOverflow.ellipsis),
                        secondary: CircleAvatar(child: Text(
                          (c.displayName ?? '?').trim().substring(0, 1).toUpperCase(),
                        )),
                      ),
                      if (isSelected && numbers.length > 1)
                        Padding(padding: const EdgeInsets.fromLTRB(74, 0, 20, 8), child: DropdownButtonFormField<String>(
                          value: numbers.contains(_phone(c)) ? _phone(c) : numbers.first,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Use this number', isDense: true),
                          items: numbers.map((n) => DropdownMenuItem(value: n, child: Text(n, overflow: TextOverflow.ellipsis))).toList(),
                          onChanged: (n) { if (n != null) setState(() => _chosenPhones[id] = n); },
                        )),
                      const Divider(height: 1, indent: 16),
                    ]);
                  },
                )),
        Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selected.isEmpty ? null : _finish,
            icon: const Icon(Icons.person_add_alt_1),
            label: Text(_selected.isEmpty ? 'Select people to import' : 'Continue with ${_selected.length} selected'),
          ),
        )),
      ])),
    );
  }
}