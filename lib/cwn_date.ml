open! Core
open! Async

let fmt = "%Y.%m.%d"
let of_string s = Date_unix.parse ~fmt s
let to_string d = Date_unix.format d fmt

let strip_extension s =
  match Filename.split_extension s with
  | base, Some ("xml" | "org" | "html" | "rss") -> base
  | _, _ -> s
;;

let of_filename s = Option.try_with (fun () -> of_string (strip_extension s))
let arg_type = Command.Arg_type.create (fun s -> of_string (strip_extension s))
