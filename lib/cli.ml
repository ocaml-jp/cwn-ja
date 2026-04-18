open! Core

let run file =
  let cwn = Xmltree.of_file file |> Cwn.of_xmltree in
  let base, _ext = Filename.split_extension file in
  Out_channel.write_all (base ^ ".org") ~data:(Cwn.to_orgmode cwn);
  Out_channel.write_all (base ^ ".rss") ~data:(Cwn.to_rss cwn)
;;

let command =
  Command.basic
    ~summary:"Convert a CWN XML file into org-mode and RSS files."
    (let%map_open.Command file = anon ("FILE" %: string) in
     fun () -> run file)
;;
