/// JAM Protocol Virtual Machine (PVM) - Core Module
///
/// This module implements the main PVM execution engine following the JAM graypaper
/// specification in Appendix A.

import 'dart:typed_data';
import 'decoder.dart';
import 'executor.dart';

/// PVM exit reasons as defined in Appendix A
enum ExitReason {
  regularHalt("∎"), // Regular program termination
  panic("☇"), // Irregular program termination
  outOfGas("∞"), // Exhaustion of gas
  pageFault("F"), // Page fault with address
  hostCall("h"); // Host-call progression

  const ExitReason(this.symbol);
  final String symbol;
}

/// PVM machine state containing registers, memory, and gas
class PVMState {
  late List<int> registers; // 13 64-bit registers (rv64em has 16, PVM uses 13)
  int pc = 0; // Program counter (instruction index)
  int gas; // Gas counter
  late PagedMemory memory;
  ExitReason? exitReason;
  String? exitData;

  PVMState([int initialGas = 1000000]) : gas = initialGas {
    registers = List.filled(13, 0);
    memory = PagedMemory();
  }
}

/// PVM paged memory system with 4KB pages
/// Each page can be: inaccessible (∅), read-only (R), or read-write (W)
class PagedMemory {
  static const int pageSize = 4096; // Z_P = 2^12 = 4096 bytes

  final Map<int, PageInfo> pages = {}; // page_index -> PageInfo

  /// Read bytes from memory, checking page access
  Uint8List readBytes(int address, int length) {
    Uint8List result = Uint8List(length);

    for (int i = 0; i < length; i++) {
      int pageIdx = (address + i) ~/ pageSize;
      int pageOffset = (address + i) % pageSize;

      if (!pages.containsKey(pageIdx)) {
        throw PageFaultException("Page $pageIdx not accessible");
      }

      PageInfo pageInfo = pages[pageIdx]!;
      if (pageInfo.access == "∅") {
        throw PageFaultException("Page $pageIdx not accessible");
      }

      result[i] = pageInfo.data[pageOffset];
    }

    return result;
  }

  /// Write bytes to memory, checking page access
  void writeBytes(int address, Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      int pageIdx = (address + i) ~/ pageSize;
      int pageOffset = (address + i) % pageSize;

      if (!pages.containsKey(pageIdx)) {
        throw PageFaultException("Page $pageIdx not accessible");
      }

      PageInfo pageInfo = pages[pageIdx]!;
      if (pageInfo.access != "W") {
        throw PageFaultException("Page $pageIdx not writable");
      }

      // Modify the page data
      pageInfo.data[pageOffset] = data[i];
    }
  }

  /// Allocate a new page with specified access
  void allocatePage(int pageIdx, [String access = "W"]) {
    pages[pageIdx] = PageInfo(Uint8List(pageSize), access);
  }
}

/// Page information containing data and access permissions
class PageInfo {
  final Uint8List data;
  final String access;

  PageInfo(this.data, this.access);
}

/// Exception raised when memory access violates page permissions
class PageFaultException implements Exception {
  final String message;
  PageFaultException(this.message);

  @override
  String toString() => "PageFaultException: $message";
}

/// Polkadot Virtual Machine implementation
/// Based on RISC-V rv64em with JAM-specific modifications
class PVM {
  late PVMState state;

  /// Execute a PVM program
  ///
  /// Args:
  ///   program: Compiled PVM bytecode
  ///   initialRegisters: Initial register values (optional)
  ///   gasLimit: Maximum gas to consume
  ///
  /// Returns:
  ///   Tuple of (exit_reason, final_state)
  (ExitReason, PVMState) execute(
    Uint8List program, {
    List<int>? initialRegisters,
    int gasLimit = 1000000,
  }) {
    // Initialize state
    state = PVMState(gasLimit);
    if (initialRegisters != null) {
      int copyLength =
          initialRegisters.length < state.registers.length
              ? initialRegisters.length
              : state.registers.length;
      for (int i = 0; i < copyLength; i++) {
        state.registers[i] = initialRegisters[i];
      }
    }

    // Load program into memory
    _loadProgram(program);

    // Main execution loop
    while (true) {
      // Check gas
      if (state.gas <= 0) {
        state.exitReason = ExitReason.outOfGas;
        break;
      }

      try {
        // Fetch instruction
        int? instruction = _fetchInstruction();
        if (instruction == null) {
          state.exitReason = ExitReason.panic;
          break;
        }

        // Decode instruction
        DecodedInstruction decoded = InstructionDecoder.decode(
          instruction,
          state.pc,
        );

        // Execute instruction
        ExecutionResult result = InstructionExecutor.execute(decoded, state);

        if (result.exitReason != null) {
          state.exitReason = result.exitReason;
          state.exitData = result.exitData;
          break;
        }

        // Update PC and gas
        state.pc = result.nextPc;
        state.gas -= result.gasCost;
      } on PageFaultException catch (e) {
        state.exitReason = ExitReason.pageFault;
        state.exitData = e.message;
        break;
      } catch (e) {
        state.exitReason = ExitReason.panic;
        state.exitData = e.toString();
        break;
      }
    }

    return (state.exitReason!, state);
  }

  /// Load program into memory (simplified implementation)
  void _loadProgram(Uint8List program) {
    int programPages =
        (program.length + PagedMemory.pageSize - 1) ~/ PagedMemory.pageSize;

    for (int pageIdx = 0; pageIdx < programPages; pageIdx++) {
      state.memory.allocatePage(pageIdx, "R"); // Read-only for code

      int startOffset = pageIdx * PagedMemory.pageSize;
      int endOffset =
          (startOffset + PagedMemory.pageSize < program.length)
              ? startOffset + PagedMemory.pageSize
              : program.length;

      Uint8List pageData = Uint8List(PagedMemory.pageSize);

      // Copy program data to page
      for (int i = startOffset; i < endOffset; i++) {
        pageData[i - startOffset] = program[i];
      }

      // Store the page
      state.memory.pages[pageIdx] = PageInfo(pageData, "R");
    }
  }

  /// Fetch instruction at current PC
  int? _fetchInstruction() {
    try {
      // Read 4 bytes for instruction (simplified - actual format varies)
      Uint8List instructionBytes = state.memory.readBytes(state.pc, 4);

      // Convert to little-endian 32-bit integer
      ByteData buffer = ByteData.view(instructionBytes.buffer);
      return buffer.getUint32(0, Endian.little);
    } on PageFaultException {
      return null;
    }
  }
}
