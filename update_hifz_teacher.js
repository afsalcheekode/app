const fs = require('fs');
let code = fs.readFileSync('lib/teacher_board.dart', 'utf8');

// Update _buildHifzProgressList
code = code.replace(
  /_hifzSmallBadge\('Old', `\$\{progress\['oldFromSura'\]\} \$\{progress\['oldFromAya'\]\} - \$\{progress\['oldToSura'\]\} \$\{progress\['oldToAya'\]\}`, Colors\.orange\),/g,
  `_hifzSmallBadge('Old', \`\${progress['oldFromSura'] ?? ''} \${progress['oldFromAya'] ?? ''} - \${progress['oldToSura'] ?? ''} \${progress['oldToAya'] ?? ''}\`, Colors.orange),
                    const SizedBox(width: 8),
                    _hifzSmallBadge('Muraja\\'a', \`\${progress['murajaaFromSura'] ?? ''} \${progress['murajaaFromAya'] ?? ''} - \${progress['murajaaToSura'] ?? ''} \${progress['murajaaToAya'] ?? ''}\`, Colors.purple),`
);

const startIdx = code.indexOf('void _showHifzProgressDialog(Map<String, String> student)');
const endIdx = code.indexOf('Widget _hifzField(TextEditingController ctrl, String hint)');
if (startIdx !== -1 && endIdx !== -1) {
  const newDialogCode = `void _showHifzProgressDialog(Map<String, String> student) {
    final today = DateTime.now().toString().split(' ')[0];
    final existing = DataStore.allHifzProgress.firstWhere(
      (p) => p['studentUsername'] == student['username'] && p['date'] == today,
      orElse: () => {},
    );

    String tSFrom = existing['todayFromSura'] ?? quranSurahsArabic[0];
    final tAFrom = TextEditingController(text: existing['todayFromAya'] ?? '');
    String tSTo = existing['todayToSura'] ?? quranSurahsArabic[0];
    final tATo = TextEditingController(text: existing['todayToAya'] ?? '');
    
    String oSFrom = existing['oldFromSura'] ?? quranSurahsArabic[0];
    final oAFrom = TextEditingController(text: existing['oldFromAya'] ?? '');
    String oSTo = existing['oldToSura'] ?? quranSurahsArabic[0];
    final oATo = TextEditingController(text: existing['oldToAya'] ?? '');
    
    String mSFrom = existing['murajaaFromSura'] ?? quranSurahsArabic[0];
    final mAFrom = TextEditingController(text: existing['murajaaFromAya'] ?? '');
    String mSTo = existing['murajaaToSura'] ?? quranSurahsArabic[0];
    final mATo = TextEditingController(text: existing['murajaaToAya'] ?? '');
    
    int selectedJuzh = int.tryParse(existing['juzh']?.toString() ?? '1') ?? 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('\${student['name']} - Daily Progress'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _hifzSectionTitle('TODAY\\'S LESSON', Icons.today_rounded, Colors.blue),
                _hifzSurahAyaRangeRow(
                  tSFrom, a: tAFrom, b: tSTo, c: tATo,
                  onFromSurahChanged: (v) => setDialogState(() => tSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => tSTo = v!),
                ),
                const SizedBox(height: 16),
                _hifzSectionTitle('OLD LESSON', Icons.history_rounded, Colors.orange),
                _hifzSurahAyaRangeRow(
                  oSFrom, a: oAFrom, b: oSTo, c: oATo,
                  onFromSurahChanged: (v) => setDialogState(() => oSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => oSTo = v!),
                ),
                const SizedBox(height: 16),
                _hifzSectionTitle('MURAJA\\'A (REVIEW)', Icons.repeat_rounded, Colors.purple),
                _hifzSurahAyaRangeRow(
                  mSFrom, a: mAFrom, b: mSTo, c: mATo,
                  onFromSurahChanged: (v) => setDialogState(() => mSFrom = v!),
                  onToSurahChanged: (v) => setDialogState(() => mSTo = v!),
                ),
                const SizedBox(height: 20),
                _hifzSectionTitle('GROWTH (JUZH)', Icons.trending_up_rounded, Colors.green),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: selectedJuzh,
                      items: List.generate(30, (i) => DropdownMenuItem(value: i + 1, child: Text('Juzh \${i + 1}'))).toList(),
                      onChanged: (v) => setDialogState(() => selectedJuzh = v ?? 1),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                setState(() {
                  final data = {
                    'studentUsername': student['username'],
                    'date': today,
                    'todayFromSura': tSFrom,
                    'todayFromAya': tAFrom.text,
                    'todayToSura': tSTo,
                    'todayToAya': tATo.text,
                    'oldFromSura': oSFrom,
                    'oldFromAya': oAFrom.text,
                    'oldToSura': oSTo,
                    'oldToAya': oATo.text,
                    'murajaaFromSura': mSFrom,
                    'murajaaFromAya': mAFrom.text,
                    'murajaaToSura': mSTo,
                    'murajaaToAya': mATo.text,
                    'juzh': selectedJuzh.toString(),
                  };
                  if (existing.isNotEmpty) {
                    final idx = DataStore.allHifzProgress.indexOf(existing);
                    DataStore.allHifzProgress[idx] = data;
                  } else {
                    DataStore.allHifzProgress.add(data);
                  }
                  DataStore.saveAllData();
                });
                Navigator.pop(context);
              },
              child: const Text('SAVE PROGRESS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hifzSectionTitle(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: color, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _hifzSurahAyaRangeRow(
    String sF, {
    required TextEditingController a,
    required String b,
    required TextEditingController c,
    required Function(String?) onFromSurahChanged,
    required Function(String?) onToSurahChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(flex: 3, child: _surahDropdown(sF, onFromSurahChanged)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _hifzField(a, 'Aya')),
          ],
        ),
        const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Text('to', style: TextStyle(fontSize: 10, color: Colors.grey))),
        Row(
          children: [
            Expanded(flex: 3, child: _surahDropdown(b, onToSurahChanged)),
            const SizedBox(width: 8),
            Expanded(flex: 2, child: _hifzField(c, 'Aya')),
          ],
        ),
      ],
    );
  }

  Widget _surahDropdown(String value, Function(String?) onChanged) {
    String safeValue = quranSurahsArabic.contains(value) ? value : quranSurahsArabic[0];
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: safeValue,
          style: const TextStyle(fontSize: 13, color: Colors.black, fontFamily: 'sans-serif'),
          items: quranSurahsArabic.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  `;
  code = code.substring(0, startIdx) + newDialogCode + code.substring(endIdx);
}

fs.writeFileSync('lib/teacher_board.dart', code);
