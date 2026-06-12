import 'package:flutter/material.dart';

class RecentQuestionCard extends StatelessWidget {
  final String question;
  final VoidCallback? onTap;

  const RecentQuestionCard({
    super.key,
    required this.question,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          Icons.history,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(
          question,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: const Icon(Icons.chevron_right, size: 20),
        onTap: onTap,
      ),
    );
  }
}
