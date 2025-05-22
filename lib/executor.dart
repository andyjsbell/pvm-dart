/// JAM PVM Instruction Executor
///
/// Executes decoded PVM instructions according to the instruction semantics
/// defined in Appendix A.5 of the JAM graypaper.

import 'dart:typed_data';
import 'decoder.dart';
import 'pvm.dart';

/// Custom exception for page faults
class PageFaultException implements Exception {
  final String message;

  PageFaultException(this.message);

  @override
  String toString() => 'PageFaultException: $message';
}

/// Memory page state
class MemoryPage {
  final Uint8List data;
  final String permissions; // "R", "W", "RW"

  MemoryPage(this.data, this.permissions);
}

/// Memory management for PVM
class Memory {
  final Map<int, MemoryPage> pages = {};
  static const int PAGE_SIZE = 4096;

  /// Allocate a new page with given permissions
  void allocatePage(int pageIdx, String permissions) {
    pages[pageIdx] = MemoryPage(Uint8List(PAGE_SIZE), permissions);
  }

  /// Read bytes from memory, checking permissions
  Uint8List readBytes(int address, int size) {
    int pageIdx = address ~/ PAGE_SIZE;
    int offset = address % PAGE_SIZE;

    if (!pages.containsKey(pageIdx)) {
      throw PageFaultException('Page not allocated: $pageIdx');
    }

    var page = pages[pageIdx]!;
    if (!page.permissions.contains('R')) {
      throw PageFaultException('No read permission on page: $pageIdx');
    }

    if (offset + size > PAGE_SIZE) {
      // Cross-page read not implemented in this example
      throw PageFaultException('Cross-page read not supported');
    }

    return Uint8List.fromList(page.data.sublist(offset, offset + size));
  }

  /// Write bytes to memory, checking permissions
  void writeBytes(int address, Uint8List data) {
    int pageIdx = address ~/ PAGE_SIZE;
    int offset = address % PAGE_SIZE;

    if (!pages.containsKey(pageIdx)) {
      throw PageFaultException('Page not allocated: $pageIdx');
    }

    var page = pages[pageIdx]!;
    if (!page.permissions.contains('W')) {
      throw PageFaultException('No write permission on page: $pageIdx');
    }

    if (offset + data.length > PAGE_SIZE) {
      // Cross-page write not implemented in this example
      throw PageFaultException('Cross-page write not supported');
    }

    for (int i = 0; i < data.length; i++) {
      page.data[offset + i] = data[i];
    }
  }
}

/// Result of executing a single instruction
class ExecutionResult {
  final int nextPc;
  final int gasCost;
  final ExitReason? exitReason;
  final String? exitData;

  ExecutionResult({
    required this.nextPc,
    required this.gasCost,
    this.exitReason,
    this.exitData,
  });
}

/// Executes PVM instructions
///
/// Implements the instruction semantics from Appendix A.5
class InstructionExecutor {
  /// Execute a single decoded instruction
  ///
  /// Args:
  ///   instruction: Decoded instruction to execute
  ///   state: Current PVM state (modified in place)
  ///
  /// Returns:
  ///   ExecutionResult with next PC and gas cost
  static ExecutionResult execute(
    DecodedInstruction instruction,
    PVMState state,
  ) {
    // Default next PC is current PC + 4 (standard instruction length)
    int nextPc = instruction.pc + 4;
    int gasCost = instruction.instruction.gasCost;

    try {
      // Execute based on instruction name
      switch (instruction.instruction.name) {
        case "trap":
          return ExecutionResult(
            nextPc: instruction.pc,
            gasCost: 0,
            exitReason: ExitReason.panic,
            exitData: "Trap instruction executed",
          );

        case "fallthrough":
          // Just continue to next instruction
          break;

        case "load_imm":
          // Load immediate value into register
          int reg = instruction.args[0] as int;
          int imm = instruction.args[1] as int;
          state.registers[reg] = imm;
          break;

        case "load_imm_64":
          // Load 64-bit immediate into register
          int reg = instruction.args[0] as int;
          int imm = instruction.args[1] as int;
          state.registers[reg] = imm;
          break;

        case "move_reg":
          // Move value from one register to another
          int dstReg = instruction.args[0] as int;
          int srcReg = instruction.args[1] as int;
          state.registers[dstReg] = state.registers[srcReg];
          break;

        case "add_64":
          // 64-bit addition
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          int result =
              (val1 + val2) & 0xFFFFFFFFFFFFFFFF; // 64-bit overflow wrap
          state.registers[dstReg] = result;
          break;

        case "add_32":
          // 32-bit addition with sign extension
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg] & 0xFFFFFFFF;
          int val2 = state.registers[src2Reg] & 0xFFFFFFFF;
          int result = (val1 + val2) & 0xFFFFFFFF;
          // Sign extend to 64 bits
          if ((result & 0x80000000) != 0) {
            result |= 0xFFFFFFFF00000000;
          }
          state.registers[dstReg] = result;
          break;

        case "sub_64":
          // 64-bit subtraction
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          int result = (val1 - val2) & 0xFFFFFFFFFFFFFFFF;
          state.registers[dstReg] = result;
          break;

        case "sub_32":
          // 32-bit subtraction with sign extension
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg] & 0xFFFFFFFF;
          int val2 = state.registers[src2Reg] & 0xFFFFFFFF;
          int result = (val1 - val2) & 0xFFFFFFFF;
          // Sign extend to 64 bits
          if ((result & 0x80000000) != 0) {
            result |= 0xFFFFFFFF00000000;
          }
          state.registers[dstReg] = result;
          break;

        case "mul_64":
          // 64-bit multiplication
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          int result = (val1 * val2) & 0xFFFFFFFFFFFFFFFF;
          state.registers[dstReg] = result;
          break;

        case "and":
          // Bitwise AND
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          state.registers[dstReg] = val1 & val2;
          break;

        case "or":
          // Bitwise OR
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          state.registers[dstReg] = val1 | val2;
          break;

        case "xor":
          // Bitwise XOR
          int src1Reg = instruction.args[0] as int;
          int src2Reg = instruction.args[1] as int;
          int dstReg = instruction.args[2] as int;
          int val1 = state.registers[src1Reg];
          int val2 = state.registers[src2Reg];
          state.registers[dstReg] = val1 ^ val2;
          break;

        case "load_u8":
          // Load unsigned 8-bit value from memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          Uint8List data = state.memory.readBytes(address, 1);
          state.registers[reg] = data[0];
          break;

        case "load_u16":
          // Load unsigned 16-bit value from memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          Uint8List data = state.memory.readBytes(address, 2);
          state.registers[reg] = data[0] | (data[1] << 8);
          break;

        case "load_u32":
          // Load unsigned 32-bit value from memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          Uint8List data = state.memory.readBytes(address, 4);
          state.registers[reg] =
              data[0] | (data[1] << 8) | (data[2] << 16) | (data[3] << 24);
          break;

        case "load_u64":
          // Load unsigned 64-bit value from memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          Uint8List data = state.memory.readBytes(address, 8);
          int value = 0;
          for (int i = 0; i < 8; i++) {
            value |= data[i] << (i * 8);
          }
          state.registers[reg] = value;
          break;

        case "store_u8":
          // Store 8-bit value to memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          int value = state.registers[reg] & 0xFF;
          state.memory.writeBytes(address, Uint8List.fromList([value]));
          break;

        case "store_u16":
          // Store 16-bit value to memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          int value = state.registers[reg] & 0xFFFF;
          state.memory.writeBytes(
            address,
            Uint8List.fromList([value & 0xFF, (value >> 8) & 0xFF]),
          );
          break;

        case "store_u32":
          // Store 32-bit value to memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          int value = state.registers[reg] & 0xFFFFFFFF;
          state.memory.writeBytes(
            address,
            Uint8List.fromList([
              value & 0xFF,
              (value >> 8) & 0xFF,
              (value >> 16) & 0xFF,
              (value >> 24) & 0xFF,
            ]),
          );
          break;

        case "store_u64":
          // Store 64-bit value to memory
          int reg = instruction.args[0] as int;
          int offset = instruction.args[1] as int;
          int address = state.registers[reg] + offset;
          int value = state.registers[reg];
          Uint8List bytes = Uint8List(8);
          for (int i = 0; i < 8; i++) {
            bytes[i] = (value >> (i * 8)) & 0xFF;
          }
          state.memory.writeBytes(address, bytes);
          break;

        case "jump":
          // Unconditional jump
          int offset = instruction.args[0] as int;
          nextPc = instruction.pc + offset;
          break;

        case "ecalli":
          // Host call instruction
          int hostCallId = instruction.args[0] as int;
          return ExecutionResult(
            nextPc: instruction.pc,
            gasCost: gasCost,
            exitReason: ExitReason.hostCall,
            exitData: "Host call $hostCallId",
          );

        case "sbrk":
          // System break - allocate memory
          int dstReg = instruction.args[0] as int;
          int sizeReg = instruction.args[1] as int;
          int size = state.registers[sizeReg];

          // Simple implementation - allocate pages as needed
          // Real implementation would be more sophisticated
          int startAddress = state.memory.pages.length * Memory.PAGE_SIZE;
          int pagesNeeded = (size + Memory.PAGE_SIZE - 1) ~/ Memory.PAGE_SIZE;

          for (int i = 0; i < pagesNeeded; i++) {
            int pageIdx = state.memory.pages.length + i;
            state.memory.allocatePage(pageIdx, "W");
          }

          state.registers[dstReg] = startAddress;
          break;

        default:
          // Unimplemented instruction
          return ExecutionResult(
            nextPc: instruction.pc,
            gasCost: 0,
            exitReason: ExitReason.panic,
            exitData:
                "Unimplemented instruction: ${instruction.instruction.name}",
          );
      }
    } on PageFaultException catch (e) {
      return ExecutionResult(
        nextPc: instruction.pc,
        gasCost: 0,
        exitReason: ExitReason.pageFault,
        exitData: e.toString(),
      );
    } catch (e) {
      return ExecutionResult(
        nextPc: instruction.pc,
        gasCost: 0,
        exitReason: ExitReason.panic,
        exitData: "Execution error: $e",
      );
    }

    return ExecutionResult(nextPc: nextPc, gasCost: gasCost);
  }
}
