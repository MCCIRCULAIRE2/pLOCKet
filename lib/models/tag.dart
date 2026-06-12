enum TagCategory { type, domain, subdomain, status }

class Tag {
  final String id;
  final String label;
  final TagCategory category;

  Tag({required this.id, required this.label, required this.category});

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'category': category.name,
      };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
        id: map['id'] as String,
        label: map['label'] as String,
        category: TagCategory.values.firstWhere(
            (c) => c.name == map['category'],
            orElse: () => TagCategory.type),
      );
}
