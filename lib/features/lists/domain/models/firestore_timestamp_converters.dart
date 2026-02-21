import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class FirestoreDateTimeConverter implements JsonConverter<DateTime, Object?> {
  const FirestoreDateTimeConverter();

  @override
  DateTime fromJson(Object? json) {
    if (json is Timestamp) {
      return json.toDate().toUtc();
    }
    if (json is DateTime) {
      return json.toUtc();
    }
    if (json is int) {
      return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true);
    }
    throw ArgumentError('Unsupported DateTime JSON value: $json');
  }

  @override
  Object? toJson(DateTime object) {
    return Timestamp.fromDate(object.toUtc());
  }
}

class NullableFirestoreDateTimeConverter
    implements JsonConverter<DateTime?, Object?> {
  const NullableFirestoreDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) {
      return null;
    }
    return const FirestoreDateTimeConverter().fromJson(json);
  }

  @override
  Object? toJson(DateTime? object) {
    if (object == null) {
      return null;
    }
    return Timestamp.fromDate(object.toUtc());
  }
}
