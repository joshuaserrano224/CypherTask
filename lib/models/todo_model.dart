class TodoModel {
  final int? id;
  final String title;
  final String secretNote;
  final bool isDone;
  final String createdAt; // Ensure this line exists
  final String updatedAt; // Ensure this line exists

  TodoModel({
    this.id,
    required this.title,
    required this.secretNote,
    required this.isDone,
    required this.createdAt, // Ensure this is here
    required this.updatedAt, // Ensure this is here
  });

  factory TodoModel.fromMap(Map<String, dynamic> map) {
    return TodoModel(
      id: map['id'],
      title: map['title'] ?? '',
      secretNote: map['secretNote'] ?? '',
      isDone: map['isDone'] == 1,
      createdAt: map['createdAt'] ?? '',
      updatedAt: map['updatedAt'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'secretNote': secretNote,
      'isDone': isDone ? 1 : 0,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}