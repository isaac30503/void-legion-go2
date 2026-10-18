#!/usr/bin/env python3
"""ssh_find_test.py — tests of common/ssh-find/ssh-find without a network: real TCP connections to the loopback, and
the parts that need the home network (the neighbour table, the names, the discovery sweep) replaced by fakes.
Run by tests/run.sh, which counts its lines: one per check, "name<TAB>expected<TAB>got" (tabs and newlines escaped)."""
import importlib.machinery
import contextlib
import importlib.util
import io
import os
import socket
import sys
import tempfile
import threading
import time

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HOME = tempfile.mkdtemp()
os.environ["HOME"] = HOME                      # CONF and STATE are read from ~ when the module loads
loader = importlib.machinery.SourceFileLoader("ssh_find", os.path.join(REPO, "common", "ssh-find", "ssh-find"))
spec = importlib.util.spec_from_loader("ssh_find", loader)
sf = importlib.util.module_from_spec(spec)
loader.exec_module(sf)
sf.CONNECT_TIMEOUT, sf.TOTAL_TIMEOUT, sf.RESOLVE_TIMEOUT = 0.5, 1.5, 0.3
sf.say = lambda msg: SAID.append(msg)
SAID = []


def check(name, expected, got):
    esc = lambda v: str(v).replace("\t", "\\t").replace("\n", "\\n")
    print(f"ssh-find: {name}\t{esc(expected)}\t{esc(got)}")


def listener():
    """A TCP server on 127.0.0.1 that accepts and holds its connections; returns its port."""
    srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    srv.bind(("127.0.0.1", 0))
    srv.listen(8)
    held = []
    threading.Thread(target=lambda: [held.append(srv.accept()) for _ in iter(int, 1)], daemon=True).start()
    return srv.getsockname()[1]


def closed_port():
    """A port of 127.0.0.1 where nothing listens (connecting is refused at once)."""
    s = socket.socket()
    s.bind(("127.0.0.1", 0))
    port = s.getsockname()[1]
    s.close()
    return port


def setup(conf, state=None, neigh=(), resolved=(), up=("wlan0", "eth0")):
    os.makedirs(os.path.dirname(sf.CONF), exist_ok=True)
    with open(sf.CONF, "w") as f:
        f.write(conf)
    if state is None:
        try:
            os.remove(sf.STATE)
        except FileNotFoundError:
            pass
    else:
        sf.save_state(state)
    sf.neighbours = lambda: list(neigh)
    sf.resolve = lambda names: list(resolved)
    sf.up_interfaces = lambda: list(up)
    DISCOVERED.clear()
    sf.discover = lambda: DISCOVERED.append(1)
    SAID.clear()


DISCOVERED = []
MAC_A, MAC_B = "02:00:00:00:00:aa", "02:00:00:00:00:bb"
CONF = f"[lego]\nnames = lego.invalid other.invalid\nmacs = {MAC_A}\n"

# ---- candidates_for: which addresses are tried for one address -------------------------------------------------
sf.up_interfaces = lambda: ["wlan0", "eth0"]
check("candidates: IPv4", [("192.168.0.5", None)], sf.candidates_for("192.168.0.5"))
check("candidates: global IPv6", [("2001:db8::5", None)], sf.candidates_for("2001:db8::5"))
check("candidates: link-local IPv6 without interface → every interface that is up",
      [("fe80::5", "wlan0"), ("fe80::5", "eth0")], sf.candidates_for("fe80::5"))
check("candidates: link-local IPv6 with %interface", [("fe80::5", "wlan0")], sf.candidates_for("fe80::5%wlan0"))
check("candidates: not an address", [], sf.candidates_for("lego.invalid"))

# ---- neighbours: the kernel's table, without the failed entries ------------------------------------------------
real_run = sf.subprocess.run


class Out:
    stdout = ("192.168.0.5 dev wlan0 lladdr 02:00:00:00:00:AA REACHABLE\n"
              "fe80::5 dev wlan0 lladdr 02:00:00:00:00:aa STALE\n"
              "192.168.0.9 dev wlan0  FAILED\n"
              "192.168.0.7 dev eth0 lladdr 02:00:00:00:00:cc INCOMPLETE\n")


sf.subprocess.run = lambda *a, **k: Out()
check("neighbours: parsed, MAC in lowercase, FAILED/INCOMPLETE left out",
      [("192.168.0.5", "wlan0", MAC_A), ("fe80::5", "wlan0", MAC_A)], sf.neighbours())
sf.subprocess.run = real_run

# ---- try_connect: every candidate at once, the first that answers wins -----------------------------------------
port = listener()
won = sf.try_connect([("127.0.0.2", None), ("127.0.0.1", None)], port)   # 127.0.0.2: loopback, nothing listens there
check("try_connect: the one that answers wins (a refused one beside it)", ("127.0.0.1", None), won[1] if won else None)
if won:
    won[0].close()
won = sf.try_connect([("127.0.0.1", None)], closed_port())
check("try_connect: nothing answers → None", None, won)
check("try_connect: no candidates → None", None, sf.try_connect([], 22))
t0 = time.monotonic()
sf.try_connect([("192.0.2.1", None)], 22)          # TEST-NET-1: never answers, nor refuses
check("try_connect: a silent address costs one round at most", True, time.monotonic() - t0 < sf.CONNECT_TIMEOUT + 0.5)

# ---- find: the order of the ways, and what it learns -----------------------------------------------------------
setup(CONF, state={"lego": {"last": ["127.0.0.1", None]}}, neigh=[("127.0.0.1", "lo", MAC_A)])
found, state = sf.find("lego", port)
check("find: the last address that worked", "127.0.0.1", found[1] if found else None)
check("find: it remembers where", ["127.0.0.1", None], state["lego"]["last"])
check("find: it learns the MAC it reached", [MAC_A], state["lego"].get("macs"))
check("find: no discovery when it is found at once", 0, len(DISCOVERED))
if found:
    found[0].close()

setup(CONF, neigh=[("127.0.0.1", "lo", MAC_A)])
found, state = sf.find("lego", port)
check("find: by MAC in the neighbour table (nothing remembered)", "127.0.0.1", found[1] if found else None)
if found:
    found[0].close()

setup(CONF, resolved=["127.0.0.1"])
found, state = sf.find("lego", port)
check("find: by name (no MAC in the table)", "127.0.0.1", found[1] if found else None)
if found:
    found[0].close()

setup(CONF, state={"lego": {"last": ["127.0.0.1", None]}}, neigh=[("127.0.0.1", "lo", MAC_B)])
found, state = sf.find("lego", port)
check("find: the last address is another machine's today (another MAC) → skipped", None, found)
check("find: then discovery rounds, until the deadline", True, len(DISCOVERED) >= 1)
check("find: and a message that says what it knew", True, any("lego" in m and MAC_A in m for m in SAID))

setup(CONF.replace(f"macs = {MAC_A}\n", ""), resolved=[])
t0 = time.monotonic()
found, _ = sf.find("lego", closed_port())
check("find: without MACs there is no discovery (nothing to look for)", 0, len(DISCOVERED))
check("find: it gives up at SSH_FIND_TIMEOUT", True, time.monotonic() - t0 < sf.TOTAL_TIMEOUT + 1.5)

setup(CONF, state={"lego": {"last": ["127.0.0.1", None], "macs": [MAC_B]}}, neigh=[("127.0.0.1", "lo", MAC_B)])
found, state = sf.find("lego", port)
check("find: a MAC learned before counts as the machine's", "127.0.0.1", found[1] if found else None)
check("find: learning again does not repeat it", [MAC_B], state["lego"]["macs"])
if found:
    found[0].close()

setup(CONF)
found, _ = sf.find("deck", port)
check("find: an alias that is not in hosts.conf", None, found)
check("find: ... says so", True, any("deck" in m for m in SAID))

# ---- state: saved atomically, and a broken file is not fatal ---------------------------------------------------
sf.save_state({"lego": {"last": ["10.0.0.1", None]}})
check("state: saved and read back", {"lego": {"last": ["10.0.0.1", None]}}, sf.load_state())
check("state: no temporary file left", False, os.path.exists(sf.STATE + ".tmp"))
with open(sf.STATE, "w") as f:
    f.write("{broken")
check("state: a broken file reads as empty", {}, sf.load_state())

# ---- --list ----------------------------------------------------------------------------------------------------
setup(CONF, state={"lego": {"last": ["fe80::5", "wlan0"], "macs": [MAC_B], "when": "2026-10-17 10:00:00"}})
buf = io.StringIO()
sys.argv = ["ssh-find", "--list"]
with contextlib.redirect_stdout(buf):
    rc = sf.main()
check("--list: exit", 0, rc)
check("--list: names, MACs (configured and learned) and the last address with its interface",
      f"lego: lego.invalid other.invalid  macs: {MAC_A} {MAC_B}  last: fe80::5%wlan0 2026-10-17 10:00:00",
      buf.getvalue().strip())
sys.argv = ["ssh-find", "lego"]
check("usage: a wrong number of arguments", 2, sf.main())
