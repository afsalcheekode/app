const fs = require('fs');
const files = ['lib/student_board.dart', 'lib/teacher_board.dart', 'lib/director_board.dart'];
for (const file of files) {
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(/\['photo'\] != null && ([\w\.]+)\['photo'\]!\.isNotEmpty/g, "['photo'] != null && $1['photo']!.isNotEmpty && $1['photo'] != 'null'");
  content = content.replace(/photoBase64 != null && photoBase64!\.isNotEmpty/g, "photoBase64 != null && photoBase64!.isNotEmpty && photoBase64 != 'null'");
  content = content.replace(/photoBase64 != null \? MemoryImage/g, "photoBase64 != null && photoBase64 != 'null' ? MemoryImage");
  fs.writeFileSync(file, content);
  console.log(`Updated ${file}`);
}
