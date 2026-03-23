# Experimental - Calling Lua from Rust

The goal of this XL project is to use Lua as a scripting language for a Rust program while restraining its globals space. It is based on the `mlua` crate, more specifically on its [guided tour](https://github.com/mlua-rs/mlua/blob/main/examples/guided_tour.rs). Other elements are based on a similar project by [Jeremy Chone](https://github.com/jeremychone-channel/rust-xp-lua/blob/main/examples/c03-lua-fn.rs).

Please notice that this relies on the availability of a C compiler; it was tested under Windows with [WinLibs](https://winlibs.com/), or more specifically as distributed [here](https://github.com/brechtsanders/winlibs_mingw).
