open! Core
open! Async

type args =
  { file : string option
  ; since : string option
  ; from_ref : string option
  ; to_ref : string option
  }

let date_re = Re.compile (Re.Perl.re {|^(\d{4}\.\d{2}\.\d{2})\.(?:xml|org)$|})

let date_of_filename name =
  match Re.exec_opt date_re name with
  | Some g -> Some (Re.Group.get g 1)
  | None -> None
;;

let strip_date_extension name =
  match Filename.split_extension name with
  | base, Some ("xml" | "org") -> base
  | _, _ -> name
;;

let ls_dir_safe dir =
  match Sys_unix.is_directory dir with
  | `Yes -> Sys_unix.ls_dir dir
  | `No | `Unknown -> []
;;

let dates_in dir ~suffix =
  ls_dir_safe dir
  |> List.filter_map ~f:(fun f ->
    match String.is_suffix f ~suffix with
    | true -> date_of_filename f
    | false -> None)
;;

let list_dates_via_git_diff ~cwn_data_dir ~from_ref ~to_ref =
  let%map output =
    Process.run
      ~working_dir:cwn_data_dir
      ~prog:"git"
      ~args:[ "diff"; "--name-only"; from_ref; to_ref; "--"; "*.xml"; "*.org" ]
      ()
  in
  Or_error.map output ~f:(fun output ->
    String.split_lines output
    |> List.filter_map ~f:(fun line -> date_of_filename (Filename.basename line))
    |> List.dedup_and_sort ~compare:String.compare)
;;

let list_dates_default ~cwn_data_dir ~ja_dir ~since =
  let cwn_files = ls_dir_safe cwn_data_dir in
  let published =
    List.filter_map cwn_files ~f:(fun f ->
      match String.is_suffix f ~suffix:".org" with
      | true -> date_of_filename f
      | false -> None)
    |> String.Set.of_list
  in
  let xml_dates =
    List.filter_map cwn_files ~f:(fun f ->
      match String.is_suffix f ~suffix:".xml" with
      | true ->
        (match date_of_filename f with
         | Some d when Set.mem published d -> Some d
         | _ -> None)
      | false -> None)
  in
  match since with
  (* --since implies force: include even already-translated dates. *)
  | Some _ -> xml_dates
  | None ->
    let translated = String.Set.of_list (dates_in ja_dir ~suffix:".xml") in
    List.filter xml_dates ~f:(fun d -> not (Set.mem translated d))
;;

let list_dates ~cwn_data_dir ~ja_dir args =
  let validate_file_arg file =
    let date = strip_date_extension (Filename.basename file) in
    let xml_path = Filename.concat cwn_data_dir [%string "%{date}.xml"] in
    match Sys_unix.file_exists xml_path with
    | `Yes -> Or_error.return [ date ]
    | `No | `Unknown -> Or_error.errorf "File not found: %s" xml_path
  in
  let%bind dates =
    match args.file, args.from_ref, args.to_ref with
    | Some file, _, _ -> validate_file_arg file |> Deferred.return
    | None, Some from_ref, Some to_ref ->
      list_dates_via_git_diff ~cwn_data_dir ~from_ref ~to_ref
    | None, Some _, None | None, None, Some _ ->
      Deferred.Or_error.error_string "--from-ref and --to-ref must be used together"
    | None, None, None ->
      list_dates_default ~cwn_data_dir ~ja_dir ~since:args.since
      |> Or_error.return
      |> Deferred.return
  in
  Deferred.return
    (Or_error.map dates ~f:(fun dates ->
       let dates =
         match args.since with
         | None -> dates
         | Some since -> List.filter dates ~f:(fun d -> String.(d >= since))
       in
       List.sort dates ~compare:String.ascending))
;;
