#!/usr/bin/env python3
import subprocess
import os
import pwd
from getpass import getpass
import time
from multiprocessing import Process


def target_home():
    sudo_user = os.environ.get("SUDO_USER")
    if sudo_user:
        return pwd.getpwnam(sudo_user).pw_dir
    return os.path.expanduser("~")


def detachify(func):
    def forkify(*args, **kwargs):
        if os.fork() != 0:
            return
        func(*args, **kwargs)
    def wrapper(*args, **kwargs):
        proc = Process(target=lambda: forkify(*args, **kwargs))
        proc.start()
        proc.join()
    return wrapper


def is_mounted():
    try:
        result = subprocess.run(['mount'], capture_output=True, text=True)
        return mount_dir in result.stdout
    except Exception:
        return False


def unmount():
    attempts = 0
    while is_mounted():
        print(".", end="", flush=True)
        subprocess.run(['fusermount', '-u', mount_dir], capture_output=True)
        time.sleep(1)
        attempts += 1
        if attempts >= 3:
            break


@detachify
def auto_lock(delay=60):
    time.sleep(delay)
    unmount()


# Ensure directories exist
home_dir = target_home()
cipher_dir = os.path.join(home_dir, ".secret-encrypted")
mount_dir = os.path.join(home_dir, "secret")
os.makedirs(cipher_dir, mode=0o700, exist_ok=True)
os.makedirs(mount_dir, mode=0o700, exist_ok=True)

# Check if gocryptfs filesystem is initialized
if not os.path.exists(os.path.join(cipher_dir, "gocryptfs.conf")):
    print("Initializing encrypted vault...")
    pw = getpass("Create passphrase: ")
    pw_confirm = getpass("Confirm passphrase: ")
    if pw != pw_confirm:
        print("Passwords don't match!")
        exit(1)
    
    result = subprocess.run(
        ['gocryptfs', '-init', cipher_dir],
        input=f"{pw}\n",
        text=True,
        capture_output=True
    )
    if result.returncode != 0:
        print(f"Initialization failed: {result.stderr}")
        exit(1)
    print("Vault initialized!")

if is_mounted():
    print("Already open, locking now.")
    auto_lock(0)
else:
    pw = getpass()
    
    result = subprocess.run(
        ['gocryptfs', '-q', cipher_dir, mount_dir],
        input=f"{pw}\n",
        text=True,
        capture_output=True
    )
    if result.returncode != 0:
        print("Wrong password or mount failed.")
    else:
        print("Opened! Will lock back in 1 minute.")
        auto_lock()
