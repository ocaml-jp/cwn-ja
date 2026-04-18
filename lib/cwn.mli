(** Typed representation of an OCaml Weekly News issue and serialisers to
    org-mode and RSS. *)

open! Core

type t [@@deriving sexp_of]

val of_xmltree : Xmltree.t -> t
val to_orgmode : t -> string
val to_rss : t -> string
