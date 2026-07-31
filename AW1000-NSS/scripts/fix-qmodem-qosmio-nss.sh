#!/bin/sh
set -eu

# qosmio/nss-packages uses kmod-usb-net-qmi-wwan-quectel for its NSS-aware
# Quectel USB driver. QModem uses another name for its nested copy, which is
# not exposed as an OpenWrt package in this source layout. Map QModem's NSS
# choice to the package that this build line actually provides.

qmodem_makefile="package/custom-feeds/qmodem/application/qmodem/Makefile"

python3 - "$qmodem_makefile" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"ERROR: missing QModem application Makefile: {path}")

old = """\t\t+PACKAGE_luci-app-qmodem_INCLUDE_nss-qmi-wwan:kmod-rmnet-nss \\
\t\t+PACKAGE_luci-app-qmodem_INCLUDE_nss-qmi-wwan:kmod-qmi_wwan_q_nss \\
"""
new = """\t\t+PACKAGE_luci-app-qmodem_INCLUDE_nss-qmi-wwan:kmod-usb-net-qmi-wwan-quectel \\
"""

text = path.read_text()
if old in text:
    path.write_text(text.replace(old, new, 1))
    print("==> mapped QModem NSS QMI choice to qosmio WWAN packages")
elif new in text:
    print("==> QModem already uses the qosmio NSS QMI package mapping")
else:
    raise SystemExit(
        "ERROR: QModem NSS dependency block changed upstream; "
        "refusing an unverified replacement"
    )
PY
