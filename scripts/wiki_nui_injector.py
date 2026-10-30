"""Local wiki reader injected into the verified stock NWN:EE Windows client.

Run with Python 3.12 and frida. --inspect never attaches to a process.
No server commands, network connections, or executable-file patches are made.
"""
from __future__ import annotations

import argparse
import ctypes
import hashlib
import json
import msvcrt
import os
from pathlib import Path
import queue
import struct
import sys
import time

from wiki_nui_data import TOKEN, WikiReader, load_export

ROOT = Path(__file__).resolve().parents[1]
EXPECTED_SHA = "3b7cb1252e0edb2ce22d7971f333aade027039ae30a45b4bc64732c3e6bec73a"
RVAS = {"dispatch": 0x7A41A0, "receive": 0x7A5F20, "events": 0x746130,
        "send": 0x7C25C0, "setRead": 0x2DA7B0, "overflow": 0x2D9460,
        "underflow": 0x2D9520, "render": 0x74B810}


def preflight(executable: Path):
    raw = executable.read_bytes()
    digest = hashlib.sha256(raw).hexdigest()
    if digest != EXPECTED_SHA:
        raise ValueError(f"Unsupported nwmain.exe SHA-256: {digest}; no attachment attempted")
    pe = struct.unpack_from("<I", raw, 0x3C)[0]
    machine, section_count = struct.unpack_from("<HH", raw, pe + 4)
    optional_size = struct.unpack_from("<H", raw, pe + 20)[0]
    if raw[pe:pe + 4] != b"PE\0\0" or machine != 0x8664:
        raise ValueError("Expected AMD64 PE executable")
    sections = []
    for i in range(section_count):
        at = pe + 24 + optional_size + 40 * i
        virtual_size, rva, size, offset = struct.unpack_from("<IIII", raw, at + 8)
        sections.append((rva, max(virtual_size, size), offset))
    signatures = {}
    for name, target in RVAS.items():
        section = next((s for s in sections if s[0] <= target < s[0] + s[1]), None)
        if section is None:
            raise ValueError("Missing native function section")
        offset = section[2] + target - section[0]
        signatures[name] = {"rva": target, "hex": raw[offset:offset + 16].hex()}
    return signatures


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--xml", type=Path, default=ROOT / "wikiexport2.xml")
    parser.add_argument("--article", default="Forest Gnome")
    parser.add_argument("--section", type=int, default=0, help="Initial zero-based section")
    parser.add_argument("--pid", type=int)
    parser.add_argument("--exe", type=Path, default=Path("C:/Program Files (x86)/Steam/steamapps/common/Neverwinter Nights/bin/win32/nwmain.exe"))
    parser.add_argument("--report", type=Path, default=ROOT / "runtime-logs/wiki-nui-injector/status.json")
    parser.add_argument("--control", type=Path, default=ROOT / "runtime-logs/wiki-nui-injector/control.json")
    parser.add_argument("--duration", type=float, default=0, help="Optional automatic stop after N seconds")
    parser.add_argument("--inspect", action="store_true", help="Print converted-data and payload statistics without attaching")
    args = parser.parse_args()
    articles = load_export(args.xml)
    reader = WikiReader(articles, args.article)
    if not 0 <= args.section < len(articles[reader.article].sections):
        raise ValueError("Initial section out of range")
    reader.section = args.section
    if args.inspect:
        largest_update = 0
        for article in articles:
            single = WikiReader([article], article.title)
            for index in range(len(article.sections)):
                single.section = index
                largest_update = max(largest_update, len(single.update()))
        print(json.dumps({"articles": len(articles), "sections": sum(len(a.sections) for a in articles),
                          "maxSectionChars": max(len(t) for a in articles for _, t in a.sections),
                          "initialArticle": articles[reader.article].title,
                          "createPacketBytes": len(reader.create()),
                          "initialUpdateBytes": len(reader.update()),
                          "largestSectionUpdateBytes": largest_update}, indent=2))
        return 0

    signatures = preflight(args.exe)
    import frida  # Optional until an actual attachment is requested.
    device = frida.get_local_device()
    matches = [p for p in device.enumerate_processes() if p.name.casefold() == "nwmain.exe" and (args.pid is None or p.pid == args.pid)]
    if len(matches) != 1:
        raise RuntimeError("Select exactly one running nwmain.exe using --pid")
    pid = matches[0].pid
    # Verify the selected process path as well as the caller-provided file.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    kernel.OpenProcess.restype = ctypes.c_void_p
    kernel.QueryFullProcessImageNameW.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_wchar_p, ctypes.POINTER(ctypes.c_uint32)]
    kernel.CloseHandle.argtypes = [ctypes.c_void_p]
    handle = kernel.OpenProcess(0x1000, 0, pid)
    try:
        path_buffer = ctypes.create_unicode_buffer(32768)
        path_size = ctypes.c_uint32(len(path_buffer))
        if not handle or not kernel.QueryFullProcessImageNameW(handle, 0, path_buffer, ctypes.byref(path_size)):
            raise OSError("Cannot verify selected process executable")
        if Path(path_buffer.value).resolve() != args.exe.resolve():
            raise ValueError("Selected process does not use the verified executable path")
    finally:
        if handle:
            kernel.CloseHandle(handle)

    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.control.parent.mkdir(parents=True, exist_ok=True)
    lock = (args.report.parent / f"client-{pid}.lock").open("a+b")
    lock.seek(0)
    if lock.read(1) == b"":
        lock.write(b"0"); lock.flush()
    lock.seek(0)
    msvcrt.locking(lock.fileno(), msvcrt.LK_NBLCK, 1)
    events = queue.Queue()
    report = {"clientPid": pid, "injectorPid": os.getpid(), "executableSha256": EXPECTED_SHA,
              "scope": "Local standard NUI packets fed to the stock receiver; local token events filtered; no server commands",
              "articles": len(articles), "events": [], "started": time.time(), "running": False}
    session = script = None
    detached_state = {}
    log = args.report.with_suffix(".jsonl").open("a", encoding="utf-8")

    def record(event):
        event = {"time": time.time(), **event}
        report["events"].append(event)
        report["events"] = report["events"][-150:]
        log.write(json.dumps(event, ensure_ascii=False) + "\n"); log.flush()
        print(json.dumps(event, ensure_ascii=True), flush=True)

    def save():
        report["article"] = articles[reader.article].title
        report["section"] = reader.section
        report["updated"] = time.time()
        temporary = args.report.with_suffix(".tmp")
        temporary.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
        os.replace(temporary, args.report)

    def queue_packet(packet, label):
        script.exports_sync.enqueue(list(packet), label)

    def on_detached(reason, crash):
        detached_state.update(reason=reason, crashReported=crash is not None)
        events.put({"kind": "session-ended", **detached_state})

    try:
        config = {"token": TOKEN, "signatures": signatures, "renderRva": RVAS["render"], "indexedBinds": True}
        source = "const CONFIG = " + json.dumps(config) + ";\n" + Path(__file__).with_name("wiki-nui-agent.js").read_text(encoding="utf-8")
        session = device.attach(pid)
        session.on("detached", on_detached)
        script = session.create_script(source, name="local-wiki-nui")
        script.on("message", lambda message, _data: events.put(message.get("payload", {"kind": "agent-error", "message": message.get("stack", message.get("description", str(message)))})))
        script.load()
        initial_status = script.exports_sync.status()
        mode = initial_status["mode"]
        queue_packet(reader.create(mode), "create")
        report["running"] = True
        record({"kind": "attached", "pid": pid, "mode": mode, "initialPacketBytes": len(reader.create(mode))})
        control_mtime, next_status = (args.control.stat().st_mtime_ns if args.control.exists() else 0), 0
        while not args.duration or time.time() - report["started"] < args.duration:
            while not events.empty():
                event = events.get_nowait()
                record(event)
                if event["kind"] == "session-ended":
                    report["sessionEnd"] = dict(detached_state)
                    continue
                if event["kind"] in {"error", "agent-error", "collision"}:
                    report["failure"] = event
                    raise RuntimeError(event.get("message", "Native injector failed"))
                if event["kind"] == "local-event" and event["type"] == "click":
                    if reader.click(event["element"]):
                        queue_packet(reader.update(mode), "navigate")
            if detached_state:
                break
            if args.control.exists() and args.control.stat().st_mtime_ns != control_mtime:
                control_mtime = args.control.stat().st_mtime_ns
                control = json.loads(args.control.read_text(encoding="utf-8-sig"))
                action = control.get("action")
                if action == "stop":
                    break
                if action == "show":
                    if "article" in control:
                        index = reader.by_title.get(str(control["article"]).casefold())
                        if index is None:
                            raise ValueError("Unknown article in local control file")
                        reader.article, reader.section, reader.contents = index, 0, False
                    if "section" in control:
                        section = int(control["section"])
                        if not 0 <= section < len(articles[reader.article].sections):
                            raise ValueError("Invalid section in local control file")
                        reader.section = section
                    opened = script.exports_sync.status()["opened"]
                    queue_packet(reader.update(mode) if opened else reader.create(mode), "control-show")
                elif action == "click" and reader.click(str(control.get("element", ""))):
                    queue_packet(reader.update(mode), "control-navigate")
                elif action == "hide":
                    queue_packet(reader.destroy(mode), "control-hide")
            if time.time() >= next_status:
                report["native"] = script.exports_sync.status()
                save(); next_status = time.time() + 1
            time.sleep(0.05)
    except KeyboardInterrupt:
        record({"kind": "stop", "reason": "keyboard interrupt"})
    except Exception as error:
        if detached_state:
            report["sessionEnd"] = dict(detached_state)
            record({"kind": "session-ended", **detached_state})
        else:
            report["failure"] = str(error)
            record({"kind": "failure", "message": str(error)})
    finally:
        if script is not None and not detached_state:
            try:
                status = script.exports_sync.status()
                if status["active"] and (status["opened"] or status["queue"]):
                    script.exports_sync.enqueue(list(reader.destroy(status["mode"])), "shutdown-destroy")
                    deadline = time.time() + 4
                    while time.time() < deadline:
                        status = script.exports_sync.status()
                        if not status["opened"] and status["queue"] == 0:
                            break
                        time.sleep(0.05)
                script.exports_sync.detach()
                report["native"] = script.exports_sync.status()
                while not events.empty():
                    record(events.get_nowait())
                record({"kind": "detached", "windowDestroyed": True})
            except Exception as error:
                record({"kind": "cleanup-error", "message": str(error)})
            try:
                script.unload()
            except Exception:
                pass
        if session is not None:
            try:
                session.detach()
            except Exception:
                pass
        report["running"] = False
        if detached_state:
            report["sessionEnd"] = dict(detached_state)
            if report.get("native"):
                report["native"]["active"] = False
                report["native"]["opened"] = False
            if detached_state.get("crashReported"):
                report["failure"] = "Target process ended with a crash reported by Frida"
        save()
        log.close()
        lock.close()
    return int("failure" in report)


if __name__ == "__main__":
    sys.exit(main())
