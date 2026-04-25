open! Core
open! Async

(* Match the printing strategy from scripts/translate.ts:18-33: rewrite the
   same line on a TTY; emit periodic newline-terminated lines otherwise so
   batch logs stay readable. *)
module Progress = struct
  type t =
    { mutable last_chars : int
    ; mutable total_chars : int
    ; start : Time_float.t
    ; is_tty : bool
    }

  let create () =
    { last_chars = 0
    ; total_chars = 0
    ; start = Time_float.now ()
    ; is_tty = Core_unix.isatty Core_unix.stderr
    }
  ;;

  let chars_per_sec t =
    let elapsed_sec =
      Time_float.diff (Time_float.now ()) t.start |> Time_float.Span.to_sec
    in
    match Float.(elapsed_sec > 0.) with
    | true -> Float.iround_nearest_exn (Float.of_int t.total_chars /. elapsed_sec)
    | false -> 0
  ;;

  let advance t ~chars =
    t.total_chars <- t.total_chars + chars;
    let line =
      sprintf "  %d chars received (%d chars/sec)..." t.total_chars (chars_per_sec t)
    in
    match t.is_tty with
    | true -> eprintf "\r\x1b[K%s%!" line
    | false ->
      (match t.total_chars - t.last_chars >= 500 with
       | true ->
         eprintf "%s\n%!" line;
         t.last_chars <- t.total_chars
       | false -> ())
  ;;

  let finalize t =
    let elapsed_sec =
      Time_float.diff (Time_float.now ()) t.start |> Time_float.Span.to_sec
    in
    let line =
      sprintf
        "  %d chars in %.1fs (%d chars/sec)"
        t.total_chars
        elapsed_sec
        (chars_per_sec t)
    in
    match t.is_tty with
    | true -> eprintf "\r\x1b[K%s\n%!" line
    | false -> eprintf "%s\n%!" line
  ;;
end

let build_request ~model ~system_prompt ~content : Openrouter_api.Completions.Request.t =
  { model
  ; messages =
      [ Openrouter_api.Completions.Request.Message.system system_prompt
      ; Openrouter_api.Completions.Request.Message.user content
      ]
  ; stream = true
  ; reasoning = None
  ; tools = []
  ; tool_choice = None
  ; parallel_tool_calls = None
  ; plugins = []
  ; temperature = None
  ; top_p = None
  ; max_tokens = Some 128_000
  ; seed = None
  ; stop = None
  ; frequency_penalty = None
  ; presence_penalty = None
  ; repetition_penalty = None
  ; response_format = None
  }
;;

let translate ~api_key ~model ~system_prompt ~content =
  let request = build_request ~model ~system_prompt ~content in
  let%bind reader = Openrouter_api.Completions.create_stream ~api_key request in
  let buf = Buffer.create 64_000 in
  let progress = Progress.create () in
  let finish_reason = ref None in
  let stream_error = ref None in
  let%map () =
    Pipe.iter_without_pushback reader ~f:(fun chunk_result ->
      match chunk_result with
      | Error err ->
        (* Keep the first error so we report the original cause. *)
        (match !stream_error with
         | Some _ -> ()
         | None -> stream_error := Some err)
      | Ok (chunk : Openrouter_api.Completions.Stream_chunk.t) ->
        List.iter chunk.choices ~f:(fun choice ->
          (match choice.delta.content with
           | None -> ()
           | Some text ->
             Buffer.add_string buf text;
             Progress.advance progress ~chars:(String.length text));
          match choice.finish_reason with
          | None -> ()
          | Some reason -> finish_reason := Some reason))
  in
  Progress.finalize progress;
  match !stream_error with
  | Some err -> Error err
  | None ->
    let result = Buffer.contents buf in
    (match !finish_reason with
     | None | Some "stop" -> Ok result
     | Some reason ->
       Or_error.error_s
         [%message
           "Translation finished with non-stop finish_reason — output likely truncated"
             ~finish_reason:(reason : string)
             ~chars:(String.length result : int)])
;;
