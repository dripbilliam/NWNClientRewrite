import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.listing.Function;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;

public class InspectSceneRenderSlots extends GhidraScript {
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
		String[][] types = {
			{"Scene", "1412a4208"},
			{"CAurScene", "1412a41b0"},
			{"Camera", "1412a2d38"},
			{"CClientExoApp", "1412bc4f0"},
			{"PartSkin", "1412a3750"},
			{"CGuiViewport", "1412ac460"}
		};
		Memory memory = currentProgram.getMemory();
		Address imageBase = currentProgram.getImageBase();
		List<BlockBytes> blocks = new ArrayList<>();
		for (MemoryBlock block : memory.getBlocks()) {
			if (!block.isInitialized() || !block.isRead() || block.getSize() > Integer.MAX_VALUE) {
				continue;
			}
			byte[] bytes = new byte[(int) block.getSize()];
			memory.getBytes(block.getStart(), bytes);
			blocks.add(new BlockBytes(block.getStart(), bytes));
		}

		for (String[] type : types) {
			Address typeName = toAddr(Long.parseUnsignedLong(type[1], 16));
			Address typeDescriptor = typeName.subtract(16);
			long typeRva = typeDescriptor.subtract(imageBase);
			println("TYPE " + type[0] + " descriptor=" + typeDescriptor + " RVA=" + Long.toHexString(typeRva));
			int locatorCount = 0;
			int vtableCount = 0;

			for (BlockBytes block : blocks) {
				ByteBuffer data = ByteBuffer.wrap(block.bytes).order(ByteOrder.LITTLE_ENDIAN);
				for (int offset = 12; offset <= block.bytes.length - 4; offset++) {
					if (Integer.toUnsignedLong(data.getInt(offset)) != typeRva) {
						continue;
					}
					Address locator = block.start.add(offset - 12L);
					if (memory.getInt(locator) != 1 ||
						Integer.toUnsignedLong(memory.getInt(locator.add(12))) != typeRva) {
						continue;
					}
					locatorCount++;
					println("  COL " + locator);

					for (BlockBytes refBlock : blocks) {
						ByteBuffer references = ByteBuffer.wrap(refBlock.bytes).order(ByteOrder.LITTLE_ENDIAN);
						for (int refOffset = 0; refOffset <= refBlock.bytes.length - 8; refOffset += 8) {
							if (references.getLong(refOffset) != locator.getOffset()) {
								continue;
							}
							Address vtable = refBlock.start.add(refOffset + 8L);
							println("  VTABLE " + vtable);
							vtableCount++;
							for (int slot = 0; slot <= 75; slot++) {
								Address pointer = vtable.add((long) slot * 8L);
								long targetValue;
								try {
									targetValue = memory.getLong(pointer);
								}
								catch (Exception exception) {
									break;
								}
								Address target = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(targetValue);
								Function function = currentProgram.getFunctionManager().getFunctionAt(target);
								if (function == null) {
									break;
								}
								if (type[0].equals("CClientExoApp") || type[0].equals("PartSkin") || slot < 10 ||
									(slot >= 45 || function.getName().contains("Render"))) {
									println("    slot " + slot + " @ " + pointer + " -> " + target + " " + function.getName());
								}
							}
						}
					}
				}
			}
			println("  RTTI locators=" + locatorCount + ", vtable candidates=" + vtableCount);
		}
	}
}
