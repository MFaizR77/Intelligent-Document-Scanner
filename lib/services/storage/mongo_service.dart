import 'package:mongo_dart/mongo_dart.dart';

import '../../config/env.dart';

class MongoService {
  MongoService._();

  static final MongoService instance = MongoService._();

  Db? _db;
  DbCollection? _collection;

  bool get isConnected => _db?.isConnected ?? false;

  Future<void> init() async {
    final uri = Env.mongoUri;
    if (uri.isEmpty) {
      return;
    }

    _db = await Db.create(uri);
    await _db!.open();
    _collection = _db!.collection(Env.mongoCollection);
  }

  Future<void> insertScanMetadata({
    required String documentType,
    required double confidence,
    required DateTime scannedAt,
  }) async {
    if (!isConnected || _collection == null) {
      return;
    }

    await _collection!.insertOne({
      'documentType': documentType,
      'confidence': confidence,
      'scannedAt': scannedAt.toUtc().toIso8601String(),
      'owner': 'faiz',
      'phase': 1,
    });
  }

  Future<void> dispose() async {
    if (_db?.isConnected ?? false) {
      await _db!.close();
    }
  }
}
