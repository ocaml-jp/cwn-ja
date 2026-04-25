(** Resolves translator CLI flags into the set of CWN dates to translate.
    Mirrors the discovery logic from [scripts/pipeline.ts]. *)

open! Core
open! Async

type args =
  { file : string option
  ; since : string option
  ; from_ref : string option
  ; to_ref : string option
  }

(** Returns the dates ([YYYY.MM.DD]) to translate, sorted ascending.

    - [file]: a single file (with or without [.xml]/[.org] extension); the
      upstream [.xml] must exist.
    - [from_ref] + [to_ref]: dates whose [.xml] or [.org] changed in
      [cwn_data_dir] between the two git refs.
    - Otherwise: every date for which upstream has both [.xml] and [.org];
      already-translated dates (those with [ja_dir/DATE.xml] present) are
      excluded unless [since] is set.

    [since] further filters the result to dates [>= since] in lexical order.
    It is an error to set only one of [from_ref]/[to_ref]. *)
val list_dates
  :  cwn_data_dir:string
  -> ja_dir:string
  -> args
  -> string list Or_error.t Deferred.t
