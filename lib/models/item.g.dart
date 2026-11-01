// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 0;

  @override
  Item read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Item(
      id: fields[0] as String,
      nome: fields[1] as String,
      categoria: fields[2] as String,
      quantidade: fields[3] as double,
      unidade: fields[4] as String,
      validade: fields[5] as DateTime?,
      localizacao: fields[6] as String?,
      notas: fields[7] as String?,
      criadoEm: fields[8] as DateTime,
      atualizadoEm: fields[9] as DateTime?,
      quantidadeMinima: fields[10] as double?,
    );
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.nome)
      ..writeByte(2)
      ..write(obj.categoria)
      ..writeByte(3)
      ..write(obj.quantidade)
      ..writeByte(4)
      ..write(obj.unidade)
      ..writeByte(5)
      ..write(obj.validade)
      ..writeByte(6)
      ..write(obj.localizacao)
      ..writeByte(7)
      ..write(obj.notas)
      ..writeByte(8)
      ..write(obj.criadoEm)
      ..writeByte(9)
      ..write(obj.atualizadoEm)
      ..writeByte(10)
      ..write(obj.quantidadeMinima);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
