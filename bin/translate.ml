open! Core
open! Async

(* OpenRouter prefixes provider name. Default mirrors the Anthropic-direct
   default that scripts/translate.ts used (claude-sonnet-4-6); contributors
   can override via OPENROUTER_MODEL. *)
let default_model = "anthropic/claude-sonnet-4.6"

let getenv name =
  Sys.getenv name
  |> Result.of_option
       ~error:(Error.create_s [%message "environment variable not set" ~_:(name : string)])
;;

let translate_one ~api_key ~model ~system_prompt ~ja_dir ~cwn_data_dir date =
  printf "--- Translating %s ---\n%!" date;
  let input = Filename.concat cwn_data_dir [%string "%{date}.xml"] in
  let output = Filename.concat ja_dir [%string "%{date}.xml"] in
  let%bind content = Reader.file_contents input in
  match%bind Cwn_ja_lib.Translator.translate ~api_key ~model ~system_prompt ~content with
  | Error err ->
    eprintf "FAILED: %s\n  %s\n%!" date (Error.to_string_hum err);
    return false
  | Ok translated ->
    let%map () = Writer.save output ~contents:translated in
    true
;;

let command =
  Command.async_or_error
    ~summary:"Translate cwn-data XML files to Japanese via OpenRouter."
    (let%map_open.Command file =
       flag "file" (optional string) ~doc:"DATE single date to translate (YYYY.MM.DD)"
     and since =
       flag
         "since"
         (optional string)
         ~doc:"DATE force-retranslate dates >= DATE (lexical compare)"
     and from_ref =
       flag
         "from-ref"
         (optional string)
         ~doc:"REF cwn-data git ref (paired with --to-ref)"
     and to_ref =
       flag
         "to-ref"
         (optional string)
         ~doc:"REF cwn-data git ref (paired with --from-ref)"
     and prompt_path =
       flag
         "prompt"
         (optional_with_default "scripts/prompt.md" string)
         ~doc:"FILE path to system prompt (default: scripts/prompt.md)"
     and cwn_data_dir =
       flag
         "cwn-data"
         (optional_with_default "cwn-data" string)
         ~doc:"DIR upstream submodule (default: cwn-data)"
     and ja_dir =
       flag
         "ja"
         (optional_with_default "ja" string)
         ~doc:"DIR translation output (default: ja)"
     in
     fun () ->
       let open Deferred.Or_error.Let_syntax in
       let%bind api_key = Deferred.return (getenv "OPENROUTER_API_KEY") in
       let model = Option.value (Sys.getenv "OPENROUTER_MODEL") ~default:default_model in
       let%bind system_prompt =
         Monitor.try_with_or_error (fun () -> Reader.file_contents prompt_path)
       in
       let%bind dates =
         Cwn_ja_lib.Source_set.list_dates
           ~cwn_data_dir
           ~ja_dir
           { file; since; from_ref; to_ref }
       in
       match List.is_empty dates with
       | true ->
         print_endline "No files to translate.";
         Deferred.Or_error.return ()
       | false ->
         printf
           "Found %d file(s) to translate: %s\n%!"
           (List.length dates)
           (String.concat ~sep:", " dates);
         let%bind succeeded, failed =
           Deferred.List.fold dates ~init:(0, 0) ~f:(fun (s, f) date ->
             Deferred.map
               (translate_one ~api_key ~model ~system_prompt ~ja_dir ~cwn_data_dir date)
               ~f:(function
                 | true -> s + 1, f
                 | false -> s, f + 1))
           |> Deferred.ok
         in
         printf "\nTranslation: %d succeeded, %d failed.\n%!" succeeded failed;
         (match failed with
          | 0 -> Deferred.Or_error.return ()
          | _ -> Deferred.Or_error.error_string "some translations failed"))
;;

let () = Command_unix.run command
