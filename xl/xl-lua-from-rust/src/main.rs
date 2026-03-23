use mlua::prelude::*;
use mlua::{Function, Value};
use std::fs::{read_to_string};

//////////////////////////////////////////////////////////////////////////////
// Pure Rust implementation of the Arrhenius factor
//////////////////////////////////////////////////////////////////////////////

fn arrhenius_factor(a: f64, e: f64, r: f64, t: f64) -> f64 {
    a * (-e / (r * t)).exp()
}

//////////////////////////////////////////////////////////////////////////////
/// Wrapper functions for Lua
//////////////////////////////////////////////////////////////////////////////

fn arrhenius_factor_lua(
        lua: &Lua,
        (a, e, r, t): (f64, f64, f64, f64),
    ) -> LuaResult<Value> {
    let res = arrhenius_factor(a, e, r, t);
    res.into_lua(lua)
}

//////////////////////////////////////////////////////////////////////////////
/// Manage Lua environment
//////////////////////////////////////////////////////////////////////////////

fn set_environment(lua: &Lua, env: &LuaTable) -> LuaResult<()> {
    // IMPORTANT: when you add an environment to a function, you are
    // replacing its entire environment. So we need to copy existing
    // globals into the new environment.
    let globals = lua.globals();

    for pair in globals.pairs::<Value, Value>() {
        let (key, value) = pair?;
        env.set(key, value)?;
    }

    Ok(())
}

fn append_extension_utils(lua: &Lua) -> LuaResult<LuaTable> {
    // Create the arrhenius_factor function from Rust
    let arrhenius_fn = lua.create_function(arrhenius_factor_lua)?;

    // Create table with variables to be visible in Lua scripts:
    let new_globals = lua.create_table()?;
    new_globals.set("gas_constant", 8.314)?;

    // Create a utils table and add the function; then set it as a global
    // so that Lua scripts can access it (sourcing needed later!).
    let utils = lua.create_table()?;
    utils.set("arrhenius_factor", arrhenius_fn)?;
    new_globals.set("utils", utils)?;

    // Notice that doing in this order (first adding utils to globals, then
    // setting the environment) makes whatever is in `env` available as global
    // variables and the functions in `utils` accessible in named scope.
	set_environment(&lua, &new_globals)?;

    Ok(new_globals)
}

//////////////////////////////////////////////////////////////////////////////
/// Default Lua environment with physical constants
//////////////////////////////////////////////////////////////////////////////

struct DiffusionCoefficientLua {
    f: LuaFunction,
}

impl DiffusionCoefficientLua {
    fn new(lua: &Lua, env: &LuaTable, fname: &str) -> LuaResult<Self> {
        let code = read_to_string(fname)?;
        let chunk = lua.load(&code);

        let lua_fn: Function = chunk.eval()?;
        lua_fn.set_environment(env.clone())?;

        Ok(DiffusionCoefficientLua { f: lua_fn })
    }

    fn eval(&self, temp: f64) -> f64 {
        let result: f64 = self.f.call(temp).unwrap();
        result
    }
}

fn main() -> LuaResult<()> {
    let lua = Lua::new();
    let env = append_extension_utils(&lua)?;

    let diffusion = DiffusionCoefficientLua::new(&lua, &env, "extension.lua")?;
    let result: f64 = diffusion.eval(1173.15f64);

    println!("Result from Lua function: {:?}", result);

    Ok(())
}