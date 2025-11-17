import 'package:cloud_firestore/cloud_firestore.dart';

class AppAnnouncement {
  const AppAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.publishedAt,
    this.category,
    this.link,
  });

  final String id;
  final String title;
  final String body;
  final DateTime publishedAt;
  final String? category;
  final String? link;

  factory AppAnnouncement.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AppAnnouncement(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      publishedAt:
          (data['published_at'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      category: data['category'] as String?,
      link: data['link'] as String?,
    );
  }
}




