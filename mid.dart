  Widget _buildMessagesTab(ColorScheme colorScheme) {
    // Group students by class, then show classes. Clicking class => students list => chat
    final classes = _classes;
    final allStudents = _students;
    final allTeachers = _teachers;

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: colorScheme.primary,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8)],
          ),
          child: Row(
            children: [
              Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.campaign_rounded, color: Colors.white),
                onPressed: _showAddMessageDialog,
                tooltip: 'Send Broadcast Message',
              ),
            ],
          ),
        ),
        // Section: Teachers
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              if (allTeachers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Text('Teachers', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.2)),
                ),
                ...allTeachers.map((t) => _buildContactTile(
                  context: context,
                  colorScheme: colorScheme,
                  avatar: t['name']?[0].toUpperCase() ?? 'T',
                  avatarColor: Colors.green,
                  name: t['name'] ?? '',
                  subtitle: 'Teacher • Class ${t['class']}',
                  onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DirectChatScreen(
                      peerId: t['username'] ?? '',
                      peerName: t['name'] ?? '',
                      peerDept: 'Class ${t['class']}',
                      peerColor: Colors.green,
                      myId: 'manager',
                      myName: 'Manager',
                      onBack: () => Navigator.pop(context),
                    ),

                  )),
                )),
              ],
              // By class
              ...classes.map((cls) {
                final clsStudents = allStudents.where((s) => s['std'] == cls).toList();
                if (clsStudents.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text('Class $cls', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: colorScheme.primary, letterSpacing: 1.2)),
                    ),
                    ...clsStudents.map((s) => _buildContactTile(
                      context: context,
                      colorScheme: colorScheme,
                      avatar: s['name']?[0].toUpperCase() ?? 'S',
                      avatarColor: Colors.orange,
                      name: s['name'] ?? '',
                      subtitle: 'Student • Class $cls',
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DirectChatScreen(
                          peerId: s['username'] ?? '',
                          peerName: s['name'] ?? '',
                          peerDept: 'Class $cls',
                          peerColor: Colors.orange,
                          myId: 'manager',
                          myName: 'Manager',
                          onBack: () => Navigator.pop(context),
                        ),

                      )),
                    )),
                  ],
                );
              }),
              if (allStudents.isEmpty && allTeachers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 80),
                    child: Column(
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        const Text('No teachers or students added yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContactTile({
    required BuildContext context,
    required ColorScheme colorScheme,
    required String avatar,
    required MaterialColor avatarColor,
    required String name,
    required String subtitle,
    required VoidCallback onTap,
    String? lastMessage,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: avatarColor.shade100,
              child: Text(avatar, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: avatarColor.shade700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    lastMessage ?? subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }


}
