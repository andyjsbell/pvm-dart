import 'dart:typed_data';
import 'package:dart_pvm/decoder.dart';

Uint8List assemble(String code) {
  List<String> lines = code.split(RegExp(r'\r\n|\r|\n'));
  List<Uint8List> chunks = [];

  for (String line in lines) {
    line = line.trim();
    if (line.startsWith("#") || line.isEmpty) {
      continue;
    }
    chunks.add(assembleInstruction(line));
  }

  int totalLength = chunks.fold(0, (sum, chunk) => sum + chunk.length);
  Uint8List result = Uint8List(totalLength);
  int offset = 0;
  for (var chunk in chunks) {
    result.setAll(offset, chunk);
    offset += chunk.length;
  }

  return result;
}

Uint8List packUint32(int value) {
  return (ByteData(4)..setUint32(0, value, Endian.little)).buffer.asUint8List();
}

int parseRegister(String regStr) {
  // Example implementation - adjust based on your register format
  if (regStr.startsWith('r')) {
    return int.parse(regStr.substring(1));
  }
  throw ArgumentError('Invalid register format: $regStr');
}

Uint8List assembleInstruction(String line) {
  var parts = line.replaceAll(",", "").split(RegExp(r'\s+'));
  if (parts.isEmpty) return Uint8List(0);
  var opcodeName = parts[0];
  List<String> args = parts.length > 1 ? parts.skip(1).toList() : [];
  if (!opcodeMap.containsKey(opcodeName)) {
    throw Exception("Unknown instruction: $opcodeName");
  }
  var opcode = opcodeMap[opcodeName];
  if (opcode == null) {
    throw ArgumentError('Unknown opcode: $opcodeName');
  }

  if (["trap", "fallthrough"].contains(opcodeName)) {
    ByteData buffer = ByteData(4);
    buffer.setUint32(0, opcode, Endian.little);
    return buffer.buffer.asUint8List();
  } else if (opcodeName == "ecalli") {
    // One immediate argument
    int imm = int.parse(args[0]);
    int instruction = opcode | ((imm & 0xFFFFFF) << 8);
    return packUint32(instruction);
  } else if ([
    "load_imm",
    "load_u8",
    "load_u16",
    "load_u32",
    "load_u64",
    "store_u8",
    "store_u16",
    "store_u32",
    "store_u64",
  ].contains(opcodeName)) {
    // One register, one immediate
    int reg = parseRegister(args[0]);
    int imm = int.parse(args[1]);
    int instruction = opcode | ((reg & 0xF) << 8) | ((imm & 0xFFFFF) << 12);
    return packUint32(instruction);
  } else if (opcodeName == "load_imm_64") {
    // One register, one extended immediate
    int reg = parseRegister(args[0]);
    int imm = int.parse(args[1]);
    int instruction = opcode | ((reg & 0xF) << 8) | ((imm & 0xFFFF) << 16);
    return packUint32(instruction);
  } else if (["move_reg", "sbrk"].contains(opcodeName)) {
    // Two registers
    int reg1 = parseRegister(args[0]);
    int reg2 = parseRegister(args[1]);
    int instruction = opcode | ((reg1 & 0xF) << 8) | ((reg2 & 0xF) << 12);
    return packUint32(instruction);
  } else if ([
    "add_32",
    "sub_32",
    "mul_32",
    "add_64",
    "sub_64",
    "mul_64",
    "and",
    "xor",
    "or",
  ].contains(opcodeName)) {
    // Three registers
    int reg1 = parseRegister(args[0]);
    int reg2 = parseRegister(args[1]);
    int reg3 = parseRegister(args[2]);
    int instruction =
        opcode |
        ((reg1 & 0xF) << 8) |
        ((reg2 & 0xF) << 12) |
        ((reg3 & 0xF) << 16);
    return packUint32(instruction);
  } else if (opcodeName == "jump") {
    // One offset
    int offset = int.parse(args[0]);
    int instruction = opcode | ((offset & 0xFFFFFF) << 8);
    return packUint32(instruction);
  } else {
    // Default: just opcode
    return packUint32(opcode);
  }
}
