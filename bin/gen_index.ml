open! Core

let date_re = Re.compile (Re.Perl.re {|^(\d{4}\.\d{2}\.\d{2})\.html$|})

let () =
  let dir = if Array.length (Sys.get_argv ()) > 1 then (Sys.get_argv ()).(1) else "." in
  let dates =
    Sys_unix.ls_dir dir
    |> List.filter_map ~f:(fun f ->
      match Re.exec_opt date_re f with
      | Some g -> Some (Re.Group.get g 1)
      | None -> None)
    |> List.sort ~compare:String.descending
  in
  print_string (Cwn_ja_lib.Index_page.to_html ~dates)
;;
