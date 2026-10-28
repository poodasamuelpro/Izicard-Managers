import 'package:flutter/material.dart';

import '../../../core/widgets/izi_ui.dart';
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
                        'La suspension d’un accès bloque immédiatement le client.',
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
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                const IziNotice(
                  'Invitez vos clients, suivez leurs accès et créez des dossiers pour eux depuis cette page.',
                ),
                const SizedBox(height: 14),
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
                    padding: EdgeInsets.only(top: 24),
                    child: IziEmptyState(
                      icon: Icons.person_search_outlined,
                      title: 'Aucun client trouvé',
                      message: 'Modifiez la recherche ou invitez un nouveau client.',
                    ),
                  )
                else
                  ...clients.map(
                    (client) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ClientCard(
                        client: client,
                        onEdit: () => _edit(client),
                        onAccess: () => _manageAccess(client),
                        onCreateBatch:
                            widget.profile == null
                                ? null
                                : () => _createBatchFor(client),
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
  Widget build(BuildContext context) => IziErrorState(
    message: 'Impossible de charger les clients. Vérifiez votre connexion.',
    onRetry: onRetry,
  );
}

class _ClientCard extends StatelessWidget {
  const _ClientCard({
    required this.client,
    required this.onEdit,
    required this.onAccess,
    this.onCreateBatch,
  });
  final NfcClient client;
  final VoidCallback onEdit;
  final VoidCallback onAccess;
  final VoidCallback? onCreateBatch;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final ink = context.ink;
    final Color tone =
        !client.active
            ? ink.error
            : client.isExpired
            ? ink.pending
            : ink.verified;
    final details = [
      if (client.email?.isNotEmpty == true) client.email!,
      if (client.contactName?.isNotEmpty == true) client.contactName!,
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(Icons.business_rounded, color: colors.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (details.isNotEmpty)
                          Text(
                            details,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IziPill(client.accessLabel, color: tone),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 4,
                children: [
                  if (onCreateBatch != null)
                    TextButton.icon(
                      onPressed: onCreateBatch,
                      icon: const Icon(Icons.create_new_folder_outlined, size: 20),
                      label: const Text('Dossier'),
                    ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: const Text('Modifier'),
                  ),
                  TextButton.icon(
                    onPressed: onAccess,
                    icon: const Icon(Icons.manage_accounts_rounded, size: 20),
                    label: const Text('Accès'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
