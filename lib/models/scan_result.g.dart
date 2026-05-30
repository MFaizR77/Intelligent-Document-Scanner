// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scan_result.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ScanResultAdapter extends TypeAdapter<ScanResult> {
  @override
  final int typeId = 0;

  @override
  ScanResult read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScanResult(
      imagePath: fields[0] as String,
      scanDate: fields[1] as DateTime,
      documentType: fields[2] as String,
      confidenceScore: fields[3] as double,
      title: fields[4] as String?,
      pagePaths: (fields[5] as List?)?.cast<String>(),
      originalPaths: (fields[6] as List?)?.cast<String>(),
      pageCorners: (fields[7] as List?)?.cast<String>(),
      pageEngines: (fields[8] as List?)?.cast<String>(),
      pageModes: (fields[9] as List?)?.cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, ScanResult obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.imagePath)
      ..writeByte(1)
      ..write(obj.scanDate)
      ..writeByte(2)
      ..write(obj.documentType)
      ..writeByte(3)
      ..write(obj.confidenceScore)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.pagePaths)
      ..writeByte(6)
      ..write(obj.originalPaths)
      ..writeByte(7)
      ..write(obj.pageCorners)
      ..writeByte(8)
      ..write(obj.pageEngines)
      ..writeByte(9)
      ..write(obj.pageModes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScanResultAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
