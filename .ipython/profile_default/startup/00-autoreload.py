# -*- coding: utf-8 -*-
print("\n\033[32mKOMPANION IPYTHON\033[0m")

try:
    from IPython import get_ipython

    if (ipython := get_ipython()) is not None:
        ipython.run_line_magic("load_ext", "autoreload")
        ipython.run_line_magic("autoreload", "2")
        print("\033[34m- Autoreload enabled (mode 2)\033[0m")
except Exception as e:
    print(f"\033[31m- Could not enable autoreload: {e}\033[0m")

try:
    import majordome as mj
    print("\033[34m- Imported majordome as mj\033[0m")
except ImportError:
    print("\033[31m- Could not import majordome\033[0m")
