/// Modelo de Lista de Reproducción del usuario
class PlaylistModel {
  final int id;
  final String name;
  final String? description;
  final int createdAt;
  final int updatedAt;
  final int trackCount;

  PlaylistModel({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.trackCount = 0,
  });

  PlaylistModel copyWith({
    int? id,
    String? name,
    String? description,
    int? createdAt,
    int? updatedAt,
    int? trackCount,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trackCount: trackCount ?? this.trackCount,
    );
  }
}
