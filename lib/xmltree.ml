open! Core
open! Async

type t =
  | Element of string * t list
  | Data of string
[@@deriving sexp_of]

let sanitise =
  let is_blank d = String.is_empty (String.strip d) in
  let rec clean nodes =
    List.filter_map nodes ~f:(function
      | Data d when is_blank d -> None
      | Data _ as n -> Some n
      | Element (tag, children) -> Some (Element (tag, clean children)))
  in
  function
  | Data _ as t -> t
  | Element (tag, children) -> Element (tag, clean children)
;;

let of_input input =
  let el ((_, local), _) children = Element (local, children) in
  let data d = Data d in
  snd (Xmlm.input_doc_tree ~el ~data input) |> sanitise
;;

(* Xmlm resolves XML's five predefined entities and numeric character
   references on its own; everything else is left to this callback. CWN bodies
   are technical prose, so the named HTML entities a translator is liable to
   emit are punctuation and arrows. *)
let entity =
  let html_entities =
    String.Map.of_alist_exn
      [ "nbsp", "\u{00A0}"
      ; "ensp", "\u{2002}"
      ; "emsp", "\u{2003}"
      ; "mdash", "\u{2014}"
      ; "ndash", "\u{2013}"
      ; "hellip", "\u{2026}"
      ; "lsquo", "\u{2018}"
      ; "rsquo", "\u{2019}"
      ; "ldquo", "\u{201C}"
      ; "rdquo", "\u{201D}"
      ; "laquo", "\u{00AB}"
      ; "raquo", "\u{00BB}"
      ; "copy", "\u{00A9}"
      ; "reg", "\u{00AE}"
      ; "trade", "\u{2122}"
      ; "deg", "\u{00B0}"
      ; "times", "\u{00D7}"
      ; "divide", "\u{00F7}"
      ; "middot", "\u{00B7}"
      ; "bull", "\u{2022}"
      ; "dagger", "\u{2020}"
      ; "rarr", "\u{2192}"
      ; "larr", "\u{2190}"
      ; "uarr", "\u{2191}"
      ; "darr", "\u{2193}"
      ; "harr", "\u{2194}"
      ]
  in
  fun name ->
    match Map.find html_entities name with
    | Some _ as replacement -> replacement
    (* An unknown reference is preserved verbatim rather than raising: one stray
       entity should degrade to literal text, not sink the whole build. *)
    | None -> Some [%string "&%{name};"]
;;

let of_string s = of_input (Xmlm.make_input ~entity (`String (0, s)))

let get_children_with_tag tag = function
  | Data _ -> failwith "No children found."
  | Element (_, children) ->
    List.find_map children ~f:(function
      | Element (t, cc) when String.equal t tag -> Some cc
      | _ -> None)
    |> Option.value_or_thunk ~default:(fun () ->
      raise_s [%message "no element with tag in document" (tag : string)])
;;

let get_data_with_tag tag = function
  | [] -> failwith "No children found."
  | Element (t, [ Data d ]) :: rest ->
    (match String.equal t tag with
     | true -> d, rest
     | false ->
       raise_s
         [%message "wrong tag on first child" ~expected:(tag : string) ~found:(t : string)])
  | _ -> failwith "The first child has no tag."
;;

let find_data_with_tag tag = function
  | Element (t, [ Data d ]) :: rest when String.equal t tag -> Some (d, rest)
  | _ -> None
;;

let get_children = function
  | Element (_, c) -> c
  | Data _ -> []
;;
