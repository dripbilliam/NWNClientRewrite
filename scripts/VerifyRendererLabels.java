import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;

public class VerifyRendererLabels extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[][] expected = {
			{"140af3390", "LoadOpenGLLibraryAndWGLFunctions"},
			{"140af3000", "InitializeWGLBootstrapContext"},
			{"140af3a60", "SwapWindowBuffers"},
			{"140aefcb0", "CreateSDLWin32Window"},
			{"140aef960", "InitializeSDLWin32WindowData"},
			{"140af37f0", "SetSDLWindowPixelFormat"},
			{"140af3790", "InitializeSDLWindowOpenGLContext"},
			{"140af2c10", "CreateSDLWindowWGLContext"},
			{"140af3510", "MakeSDLWindowWGLContextCurrent"}
		};

		for (String[] entry : expected) {
			Address address = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(entry[0]);
			Function function = currentProgram.getFunctionManager().getFunctionAt(address);
			if (function == null || !function.getName().equals(entry[1])) {
				throw new IllegalStateException("Expected " + entry[1] + " at " + address + ", found " +
					(function == null ? "no function" : function.getName()));
			}
			println("VERIFIED " + function.getName() + " @ " + address);
		}
	}
}