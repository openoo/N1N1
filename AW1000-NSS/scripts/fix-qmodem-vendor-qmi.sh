#!/bin/sh
set -eu

# QModem d35cce9 (2026-07-02) enabled the RMNET/NSS callback path for every
# IPQ8074 build, including the ordinary vendor QMI package, and removed the
# Linux 6.10+ usbnet statistics compatibility path. Restore both pieces from
# the last known-good AW1000 driver while retaining all other current QModem
# sources and kernel fixes.

qmi_source="package/custom-feeds/qmodem/driver/quectel_QMI_WWAN/src/qmi_wwan_q.c"

python3 - "$qmi_source" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.is_file():
    raise SystemExit(f"ERROR: missing QModem vendor QMI source: {path}")

unsafe = """#if defined(CONFIG_PINCTRL_IPQ807x) || defined(CONFIG_PINCTRL_IPQ5018) || defined(CONFIG_PINCTRL_IPQ8074)
//#ifdef CONFIG_RMNET_DATA //spf12.x none, not effect for spf11.x
#define CONFIG_QCA_NSS_DRV
/* define at qsdk/qca/src/linux-4.4/net/rmnet_data/rmnet_data_main.c */ //for spf11.x
/* define at qsdk/qca/src/datarmnet/core/rmnet_config.c */ //for spf12.x
/* set at qsdk/qca/src/data-kernel/drivers/rmnet-nss/rmnet_nss.c */
/* need add DEPENDS:= kmod-rmnet-core in feeds/makefile */
extern struct rmnet_nss_cb *rmnet_nss_callbacks __rcu __read_mostly;
//#endif
#endif
"""

safe = """#if defined(CONFIG_PINCTRL_IPQ807x) || defined(CONFIG_PINCTRL_IPQ5018)
#ifdef CONFIG_RMNET_DATA
#define CONFIG_QCA_NSS_DRV
/* define at qsdk/qca/src/linux-4.4/net/rmnet_data/rmnet_data_main.c */ //for spf11.x
/* define at qsdk/qca/src/datarmnet/core/rmnet_config.c */ //for spf12.x
/* set at qsdk/qca/src/data-kernel/drivers/rmnet-nss/rmnet_nss.c */
/* need add DEPENDS:= kmod-rmnet-core in feeds/makefile */
extern struct rmnet_nss_cb *rmnet_nss_callbacks __rcu __read_mostly;
#endif
#endif
"""

text = path.read_text()
if unsafe in text:
    text = text.replace(unsafe, safe, 1)
    print("==> fixed QModem vendor QMI RMNET/NSS guard")
elif safe in text:
    print("==> QModem vendor QMI RMNET/NSS guard is already safe")
else:
    raise SystemExit(
        "ERROR: QModem vendor QMI guard changed upstream; refusing an unverified patch"
    )

unsafe_stats = """\tif (!_usbnet_get_stats64)
\t\t_usbnet_get_stats64 = dev->net->netdev_ops->ndo_get_stats64;
\tdev->net->netdev_ops = &qmi_wwan_netdev_ops;
"""

safe_stats = """\tif (!_usbnet_get_stats64)
#if (LINUX_VERSION_CODE < KERNEL_VERSION( 6,10,0 ))
\t\t_usbnet_get_stats64 = dev->net->netdev_ops->ndo_get_stats64;
#else
\t\t/* usbnet uses per-CPU tstats and has no ndo_get_stats64 on 6.10+. */
\t\tif (dev->net->pcpu_stat_type == NETDEV_PCPU_STAT_TSTATS)
\t\t\t_usbnet_get_stats64 = dev_get_tstats64;
#endif
\tdev->net->netdev_ops = &qmi_wwan_netdev_ops;
"""

if unsafe_stats in text:
    text = text.replace(unsafe_stats, safe_stats, 1)
    print("==> restored QModem vendor QMI Linux 6.10+ statistics path")
elif safe_stats in text:
    print("==> QModem vendor QMI statistics path is already safe")
else:
    raise SystemExit(
        "ERROR: QModem vendor QMI statistics code changed upstream; "
        "refusing an unverified patch"
    )

path.write_text(text)
PY
