(** Top-level [cwn_ja] CLI: a [Command.group] of every subcommand the build
    pipeline drives. Run with {!Command_unix.run}. *)

open! Core

val command : Command.t
