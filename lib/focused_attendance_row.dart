class _FocusedAttendanceRow extends StatefulWidget {
  final Map<String, String> student;
  final String date;
  final int periodIdx;
  final String subject;

  const _FocusedAttendanceRow({
    required this.student,
    required this.date,
    required this.periodIdx,
    required this.subject,
  });

  @override
  State<_FocusedAttendanceRow> createState() => _FocusedAttendanceRowState();
}

class _FocusedAttendanceRowState extends State<_FocusedAttendanceRow> {
  String _status = '-';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_FocusedAttendanceRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.date != widget.date || oldWidget.periodIdx != widget.periodIdx) {
      _loadData();
    }
  }

  void _loadData() {
    final record = _LoginScreenState._allAttendance.firstWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date,
      orElse: () => {},
    );
    if (record.isNotEmpty) {
      final pMap = Map<String, String>.from(record['periods'] ?? {});
      _status = pMap[(widget.periodIdx + 1).toString()] ?? '-';
    } else {
      _status = '-';
    }
    setState(() {});
  }

  void _updateStatus(String newStatus) {
    setState(() => _status = newStatus);
    
    final index = _LoginScreenState._allAttendance.indexWhere(
      (a) => a['studentUsername'] == widget.student['username'] && a['date'] == widget.date
    );

    final record = index != -1 
      ? Map<String, dynamic>.from(_LoginScreenState._allAttendance[index])
      : {
          'studentUsername': widget.student['username'],
          'date': widget.date,
          'periods': <String, String>{},
          'leaveReason': '',
          'timetable': List<String>.generate(10, (i) => 'Free'),
        };

    final pMap = Map<String, String>.from(record['periods'] ?? {});
    pMap[(widget.periodIdx + 1).toString()] = newStatus;
    record['periods'] = pMap;

    // Snapshot current timetable if first entry for this day
    if (index == -1) {
      final dt = DateTime.parse(widget.date);
      final dayIdx = dt.weekday - 1;
      record['timetable'] = List<String>.from(
        (_LoginScreenState._allTimetables[widget.student['class']] ?? {})[dayIdx.toString()] ?? List.generate(10, (i) => 'Free')
      );
    }

    if (index != -1) {
      _LoginScreenState._allAttendance[index] = record;
    } else {
      _LoginScreenState._allAttendance.add(record);
    }
    _LoginScreenState.saveAllData();
  }

  @override
  Widget build(BuildContext context) {
    final isFree = widget.subject.toLowerCase() == 'free';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: isFree ? Colors.grey.shade100 : Colors.teal.shade50,
              child: Text(widget.student['name']?[0] ?? 'S', style: TextStyle(color: isFree ? Colors.grey : Colors.teal, fontWeight: FontWeight.bold, fontSize: 11)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.student['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('ID: ${widget.student['username']}', style: const TextStyle(fontSize: 9, color: Colors.grey)),
                ],
              ),
            ),
            if (isFree)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: const Text('Free Period', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
              )
            else
              Row(
                children: [
                  _statusBtn('P', Colors.green),
                  const SizedBox(width: 4),
                  _statusBtn('A', Colors.red),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusBtn(String label, Color color) {
    final isSelected = _status == label;
    return GestureDetector(
      onTap: () => _updateStatus(label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? Colors.transparent : color.withOpacity(0.15)),
        ),
        child: Text(label, style: TextStyle(color: isSelected ? Colors.white : color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}
