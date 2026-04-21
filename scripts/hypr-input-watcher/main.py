import asyncio
import logging

logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

KEYBOARD_MAC_PATH = "C5_C9_DB_78_22_4B"


async def restart_espanso() -> None:
    logger.info("restarting espanso")
    proc = await asyncio.create_subprocess_exec(
        "systemctl", "--user", "restart", "espanso"
    )
    await proc.wait()


async def wait_for_wifi(timeout: int = 30) -> bool:
    for _ in range(timeout):
        proc = await asyncio.create_subprocess_exec(
            "ip", "addr", "show", "wlan0",
            stdout=asyncio.subprocess.PIPE,
        )
        out, _ = await proc.communicate()
        if b"inet " in out and b"state UP" in out:
            return True
        await asyncio.sleep(1)
    return False


async def restart_sing_box() -> None:
    logger.info("waiting for wifi before restarting sing-box")
    if not await wait_for_wifi():
        logger.warning("wifi not ready after 30s, restarting sing-box anyway")
    else:
        logger.info("wifi is up")
    logger.info("stopping sing-box")
    stop = await asyncio.create_subprocess_exec(
        "sudo", "systemctl", "stop", "sing-box"
    )
    await stop.wait()
    logger.info("starting sing-box")
    start = await asyncio.create_subprocess_exec(
        "sudo", "systemctl", "start", "sing-box"
    )
    await start.wait()


async def main() -> None:
    while True:
        try:
            proc = await asyncio.create_subprocess_exec(
                "dbus-monitor",
                "--system",
                "type='signal',sender='org.bluez',"
                "interface='org.freedesktop.DBus.Properties',"
                "member='PropertiesChanged'",
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
            )
            logger.info("monitoring bluetooth via dbus")
            buf = []
            while True:
                line = await proc.stdout.readline()
                if not line:
                    break
                text = line.decode("utf-8").strip()
                if text.startswith("signal "):
                    if buf:
                        block = "\n".join(buf)
                        if (
                            KEYBOARD_MAC_PATH in block
                            and "Connected" in block
                            and "true" in block
                        ):
                            logger.info("keyboard connected via bluetooth")
                            await restart_espanso()
                            await restart_sing_box()
                    buf = [text]
                else:
                    buf.append(text)
            logger.warning("dbus-monitor exited, restarting")
        except Exception as e:
            logger.error("error: %s, retrying in 3s", e)
        await asyncio.sleep(3)


if __name__ == "__main__":
    asyncio.run(main())
