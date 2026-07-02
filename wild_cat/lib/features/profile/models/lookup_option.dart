class LookupOption {
  const LookupOption({
    required this.id,
    required this.name,
  });

  final int id;
  final String name;

  factory LookupOption.fromJson(Map<String, dynamic> json) {
    return LookupOption(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
    );
  }
}
