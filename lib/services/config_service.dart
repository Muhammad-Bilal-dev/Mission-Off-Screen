import 'package:cloud_firestore/cloud_firestore.dart';

class ConfigService {
  static final _doc =
  FirebaseFirestore.instance.collection('App_Config').doc('global');

  static Stream<bool> paywallEnabledStream() {
    return _doc.snapshots().map((s) => (s.data()?['paywallEnabled'] == true));
  }

  static Future<bool> fetchPaywallEnabled() async {
    final s = await _doc.get();
    return s.data()?['paywallEnabled'] == true;
  }
}
