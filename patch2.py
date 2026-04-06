import re

with open('lib/main.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Replace Teacher's _buildMessagesTab
import re
teacher_replace_re = re.compile(r'(Widget _buildMessagesTab\(ColorScheme colorScheme\) \{)(.*?_messages\.isEmpty.*?\);[\n\s]*\})', re.DOTALL)
matches = teacher_replace_re.findall(text)

if len(matches) == 1:
    print('Replacing Teacher buildMessagesTab')
    text = text.replace(matches[0][0] + matches[0][1], r"""Widget _buildMessagesTab(ColorScheme colorScheme) {
    return ChatInterface(
      currentUserUsername: widget.teacherUsername,
      currentUserName: widget.teacherName,
      role: "Teacher",
      assignedClass: widget.assignedClass,
      colorScheme: colorScheme,
    );
  }""")
else:
    print(f'Expected 1 match, found {len(matches)}')

with open('lib/main.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print("Patch 2 applied!")
