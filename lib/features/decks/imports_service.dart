// // lib/features/decks/imports_service.dart
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// class ImportMeta {
//   ImportMeta({
//     required this.id,
//     required this.deckTitle,
//     this.description = '',
//   });
//   final String id;
//   final String deckTitle;
//   final String description;
// }
//
// class ImportCard {
//   ImportCard({required this.front, required this.back, required this.order});
//   final String front;
//   final String back;
//   final int order;
// }
//
// class ImportsService {
//   final _db = FirebaseFirestore.instance;
//
//   Future<(ImportMeta, List<ImportCard>)> fetchImport(String importId) async {
//     final metaRef = _db.collection('imports').doc(importId);
//     final metaSnap = await metaRef.get();
//     if (!metaSnap.exists) {
//       throw Exception('Import not found: $importId');
//     }
//     final metaData = metaSnap.data()!;
//     final meta = ImportMeta(
//       id: metaSnap.id,
//       deckTitle: (metaData['deckTitle'] ?? '') as String,
//       description: (metaData['description'] ?? '') as String,
//     );
//
//     final cardsSnap = await metaRef.collection('cards').orderBy('order').get();
//
//     final cards = cardsSnap.docs.map((d) {
//       final m = d.data();
//       return ImportCard(
//         front: (m['front'] ?? '') as String,
//         back: (m['back'] ?? '') as String,
//         order: (m['order'] ?? 0) as int,
//       );
//     }).toList();
//
//     return (meta, cards);
//   }
//
//   /// 取り込み後に削除（cards サブコレクション → 親doc の順）
//   Future<void> deleteImport(String importId) async {
//     final batch = _db.batch();
//     final metaRef = _db.collection('imports').doc(importId);
//     final cardsCol = metaRef.collection('cards');
//     final cards = await cardsCol.get();
//     for (final doc in cards.docs) {
//       batch.delete(doc.reference);
//     }
//     batch.delete(metaRef);
//     await batch.commit();
//   }
//
//
// }
