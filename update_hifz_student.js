const fs = require('fs');
let code = fs.readFileSync('lib/student_board.dart', 'utf8');

code = code.replace(
  /_hifzProgressRow\('Old Review', `\$\{latest\['oldFromSura'\]\} \$\{latest\['oldFromAya'\]\} \| \$\{latest\['oldToSura'\]\} \$\{latest\['oldToAya'\]\}`, Colors\.orange\),/g,
  `_hifzProgressRow('Old Lesson', \`\${latest['oldFromSura']} \${latest['oldFromAya']} | \${latest['oldToSura']} \${latest['oldToAya']}\`, Colors.orange),
                  if (latest['murajaaFromSura'] != null) ...[
                    const SizedBox(height: 12),
                    _hifzProgressRow('Muraja\\'a (Review)', \`\${latest['murajaaFromSura']} \${latest['murajaaFromAya']} | \${latest['murajaaToSura']} \${latest['murajaaToAya']}\`, Colors.purple),
                  ],`
);

code = code.replace(
  /_hifzProgressRow\('Old Review', `\$\{p\['oldFromSura'\]\} \$\{p\['oldFromAya'\]\} \| \$\{p\['oldToSura'\]\} \$\{p\['oldToAya'\]\}`, Colors\.orange\),/g,
  `_hifzProgressRow('Old Lesson', \`\${p['oldFromSura']} \${p['oldFromAya']} | \${p['oldToSura']} \${p['oldToAya']}\`, Colors.orange),
                          if (p['murajaaFromSura'] != null) ...[
                            const SizedBox(height: 12),
                            _hifzProgressRow('Muraja\\'a (Review)', \`\${p['murajaaFromSura']} \${p['murajaaFromAya']} | \${p['murajaaToSura']} \${p['murajaaToAya']}\`, Colors.purple),
                          ],`
);

fs.writeFileSync('lib/student_board.dart', code);
