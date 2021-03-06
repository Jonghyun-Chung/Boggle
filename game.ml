open Board
open Word
open Allwords

type player = {
  name: string;
  words : string list;
  points : int;
  has_turn : bool;
}

type t = {
  players: player list;
  board:  Board.t;
  possible_words: string list
}

let get_player_names game = 
  let rec get_players_helper acc = function
    | [] -> acc
    | h::t -> get_players_helper (h.name::acc) t in
  get_players_helper [] game.players

let get_players_left game = 
  let rec get_players_left_helper acc = function
    | [] -> acc
    | h::t -> if h.has_turn 
      then get_players_left_helper (h.name::acc) t 
      else get_players_left_helper acc t in
  get_players_left_helper [] game.players

(** [get_player game player_name] is the player represented in the game [game] 
    by name [player_name]. Fails if there is not exactly one player with the
    name [player_name] in the game [game]. *)
let get_player game player_name =
  let my_player = List.filter (fun e -> e.name = player_name) game.players in
  match my_player with 
  | [] -> failwith "No player with this name."
  | [p] -> p
  | _ -> failwith "More than one player with this name."

let get_words_of_player game player_name = 
  let my_player = get_player game player_name in
  my_player.words

let get_score_of_player game player_name = 
  let my_player = get_player game player_name in
  my_player.points

let get_turn_of_player game player_name = 
  let my_player = get_player game player_name in 
  my_player.has_turn

let rec no_turns_left = function
  | [] -> true
  | h::t -> 
    if h.has_turn = true 
    then false 
    else no_turns_left t

(** [update_player player_name player_words points] is an instance of an
    of an updated player [player_name] with words [player_words] and points 
    [points]. *)
let update_player player_name player_words points turn= 
  {
    name = player_name;
    words = player_words;
    points = points;
    has_turn = turn;
  }

let set_score_of_player game player_name score =
  let new_players = List.filter (fun e -> e.name <> player_name) game.players in 
  let old_player = get_player game player_name in 
  let updated_player = 
    update_player player_name old_player.words score old_player.has_turn in 

  {
    players = updated_player :: new_players;
    board = game.board;
    possible_words = game.possible_words
  }

(** [update_player_turn acc player players] is the list of players that contains
    list of [players] where only a [player] has false as its has_turn field.*)
let rec update_player_turn acc player = function
  | [] -> acc
  | h::t -> if h.name = player.name
    then update_player_turn (update_player player.name player.words 
                               player.points false::acc) player t
    else update_player_turn (h::acc) player t

let expire_turn game player_name = 
  let updated_players = game.players
                        |> update_player_turn [] (get_player game player_name)
                        |> List.rev in
  {
    players = updated_players;
    board = game.board;
    possible_words = game.possible_words
  }

(** [update_player_words acc player_name new_words players] is a player list 
    generated by players [players] where player [player_name] has words
    [new_words]. *)
let rec update_player_words acc player new_words word = function
  | [] -> acc
  | h::t -> if h.name = player.name 
    then update_player_words 
        (update_player player.name new_words 
           player.points true::acc) player new_words word t
    else update_player_words (h::acc) player new_words word t

let add_word game player_name word = 
  let word = String.lowercase_ascii word in
  let old_words = get_words_of_player game player_name in
  if List.mem word old_words || 
     legal_word_in_board word game.board = false ||
     is_word word = false || 
     is_english_word word = false 
  then game
  else 
    begin
      let new_words = word::old_words |> List.sort_uniq compare in
      let updated_players = game.players 
                            |> update_player_words [] (get_player game 
                                                         player_name) 
                              new_words word
                            |> List.rev in
      {
        players = updated_players;
        board = game.board;
        possible_words = game.possible_words
      }
    end

(** [init_player player_name] is an initialized player for [player_name]. *)
let init_player player_name = 
  {
    name = player_name;
    words = [];
    points = 0;
    has_turn = true;
  }

(** [init_players acc player_names] is a player list given player names 
    [player_names] starting from accumulator [acc]. *)
let rec init_players acc = function
  | [] -> acc
  | h::t -> init_players (init_player h::acc) t

let init_game board player_names = 
  {
    players = (init_players [] player_names)|>List.rev;
    board = board; 
    possible_words = Allwords.valid_words board 8;
  }

(** [other_player_words players player_name] retrieves the words of every player
    in [game] except for that of the player with [player_name] *)
let rec other_player_words players player_name words=
  match players with
  | [] -> words
  | h::t -> 
    if h.name = player_name 
    then other_player_words t player_name words
    else other_player_words t player_name (h.words @ words)


(** [update_final_scores_helper game players] updates the final score
    for each [player] of [players] in [game] *)
let rec update_final_scores_helper players game = 
  match players with 
  | [] -> game
  | h::t -> 
    other_player_words game.players h.name []
    |> player_score h.words
    |> Int.add h.points 
    |> set_score_of_player game h.name 
    |> update_final_scores_helper t 

let update_final_scores game =
  update_final_scores_helper game.players game 

let rec string_of_list acc = function 
  | [] -> acc
  | e::[] -> e^acc
  | e::l -> string_of_list (", "^e^acc) l

let rec print_words game = function
  | [] -> print_endline "";
  | h::t -> print_endline ("In this round "^ h.name ^ " found the words: " ^ 
                           ((get_words_of_player game h.name)
                            |> List.rev 
                            |> string_of_list "")); 
    print_words game t 

let rec print_scores game = function
  | [] -> print_endline "";
  | h::t -> print_endline ("After this round "^h.name^"'s total score is "^ 
                           string_of_int 
                             (get_score_of_player game h.name)); 
    print_scores game t

let rec who_won = function
  | [] -> failwith "None"
  | h::[] -> h
  | h::t -> let a = who_won t in
    if a.points > h.points then a else h

let rec print_who_won game players = 
  let print_statement = 
    (who_won game.players).name ^" is currently winning the game! \n" in
  match players with
  | [] -> failwith "Failure"
  | h::[] -> print_endline "The game is a draw!"
  | h::t -> 
    if h.points = (List.hd t).points 
    then print_who_won game t 
    else print_endline print_statement

(** [give_ranking player_name player_score max_score] calculates the 
    ranking of a player based on the [max_score] and prints out
    the [player_name] and according rank. *)
let give_ranking player_name player_score max_score = 
  let rank_score = 
    if player_score = 0
    then 10
    else max_score / player_score in 
  if rank_score <= 2 
  then print_endline ("In this round " ^ player_name ^ 
                      " achieved platinum rank. "^
                      "They got at least 50% of all words!")
  else if rank_score <= 3
  then print_endline ("In this round " ^ player_name ^ 
                      " achieved gold rank. "^
                      "They got at least 33% of all words!")
  else if rank_score <= 6 
  then print_endline ("In this round " ^ player_name ^ 
                      " achieved silver rank. "^
                      "They got at least 17% of all words!")
  else print_endline ("In this round " ^ player_name ^ 
                      " achieved bronze rank. "^
                      "They got less than 17% of all words! ")

(** [print_ranking_helper] is a helper function for print_rankings that prints
    the scores [score] of the players [players]. *)
let rec print_rankings_helper players max_score = 
  match players with 
  | [] -> print_endline 
            ("\nThe maximum possible score this round was " ^ 
             (string_of_int max_score))
  | h::t -> 
    give_ranking h.name h.points max_score;
    print_rankings_helper t max_score

let print_rankings game =
  let max_score = player_score (game.possible_words) [] in 
  print_rankings_helper game.players max_score

let print_all_words game = 
  print_endline ("\nHow strong is your vocabulary? Keep in mind that we "^
                 "reference a very \nlarge dictionary so some words may be "^
                 "abbreviations you might not recognize.\n"^
                 "\nThese are some possible words on this board:\n");
  game.possible_words
  |> List.map (fun str -> str ^ " ")
  |> List.map (fun str -> String.lowercase_ascii str)
  |> List.map (print_string)
  |> (fun _ -> ())

