import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

teacher_replace_re = re.compile(r'(Widget _buildMessagesTab\(ColorScheme colorScheme\) \{)(.*?_messages\.isEmpty.*?\);[\n\s]*\})', re.DOTALL)
matches = teacher_replace_re.findall(text)

if len(matches) == 2:
    print('Replacing both buildMessagesTab')
    # Manager is the first one
    text = text.replace(matches[0][0] + matches[0][1], r"""Widget _buildMessagesTab(ColorScheme colorScheme) {
    return ChatInterface(
      currentUserUsername: "manager",
      currentUserName: "Manager",
      role: "Manager",
      assignedClass: null,
      colorScheme: colorScheme,
    );
  }""")
    # Teacher is the second one
    text = text.replace(matches[1][0] + matches[1][1], r"""Widget _buildMessagesTab(ColorScheme colorScheme) {
    return ChatInterface(
      currentUserUsername: widget.teacherUsername,
      currentUserName: widget.teacherName,
      role: "Teacher",
      assignedClass: widget.assignedClass,
      colorScheme: colorScheme,
    );
  }""")
else:
    print(f'Expected 2 match, found {len(matches)}')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print("Patch 3 applied!")
