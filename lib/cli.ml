open! Core

let run ~language file =
  let cwn = Xmltree.of_file file |> Cwn.of_xmltree in
  let base, _ext = Filename.split_extension file in
  Out_channel.write_all (base ^ ".org") ~data:(Cwn.to_orgmode ~language cwn);
  Out_channel.write_all (base ^ ".rss") ~data:(Cwn.to_rss ~language cwn)
;;

let command =
  Command.basic
    ~summary:"Convert a CWN XML file into org-mode and RSS files."
    (let%map_open.Command file = anon ("FILE" %: string)
     and japanese =
       flag
         "-japanese"
         no_arg
         ~doc:" emit Japanese boilerplate, nav links, and RSS URLs"
     in
     fun () ->
       let language : Language.t =
         match japanese with
         | true -> Japanese
         | false -> English
       in
       run ~language file)
;;
