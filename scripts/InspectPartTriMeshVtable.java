import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryAccessException;
import ghidra.program.model.mem.MemoryBlock;

public class InspectPartTriMeshVtable extends GhidraScript {
	private static class BlockBytes {
		final Address start;
		final byte[] bytes;

		BlockBytes(Address start, byte[] bytes) {
			this.start = start;
			this.bytes = bytes;
		}
	}

	@Override
	protected void run() throws Exception {
		Memory memory = currentProgram.getMemory();
		Address imageBase = currentProgram.getImageBase();
		Address typeName = toAddr(0x1412a3668L);
		Address typeDescriptor = typeName.subtract(16);
		long typeRva = typeDescriptor.subtract(imageBase);
		List<BlockBytes> blocks = new ArrayList<>();

		for (MemoryBlock block : memory.getBlocks()) {
			if (!block.isInitialized() || !block.isRead() || block.getSize() > Integer.MAX_VALUE) {
				continue;
			}
			byte[] bytes = new byte[(int) block.getSize()];
			memory.getBytes(block.getStart(), bytes);
			blocks.add(new BlockBytes(block.getStart(), bytes));
		}

		int locatorCount = 0;
		int vtableCount = 0;
		for (BlockBytes block : blocks) {
			ByteBuffer data = ByteBuffer.wrap(block.bytes).order(ByteOrder.LITTLE_ENDIAN);
			for (int offset = 12; offset <= block.bytes.length - 4; offset++) {
				if (Integer.toUnsignedLong(data.getInt(offset)) != typeRva) {
					continue;
				}

				Address rvaField = block.start.add(offset);
				Address locator = rvaField.subtract(12);
				if (memory.getInt(locator) != 1 ||
					Integer.toUnsignedLong(memory.getInt(locator.add(12))) != typeRva) {
					continue;
				}
				locatorCount++;
				println("COL @ " + locator);

				for (BlockBytes referenceBlock : blocks) {
					ByteBuffer references = ByteBuffer.wrap(referenceBlock.bytes).order(ByteOrder.LITTLE_ENDIAN);
					for (int referenceOffset = 0; referenceOffset <= referenceBlock.bytes.length - 8; referenceOffset += 8) {
						if (references.getLong(referenceOffset) != locator.getOffset()) {
							continue;
						}

						Address vtable = referenceBlock.start.add(referenceOffset + 8L);
						Address drawSlot = vtable.add(25L * 8L);
						long drawAddressValue;
						try {
							drawAddressValue = memory.getLong(drawSlot);
						}
						catch (MemoryAccessException exception) {
							continue;
						}

						Address drawAddress = currentProgram.getAddressFactory()
							.getDefaultAddressSpace().getAddress(drawAddressValue);
						Function function = currentProgram.getFunctionManager().getFunctionAt(drawAddress);
						println("  vtable @ " + vtable + ", Part::Draw slot @ " + drawSlot +
							" -> " + drawAddress + (function == null ? " (no function)" : " (" + function.getName() + ")"));
						vtableCount++;
					}
				}
			}
		}

		if (locatorCount == 0) {
			throw new IllegalStateException("No x64 RTTI complete-object locator found for PartTriMesh type descriptor " + typeDescriptor);
		}
		println("RTTI locators=" + locatorCount + ", vtable candidates=" + vtableCount);
	}
}