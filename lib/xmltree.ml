open! Core

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

let of_channel ic = of_input (Xmlm.make_input (`Channel ic))
let of_string s = of_input (Xmlm.make_input (`String (0, s)))
let of_file filename = In_channel.with_file filename ~f:of_channel

let get_children_with_tag tag = function
  | Data _ -> failwith "No children found."
  | Element (_, children) ->
    List.find_map children ~f:(function
      | Element (t, cc) when String.equal t tag -> Some cc
      | _ -> None)
    |> Option.value_exn
         ~message:[%string "No element with tag %{tag} in the document."]
;;

let get_data_with_tag tag = function
  | [] -> failwith "No children found."
  | Element (t, [ Data d ]) :: rest ->
    if String.equal t tag
    then d, rest
    else failwithf "Wrong tag on first child: expected %S, found %S." tag t ()
  | _ -> failwith "The first child has no tag."
;;

let get_children = function
  | Element (_, c) -> c
  | Data _ -> []
;;
