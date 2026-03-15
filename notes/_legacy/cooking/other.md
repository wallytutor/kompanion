# Other languages

## Erlang

- [Getting started](https://www.erlang.org/doc/system/getting_started.html)

## Fortran

- [Quick-start](https://fortran-lang.org/learn/quickstart/).

### Cheat-sheet

- Subroutines can be declared directly inside a program

```fortran
program program_name
    implicit none

    some_subroutine()

    contains

    subroutine some_subroutine()
        print *, "Hello, world!"
    end subroutine some_subroutine

end program program_name
```

- Flow control

    - Both single branch `if` and `if-else` conditionals are supported

    - Multi-branch is obtained by chaining `if-else` conditionals

- Strings

    - Constant size allocation with `character(len=<n>)` for `n` characters

    - Runtime allocation declared with `character(:), allocatable`

    - Allocation can be done explicitly `allocate(character(<n>) :: <var-name>)` or implicitly on assignment

    - Concatenation is performed with `//`

    - An array of strings keeps strings of a single size (which can be trimmed for display)

## LISP

- [Recommended environment Portacle](https://portacle.github.io/)
- [Common LISP resources](https://lisp-lang.org/learn/getting-started/)
- [Tutorialspoint tutorial](https://www.tutorialspoint.com/lisp/index.htm)

### Tips

- Who do I produce an executable from within the REPL?

```lisp
; For Windows use the `.exe` otherwise it won't execute!
(save-lisp-and-die "myapp.exe" :executable t :toplevel #'main)
```
