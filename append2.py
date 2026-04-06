new_code = """
// ==========================================
// STUDENT BOARD SCREEN
// ==========================================
class StudentBoardScreen extends StatefulWidget {
  final Map<String, String> studentData;
  const StudentBoardScreen({super.key, required this.studentData});

  @override
  State<StudentBoardScreen> createState() => _StudentBoardScreenState();
}

class _StudentBoardScreenState extends State<StudentBoardScreen> {
  int _currentIndex = -1;

  Widget _buildBody(ColorScheme colorScheme) {
    switch (_currentIndex) {
      case 0:
        return ChatInterface(
          currentUserUsername: widget.studentData['username'] ?? '',
          currentUserName: widget.studentData['name'] ?? 'Student',
          role: 'Student',
          assignedClass: widget.studentData['std'],
          colorScheme: colorScheme,
        );
      case -1:
      default:
        return _buildOverview(colorScheme);
    }
  }

  Widget _buildOverview(ColorScheme colorScheme) {
    final progress = 80;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome, ${widget.studentData['name']}!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Class: ${widget.studentData['std']} | Blood: ${widget.studentData['blood'] ?? ''}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          const Text('Your Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: progress / 100, minHeight: 12, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 8),
          Text('$progress% Completed', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FadeInEntrance(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Student Dashboard', style: TextStyle(color: Colors.white)),
          backgroundColor: colorScheme.primary,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              },
            )
          ],
        ),
        body: _buildBody(colorScheme),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex == -1 ? 0 : 1, // hacky
          onTap: (idx) => setState(() => _currentIndex = idx == 0 ? -1 : 0),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Overview'),
            BottomNavigationBarItem(icon: Icon(Icons.message), label: 'Messages'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// CHAT INTERFACE
// ==========================================
class ChatInterface extends StatefulWidget {
  final String currentUserUsername;
  final String currentUserName;
  final String role; // 'Manager', 'Teacher', 'Student'
  final String? assignedClass;
  final ColorScheme colorScheme;

  const ChatInterface({
    super.key,
    required this.currentUserUsername,
    required this.currentUserName,
    required this.role,
    this.assignedClass,
    required this.colorScheme,
  });

  @override
  State<ChatInterface> createState() => _ChatInterfaceState();
}

class _ChatInterfaceState extends State<ChatInterface> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filteredContacts = [];

  // Expose global lists from _LoginScreenState using reflection/getter if needed
  // We can just use the static lists since they are in the same file!
  List<Map<String, String>> get _teachers => _LoginScreenState._allTeachers;
  List<Map<String, String>> get _students => _LoginScreenState._allStudents;

  @override
  void initState() {
    super.initState();
    _buildContactList();
    _filteredContacts = List.from(_contacts);
    _searchCtrl.addListener(_filterContacts);
  }

  void _buildContactList() {
    _contacts.clear();
    
    // Add Groups
    if (widget.role == 'Manager') {
      _contacts.add({'id': 'group_global', 'name': 'Global (All Teachers & Students)', 'type': 'group'});
      for (var t in _teachers) _contacts.add({'id': t['username'], 'name': t['name'], 'type': 'personal_teacher'});
      for (var s in _students) _contacts.add({'id': s['username'], 'name': s['name'], 'type': 'personal_student'});
    } else if (widget.role == 'Teacher') {
      _contacts.add({'id': 'group_${widget.assignedClass}', 'name': 'Class ${widget.assignedClass} Group', 'type': 'group'});
      final myStudents = _students.where((s) => s['std'] == widget.assignedClass).toList();
      for (var s in myStudents) _contacts.add({'id': s['username'], 'name': s['name'], 'type': 'personal_student'});
      // Can they message other teachers? Maybe yes
      for (var t in _teachers) {
        if (t['username'] != widget.currentUserUsername) {
          _contacts.add({'id': t['username'], 'name': t['name'], 'type': 'personal_teacher'});
        }
      }
    } else if (widget.role == 'Student') {
      _contacts.add({'id': 'group_${widget.assignedClass}', 'name': 'Class ${widget.assignedClass} Group', 'type': 'group'});
      final myTeachers = _teachers.where((t) => t['class'] == widget.assignedClass).toList();
      for (var t in myTeachers) _contacts.add({'id': t['username'], 'name': t['name'] ?? 'Class Teacher', 'type': 'personal_teacher'});
    }
  }

  void _filterContacts() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filteredContacts = _contacts.where((c) => c['name'].toString().toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(30)),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredContacts.length,
            itemBuilder: (context, index) {
              final c = _filteredContacts[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: c['type'] == 'group' ? widget.colorScheme.primary : Colors.grey.shade200,
                  child: Icon(
                    c['type'] == 'group' ? Icons.group : Icons.person,
                    color: c['type'] == 'group' ? Colors.white : Colors.grey.shade700,
                  ),
                ),
                title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(c['type'] == 'group' ? 'Public Place' : 'Personal Message'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        chatId: c['id'],
                        chatName: c['name'],
                        isGroup: c['type'] == 'group',
                        currentUserUsername: widget.currentUserUsername,
                        currentUserName: widget.currentUserName,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class ChatRoomScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final bool isGroup;
  final String currentUserUsername;
  final String currentUserName;

  const ChatRoomScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.isGroup,
    required this.currentUserUsername,
    required this.currentUserName,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _msgCtrl = TextEditingController();
  List<Map<String, dynamic>> get _allMessages => _LoginScreenState._allMessages;

  String _getConversationId() {
    if (widget.isGroup) return widget.chatId;
    final List<String> sorted = [widget.currentUserUsername, widget.chatId]..sort();
    return sorted.join('_');
  }

  void _sendMessage() {
    if (_msgCtrl.text.trim().isEmpty) return;
    setState(() {
      _allMessages.add({
        'convId': _getConversationId(),
        'senderUsername': widget.currentUserUsername,
        'senderName': widget.currentUserName,
        'text': _msgCtrl.text.trim(),
        'timestamp': DateTime.now().toIso8601String(),
      });
      _LoginScreenState.saveAllData();
      _msgCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final convId = _getConversationId();
    // Filter messages for this conversation
    final myMsgs = _allMessages.where((m) => m['convId'] == convId).toList()
      ..sort((a, b) => (a['timestamp'] ?? '').compareTo(b['timestamp'] ?? ''));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(widget.isGroup ? Icons.group : Icons.person, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.chatName, style: const TextStyle(color: Colors.white, fontSize: 16), overflow: TextOverflow.ellipsis)),
          ],
        ),
        backgroundColor: colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: myMsgs.length,
              itemBuilder: (context, index) {
                final m = myMsgs[index];
                final isMe = m['senderUsername'] == widget.currentUserUsername;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8, top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 0),
                        bottomRight: Radius.circular(isMe ? 0 : 16),
                      ),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isMe && widget.isGroup)
                          Text(m['senderName'] ?? '', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                        Text(
                          m['text'] ?? '',
                          style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: colorScheme.primary,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

if "class StudentBoardScreen" not in text:
    with open('lib/main.dart', 'a', encoding='utf-8') as f:
        f.write(new_code)
    print("Code appended!")
