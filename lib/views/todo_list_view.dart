import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:screen_protector/screen_protector.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../viewmodels/todo_viewmodel.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../models/todo_model.dart';
import 'login_view.dart';

class TodoListView extends StatefulWidget {
  const TodoListView({super.key});

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> with WidgetsBindingObserver {
  static const Color primaryCyan = Color(0xFF0DA6F2);
  static const Color accentGreen = Color(0xFF0DA6F2);
  static const Color accentRed = Color(0xFFFF00FF);
  static const Color darkBg = Color(0xFF020405);
  static const Color cardBg = Color(0xFF0A0F14);

  final TextEditingController _taskTitleController = TextEditingController();
  final TextEditingController _taskNoteController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  bool _isSearching = false;
  Timer? _sessionTimer; // Timer for inactivity

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _enableSecureMode();
    _startTimeout(); // Initialize timer on start
  }

  Future<void> _enableSecureMode() async => await ScreenProtector.preventScreenshotOn();
  Future<void> _disableSecureMode() async => await ScreenProtector.preventScreenshotOff();

  void _startTimeout() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer(const Duration(minutes: 2), () => _handleInactivity());
  }

  void _handleInactivity() {
    if (mounted) {
      // Show expiration message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: accentRed,
          content: Text(
            "SESSION EXPIRED DUE TO INACTIVITY",
            style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12),
          ),
        ),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginView()),
        (route) => false,
      );
    }
  }

  void _refreshSession() {
    _startTimeout(); // Reset the 2-minute timer
    context.read<TodoViewModel>().resetInactivityTimer(context, () {
      if (mounted) {
        _handleInactivity();
      }
    });
  }

  @override
  void dispose() {
    _sessionTimer?.cancel(); // Clean up timer
    _disableSecureMode();
    WidgetsBinding.instance.removeObserver(this);
    _taskTitleController.dispose();
    _taskNoteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    context.read<TodoViewModel>().setMinimized(state != AppLifecycleState.resumed);
  }

  void _secureActionGate(BuildContext context, bool isLocked, String storedPin, VoidCallback onSuccess) {
    if (isLocked) {
      _showPinPrompt(context, storedPin, onSuccess);
    } else {
      onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);

    return ChangeNotifierProvider<TodoViewModel>(
      create: (_) => TodoViewModel(), 
      child: Consumer<TodoViewModel>(
        builder: (context, todoVM, child) {
          if (todoVM.isMinimized) {
            return const Scaffold(
              backgroundColor: darkBg, 
              body: SizedBox.expand(),
            );
          }

          return Listener(
            onPointerDown: (_) => _refreshSession(),
            child: Scaffold(
              backgroundColor: darkBg,
              resizeToAvoidBottomInset: true, 
              body: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.05,
                        child: CustomPaint(painter: GridPainter(color: primaryCyan)),
                      ),
                    ),
                  ),

                  SafeArea(
                    child: Column(
                      children: [
                        _buildHeader(context, authVM, todoVM),
                        _buildStatusPanel(),

                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: cardBg.withOpacity(0.95),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1), 
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  color: Colors.white.withOpacity(0.03),
                                  child: Row(
                                    children: [
                                      Container(width: 4, height: 4, color: primaryCyan),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "PRIVATE FOLDER",
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.shareTechMono(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 10,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                Expanded(
                                  child: todoVM.isLoading && todoVM.todos.isEmpty
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: primaryCyan,
                                            strokeWidth: 1.5,
                                          ),
                                        )
                                      : _buildTerminalTaskList(todoVM),
                                ),
                              ],
                            ),
                          ),
                        ),

                        _buildFooterAction(todoVM),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthViewModel authVM, TodoViewModel todoVM) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
      decoration: const BoxDecoration(color: Colors.black),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _isSearching 
          ? Row(
              key: const ValueKey("searchBar"),
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 16),
                    onChanged: (value) => todoVM.updateSearchQuery(value),
                    decoration: InputDecoration(
                      hintText: "> SEARCH NOTES...",
                      hintStyle: GoogleFonts.shareTechMono(color: Colors.white24, fontSize: 14),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: accentRed),
                  onPressed: () {
                    setState(() {
                      _isSearching = false;
                      _searchController.clear();
                      todoVM.updateSearchQuery("");
                    });
                  },
                ),
              ],
            )
          : Row(
              key: const ValueKey("standardHeader"),
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMenu(context, authVM, todoVM),
                
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "CYPHERTASK",
                        style: GoogleFonts.shareTechMono(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 40, height: 2, color: primaryCyan),
                          const SizedBox(width: 4),
                          Container(width: 4, height: 2, color: accentRed),
                        ],
                      ),
                    ],
                  ),
                ),

                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: const Icon(Icons.search, color: primaryCyan, size: 22),
                      onPressed: () => setState(() => _isSearching = true),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await todoVM.toggleBiometrics();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: todoVM.isBiometricEnabled ? primaryCyan : Colors.white10, 
                            width: 1
                          ),
                        ),
                        child: Icon(
                          Icons.fingerprint,
                          color: todoVM.isLoading 
                              ? Colors.white10 
                              : (todoVM.isBiometricEnabled ? primaryCyan : Colors.white24),
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context, AuthViewModel authVM, TodoViewModel todoVM) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.menu, color: Colors.white54, size: 26),
      color: cardBg,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(),
      onSelected: (value) async {
        if (value == 'logout') {
          _showLogoutConfirmation(context, authVM);
        } else if (value == 'delete') {
          _showRepositoryWipeConfirmation(context, todoVM);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'logout', 
          child: Text("LOG OUT", style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12))
        ),
        PopupMenuItem(
          value: 'delete', 
          child: Text("DELETE ACCOUNT", style: GoogleFonts.shareTechMono(color: accentRed, fontSize: 12))
        ),
      ],
    );
  }

  void _showLogoutConfirmation(BuildContext context, AuthViewModel authVM) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBg,
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: primaryCyan, width: 1),
        ),
        title: Text(
          "TERMINATE SESSION?", 
          style: GoogleFonts.shareTechMono(color: primaryCyan, fontSize: 14)
        ),
        content: Text(
          "Encryption keys will be locked until your next authentication.",
          style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: Text("CANCEL", style: GoogleFonts.shareTechMono(color: Colors.white38))
          ),
          TextButton(
            onPressed: () async {
              await authVM.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (context) => const LoginView()), 
                  (route) => false
                );
              }
            },
            child: Text("LOGOUT", style: GoogleFonts.shareTechMono(color: accentRed, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildDiagnosticItem("STATUS", "ONLINE", accentGreen),
          _buildDiagnosticItem("SECURITY", "ACTIVE", primaryCyan),
          _buildDiagnosticItem("NETWORK", "STABLE", primaryCyan),
        ],
      ),
    );
  }

  Widget _buildDiagnosticItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.shareTechMono(color: Colors.white38, fontSize: 7, letterSpacing: 1)),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 3, height: 3, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.shareTechMono(color: color, fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildTerminalTaskList(TodoViewModel vm) {
  final displayList = vm.filteredTodos;

  if (displayList.isEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Text(
          _isSearching ? "> NOTHING FOUND" : "> NO NOTES YET",
          textAlign: TextAlign.center,
          style: GoogleFonts.shareTechMono(
            color: primaryCyan.withOpacity(0.3), 
            fontSize: 12
          ),
        ),
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 4),
    itemCount: displayList.length,
    itemBuilder: (context, index) {
      final todo = displayList[index];
      final decryptedRaw = vm.getDecryptedNote(todo.secretNote);
      final lockRegex = RegExp(r'^\[LOCKED:(\d{4})\]');
      final match = lockRegex.firstMatch(decryptedRaw);

      bool isLocked = match != null;
      String storedPin = isLocked ? match.group(1)! : "";
      String displayNote = isLocked ? decryptedRaw.replaceFirst(lockRegex, '') : decryptedRaw;

      String formattedTimestamp = "N/A";
      if (todo.createdAt != null) {
        try {
          DateTime dt = DateTime.parse(todo.createdAt!);
          formattedTimestamp = DateFormat('MMM dd, yyyy | HH:mm:ss').format(dt);
        } catch (_) {}
      }

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          border: Border(
            left: BorderSide(color: isLocked ? accentRed : primaryCyan, width: 2)
          ),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          title: Text(
            todo.title.toUpperCase(),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.shareTechMono(
              color: Colors.white, 
              fontSize: 13, 
              fontWeight: FontWeight.bold
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                "ID: ${todo.id}",
                style: GoogleFonts.shareTechMono(
                  color: primaryCyan.withOpacity(0.5), 
                  fontSize: 8
                ),
              ),
              const SizedBox(height: 2),
              Text(
                "LOGGED: $formattedTimestamp",
                style: GoogleFonts.shareTechMono(
                  color: Colors.white24, 
                  fontSize: 8,
                  height: 1.3
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.edit, color: Colors.white24, size: 16),
                onPressed: () => _secureActionGate(context, isLocked, storedPin, 
                    () => _showNoteDialog(context, vm, existingTodo: todo)),
              ),
              const SizedBox(width: 10),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isLocked ? Icons.lock : Icons.lock_open, 
                  color: isLocked ? accentRed : primaryCyan.withOpacity(0.4), 
                  size: 16
                ),
                onPressed: () => _secureActionGate(context, isLocked, storedPin, 
                    () => _showDecryptedNote(context, todo.title, displayNote)),
              ),
              const SizedBox(width: 10),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline, color: Colors.white12, size: 16),
                onPressed: () => _secureActionGate(context, isLocked, storedPin, 
                    () => _showTaskDeleteConfirmation(context, vm, todo.id!)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  void _showNoteDialog(BuildContext context, TodoViewModel vm, {TodoModel? existingTodo}) {
    bool isEditing = existingTodo != null;
    bool lockNote = false;
    String initialPin = "";
    
    if (isEditing) {
      _taskTitleController.text = existingTodo.title;
      String raw = vm.getDecryptedNote(existingTodo.secretNote);
      final lockRegex = RegExp(r'^\[LOCKED:(\d{4})\]');
      final match = lockRegex.firstMatch(raw);
      
      if (match != null) {
        lockNote = true;
        initialPin = match.group(1)!;
        _taskNoteController.text = raw.replaceFirst(lockRegex, "");
      } else {
        _taskNoteController.text = raw;
      }
    } else {
      _taskTitleController.clear();
      _taskNoteController.clear();
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardBg,
          shape: const RoundedRectangleBorder(side: BorderSide(color: primaryCyan, width: 1)),
          title: Text(isEditing ? "EDIT NOTE" : "NEW NOTE", style: GoogleFonts.shareTechMono(color: primaryCyan)),
          content: SingleChildScrollView( 
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTextField(_taskTitleController, "TITLE"),
                _buildTextField(_taskNoteController, "CONTENT"),
                const SizedBox(height: 10),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("PROTECT WITH PIN", style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 10)),
                  value: lockNote,
                  activeColor: accentRed,
                  onChanged: (val) => setDialogState(() => lockNote = val!),
                )
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: GoogleFonts.shareTechMono(color: Colors.white38))),
            TextButton(
              onPressed: () {
                if (lockNote) {
                  if (isEditing && initialPin.isNotEmpty) {
                    _saveTask(vm, existingTodo.id, lockNote, initialPin);
                    Navigator.pop(context);
                  } else {
                    _showSetPinDialog(context, (providedPin) {
                      _saveTask(vm, existingTodo?.id, lockNote, providedPin);
                      Navigator.pop(context); 
                    });
                  }
                } else {
                  _saveTask(vm, existingTodo?.id, false, "");
                  Navigator.pop(context);
                }
              },
              child: Text("SAVE", style: GoogleFonts.shareTechMono(color: primaryCyan)),
            ),
          ],
        ),
      ),
    );
  }

  void _saveTask(TodoViewModel vm, int? id, bool isLocked, String pin) {
    String finalContent = isLocked ? "[LOCKED:$pin]${_taskNoteController.text}" : _taskNoteController.text;
    if (id != null) {
      vm.updateTask(id, _taskTitleController.text, finalContent);
    } else {
      vm.addTask(_taskTitleController.text, finalContent);
    }
  }

  void _showTaskDeleteConfirmation(BuildContext context, TodoViewModel vm, int taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: darkBg,
        shape: const RoundedRectangleBorder(side: BorderSide(color: accentRed, width: 1)),
        title: Text("DELETE NOTE?", style: GoogleFonts.shareTechMono(color: accentRed, fontSize: 14)),
        content: Text("This note will be removed forever.",
            style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("NO", style: GoogleFonts.shareTechMono(color: Colors.white38))),
          TextButton(
            onPressed: () {
              vm.deleteTask(taskId);
              Navigator.pop(context);
            },
            child: Text("YES", style: GoogleFonts.shareTechMono(color: accentRed)),
          ),
        ],
      ),
    );
  }

  void _showPinPrompt(BuildContext context, String storedPin, VoidCallback onVerified) {
    final TextEditingController pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: darkBg,
        shape: const RoundedRectangleBorder(side: BorderSide(color: accentRed, width: 1)),
        title: Text("ENTER PIN", style: GoogleFonts.shareTechMono(color: accentRed, fontSize: 14)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          autofocus: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: GoogleFonts.shareTechMono(color: Colors.white, letterSpacing: 10),
          decoration: const InputDecoration(counterText: "", hintText: "••••", hintStyle: TextStyle(color: Colors.white24)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (pinController.text == storedPin) {
                Navigator.pop(dialogContext);
                onVerified();
              } else {
                HapticFeedback.heavyImpact();
              }
            },
            child: Text("UNLOCK", style: GoogleFonts.shareTechMono(color: primaryCyan)),
          )
        ],
      ),
    );
  }

  void _showSetPinDialog(BuildContext context, Function(String) onPinSet) {
    final TextEditingController pinEntryController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: const RoundedRectangleBorder(side: BorderSide(color: primaryCyan, width: 1)),
        title: Text("SET PIN", style: GoogleFonts.shareTechMono(color: primaryCyan, fontSize: 14)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Create a 4-digit code to lock this note.", style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11)),
            TextField(
              controller: pinEntryController,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              maxLength: 4,
              style: GoogleFonts.shareTechMono(color: Colors.white, letterSpacing: 10),
              decoration: const InputDecoration(counterText: ""),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (pinEntryController.text.length == 4) {
                onPinSet(pinEntryController.text);
                Navigator.pop(context);
              } else {
                HapticFeedback.vibrate();
              }
            },
            child: Text("DONE", style: GoogleFonts.shareTechMono(color: primaryCyan)),
          ),
        ],
      ),
    );
  }

void _showDecryptedNote(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 24),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: primaryCyan, width: 1),
        ),
        title: Text(
          title.toUpperCase(), 
          style: GoogleFonts.shareTechMono(
            color: primaryCyan, 
            fontSize: 18, 
            fontWeight: FontWeight.bold
          )
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  content,
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white, 
                    fontSize: 18, 
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Opened at: ${DateFormat('hh:mm a').format(DateTime.now())}",
                  style: GoogleFonts.shareTechMono(
                    color: Colors.white24, 
                    fontSize: 10
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "BACK", 
              style: GoogleFonts.shareTechMono(
                color: primaryCyan,
                fontSize: 14,
                fontWeight: FontWeight.bold
              )
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.shareTechMono(color: primaryCyan, fontSize: 11),
        enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
      ),
    );
  }

  Widget _buildFooterAction(TodoViewModel vm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: primaryCyan, width: 1.5),
          backgroundColor: Colors.black,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        onPressed: () => _showNoteDialog(context, vm),
        child: Text("ADD NEW NOTE",
            style: GoogleFonts.shareTechMono(color: primaryCyan, letterSpacing: 1.5, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  void _showRepositoryWipeConfirmation(BuildContext context, TodoViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: cardBg,
        shape: const RoundedRectangleBorder(side: BorderSide(color: accentRed, width: 1)),
        title: Text("DELETE ACCOUNT?", style: GoogleFonts.shareTechMono(color: accentRed)),
        content: Text("This will permanently delete your account.",
            style: GoogleFonts.shareTechMono(color: Colors.white70, fontSize: 11)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text("CANCEL", style: GoogleFonts.shareTechMono(color: Colors.white))),
          TextButton(
              onPressed: () async {
                await vm.deleteUserAccount();
                if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginView()), (route) => false);
              },
              child: Text("DELETE ALL", style: GoogleFonts.shareTechMono(color: accentRed))
          ),
        ],
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  final Color color;
  GridPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()..color = color.withOpacity(0.08)..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 30) canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    for (double i = 0; i < size.height; i += 30) canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
  }
  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}