import 'package:cloud_firestore/cloud_firestore.dart';

class Session {
  final String status;      // running | paused | complete
  final int minutes;        // originally requested minutes
  final String childId;     // which child this session is for
  final Timestamp? startAt; // Firestore server timestamp

  Session({
    required this.status,
    required this.minutes,
    required this.childId,
    this.startAt,
  });

  factory Session.fromMap(Map<String, dynamic> m) => Session(
    status: (m['status'] as String?) ?? 'running',
    minutes: (m['minutes'] as num?)?.toInt() ?? 0,
    childId: (m['childId'] as String?) ?? '',
    startAt: m['startAt'] as Timestamp?,
  );
}
