import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/todo_viewmodel.dart';

class TodoListView extends StatefulWidget {
  // Removed 'const' constructor as this widget has dynamic lifecycle logic
  TodoListView({super.key});

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  @override
  void initState() {
    super.initState();
    // Safely load tasks after the first frame
    Future.microtask(() {
      if (mounted) {
        context.read<TodoViewModel>().loadTasks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020408),
      appBar: AppBar(
        title: const Text(
          "SECURE VAULT TASKS", 
          style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold, fontSize: 16)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Consumer<TodoViewModel>(
        builder: (context, vm, child) {
          if (vm.tasks.isEmpty) {
            return const Center(
              child: Text("NO ENCRYPTED RECORDS FOUND", 
                style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2))
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: vm.tasks.length,
            itemBuilder: (context, index) {
              final task = vm.tasks[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  border: Border.all(color: Colors.white10),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: ListTile(
                  title: Text(task['title'] ?? 'Untitled', 
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text(task['display_note'] ?? '', 
                    style: const TextStyle(color: Color(0xFF0DA6F2), fontSize: 12)),
                  leading: const Icon(Icons.lock_outline, color: Color(0xFFFF00FF), size: 20),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF0DA6F2),
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add, color: Colors.black),
      ),
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF020408),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: Color(0xFF0DA6F2), width: 1)
        ),
        title: const Text("NEW ENCRYPTED RECORD", 
          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController, 
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Record Title", 
                hintStyle: TextStyle(color: Colors.white24)
              )
            ),
            const SizedBox(height: 10),
            TextField(
              controller: noteController, 
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: "Encrypted Note", 
                hintStyle: TextStyle(color: Colors.white24)
              )
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("ABORT", style: TextStyle(color: Colors.redAccent))
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                context.read<TodoViewModel>().addTask(titleController.text, noteController.text);
                Navigator.pop(context);
              }
            },
            child: const Text("SAVE TO VAULT", style: TextStyle(color: Color(0xFF0DA6F2))),
          ),
        ],
      ),
    );
  }
}