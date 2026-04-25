(lang dune 3.22)

(name cwn_ja)

(package
 (name cwn_ja)
 (depends
  (ocaml
   (>= 5.4.1))
  ppx_jane
  async
  core
  core_unix
  openrouter_api
  re
  xmlm))

; Pin openrouter_api to the v0.0.1 release tag until the package lands in
; opam-repository (ocaml/opam-repository#29745). Once merged, drop this stanza
; and re-run `dune pkg lock`.
(pin
 (url "git+https://github.com/mt-caret/openrouter-ocaml.git#v0.0.1")
 (package
  (name openrouter_api)))
