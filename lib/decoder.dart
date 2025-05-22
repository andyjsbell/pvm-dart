enum InstructionType {
  noArgs,
  oneImm,
  oneRegOneExtImm,
  twoImm,
  oneOffset,
  oneRegOneImm,
  oneRegTwoImm,
  oneRegOneImmOneOffset,
  twoReg,
  twoRegOneImm,
  twoRegOneOffset,
  twoRegTwoImm,
  threeReg,
}

class Instruction {
  final int opcode;
  final String name;
  final InstructionType instructionType;
  final int gasCost;

  Instruction(this.opcode, this.name, this.instructionType, this.gasCost);
}

class DecodedInstruction {
  Instruction instruction;
  List<Object> args;
  int pc;

  DecodedInstruction(this.instruction, this.args, this.pc);
}

/// Extends a value from srcBits to 32 bits, preserving the sign.
int signExtend(int value, int srcBits) {
  // Calculate the mask for the sign bit
  int signBit = 1 << (srcBits - 1);

  // If the sign bit is set, extend it
  if ((value & signBit) != 0) {
    // Create a mask for the bits to be filled with 1s
    int mask = (~0) << srcBits;
    return value | mask;
  }

  return value;
}

const Map<String, int> opcodeMap = {
  "trap": 0,
  "fallthrough": 1,
  "ecalli": 10,
  "load_imm_64": 20,
  "store_imm_u8": 30,
  "store_imm_u16": 31,
  "store_imm_u32": 32,
  "store_imm_u64": 33,
  "jump": 40,
  "jump_ind": 50,
  "load_imm": 51,
  "load_u8": 52,
  "load_i8": 53,
  "load_u16": 54,
  "load_i16": 55,
  "load_u32": 56,
  "load_i32": 57,
  "load_u64": 58,
  "store_u8": 59,
  "store_u16": 60,
  "store_u32": 61,
  "store_u64": 62,
  "move_reg": 100,
  "sbrk": 101,
  "add_32": 190,
  "sub_32": 191,
  "mul_32": 192,
  "add_64": 200,
  "sub_64": 201,
  "mul_64": 202,
  "and": 210,
  "xor": 211,
  "or": 212,
};

class InstructionDecoder {
  static final Map<int, Instruction> instructions = {
    0: Instruction(0, "trap", InstructionType.noArgs, 0),
    1: Instruction(1, "fallthrough", InstructionType.noArgs, 0),
    10: Instruction(10, "ecalli", InstructionType.oneImm, 0),
    20: Instruction(20, "load_imm_64", InstructionType.oneRegOneExtImm, 0),
    // Instructions with two immediate values
    30: Instruction(30, "store_imm_u8", InstructionType.twoImm, 0),
    31: Instruction(31, "store_imm_u16", InstructionType.twoImm, 0),
    32: Instruction(32, "store_imm_u32", InstructionType.twoImm, 0),
    33: Instruction(33, "store_imm_u64", InstructionType.twoImm, 0),

    // Instructions with one offset
    40: Instruction(40, "jump", InstructionType.oneOffset, 0),

    // Instructions with one register and one immediate
    50: Instruction(50, "jump_ind", InstructionType.oneRegOneImm, 0),
    51: Instruction(51, "load_imm", InstructionType.oneRegOneImm, 0),
    52: Instruction(52, "load_u8", InstructionType.oneRegOneImm, 0),
    53: Instruction(53, "load_i8", InstructionType.oneRegOneImm, 0),
    54: Instruction(54, "load_u16", InstructionType.oneRegOneImm, 0),
    55: Instruction(55, "load_i16", InstructionType.oneRegOneImm, 0),
    56: Instruction(56, "load_u32", InstructionType.oneRegOneImm, 0),
    57: Instruction(57, "load_i32", InstructionType.oneRegOneImm, 0),
    58: Instruction(58, "load_u64", InstructionType.oneRegOneImm, 0),
    59: Instruction(59, "store_u8", InstructionType.oneRegOneImm, 0),
    60: Instruction(60, "store_u16", InstructionType.oneRegOneImm, 0),
    61: Instruction(61, "store_u32", InstructionType.oneRegOneImm, 0),
    62: Instruction(62, "store_u64", InstructionType.oneRegOneImm, 0),

    // Instructions with two registers
    100: Instruction(100, "move_reg", InstructionType.twoReg, 0),
    101: Instruction(101, "sbrk", InstructionType.twoReg, 0),
    102: Instruction(102, "count_set_bits_64", InstructionType.twoReg, 0),
    103: Instruction(103, "count_set_bits_32", InstructionType.twoReg, 0),
    104: Instruction(104, "leading_zero_bits_64", InstructionType.twoReg, 0),
    105: Instruction(105, "leading_zero_bits_32", InstructionType.twoReg, 0),
    106: Instruction(106, "trailing_zero_bits_64", InstructionType.twoReg, 0),
    107: Instruction(107, "trailing_zero_bits_32", InstructionType.twoReg, 0),
    108: Instruction(108, "sign_extend_8", InstructionType.twoReg, 0),
    109: Instruction(109, "sign_extend_16", InstructionType.twoReg, 0),
    110: Instruction(110, "zero_extend_16", InstructionType.twoReg, 0),
    111: Instruction(111, "reverse_bytes", InstructionType.twoReg, 0),

    // Instructions with three registers - arithmetic
    190: Instruction(190, "add_32", InstructionType.threeReg, 0),
    191: Instruction(191, "sub_32", InstructionType.threeReg, 0),
    192: Instruction(192, "mul_32", InstructionType.threeReg, 0),
    193: Instruction(193, "div_u_32", InstructionType.threeReg, 0),
    194: Instruction(194, "div_s_32", InstructionType.threeReg, 0),
    195: Instruction(195, "rem_u_32", InstructionType.threeReg, 0),
    196: Instruction(196, "rem_s_32", InstructionType.threeReg, 0),
    197: Instruction(197, "shlo_l_32", InstructionType.threeReg, 0),
    198: Instruction(198, "shlo_r_32", InstructionType.threeReg, 0),
    199: Instruction(199, "shar_r_32", InstructionType.threeReg, 0),

    200: Instruction(200, "add_64", InstructionType.threeReg, 0),
    201: Instruction(201, "sub_64", InstructionType.threeReg, 0),
    202: Instruction(202, "mul_64", InstructionType.threeReg, 0),
    203: Instruction(203, "div_u_64", InstructionType.threeReg, 0),
    204: Instruction(204, "div_s_64", InstructionType.threeReg, 0),
    205: Instruction(205, "rem_u_64", InstructionType.threeReg, 0),
    206: Instruction(206, "rem_s_64", InstructionType.threeReg, 0),
    207: Instruction(207, "shlo_l_64", InstructionType.threeReg, 0),
    208: Instruction(208, "shlo_r_64", InstructionType.threeReg, 0),
    209: Instruction(209, "shar_r_64", InstructionType.threeReg, 0),

    210: Instruction(210, "and", InstructionType.threeReg, 0),
    211: Instruction(211, "xor", InstructionType.threeReg, 0),
    212: Instruction(212, "or", InstructionType.threeReg, 0),
    213: Instruction(213, "mul_upper_s_s", InstructionType.threeReg, 0),
    214: Instruction(214, "mul_upper_u_u", InstructionType.threeReg, 0),
    215: Instruction(215, "mul_upper_s_u", InstructionType.threeReg, 0),
    216: Instruction(216, "set_lt_u", InstructionType.threeReg, 0),
    217: Instruction(217, "set_lt_s", InstructionType.threeReg, 0),
    218: Instruction(218, "cmov_iz", InstructionType.threeReg, 0),
    219: Instruction(219, "cmov_nz", InstructionType.threeReg, 0),
  };

  static DecodedInstruction decode(int instructionWord, int pc) {
    var opcode = instructionWord & 0xff;
    if (!InstructionDecoder.instructions.containsKey(opcode)) {
      throw Exception("Unknown opcode $opcode at PC $pc");
    } else {
      var instruction = InstructionDecoder.instructions[opcode];
      var args = decodeArgs(instructionWord, instruction!.instructionType);
      return DecodedInstruction(instruction, args, pc);
    }
  }

  static List<Object> decodeArgs(
    int instructionWord,
    InstructionType instructionType,
  ) {
    switch (instructionType) {
      case InstructionType.noArgs:
        return [];

      case InstructionType.oneImm:
        return [(instructionWord >> 8) & 0xffffff];

      case InstructionType.oneRegOneExtImm:
        return [(instructionWord >> 8) & 0xf, (instructionWord >> 16) & 0xffff];

      case InstructionType.twoImm:
        // Extract two immediate values
        int imm1 = (instructionWord >> 8) & 0xFF;
        int imm2 = (instructionWord >> 16) & 0xFFFF;
        return [imm1, imm2];

      case InstructionType.oneOffset:
        // Extract offset
        int offset = (instructionWord >> 8) & 0xFFFFFF;
        offset = signExtend(offset, 24);
        return [offset];

      case InstructionType.oneRegOneImm:
        // Extract register and immediate
        int reg = (instructionWord >> 8) & 0xF;
        int imm = (instructionWord >> 12) & 0xFFFFF;
        return [reg, imm];

      case InstructionType.twoReg:
        // Extract two registers
        int reg1 = (instructionWord >> 8) & 0xF;
        int reg2 = (instructionWord >> 12) & 0xF;
        return [reg1, reg2];

      case InstructionType.threeReg:
        // Extract three registers
        int reg1 = (instructionWord >> 8) & 0xF;
        int reg2 = (instructionWord >> 12) & 0xF;
        int reg3 = (instructionWord >> 16) & 0xF;
        return [reg1, reg2, reg3];

      default:
        throw ArgumentError('Unknown instruction type: $instructionType');
    }
  }
}
