class TodoModel {
  final int? id;
  final String title;
  final String note; // This will hold the plaintext version in memory

  TodoModel({
    this.id,
    required this.title,
    required this.note,
  });

  // Convert a Map from the database into a TodoModel
  // The 'note' here should be the decrypted string from the ViewModel
  factory TodoModel.fromMap(Map<String, dynamic> map, String decryptedNote) {
    return TodoModel(
      id: map['id'],
      title: map['title'],
      note: decryptedNote,
    );
  }

  // Convert a TodoModel into a Map to store in the database
  // Note: We don't encrypt here; the ViewModel handles encryption 
  // before passing the data to the DatabaseService.
  Map<String, dynamic> toMap(String encryptedNote) {
    return {
      if (id != null) 'id': id,
      'title': title,
      'encrypted_note': encryptedNote,
    };
  }
}