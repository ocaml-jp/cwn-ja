open! Core
open! Async

type t =
  { file : Date.t option
  ; since : Date.t option
  ; from_ref : string option
  ; to_ref : string option
  }

let ls_dir_safe dir =
  match%bind Sys.is_directory dir with
  | `Yes -> Sys.ls_dir dir
  | `No | `Unknown -> return []
;;

let dates_in dir ~suffix =
  let%map files = ls_dir_safe dir in
  List.filter_map files ~f:(fun f ->
    match String.is_suffix f ~suffix with
    | true -> Cwn_date.of_filename f
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
    |> List.filter_map ~f:(fun line -> Cwn_date.of_filename (Filename.basename line))
    |> List.dedup_and_sort ~compare:Date.compare)
;;

let list_dates_default ~cwn_data_dir ~ja_dir ~since =
  let%bind cwn_files = ls_dir_safe cwn_data_dir in
  let pull_dates ~suffix =
    List.filter_map cwn_files ~f:(fun f ->
      match String.is_suffix f ~suffix with
      | true -> Cwn_date.of_filename f
      | false -> None)
  in
  let published = Date.Set.of_list (pull_dates ~suffix:".org") in
  let xml_dates =
    pull_dates ~suffix:".xml"
    |> List.filter ~f:(Set.mem published)
  in
  match since with
  (* --since implies force: include even already-translated dates. *)
  | Some _ -> return xml_dates
  | None ->
    let%map translated_list = dates_in ja_dir ~suffix:".xml" in
    let translated = Date.Set.of_list translated_list in
    List.filter xml_dates ~f:(fun d -> not (Set.mem translated d))
;;

let list_dates ~cwn_data_dir ~ja_dir { file; since; from_ref; to_ref } =
  let validate_file_arg date =
    let xml_path =
      Filename.concat cwn_data_dir [%string "%{date#Cwn_date}.xml"]
    in
    match%map Sys.file_exists xml_path with
    | `Yes -> Or_error.return [ date ]
    | `No | `Unknown ->
      Or_error.error_s [%message "file not found" (xml_path : string)]
  in
  let%bind dates =
    match file, from_ref, to_ref with
    | Some date, _, _ -> validate_file_arg date
    | None, Some from_ref, Some to_ref ->
      list_dates_via_git_diff ~cwn_data_dir ~from_ref ~to_ref
    | None, Some _, None | None, None, Some _ ->
      Deferred.Or_error.error_string "--from-ref and --to-ref must be used together"
    | None, None, None ->
      let%map dates = list_dates_default ~cwn_data_dir ~ja_dir ~since in
      Or_error.return dates
  in
  Deferred.return
    (Or_error.map dates ~f:(fun dates ->
       let dates =
         match since with
         | None -> dates
         | Some since -> List.filter dates ~f:(fun d -> Date.(d >= since))
       in
       List.sort dates ~compare:Date.compare))
;;
