# -*- coding: utf-8 -*-

def _patch_load_extension_warning():
    """ Silence %load_ext if already loaded to avoid useless warnings. """
    from IPython.core.extensions import BUILTINS_EXTS, ExtensionManager

    if getattr(ExtensionManager, "_kompanion_quiet_load_ext", False):
        return

    def _quiet_load_extension(self, module_str):
        try:
            result = self._load_extension(module_str)
        except ModuleNotFoundError:
            if module_str in BUILTINS_EXTS:
                BUILTINS_EXTS[module_str] = True
                result = self._load_extension(
                    "IPython.extensions." + module_str)
            else:
                raise

        if result == "already loaded":
            return None

        return result

    ExtensionManager.load_extension = _quiet_load_extension
    ExtensionManager._kompanion_quiet_load_ext = True


def _patch_load_autoreload():
    """ Make %load_ext autoreload always present in sessions. """
    from IPython import get_ipython

    try:
        if (ip := get_ipython()) is not None:
            ip.run_line_magic("load_ext", "autoreload")
            ip.run_line_magic("autoreload", "2")
            print("\033[34m- Autoreload enabled (mode 2)\033[0m")
    except Exception as e:
        print(f"\033[31m- Could not enable autoreload: {e}\033[0m")


def _patch_builtins():
    """ Inject elements into the builtins namespace. """
    import builtins
    from pathlib import Path
    from IPython import get_ipython

    if not hasattr(builtins, "__file__"):
        if (ip := get_ipython()) is not None:
            wd = ip.run_line_magic("pwd", "")
            builtins.__file__ = Path(wd).as_posix()
            print("\033[34m- __file__ injected into builtins\033[0m")


def _kompanion_ipython():
    """ Apply all patches to the IPython environment. """
    import sys as sys
    from pathlib import Path

    print(f"\n\033[32mKOMPANION IPYTHON\033[0m")
    print(f"\033[34mUsing: {Path(sys.executable).as_posix()}\033[0m\n")

    _patch_load_extension_warning()
    _patch_load_autoreload()
    _patch_builtins()


_kompanion_ipython()
