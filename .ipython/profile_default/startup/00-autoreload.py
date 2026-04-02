# -*- coding: utf-8 -*-
from pathlib import Path
import sys

print(f"\n\033[32mKOMPANION IPYTHON\033[0m")
print(f"\033[34mUsing: {Path(sys.executable).as_posix()}\033[0m\n")

from IPython import get_ipython
from IPython.core.extensions import BUILTINS_EXTS, ExtensionManager


def _patch_load_extension_warning():
    # Silence %load_ext: if already loaded
    if getattr(ExtensionManager, "_kompanion_quiet_load_ext", False):
        return

    def _quiet_load_extension(self, module_str):
        try:
            result = self._load_extension(module_str)
        except ModuleNotFoundError:
            if module_str in BUILTINS_EXTS:
                BUILTINS_EXTS[module_str] = True
                result = self._load_extension("IPython.extensions." + module_str)
            else:
                raise

        if result == "already loaded":
            return None

        return result

    ExtensionManager.load_extension = _quiet_load_extension
    ExtensionManager._kompanion_quiet_load_ext = True


_patch_load_extension_warning()

try:
    if (ip := get_ipython()) is not None:
        ip.run_line_magic("load_ext", "autoreload")
        ip.run_line_magic("autoreload", "2")
        print("\033[34m- Autoreload enabled (mode 2)\033[0m")
except Exception as e:
    print(f"\033[31m- Could not enable autoreload: {e}\033[0m")
