// @category NWN.Research
// Run only on the workspace's saved-project backup with analyzeHeadless
// -readOnly -noanalysis. Repairs returning CRT cleanup metadata IN MEMORY;
// neither the open Ghidra project nor the installed binary is changed.
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.Instruction;
import ghidra.program.model.listing.FlowOverride;
import ghidra.program.model.address.AddressSet;
import java.nio.file.Path;
import java.nio.file.Files;
import java.security.MessageDigest;
import java.util.HexFormat;

public class DecompileCombatCopy extends GhidraScript {
  public void run() throws Exception {
    String[] args = getScriptArgs();
    if (args.length < 3) throw new IllegalArgumentException("Need binary, output directory and function addresses");
    String hash = HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(Files.readAllBytes(Path.of(args[0]))));
    if (!hash.equals("3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a")) throw new IllegalArgumentException("Unexpected original binary");
    String projectHash = currentProgram.getExecutableSHA256();
    if (!hash.equalsIgnoreCase(projectHash)) throw new IllegalArgumentException("Backup program does not match original binary");
    long[] helpers = {0x140c10360L, 0x140c10370L, 0x140c1148cL, 0x140c4f024L, 0x140ca9b60L};
    for (long address : helpers) {
      Function helper = currentProgram.getFunctionManager().getFunctionAt(toAddr(address));
      if (helper == null) throw new IllegalArgumentException("Cleanup helper not found");
      println("Cleanup " + helper.getEntryPoint() + " noReturn=" + helper.hasNoReturn());
      helper.setNoReturn(false);
    }
    for (int i = 2; i < args.length; i++) {
      String[] range = args[i].split(":");
      Function function = currentProgram.getFunctionManager().getFunctionAt(toAddr(Long.parseUnsignedLong(range[0], 16)));
      if (function == null) throw new IllegalArgumentException("Function not found: " + args[i]);
      var body = range.length == 1 ? function.getBody() : new AddressSet(function.getEntryPoint(), toAddr(Long.parseUnsignedLong(range[1], 16) - 1));
      // Explicit ranges must come from the hash-checked PE unwind inspector.
      // Earlier CALL_RETURN overrides also truncated Ghidra's function body.
      if (range.length == 2) function.setBody(body);
      for (Instruction instruction : currentProgram.getListing().getInstructions(body, true)) {
        for (var reference : instruction.getReferencesFrom()) for (long helper : helpers) {
          if (reference.getToAddress().equals(toAddr(helper)) && reference.getReferenceType().isCall() && instruction.getFlowOverride() != FlowOverride.NONE) {
            println("Clearing returning cleanup call flow override at " + instruction.getAddress());
            instruction.setFlowOverride(FlowOverride.NONE);
          }
        }
      }
    }
    DecompInterface decompiler = new DecompInterface();
    try {
      decompiler.openProgram(currentProgram);
      for (int i = 2; i < args.length; i++) {
        String address = args[i].split(":")[0];
        Function function = currentProgram.getFunctionManager().getFunctionAt(toAddr(Long.parseUnsignedLong(address, 16)));
        DecompileResults result = decompiler.decompileFunction(function, 60, monitor);
        if (!result.decompileCompleted()) throw new IllegalStateException(result.getErrorMessage());
        Path output = Path.of(args[1], "resolution-" + address + "-copy-decompile.txt");
        Files.writeString(output, result.getDecompiledFunction().getC());
        println("Exported " + function.getName() + " " + output);
      }
    } finally { decompiler.dispose(); }
  }
}
