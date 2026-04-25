open! Core

(* Upstream keeps a sliding window of ~10 most recent items. *)
let max_items = 10

let date_re = Re.compile (Re.Perl.re {|^\d{4}\.\d{2}\.\d{2}\.rss$|})
let xml_decl_re = Re.compile (Re.Perl.re {|^<\?xml[^?]*\?>\s*|})

let () =
  let dir = if Array.length (Sys.get_argv ()) > 1 then (Sys.get_argv ()).(1) else "." in
  let fragments =
    Sys_unix.ls_dir dir
    |> List.filter ~f:(Re.execp date_re)
    |> List.sort ~compare:String.descending
    |> Fn.flip List.take max_items
  in
  let items =
    List.map fragments ~f:(fun f ->
      In_channel.read_all (Filename.concat dir f)
      |> Re.replace_string xml_decl_re ~by:""
      |> String.rstrip)
  in
  print_string (Cwn_ja_lib.Cwn_rss.to_xml ~items)
;;
