(** Builds the calendar-style [ja/index.html] from the set of translated dates. *)

open! Core

(** [to_html ~dates] expects each entry of [dates] to be a [YYYY.MM.DD] string,
    pre-sorted in display order (newest first). Dates are grouped by year, then
    by month, in the order they appear in the input list. *)
val to_html : dates:string list -> string
