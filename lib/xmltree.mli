(** A simplified XML tree used to parse CWN XML files.

    Wraps {!Xmlm} with a stripped-down representation — elements carry a
    local tag name and a list of children; text nodes are {!Data}.
    Whitespace-only text nodes between elements (the artefacts of
    pretty-printed XML) are discarded on parse. *)

open! Core

type t =
  | Element of string * t list
  | Data of string
[@@deriving sexp_of]

val of_string : string -> t

(** [get_children_with_tag tag tree] returns the children of the first
    element child of [tree] whose tag is [tag]. Raises [Failure] if no
    such child exists. *)
val get_children_with_tag : string -> t -> t list

(** [get_data_with_tag tag children] expects the head of [children] to be
    [Element (tag, [ Data d ])]. Returns [d] together with the remaining
    siblings. Raises [Failure] otherwise. *)
val get_data_with_tag : string -> t list -> string * t list

val get_children : t -> t list
