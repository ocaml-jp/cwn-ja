(** Date helpers anchored on the cwn-ja project's canonical format
    ([%Y.%m.%d]) — used in upstream CWN filenames, [<cwn_date>] tags, and
    nav links. *)

open! Core

(** Parse a date string in the [YYYY.MM.DD] format. Raises if the input
    isn't in that exact shape. *)
val of_string : string -> Date.t

(** Format a date as [YYYY.MM.DD]. *)
val to_string : Date.t -> string

(** Try to parse a filename like [2026.04.21.xml] or [2026.04.21]. Returns
    [None] if the leading component isn't [\d{4}\.\d{2}\.\d{2}]. Any trailing
    extension is ignored. *)
val of_filename : string -> Date.t option

(** [Command.Arg_type] for [-file] / [-since]-style flags. Accepts both bare
    [YYYY.MM.DD] and the same with a [.xml]/[.org]/[.html]/[.rss] suffix. *)
val arg_type : Date.t Command.Arg_type.t
