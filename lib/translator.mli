(** Async wrapper around [Openrouter_api.Completions.create_stream] tailored
    for the CWN translation flow: streams the response with progress logging
    and validates that the model finished with [finish_reason = "stop"]. *)

open! Core
open! Async

(** [translate ~api_key ~model ~system_prompt ~content] sends [content] as the
    user message, [system_prompt] as the system message, and accumulates the
    streamed text deltas. A non-["stop"] [finish_reason] is treated as an
    error since it usually means the output was truncated. *)
val translate
  :  api_key:string
  -> model:string
  -> system_prompt:string
  -> content:string
  -> string Or_error.t Deferred.t
