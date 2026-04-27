(** Builds the calendar-style [ja/index.html] from the set of translated dates. *)

open! Core

(** Years, months, and days are emitted in descending order (newest first). *)
val to_html : dates:Date.t list -> string
