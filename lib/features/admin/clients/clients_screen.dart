import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/izicard_colors.dart';
import '../../../data/models/nfc_client.dart';
import '../../../data/models/nfc_profile.dart';
import '../../../data/repositories/batch_repository.dart';
import '../../../data/repositories/client_repository.dart';
import '../batches/batch_create_screen.dart';
import 'client_edit_screen.dart';
import 'client_form_screen.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key, required this.repository, this.profile});
  final ClientRepository repository;

  /// Profil administrateur : permet de créer un dossier depuis la fiche d'un client.
  final NfcProfile? profile;

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
  late Future<List<NfcClient>> _clients;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _clients = widget.repository.listClients();
  }

  Future<void> _refresh() async {
    final next = widget.repository.listClients();
    setState(() => _clients = next);
    await next;
  }

  Future<void> _openInvite() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ClientFormScreen(repository: widget.repository),
      ),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _createBatchFor(NfcClient client) async {
    final profile = widget.profile;
    if (profile == null) return;
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) => BatchCreateScreen(
              profile: profile,
              repository: BatchRepository(Supabase.instance.client),
              initialClientId: client.id,
            ),
      ),
    );
    if (created == true && mounted) await _refresh();
  }

  Future<void> _edit(NfcClient client) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder:
            (_) =>
                ClientEditScreen(client: client, repository: widget.repository),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _manageAccess(NfcClient client) async {
    var active = client.active;
    DateTime? expires = client.accessExpiresAt;
    final save = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: Text('Accès · ${client.name}'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: active,
                        title: const Text('Accès actif'),
                        onChanged:
                            (value) => setDialogState(() => active = value),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        expires == null
                            ? 'Expiration : aucune'
                            : 'Expire le ${MaterialLocalizations.of(context).formatMediumDate(expires!)}',
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate:
                                    expires != null && expires!.isAfter(now)
                                        ? expires!
                                        : now.add(const Duration(days: 30)),
                                firstDate: now,
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setDialogState(
                                  () =>
                                      expires = DateTime(
                                        picked.year,
                                        picked.month,
                                        picked.day,
                                        23,
                                        59,
                                        59,
                                      ),
                                );
                              }
                            },
                            icon: const Icon(Icons.calendar_month_rounded),
                            label: const Text('Choisir'),
                          ),
                          TextButton(
                            onPressed:
                                () => setDialogState(() => expires = null),
                            child: const Text('Sans date'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'La révocation est appliquée par Supabase et bloque immédiatement les opérations autorisées.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
          ),
    );
    if (save != true || !mounted) return;

    try {
      await widget.repository.setAccess(
        clientId: client.id,
        active: active,
        expiresAt: expires,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Accès client mis à jour.')));
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is PostgrestException ? error.message : error.toString(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Clients et accès')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _openInvite,
      icon: const Icon(Icons.person_add_alt_1_rounded),
      label: const Text('Inviter un client'),
    ),
    body: SafeArea(
      child: FutureBuilder<List<NfcClient>>(
        future: _clients,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _ClientError(onRetry: _refresh);
          }
          final clients =
              (snapshot.data ?? const <NfcClient>[])
                  .where(
                    (client) =>
                        client.name.toLowerCase().contains(
                          _search.toLowerCase(),
                        ) ||
                        (client.email ?? '').toLowerCase().contains(
                          _search.toLowerCase(),
                        ),
                  )
                  .toList();

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'Les clients et leurs droits sont lus dans nfc. La création des comptes de connexion reste dans Supabase Auth ; aucun secret administrateur n’est embarqué dans l’application.',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (value) => setState(() => _search = value.trim()),
                  decoration: const InputDecoration(
                    hintText: 'Rechercher un client',
                    prefixIcon: Icon(Icons.search_rounded),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                if (clients.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Aucun client correspondant.')),
                  )
                else
                  ...clients.map(
                    (client) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(.14),
                          child: Icon(
                            Icons.business_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 5),
                          child: Text(
                            [
                              if (client.email?.isNotEmpty == true)
                                client.email!,
                              if (client.contactName?.isNotEmpty == true)
                                client.contactName!,
                              'Accès : ${client.accessLabel}',
                            ].join(' · '),
                          ),
                        ),
                        onTap: () => _edit(client),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.profile != null)
                              IconButton(
                                tooltip: 'Créer un dossier',
                                onPressed: () => _createBatchFor(client),
                                icon: const Icon(
                                  Icons.create_new_folder_outlined,
                                ),
                              ),
                            IconButton(
                              tooltip: 'Modifier le client',
                              onPressed: () => _edit(client),
                              icon: const Icon(Icons.edit_outlined),
                            ),
                            IconButton.filledTonal(
                              tooltip: 'Gérer les accès',
                              onPressed: () => _manageAccess(client),
                              icon: const Icon(Icons.manage_accounts_rounded),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    ),
  );
}

class _ClientError extends StatelessWidget {
  const _ClientError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Impossible de charger les clients.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Réessayer'),
        ),
      ],
    ),
  );
}
