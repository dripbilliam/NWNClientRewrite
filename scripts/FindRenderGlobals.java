import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.symbol.Reference;
import ghidra.program.model.symbol.ReferenceIterator;
import ghidra.program.model.symbol.Symbol;
import ghidra.program.model.symbol.SymbolTable;
import java.util.List;

public class FindRenderGlobals extends GhidraScript {
	@Override
	protected void run() throws Exception {
		String[] names = {"CurrentCamera", "currentscene", "g_pAppManager", "g_pWindow"};
		SymbolTable table = currentProgram.getSymbolTable();
		for (String name : names) {
			List<Symbol> symbols = table.getSymbols(name, currentProgram.getGlobalNamespace());
			int symbolCount = 0;
			for (Symbol symbol : symbols) {
				symbolCount++;
				Address address = symbol.getAddress();
				println("SYMBOL " + name + " @ " + address);
				ReferenceIterator references = currentProgram.getReferenceManager().getReferencesTo(address);
				while (references.hasNext()) {
					Reference reference = references.next();
					Function function = currentProgram.getFunctionManager().getFunctionContaining(reference.getFromAddress());
					println("  xref " + reference.getFromAddress() +
						(function == null ? "" : " in " + function.getName() + " @ " + function.getEntryPoint()));
				}
			}
			if (symbolCount == 0) println("NO SYMBOL " + name);
		}
	}
}
