import 'package:flutter/material.dart';

import '../../core/theme/izicard_colors.dart';
import '../../data/models/nfc_batch.dart';

class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({super.key, required this.batch});

  final NfcBatch batch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Détail du dossier')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(batch.name, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: _StatusChip(status: batch.status, label: batch.statusLabel),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _DetailRow(label: 'Cartes au total', value: '${batch.total}'),
                  _DetailRow(label: 'En attente', value: '${batch.pending}'),
                  _DetailRow(label: 'Écrites', value: '${batch.written}'),
                  _DetailRow(label: 'Vérifiées', value: '${batch.verified}'),
                  _DetailRow(label: 'Erreurs', value: '${batch.errors}'),
                  _DetailRow(label: 'Annulées', value: '${batch.voided}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: batch.progress,
              minHeight: 8,
              backgroundColor: IzicardColors.cyan.withOpacity(.12),
            ),
          ),
          const SizedBox(height: 8),
          Text('${(batch.progress * 100).round()} % des tags vérifiés',
              textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          const Text(
            'Les fonctions d’import, de lecture détaillée des tags et d’encodage seront raccordées dans les prochaines étapes.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.label});
  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => IzicardColors.success,
      'in_progress' => IzicardColors.blue,
      'ready' => IzicardColors.cyan,
      'archived' => Colors.grey,
      _ => IzicardColors.warning,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w800)),
      ),
    );
  }
}
