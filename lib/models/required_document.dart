class RequiredDocument {
  final String name;
  final bool isUploaded;
  final bool isMandatory;
  final String? description;

  RequiredDocument({
    required this.name,
    this.isUploaded = false,
    this.isMandatory = false,
    this.description,
  });

  RequiredDocument copyWith({
    String? name,
    bool? isUploaded,
    bool? isMandatory,
    String? description,
  }) {
    return RequiredDocument(
      name: name ?? this.name,
      isUploaded: isUploaded ?? this.isUploaded,
      isMandatory: isMandatory ?? this.isMandatory,
      description: description ?? this.description,
    );
  }
}

