import argparse
import hashlib
from pathlib import Path

import pefile
from capstone import Cs, CS_ARCH_X86, CS_MODE_64


EXPECTED_SHA256 = "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "binary",
        nargs="?",
        type=Path,
        default=Path(__file__).resolve().parents[2]
        / "FullDecomp/NwnRootInstall/bin/win32/nwmain.exe",
    )
    arguments = parser.parse_args()
    binary_data = arguments.binary.read_bytes()
    if hashlib.sha256(binary_data).hexdigest() != EXPECTED_SHA256:
        raise ValueError("Unexpected target binary; expected NWN:EE 89.8193.37-17")
    image = pefile.PE(data=binary_data)
    image_base = image.OPTIONAL_HEADER.ImageBase
    decoder = Cs(CS_ARCH_X86, CS_MODE_64)
    checks = (
        (0x140AF2F80, 0x14, 0x140AF2F8F, "jmp", "qword ptr [rax + 0x30]"),
        (0x1407D03A4, 0x0D, 0x1407D03AE, "call", "qword ptr [rax + 0x10]"),
        (0x1406DC249, 0x05, 0x1406DC249, "call", "0x140767d50"),
        (0x140767FD3, 0x05, 0x140767FD3, "call", "0x1407cffc0"),
        (0x1406DC26A, 0x05, 0x1406DC26A, "call", "0x1401f70e0"),
        (0x1407CD3B2, 0x13, 0x1407CD3B9, "call", "0x140059f70"),
        (0x1407E9046, 0x11, 0x1407E9054, "call", "qword ptr [rax + 0x20]"),
    )
    for start_address, size, call_address, mnemonic, operands in checks:
        instructions = list(
            decoder.disasm(image.get_data(start_address - image_base, size), start_address)
        )
        matches = [instruction for instruction in instructions if instruction.address == call_address]
        if len(matches) != 1 or (matches[0].mnemonic, matches[0].op_str) != (mnemonic, operands):
            raise ValueError(f"Instruction mismatch at {call_address:#x}")
        for instruction in instructions:
            print(f"{instruction.address:#x}: {instruction.mnemonic} {instruction.op_str}")
    ranges = [
        entry.struct
        for entry in image.DIRECTORY_ENTRY_EXCEPTION
        if entry.struct.BeginAddress <= 0x7CD3B9 < entry.struct.EndAddress
    ]
    if len(ranges) != 1 or (ranges[0].BeginAddress, ranges[0].EndAddress) != (0x7CD2C0, 0x7CDD20):
        raise ValueError("Camera initialization runtime-function range mismatch")
    print("PE runtime function: 0x1407cd2c0-0x1407cdd20")
    print("Verified target hash and seven render-tail instruction checks.")


if __name__ == "__main__":
    main()