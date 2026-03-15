# Programming in Racket

Scheme is a minimalist essence of Lisp; there are many *flavors* of Scheme, and that's exactly what the language is about: conceiving new domain specific languages. Here we have chosen to proceed with [Racket](https://racket-lang.org/), which is a *language-oriented programming language*, what intends to express its suitability at providing a sanitized macro ecosystem for conceiving DSL (domain specific languages).

Full package for Windows does not seem to be provided as a compressed folder anymore (as the Minimal Racket tarball). No worries, just navigate to [Racket: Index](https://download.racket-lang.org/releases/), choose your version and download the installer. Instead of executing, right-click the file and select *Extract to...*; all the contents will be placed in the directory of your choice, where you find `DrRacket.exe`, the IDE for the language. It seems to work out of the box.

Practical links:

- [The Racket Guide](https://docs.racket-lang.org/guide/index.html)
- [The Racket Reference](https://docs.racket-lang.org/reference/index.html)
- [HTDP](https://htdp.org/)

For the first steps, [this tutorial by Gavin Freeborn](https://youtu.be/n_7drg-R-YY) provides the basics for starting with Racket. Going further, there are two main videos by Matthew Flatt out there that worth watching, [DSL Embedding in Racket (1/2)](https://youtu.be/WQGh_NemRy4), which starts with a great introduction of Racket for programmers (assuming you already know something about programming in general), quickly presenting the built-in data types, from atomic to composed types, definitions, functions, lambdas, iteration, structures, and finally enters the macro overview which is the main subject of the talk, more specifically the second video of the series, [DSL Embedding in Racket (2/2)](https://youtu.be/JC3o87p_rBY). For a more detailed introduction, [this playlist](https://www.youtube.com/playlist?list=PLXaqTeMx01E_eK1ZEpKvKL5KwSaj7cJW9) by Kristopher Micinski provides what is needed.

## Cheat-sheet

In the tutorial directory, start an interactive session with `racket -i -f racketrc` (where `racketrc` is the local configurations file).

```scheme
;; Start program with language specification
#racket

;; Function calls syntax
(substring "the boy out of the country" 4 7)

;; Function definition
(define (extract str)
  (substring str 4 7))

;; The above is just syntax sugar for this
(define extract
  (lambda (str) (substring str 4 7)))

;; Include a script in REPL
(enter! "script.rkt")

;; Include a package
(require xrepl)

;; Clear REPL terminal:
(display "\033[2J\033[H")

;; Note on complex numbers (R+Ji) no spaces:
1.0+2.3i
```

```scheme
;; Simple conditionals:
(if (> 2 3) "2>3" "obviously not")

;; To avoid nested conditionals use `and`/`or:
(if (and  (> 2 3) (< 2 3)) "never" "obviously not")

;; Use cond for multiple tests
(cond
  [(> 2 3) "2>3"]
  [(< 2 3) "2<3"]
  [else "2=3"])

;; Lambda functions and maps at once:
(map (lambda (x) (sqrt x)) '(1 2 3))

;; You can also create closures:
(define (add-to-x x) (lambda (s) (+ s x)))
(map (add-to-x 2) '(3 4 5))

;; Racket is not pure-functional and scope is lexical:
(define (buzz-bing x)
  (define (buzz x) (* x x))
  (define (bing x) (+ x x))
  (bing (buzz x)))
(buzz-bing 2)

;; Another example but using `let` binding:
(define (mess-this x)
    (let ([y (random x)]
          [z (random x)])
    (+ y z x)))
(mess-this 5)

;; Use `let*` for sequential evaluation:
(define (re-mess-this x)
    (let* ([y (* x x)]  ; 25
           [z (+ y y)]) ; 50
    (+ y z x)))         ; 25 + 50 + 5 = 80
(re-mess-this 5)
```

```scheme
;; List definitions:
(define m (list 1 2 3))
(define m '(3 2 1))

;; Some operations on lists:
(length m)
(filter (lambda (x) (> x 1)) m)

;; Accumulate with `foldl`:
(define acc (lambda (elem v) (+ elem v)))
(foldl acc 0 '(2 3 4)) ; -> 9

;; empty, cons, first, rest:
(define m (cons "a" empty))
(define m (cons "c" (cons "b" m)))
(first m)
(rest m)

;; cons produce a pair if second element is not a list
(cons 1  2)
(define not-list (cons (list 1 2) 3))
(car not-list)
(cdr not-list)
(pair? not-list)
```

```scheme
;; Re-define `map` with the above:
(define (mapish f lst)
  (cond
    [(empty? lst) empty]
    [else (let ([a (f (first lst))]
                [b (mapish f (rest lst))])
                (cons a b))]))

;; Multiple step (with lazy eval?):
(define (maprest f lst)
    (mapish f (rest lst)))
(define (mapthis f lst)
    (let ([a (f (first lst))]
          [b (maprest f lst)])
          (cons a b)))
(define (mapish f lst)
  (cond [(empty? lst) empty]
        [else (mapthis f lst)]))

(mapish (lambda (x) (* x x)) '(1 2 3))
```

```scheme
(display (current-directory))
```
