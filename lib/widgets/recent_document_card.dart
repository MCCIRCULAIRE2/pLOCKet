import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/document.dart';

class RecentDocumentCard extends StatelessWidget {
  final Document document;
  final VoidCallback? onTap;

  const RecentDocumentCard({
    super.key,
    required this.document,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(document.createdAt);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(
          _iconForMimeType(document.mimeType),
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(
          document.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(dateStr),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  IconData _iconForMimeType(String? mime) {
    if (mime == null) return Icons.description_outlined;
    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime == 'application/pdf') return Icons.picture_as_pdf;
    return Icons.description_outlined;
  }
}
