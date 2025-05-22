import 'dart:typed_data';
import 'package:dart_pvm/assembler.dart' as assembler;
import 'package:dart_pvm/pvm.dart';

Uint8List createTestProgram() {
  var program = '''
      # Simple test program
      load_imm r0, 42        # Load 42 into register 0
      load_imm r1, 100       # Load 100 into register 1
      add_64 r0, r1, r2      # Add r0 + r1 -> r2 (should be 142)
      move_reg r3, r2        # Copy r2 to r3
      trap                   # Exit program
      ''';

  return assembler.assemble(program);
}

void main(List<String> arguments) {
  try {
    var program = createTestProgram();
    var pvm = PVM();
    var (exitReason, state) = pvm.execute(program, gasLimit: 1000);
    assert(state.registers[3] == 142, "r3 should be 142");
    assert(exitReason == ExitReason.panic, "trap should panic");
    print("The answer is ${state.registers[3]}");
  } catch (e) {
    print("error: $e");
  }
}
