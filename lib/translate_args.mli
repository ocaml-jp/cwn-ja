(** Parsed CLI flags for the [translate] subcommand, plus their resolution
    into the set of CWN dates to translate. *)

open! Core
open! Async

type t =
  { file : Date.t option
  ; since : Date.t option
  ; from_ref : string option
  ; to_ref : string option
  }

(** Returns the dates to translate, sorted ascending.

    - [file]: a single date; the upstream [.xml] must exist.
    - [from_ref] + [to_ref]: dates whose [.xml] or [.org] changed in
      [cwn_data_dir] between the two git refs.
    - Otherwise: every date for which upstream has both [.xml] and [.org];
      already-translated dates (those with [ja_dir/<date>.xml] present) are
      excluded unless [since] is set.

    [since] further filters the result to dates [>= since].
    It is an error to set only one of [from_ref]/[to_ref]. *)
val list_dates
  :  cwn_data_dir:string
  -> ja_dir:string
  -> t
  -> Date.t list Or_error.t Deferred.t
