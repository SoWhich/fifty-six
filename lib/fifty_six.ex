defmodule FiftySix do
  @moduledoc """
  FiftySix keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  defmodule Card do
    @distinct_values 6
    @num_suits 4
    @deck_size @distinct_values * 2 * @num_suits
    @moduledoc """
    Defines how cards work in fifty-six:

    It defines both the mappings between the internal representation
    and the displayed format, as well as the mapping between the card
    value and the points it counts for.
    """
    defstruct suit: :hearts, value: 0

    def gen_deck do
      Enum.reduce(
        [:hearts, :diamonds, :clubs, :spades],
        [],
        fn suit, acc ->
          Enum.reduce(
            Stream.concat(0..(@distinct_values - 1), 0..(@distinct_values - 1)),
            acc,
            fn value, acc -> [%Card{suit: suit, value: value}] ++ acc end
          )
        end
      )
    end

    def gen_hands(num_players) do
      Stream.zip(
        Enum.shuffle(Card.gen_deck()),
        Stream.cycle(0..(num_players - 1))
      )
      |> Enum.reduce(
        Tuple.duplicate([], num_players),
        fn {card, player}, hands ->
          Tuple.insert_at(hands, player, [card] ++ elem(hands, player))
        end
      )
    end

    def winner(champ, contender, trump) do
      cond do
        champ.suit == contender.suit and contender.value > champ.value ->
          contender

        contender.suit == trump ->
          contender

        true ->
          champ
      end
    end

    def points(card) do
      case card.value do
        0 -> 0
        1 -> 0
        2 -> 1
        3 -> 1
        4 -> 2
        5 -> 3
      end
    end

    def value_name(card) do
      case card.value do
        0 -> "Queen"
        1 -> "King"
        2 -> "10"
        3 -> "Ace"
        4 -> "9"
        5 -> "Jack"
      end
    end

    def suit_name(card) do
      case card.suit do
        :hearts -> "Hearts"
        :diamonds -> "Diamonds"
        :clubs -> "Clubs"
        :spades -> "Spades"
      end
    end

    def name(card) do
      Card.value_name(card.value) <> " of " <> Card.suit_name(card.suit)
    end
  end

  defmodule Trick do
    @moduledoc """
    Trick defines how an individual trick is structured and measured.

    """
    defstruct player_index: 0, plays: [], score: 0

    def finished?(trick, player_count) do
      length(trick.plays) == player_count
    end

    def trick_taker(trick, trump) do
      right_order_plays = Enum.reverse(trick.plays)

      Enum.reduce(
        right_order_plays,
        elem(right_order_plays, 0),
        fn new, old ->
          new_card = elem(new, 1)
          old_card = elem(old, 1)

          if Card.winner(old_card, new_card, trump) == old_card do
            old
          else
            new
          end
        end
      )
    end

    def starting_suit(trick) do
      {_, starting_card} = List.last(trick.plays)
      starting_card.suit
    end

    def play(trick, card) do
      %Trick{
        player_index: Kernel.rem(trick.player_index + 1, length(trick.players)),
        plays: [{trick.player_index, card}] ++ trick.plays,
        score: trick.score + Card.points(card)
      }
    end
  end

  defmodule BetRound do
    @moduledoc """
    BetRound keeps track of who bet what, and what the value of the bets was
    """
    defstruct hands: {}, bets: [], next_min: 28, current_bidder: 0

    def create(hands, starting_player) do
      %BetRound{
        hands: hands,
        current_bidder: starting_player
      }
    end

    def bid(%BetRound{bets: []} = round, nil) do
      bid(round, {round.next_min, :nose})
    end

    def bid(round, nil) do
      %BetRound{
        hands: round.hands,
        bets: [nil] ++ round.bets,
        next_min: round.next_min,
        current_bidder: Kernel.rem(round.current_bidder + 1, length(round.hands))
      }
    end

    def bid(round, bid) do
      %BetRound{
        hands: round.hands,
        bets: [bid] ++ round.bets,
        next_min: elem(bid, 1) + 1,
        current_bidder: Kernel.rem(round.current_bidder + 1, length(round.hands))
      }
    end
  end

  defmodule PlayRound do
    @moduledoc """
    PlayRound has tuple of players to hands, as well as a history of tricks
    """
    defstruct hands: {}, tricks: [], remaining: 0

    def create(hands, starting_player) do
      %PlayRound{
        hands: hands,
        tricks: [%Trick{player_index: starting_player, plays: [], score: 0}],
        remaining: Card.deck_size() / length(hands)
      }
    end

    def in_deck(round, player, card) do
      round.hands |> elem(player) |> Enum.find(card)
    end

    def trump_broken(round, trump) do
      Enum.any?(
        round.tricks,
        fn trick ->
          Enum.any?(
            trick.plays,
            fn play -> elem(play, 1).suit == trump end
          )
        end
      )
    end

    def all_trump(round, player, trump) do
      round.hands |> elem(player) |> Enum.all?(fn card -> card.suit == trump end)
    end

    def current_trick(round) do
      hd(round.tricks)
    end

    def can_follow_suit(round, player) do
      starting_suit = round |> PlayRound.current_trick() |> Trick.starting_suit()

      round.hands |> elem(player) |> Enum.any?(fn card -> starting_suit == card.suit end)
    end

    def legal?(round, player, card, trump) do
      current_trick = PlayRound.current_trick(round)

      if List.first(current_trick.plays) do
        starting_suit = round |> PlayRound.current_trick() |> Trick.starting_suit()

        cond do
          current_trick.player_index != player -> false
          !PlayRound.in_deck(round, player, card) -> false
          starting_suit == card.suit -> true
          can_follow_suit(round, player) -> false
          true -> true
        end
      else
        PlayRound.trump_broken(round, trump) || PlayRound.all_trump(round, player, trump)
      end
    end

    def play(round, player, card) do
      new_trick = Trick.play(PlayRound.current_trick(round), card)
      new_hand = List.delete(elem(round.hands, player), card)

      %PlayRound{
        hands: Tuple.insert_at(round.hands, player, new_hand),
        remaining:
          if Trick.finished?(new_trick) do
            round.remaining - 1
          else
            round.remaining
          end,
        tricks:
          if Trick.finished?(new_trick) do
            [%Trick{player_index: elem(Trick.trick_taker(new_trick), 1)}]
          else
            []
          end ++ [new_trick] ++ tl(round.tricks)
      }
    end

    def scores(round, trump) do
      Enum.reduce(
        round.tricks,
        {0, 0},
        fn trick, points ->
          team = Kernel.rem(elem(Trick.trick_taker(trick, trump), 0), 2)
          Tuple.insert_at(points, team, trick.points + elem(points, team))
        end
      )
    end
  end
end
